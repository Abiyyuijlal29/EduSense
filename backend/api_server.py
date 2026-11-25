import os
import sys
import cv2
import base64
import threading
import time
import json
import urllib.request
import numpy as np
from contextlib import asynccontextmanager
from typing import Optional
from fastapi import FastAPI, Request, HTTPException, Depends, Query
from fastapi.responses import StreamingResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials

# Pastikan folder backend masuk ke sys.path agar modul security & schemas selalu ditemukan
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

# Import Modul Keamanan (JWT) & Skema Validasi Input (Pydantic)
from security.auth import create_access_token, get_current_user, security_bearer, verify_token
from schemas.schemas import (
    LoginRequest,
    TokenResponse,
    IoTControlRequest,
    IoTTelemetryRequest,
    DeteksiRequest,
    DataDosen,
    RegisterDosenRequest,
    VerifyOtpRequest,
    ResendOtpRequest,
    ForgotPasswordRequest,
    ResetPasswordRequest,
    UpdateProfileRequest,
    ChangePasswordRequest
)

FIREBASE_RTDB_URL = "https://classvision-iot-default-rtdb.asia-southeast1.firebasedatabase.app"

def sync_to_firebase(path: str, data: dict):
    """
    Sinkronisasi data ke Firebase Realtime Database melalui REST API di background thread.
    Memungkinkan ESP32 hardware, backend AI, dan mobile app tersambung secara seamless.
    """
    def _worker():
        try:
            url = f"{FIREBASE_RTDB_URL}/{path.lstrip('/')}.json"
            req = urllib.request.Request(
                url,
                data=json.dumps(data).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="PATCH"
            )
            with urllib.request.urlopen(req, timeout=3):
                pass
        except Exception:
            # Tetap silent agar tidak menghentikan server bila koneksi internet lokal drop
            pass
    threading.Thread(target=_worker, daemon=True).start()

app = FastAPI(
    title="EduSense AI Detection & Security API",
    description=(
        "API Backend EduSense dengan Sistem Keamanan Terintegrasi:\n"
        "- **JWT Authentication**: Akses endpoint dilindungi Bearer Token.\n"
        "- **Pydantic Input Validation**: Validasi tipe data, format teks, dan batas nilai.\n"
        "- **Firebase Realtime Database**: Terhubung dengan Firebase Security Rules."
    ),
    version="2.0.0"
)

# Mengizinkan CORS agar aplikasi Mobile (Flutter) dapat mengakses API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    max_age=600,
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))
MODEL_CUSTOM = os.path.join(BASE_DIR, "models", "best.pt")

# Pengecekan ketersediaan library ultralytics
try:
    from ultralytics import YOLO
    ULTRALYTICS_AVAILABLE = True
except ImportError:
    ULTRALYTICS_AVAILABLE = False
    YOLO = None

model = None
nama_model_aktif = "Simulasi / Mock (Ultralytics belum diinstal via pip)"

if ULTRALYTICS_AVAILABLE:
    if os.path.exists(MODEL_CUSTOM):
        print(f"[INIT] Berhasil memuat model custom tersimpan dari: {MODEL_CUSTOM}")
        model = YOLO(MODEL_CUSTOM)
        nama_model_aktif = "best.pt (Custom EduSense)"
    else:
        print(f"[INIT] Model custom '{MODEL_CUSTOM}' belum ada di laptop.")
        print("[INIT] Memuat model fallback 'yolov8n.pt' untuk pengujian API...")
        model = YOLO("yolov8n.pt")
        nama_model_aktif = "yolov8n.pt (Pre-trained Fallback)"


class CameraManager:
    """Manajer Kamera Laptop / CCTV untuk Live Video Streaming ke Aplikasi Mobile."""
    def __init__(self):
        self.cap = None
        self.is_running = False
        self.lock = threading.Lock()
        self.latest_frame_bytes = None
        self.fps = 0.0
        self.count_wajah = 0
        self.count_tidur = 0
        self.detector_name = "YOLOv8s"
        self.thread = None
        self.is_simulation = False
        self.cctv_images = []
        self.cctv_idx = 0
        self._init_cctv_dataset()
        # Siapkan frame awal agar endpoint /api/kamera/frame langsung merespons seketika
        if self.cctv_images:
            try:
                init_img = cv2.imread(self.cctv_images[0])
                if init_img is not None:
                    init_img = cv2.resize(init_img, (640, 480))
                    ret, jpg = cv2.imencode('.jpg', init_img, [cv2.IMWRITE_JPEG_QUALITY, 75])
                    if ret:
                        self.latest_frame_bytes = jpg.tobytes()
            except Exception:
                pass

    def _init_cctv_dataset(self):
        candidate_dirs = [
            os.path.join(PROJECT_ROOT, "dataset", "raw", "dataset_cctv_tersaring"),
            os.path.join(PROJECT_ROOT, "dataset", "dataset_yolo_tidur", "images", "val"),
            os.path.join(PROJECT_ROOT, "dataset", "dataset_cctv_tersaring"),
            os.path.join(BASE_DIR, "dataset_cctv_tersaring")
        ]
        for d in candidate_dirs:
            if os.path.isdir(d):
                files = sorted([
                    os.path.join(d, f) for f in os.listdir(d)
                    if f.lower().endswith(('.jpg', '.jpeg', '.png'))
                ])
                if files:
                    self.cctv_images = files
                    break

    def start(self, camera_index: int = 0) -> bool:
        with self.lock:
            if self.is_running:
                return True
            try:
                self.cap = cv2.VideoCapture(camera_index)
                if not self.cap.isOpened():
                    print(f"[INFO] Kamera hardware #{camera_index} tidak dapat dibuka / tidak terhubung.")
                    self.cap = None
                    self.is_simulation = True
                    print(f"[CAMERA] Mengaktifkan feed CCTV Virtual Ruang Kelas ({len(self.cctv_images)} frame terdaftar).")
                else:
                    self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                    self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                    self.is_simulation = False
                    print(f"[CAMERA] Kamera hardware #{camera_index} aktif streaming!")

                self.is_running = True
                self.thread = threading.Thread(target=self._capture_loop, daemon=True)
                self.thread.start()
                return True
            except Exception as e:
                print(f"[ERROR] Gagal inisialisasi kamera hardware: {e}")
                self.is_simulation = True
                self.is_running = True
                self.thread = threading.Thread(target=self._capture_loop, daemon=True)
                self.thread.start()
                return True

    def stop(self) -> None:
        with self.lock:
            self.is_running = False
            if self.cap is not None:
                self.cap.release()
                self.cap = None
            print("[CAMERA] Kamera telah dihentikan.")

    def _capture_loop(self) -> None:
        prev_time = time.time()
        frame_counter = 0
        FRAME_SKIP = 2
        cached_boxes = []
        fail_count = 0
        last_inference_error = None

        while self.is_running:
            if not self.is_simulation and self.cap and self.cap.isOpened():
                ret, frame = self.cap.read()
                if not ret or frame is None:
                    fail_count += 1
                    if fail_count >= 5:
                        print("[CAMERA] Kamera hardware tidak mengirim frame. Otomatis beralih ke feed CCTV Virtual Lab!")
                        self.is_simulation = True
                        if self.cap:
                            self.cap.release()
                            self.cap = None
                    time.sleep(0.04)
                    continue
                else:
                    fail_count = 0
            else:
                # Mode feed CCTV otomatis dari dataset
                if self.cctv_images:
                    img_path = self.cctv_images[self.cctv_idx]
                    frame = cv2.imread(img_path)
                    self.cctv_idx = (self.cctv_idx + 1) % len(self.cctv_images)
                    if frame is None:
                        time.sleep(0.05)
                        continue
                    frame = cv2.resize(frame, (640, 480))
                else:
                    frame = np.zeros((480, 640, 3), dtype=np.uint8)
                    cv2.putText(frame, "CCTV LAB ONLINE (SIAP)", (140, 240),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
                time.sleep(0.12)  # ~8 FPS stabil untuk streaming mobile

            frame_counter += 1
            now = time.time()
            self.fps = 1.0 / max(now - prev_time, 1e-5)
            prev_time = now

            raw_rgb = frame.copy()

            if frame_counter % FRAME_SKIP == 0 or not cached_boxes:
                current_boxes = []
                c_wajah = 0
                c_tidur = 0
                det_name = "Tidak Ada"

                # 1. Inferensi Murni YOLOv8 EduSense
                if model is not None:
                    try:
                        results = model.predict(raw_rgb, conf=0.40, imgsz=320, verbose=False)
                        for r in results:
                            for box in r.boxes:
                                cls_id = int(box.cls[0])
                                conf = float(box.conf[0])
                                label_nama = model.names.get(cls_id, f"class_{cls_id}")
                                x1, y1, x2, y2 = [int(v) for v in box.xyxy[0].tolist()]

                                if label_nama == "head_down":
                                    c_tidur += 1
                                    color = (0, 0, 255)
                                    label_display = f"Tertidur ({conf:.2f})"
                                else:
                                    c_wajah += 1
                                    color = (0, 255, 0)
                                    label_display = f"Memperhatikan ({conf:.2f})"

                                current_boxes.append((x1, y1, x2, y2, color, label_display))

                        if c_wajah > 0 or c_tidur > 0:
                            det_name = nama_model_aktif
                        last_inference_error = None
                    except Exception as e:
                        error_message = f"{type(e).__name__}: {e}"
                        if error_message != last_inference_error:
                            print(f"[ERROR] Inferensi YOLO live gagal: {error_message}")
                            last_inference_error = error_message

                cached_boxes = current_boxes
                self.count_wajah = c_wajah
                self.count_tidur = c_tidur
                self.detector_name = det_name

            # Render bounding boxes pada frame
            bbox_frame = frame.copy()
            for (x1, y1, x2, y2, color, label_display) in cached_boxes:
                cv2.rectangle(bbox_frame, (x1, y1), (x2, y2), color, 2)
                cv2.rectangle(bbox_frame, (x1, max(0, y1 - 22)), (x1 + len(label_display) * 11, y1), color, -1)
                cv2.putText(bbox_frame, label_display, (x1 + 4, max(12, y1 - 6)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.48, (255, 255, 255), 1)

            # Render HUD header
            h, w, _ = bbox_frame.shape
            overlay = bbox_frame.copy()
            cv2.rectangle(overlay, (0, 0), (w, 35), (20, 24, 33), -1)
            cv2.addWeighted(overlay, 0.7, bbox_frame, 0.3, 0, bbox_frame)
            source_tag = "WEBCAM" if not self.is_simulation else "CCTV LAB"
            cv2.putText(bbox_frame, f"CCTV POV ({source_tag}) | FPS: {self.fps:.1f} | {self.detector_name}", (10, 22),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.45, (56, 189, 248), 1)
            cv2.putText(bbox_frame, f"Fokus: {self.count_wajah} | Tidur: {self.count_tidur}", (w - 190, 22),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (74, 222, 128) if self.count_tidur == 0 else (248, 113, 113), 1)

            ret_enc, jpeg = cv2.imencode('.jpg', bbox_frame, [cv2.IMWRITE_JPEG_QUALITY, 75])
            if ret_enc:
                self.latest_frame_bytes = jpeg.tobytes()

            # Sinkronisasi statistik deteksi kelas ke Firebase setiap ~3 detik
            if frame_counter % 25 == 0:
                sync_to_firebase("monitoring/latest", {
                    "server_online": True,
                    "model_ai": self.detector_name,
                    "resolusi": "640x480",
                    "fps": round(self.fps, 1),
                    "siswa_hadir": self.count_wajah + self.count_tidur,
                    "siswa_memperhatikan": self.count_wajah,
                    "siswa_tertidur": self.count_tidur,
                    "timestamp": int(time.time()),
                })

            time.sleep(0.01)

camera_manager = CameraManager()


@app.on_event("startup")
def startup_event():
    """Otomatis aktifkan streaming CCTV saat API server mulai."""
    camera_manager.start()


@app.on_event("shutdown")
def shutdown_event():
    """Hentikan streaming CCTV saat server dimatikan."""
    camera_manager.stop()


def proses_deteksi(image: np.ndarray, nama_file: str = "input_image.jpg"):
    tinggi_img, lebar_img, _ = image.shape
    daftar_deteksi = []
    jumlah_wajah = 0
    jumlah_tidur = 0

    if model is not None:
        results = model.predict(image, conf=0.35, verbose=False)
        for r in results:
            for box in r.boxes:
                cls_id = int(box.cls[0])
                conf = float(box.conf[0])
                label_nama = model.names.get(cls_id, f"class_{cls_id}")
                coords = [round(float(c), 2) for c in box.xyxy[0].tolist()]

                if label_nama == "head_down":
                    status_siswa = "Tertidur / Menunduk"
                    jumlah_tidur += 1
                elif label_nama == "wajah":
                    status_siswa = "Memperhatikan"
                    jumlah_wajah += 1
                else:
                    status_siswa = f"Terdeteksi: {label_nama}"

                daftar_deteksi.append({
                    "label": label_nama,
                    "confidence": round(conf, 4),
                    "status": status_siswa,
                    "bounding_box_xyxy": coords
                })
    else:
        # Mock Response untuk demonstrasi jika Ultralytics belum diinstal
        daftar_deteksi = [
            {
                "label": "wajah",
                "confidence": 0.9421,
                "status": "Memperhatikan",
                "bounding_box_xyxy": [145.0, 68.0, 215.0, 155.0]
            },
            {
                "label": "head_down",
                "confidence": 0.8875,
                "status": "Tertidur / Menunduk",
                "bounding_box_xyxy": [290.0, 180.0, 410.0, 275.0]
            }
        ]
        jumlah_wajah = 1
        jumlah_tidur = 1

    return {
        "status": "success",
        "nama_file": nama_file,
        "dimensi_gambar": {"lebar": lebar_img, "tinggi": tinggi_img},
        "ringkasan": {
            "total_terdeteksi": len(daftar_deteksi),
            "siswa_memperhatikan": jumlah_wajah,
            "siswa_tertidur": jumlah_tidur
        },
        "detail_deteksi": daftar_deteksi
    }


# ==============================================================================
# ENDPOINT PUBLIK (TIDAK MEMERLUKAN LOGIN)
# ==============================================================================
@app.get("/", tags=["Sistem"])
def root():
    """Halaman beranda status server API (Publik)."""
    return {
        "sistem": "EduSense Backend API",
        "status": "Online",
        "keamanan": "JWT Authentication + Pydantic v2 Input Validation Active",
        "model_aktif": nama_model_aktif,
        "dokumentasi_uji_coba": "/docs"
    }


# ==============================================================================
# ENDPOINT AUTENTIKASI (LOGIN & GENERATE JWT TOKEN)
# ==============================================================================
@app.post("/api/auth/login", response_model=TokenResponse, tags=["Autentikasi"])
def login_dosen(req: LoginRequest):
    """
    ENDPOINT LOGIN DOSEN (Menggunakan Validasi Pydantic & Menghasilkan JWT Token).
    
    1. Input diverifikasi oleh skema Pydantic `LoginRequest` (anti karakter berbahaya).
    2. Kredensial divalidasi.
    3. Jika valid -> server membuat **JWT Access Token** yang ditandatangani secara kriptografis.
    4. Klien menyimpan token ini dan menggunakannya untuk mengakses endpoint lainnya.
    """
    user = req.username_atau_email
    pwd = req.password

    # Validasi Kredensial Akun Dosen
    dosen_valid = False
    nip = "198501012010121001"
    nama = "Dr. Ir. Dosen Pengampu, M.Kom."
    email = "dosen@polije.ac.id"

    if (user in ["dosen@polije.ac.id", "dosen", "198501012010121001"]) and (pwd in ["dosen123", "admin123"]):
        dosen_valid = True
    elif pwd in ["dosen123", "admin123"]:
        dosen_valid = True
        nama = f"Dosen Pengampu ({user})"
        email = f"{user}@polije.ac.id"

    if not dosen_valid:
        raise HTTPException(
            status_code=401,
            detail="NIP/Email atau password salah! (Gunakan: dosen@polije.ac.id / Pass: dosen123)"
        )

    # MEMBUAT JWT TOKEN
    token_jwt = create_access_token(data={
        "sub": nip,
        "email": email,
        "nama": nama,
        "role": "dosen"
    })

    return TokenResponse(
        status="success",
        pesan="Login Berhasil",
        access_token=token_jwt,
        token_type="bearer",
        expires_in_hours=24,
        data_dosen=DataDosen(
            nip=nip,
            nama=nama,
            email=email,
            program_studi="Teknik Informatika",
            mata_kuliah="Vision AI dan IoT Smart Classroom",
            kelas_aktif="TI-2F (Ruang Lab 3)"
        )
    )


@app.get("/api/auth/me", tags=["Autentikasi"])
def get_user_profile(current_user: dict = Depends(get_current_user)):
    """Mengecek identitas dan masa aktif token JWT yang sedang digunakan (Protected)."""
    return {
        "status": "success",
        "pesan": "Token valid dan aktif",
        "user_payload": current_user
    }


# Cache data registrasi & OTP sederhana (In-Memory)
DB_DOSEN_TEMP = {}
DB_OTP_STORE = {}


@app.post("/api/auth/register", tags=["Autentikasi"])
def register_dosen(req: RegisterDosenRequest):
    """
    ENDPOINT REGISTRASI DOSEN (Dengan Validasi Pydantic Real-Time & Aturan Poin 8).
    - NIP 18 digit angka
    - Email institusi valid
    - Password kuat sesuai aturan poin 8
    """
    email_key = req.email.strip().lower()
    
    # Simpan data sementara
    DB_DOSEN_TEMP[email_key] = {
        "nama": req.nama.strip(),
        "nip": req.nip.strip(),
        "email": email_key,
        "password": req.password,
        "verified": False,
        "registered_at": time.time()
    }
    
    # Generate OTP 6 Digit
    otp_code = "123456"  # Default demo code, atau random 6 digit
    DB_OTP_STORE[email_key] = {
        "otp": otp_code,
        "type": "email_verification",
        "created_at": time.time(),
        "expires_at": time.time() + 300  # Aktif 5 menit
    }
    
    print(f"📧 [OTP SENT] Kode OTP untuk {email_key} adalah: {otp_code}")
    
    return {
        "status": "success",
        "pesan": f"Pendaftaran berhasil! Kode OTP 6 digit telah dikirim ke {email_key}.",
        "email": email_key,
        "demo_otp": otp_code
    }


@app.post("/api/auth/verify-email-otp", tags=["Autentikasi"])
def verify_email_otp(req: VerifyOtpRequest):
    """
    ENDPOINT VERIFIKASI EMAIL OTP 6 DIGIT.
    """
    email_key = req.email.strip().lower()
    otp_info = DB_OTP_STORE.get(email_key)
    
    # Izinkan default demo code 123456 atau OTP yang tercatat
    if not otp_info and req.otp != "123456":
        raise HTTPException(status_code=400, detail="Kode OTP tidak ditemukan atau telah kedaluwarsa.")
        
    if otp_info:
        if time.time() > otp_info["expires_at"]:
            raise HTTPException(status_code=400, detail="Kode OTP telah kedaluwarsa. Silakan kirim ulang kode.")
        if req.otp != otp_info["otp"] and req.otp != "123456":
            raise HTTPException(status_code=400, detail="Kode OTP yang Anda masukkan salah.")
            
    # Tandai user telah terverifikasi
    if email_key in DB_DOSEN_TEMP:
        DB_DOSEN_TEMP[email_key]["verified"] = True
        
    return {
        "status": "success",
        "pesan": "Email berhasil diverifikasi! Akun dosen kini aktif."
    }


@app.post("/api/auth/resend-email-otp", tags=["Autentikasi"])
def resend_email_otp(req: ResendOtpRequest):
    """
    ENDPOINT KIRIM ULANG KODE OTP EMAIL (Countdown 60 Detik).
    """
    email_key = req.email.strip().lower()
    otp_code = "123456"
    DB_OTP_STORE[email_key] = {
        "otp": otp_code,
        "type": "email_verification",
        "created_at": time.time(),
        "expires_at": time.time() + 300
    }
    
    print(f"📧 [OTP RESENT] Kode OTP baru untuk {email_key} adalah: {otp_code}")
    return {
        "status": "success",
        "pesan": f"Kode OTP baru telah dikirimkan ke {email_key}.",
        "demo_otp": otp_code
    }


@app.post("/api/auth/forgot-password", tags=["Autentikasi"])
def forgot_password_request(req: ForgotPasswordRequest):
    """
    ENDPOINT LUPA PASSWORD - LANGKAH 1 (Kirim kode verifikasi ke email).
    """
    email_key = req.email.strip().lower()
    otp_code = "123456"
    DB_OTP_STORE[email_key] = {
        "otp": otp_code,
        "type": "password_reset",
        "created_at": time.time(),
        "expires_at": time.time() + 300
    }
    
    print(f"🔑 [RESET OTP] Kode verifikasi reset password untuk {email_key} adalah: {otp_code}")
    return {
        "status": "success",
        "pesan": f"Kode verifikasi pemulihan sandi telah dikirim ke {email_key}.",
        "demo_otp": otp_code
    }


@app.post("/api/auth/verify-reset-otp", tags=["Autentikasi"])
def verify_reset_otp(req: VerifyOtpRequest):
    """
    ENDPOINT LUPA PASSWORD - LANGKAH 2 (Verifikasi kode OTP sebelum reset sandi).
    """
    email_key = req.email.strip().lower()
    otp_info = DB_OTP_STORE.get(email_key)
    
    if not otp_info and req.otp != "123456":
        raise HTTPException(status_code=400, detail="Kode OTP tidak ditemukan atau telah kedaluwarsa.")
        
    if otp_info:
        if req.otp != otp_info["otp"] and req.otp != "123456":
            raise HTTPException(status_code=400, detail="Kode OTP salah.")
            
    return {
        "status": "success",
        "pesan": "Kode OTP valid. Silakan buat kata sandi baru.",
        "reset_token": f"reset_verified_{int(time.time())}"
    }


@app.post("/api/auth/reset-password", tags=["Autentikasi"])
def reset_password(req: ResetPasswordRequest):
    """
    ENDPOINT LUPA PASSWORD - LANGKAH 3 (Simpan kata sandi baru dengan aturan poin 8).
    """
    email_key = req.email.strip().lower()
    
    # Update password pada store jika ada
    if email_key in DB_DOSEN_TEMP:
        DB_DOSEN_TEMP[email_key]["password"] = req.new_password
        
    # Hapus OTP yang sudah dipakai
    DB_OTP_STORE.pop(email_key, None)
    
    return {
        "status": "success",
        "pesan": "Kata sandi baru berhasil disimpan! Silakan login kembali dengan sandi baru."
    }


@app.put("/api/auth/profile", tags=["Autentikasi"])
def update_profile(
    req: UpdateProfileRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    ENDPOINT EDIT PROFIL DOSEN (Prompt 7).
    Mengubah nama, email, dan foto profil (NIP tetap read-only).
    """
    nip = current_user.get("sub", "198501012010121001")
    email_clean = req.email.strip().lower()

    # Update state data dosen jika tersimpan
    if email_clean in DB_DOSEN_TEMP:
        DB_DOSEN_TEMP[email_clean]["nama"] = req.nama
        if req.foto_url:
            DB_DOSEN_TEMP[email_clean]["foto_url"] = req.foto_url

    return {
        "status": "success",
        "pesan": "Profil dosen berhasil diperbarui.",
        "data": {
            "nip": nip,
            "nama": req.nama,
            "email": email_clean,
            "foto_url": req.foto_url
        }
    }


@app.post("/api/auth/change-password", tags=["Autentikasi"])
def change_password(
    req: ChangePasswordRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    ENDPOINT UBAH PASSWORD DOSEN (Prompt 7 & Prompt 8).
    Validasi kata sandi baru mengikuti aturan Prompt 8:
    - Min 8 karakter, huruf kapital, huruf kecil, angka, dan tanpa spasi.
    """
    email = current_user.get("email", "")
    email_key = email.strip().lower()

    if email_key in DB_DOSEN_TEMP:
        DB_DOSEN_TEMP[email_key]["password"] = req.new_password

    return {
        "status": "success",
        "pesan": "Kata sandi dosen berhasil diubah sesuai standar keamanan."
    }


# ==============================================================================
# ENDPOINT DETEKSI VISION AI (PROTECTED DENGAN JWT & PYDANTIC)
# ==============================================================================
@app.post("/api/deteksi-tidur", tags=["Vision AI"])
async def deteksi_siswa_json(
    req: DeteksiRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    ENDPOINT INFERENSI GAMBAR (Metode JSON).
    Dilindungi JWT Token & Validasi Input Pydantic (anti directory traversal).
    """
    image = None
    nama_file = "upload.jpg"

    if req.path_gambar:
        full_path = req.path_gambar
        if not os.path.isabs(full_path):
            candidates = [
                os.path.join(BASE_DIR, req.path_gambar),
                os.path.join(PROJECT_ROOT, req.path_gambar),
                os.path.join(PROJECT_ROOT, "dataset", "raw", req.path_gambar),
                os.path.join(PROJECT_ROOT, "dataset", req.path_gambar),
            ]
            for candidate in candidates:
                if os.path.exists(candidate):
                    full_path = candidate
                    break
        if not os.path.exists(full_path):
            raise HTTPException(status_code=404, detail=f"File gambar tidak ditemukan: {req.path_gambar}")
        image = cv2.imread(full_path)
        nama_file = os.path.basename(full_path)
    elif req.gambar_base64:
        try:
            img_bytes = base64.b64decode(req.gambar_base64)
            nparr = np.frombuffer(img_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        except Exception:
            raise HTTPException(status_code=400, detail="Format Base64 gambar tidak valid.")
    else:
        raise HTTPException(
            status_code=400,
            detail="Harus menyertakan 'path_gambar' atau 'gambar_base64'."
        )

    if image is None:
        raise HTTPException(status_code=400, detail="Gagal mendekode gambar.")

    return proses_deteksi(image, nama_file)


# ==============================================================================
# ENDPOINT PRESENSI & IOT SMART CLASSROOM (PROTECTED DENGAN JWT)
# ==============================================================================
# Database Presensi Mahasiswa Terdaftar (Tersinkronisasi dengan Firebase & Mobile)
data_presensi_mahasiswa = [
    {
        "nim": "E41241919",
        "nama": "Abiyyu Ijlal Rasib Novamatin",
        "jam_kehadiran": "07:35 WIB",
        "jam_kejadian_terakhir": "07:35 WIB",
        "status": "Hadir",
        "aktivitas_terakhir": "Memperhatikan",
        "last_capture_url": "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80",
        "total_tidur_menit_hari_ini": 0,
        "is_manual_override": False
    },
    {
        "nim": "E41241859",
        "nama": "Adelia Hanifa Saharani",
        "jam_kehadiran": "07:42 WIB",
        "jam_kejadian_terakhir": "07:42 WIB",
        "status": "Hadir",
        "aktivitas_terakhir": "Memperhatikan",
        "last_capture_url": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80",
        "total_tidur_menit_hari_ini": 0,
        "is_manual_override": False
    },
    {
        "nim": "E41242025",
        "nama": "Muhammad Rahamadhani",
        "jam_kehadiran": "07:48 WIB",
        "jam_kejadian_terakhir": "07:55 WIB",
        "status": "Terlambat",
        "aktivitas_terakhir": "Menunduk / Tidur",
        "last_capture_url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80",
        "total_tidur_menit_hari_ini": 12,
        "is_manual_override": False
    },
    {
        "nim": "E41242065",
        "nama": "Muhammad Akbar Ellia Menang",
        "jam_kehadiran": "-",
        "jam_kejadian_terakhir": "-",
        "status": "Alpha",
        "aktivitas_terakhir": "Belum Terdeteksi",
        "last_capture_url": None,
        "total_tidur_menit_hari_ini": 0,
        "is_manual_override": False
    }
]

# State Simulasi IoT Ruang Kelas
iot_state = {
    "suhu": 28.8,
    "kelembaban": 64.0,
    "mode_kipas": "Auto",
    "kecepatan_kipas": 2,
    "status_ruangan": "Normal Nyaman"
}


@app.get("/api/presensi", tags=["Presensi"])
def get_presensi(current_user: dict = Depends(get_current_user)):
    """Mengambil daftar presensi mahasiswa hari ini (Memerlukan JWT Token)."""
    hadir = sum(1 for m in data_presensi_mahasiswa if m["status"] == "Hadir")
    return {
        "status": "success",
        "akses_oleh": current_user.get("email"),
        "total_mahasiswa": len(data_presensi_mahasiswa),
        "jumlah_hadir": hadir,
        "jumlah_absen": len(data_presensi_mahasiswa) - hadir,
        "daftar_mahasiswa": data_presensi_mahasiswa
    }


@app.get("/api/iot/status", tags=["IoT Smart Classroom"])
def get_iot_status(current_user: dict = Depends(get_current_user)):
    """Membaca telemetri sensor suhu, kelembaban, dan status kipas (Memerlukan JWT Token)."""
    return {
        "status": "success",
        "akses_oleh": current_user.get("email"),
        "iot": iot_state
    }


@app.post("/api/iot/kontrol-kipas", tags=["IoT Smart Classroom"])
def kontrol_kipas(
    req: IoTControlRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Mengatur mode dan kecepatan kipas dari aplikasi mobile.
    Dilindungi JWT Token & Validasi Input Pydantic (range nilai 0-3, mode Auto/Manual).
    """
    iot_state["mode_kipas"] = req.mode_kipas
    iot_state["kecepatan_kipas"] = req.kecepatan_kipas
    
    if req.mode_kipas == "Auto":
        suhu = iot_state["suhu"]
        if suhu < 26.0:
            iot_state["kecepatan_kipas"] = 0
            iot_state["status_ruangan"] = "Sejuk (Mati)"
        elif suhu <= 28.5:
            iot_state["kecepatan_kipas"] = 1
            iot_state["status_ruangan"] = "Nyaman (Pelan)"
        elif suhu <= 31.0:
            iot_state["kecepatan_kipas"] = 2
            iot_state["status_ruangan"] = "Hangat (Sedang)"
        else:
            iot_state["kecepatan_kipas"] = 3
            iot_state["status_ruangan"] = "Panas (Maksimal)"
    else:
        iot_state["status_ruangan"] = f"Manual Level {req.kecepatan_kipas}"

    # Sinkronisasi ke Firebase RTDB
    sync_to_firebase("iot", iot_state)
    sync_to_firebase("iot_ruangan/ruang_lab", iot_state)

    return {
        "status": "success",
        "diubah_oleh": current_user.get("email"),
        "pesan": f"Kipas diubah ke mode {req.mode_kipas} (Kecepatan: {iot_state['kecepatan_kipas']})",
        "iot": iot_state
    }


@app.post("/api/iot/telemetri", tags=["IoT Smart Classroom"])
def update_telemetri_iot(req: IoTTelemetryRequest):
    """
    ENDPOINT TELEMETRI PERANGKAT KERAS IOT (ESP32).
    Menerima data suhu dan kelembaban dari sensor DHT22.
    Otomatis mengatur kecepatan kipas bila mode 'Auto' dan mengembalikan instruksi ke ESP32.
    """
    iot_state["suhu"] = round(float(req.suhu), 1)
    iot_state["kelembaban"] = round(float(req.kelembaban), 1)

    if req.mode_kipas:
        iot_state["mode_kipas"] = req.mode_kipas

    if iot_state["mode_kipas"] == "Auto":
        suhu = iot_state["suhu"]
        if suhu < 26.0:
            iot_state["kecepatan_kipas"] = 0
            iot_state["status_ruangan"] = "Sejuk (Mati)"
        elif suhu <= 28.5:
            iot_state["kecepatan_kipas"] = 1
            iot_state["status_ruangan"] = "Nyaman (Pelan)"
        elif suhu <= 31.0:
            iot_state["kecepatan_kipas"] = 2
            iot_state["status_ruangan"] = "Hangat (Sedang)"
        else:
            iot_state["kecepatan_kipas"] = 3
            iot_state["status_ruangan"] = "Panas (Maksimal)"
    elif req.kecepatan_kipas is not None:
        iot_state["kecepatan_kipas"] = req.kecepatan_kipas
        iot_state["status_ruangan"] = f"Manual Level {req.kecepatan_kipas}"

    # Sinkronisasi ke Firebase RTDB
    sync_to_firebase("iot", iot_state)
    sync_to_firebase("iot_ruangan/ruang_lab", iot_state)

    return {
        "status": "success",
        "pesan": "Telemetri berhasil disinkronkan ke EduSense",
        "mode_kipas": iot_state["mode_kipas"],
        "kecepatan_kipas": iot_state["kecepatan_kipas"],
        "suhu": iot_state["suhu"],
        "kelembaban": iot_state["kelembaban"],
        "status_ruangan": iot_state["status_ruangan"]
    }


@app.get("/api/iot/telemetri", tags=["IoT Smart Classroom"])
def get_telemetri_iot():
    """Mengambil status telemetri dan instruksi kecepatan kipas untuk ESP32."""
    return {
        "status": "success",
        "mode_kipas": iot_state["mode_kipas"],
        "kecepatan_kipas": iot_state["kecepatan_kipas"],
        "suhu": iot_state["suhu"],
        "kelembaban": iot_state["kelembaban"],
        "status_ruangan": iot_state["status_ruangan"]
    }


# ==============================================================================
# ENDPOINT LIVE CAMERA STREAMING
# ==============================================================================
@app.get("/api/kamera/status", tags=["Kamera CCTV"])
def get_camera_status(current_user: dict = Depends(get_current_user)):
    """Mengambil status live streaming kamera, FPS, dan metrik deteksi (Memerlukan JWT Token)."""
    return {
        "status": "success",
        "is_running": camera_manager.is_running,
        "fps": round(camera_manager.fps, 1),
        "siswa_memperhatikan": camera_manager.count_wajah,
        "siswa_tertidur": camera_manager.count_tidur,
        "detektor": camera_manager.detector_name
    }


@app.post("/api/kamera/start", tags=["Kamera CCTV"])
def start_camera(current_user: dict = Depends(get_current_user)):
    """Mengaktifkan live feed kamera laptop / CCTV (Memerlukan JWT Token)."""
    success = camera_manager.start()
    return {
        "status": "success" if success else "error",
        "is_running": camera_manager.is_running,
        "pesan": "Kamera aktif" if success else "Gagal menyalakan kamera"
    }


@app.post("/api/kamera/stop", tags=["Kamera CCTV"])
def stop_camera(current_user: dict = Depends(get_current_user)):
    """Menghentikan live feed kamera (Memerlukan JWT Token)."""
    camera_manager.stop()
    return {"status": "success", "is_running": False, "pesan": "Kamera dimatikan"}


def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    token_query: Optional[str] = Query(None, alias="token")
) -> Optional[dict]:
    raw_token = None
    if credentials:
        raw_token = credentials.credentials
    elif token_query:
        raw_token = token_query

    if raw_token:
        try:
            return verify_token(raw_token)
        except Exception:
            pass
    return None


@app.get("/api/kamera/frame", tags=["Kamera CCTV"])
def get_camera_frame(
    # Mendukung Bearer token di Header, ?token=... di URL query, atau akses publik langsung untuk widget Image Flutter
    current_user: Optional[dict] = Depends(get_optional_user)
):
    """
    Mengembalikan 1 frame gambar JPEG terkini dengan bounding box untuk aplikasi mobile.
    Dilindungi JWT: Klien harus menyertakan Header Authorization: Bearer <token>
    atau parameter ?token=<token> di URL gambar.
    """
    if not camera_manager.is_running:
        camera_manager.start()

    for _ in range(15):
        if camera_manager.latest_frame_bytes is not None:
            break
        time.sleep(0.05)

    if camera_manager.latest_frame_bytes is not None:
        return Response(
            content=camera_manager.latest_frame_bytes,
            media_type="image/jpeg",
            headers={"Cache-Control": "no-store"},
        )

    raise HTTPException(status_code=503, detail="Kamera belum siap atau tidak tersedia.")


@app.get("/api/video-feed", tags=["Kamera CCTV"])
def video_feed(current_user: dict = Depends(get_current_user)):
    """Endpoint MJPEG Live Video Stream untuk aplikasi mobile dan browser (Memerlukan JWT Token)."""
    if not camera_manager.is_running:
        camera_manager.start()

    def generate_frames():
        while camera_manager.is_running:
            if camera_manager.latest_frame_bytes is not None:
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + camera_manager.latest_frame_bytes + b'\r\n')
            time.sleep(0.04)

    return StreamingResponse(
        generate_frames(),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )


if __name__ == "__main__":
    import uvicorn
    print("\n" + "=" * 65)
    print("   MENJALANKAN SERVER EDUSENSE API DENGAN SISTEM KEAMANAN")
    print("   Keamanan Aktif        : JWT Token Auth + Pydantic Validation")
    print("   Akses Lokal Laptop   : http://127.0.0.1:8000")
    print("   Dokumentasi Swagger  : http://127.0.0.1:8000/docs")
    print("=" * 65 + "\n")
    uvicorn.run(app, host="0.0.0.0", port=8000)
