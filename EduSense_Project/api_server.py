import os
import cv2
import base64
import threading
import time
import numpy as np
from typing import Optional
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(
    title="EduSense AI Detection API",
    description="Endpoint API untuk Pengujian Model Deteksi Siswa (Request & Response) - Proyek EduSense",
    version="1.0.0"
)

# Mengizinkan CORS agar aplikasi Mobile (Flutter) dapat mengakses API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_CUSTOM = os.path.join(BASE_DIR, "models", "best.pt")
CASCADE_PATH = os.path.join(BASE_DIR, "haarcascade_frontalface_default.xml")

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

# Pengecekan Haar Cascade untuk fallback deteksi wajah
face_cascade = None
if os.path.exists(CASCADE_PATH):
    face_cascade = cv2.CascadeClassifier(CASCADE_PATH)
    if face_cascade.empty():
        face_cascade = None
else:
    cascade_cv2 = os.path.join(getattr(cv2.data, 'haarcascades', ''), "haarcascade_frontalface_default.xml")
    if os.path.exists(cascade_cv2):
        face_cascade = cv2.CascadeClassifier(cascade_cv2)


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
        dataset_dir = os.path.join(BASE_DIR, "dataset_cctv_tersaring")
        if os.path.isdir(dataset_dir):
            files = sorted([
                os.path.join(dataset_dir, f) for f in os.listdir(dataset_dir)
                if f.lower().endswith(('.jpg', '.jpeg', '.png'))
            ])
            self.cctv_images = files

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
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

            if frame_counter % FRAME_SKIP == 0 or not cached_boxes:
                current_boxes = []
                c_wajah = 0
                c_tidur = 0
                det_name = "Tidak Ada"

                # 1. Inferensi YOLOv8s EduSense
                if model is not None:
                    try:
                        results = model.predict(raw_rgb, conf=0.20, imgsz=320, verbose=False)
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
                            det_name = "YOLOv8s"
                    except Exception:
                        pass

                # 2. Fallback Haar Cascade
                if (c_wajah == 0 and c_tidur == 0) and face_cascade is not None:
                    gray_small = cv2.resize(gray, (0, 0), fx=0.5, fy=0.5)
                    faces = face_cascade.detectMultiScale(gray_small, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30))
                    if len(faces) > 0:
                        c_wajah = len(faces)
                        det_name = "Haar Cascade"
                        for (x, y, w, h) in faces:
                            x1, y1, x2, y2 = x * 2, y * 2, (x + w) * 2, (y + h) * 2
                            current_boxes.append((x1, y1, x2, y2, (0, 255, 0), "Memperhatikan (Wajah)"))

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

            time.sleep(0.01)

camera_manager = CameraManager()


@app.on_event("startup")
def startup_event():
    """Otomatis aktifkan streaming CCTV saat API server mulai."""
    camera_manager.start()


class DeteksiRequest(BaseModel):
    path_gambar: Optional[str] = None
    gambar_base64: Optional[str] = None


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


@app.get("/")
def root():
    """Halaman beranda status server API."""
    return {
        "sistem": "EduSense Backend API",
        "status": "Online",
        "model_aktif": nama_model_aktif,
        "dokumentasi_uji_coba": "/docs"
    }


@app.post("/api/deteksi-tidur")
async def deteksi_siswa_json(req: DeteksiRequest):
    """
    ENDPOINT UTAMA 1 (Metode JSON):
    Menerima REQUEST berupa JSON path file lokal atau string Base64 gambar.
    Contoh: {"path_gambar": "dataset_cctv_tersaring/cctv_0150.jpg"}
    """
    image = None
    nama_file = "upload.jpg"

    if req.path_gambar:
        full_path = req.path_gambar
        if not os.path.isabs(full_path):
            full_path = os.path.join(BASE_DIR, req.path_gambar)
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
            raise HTTPException(status_code=400, detail="String Base64 gambar tidak valid.")
    else:
        raise HTTPException(
            status_code=400,
            detail="Harus menyertakan 'path_gambar' (misal: 'dataset_cctv_tersaring/cctv_0150.jpg') atau 'gambar_base64'."
        )

    if image is None:
        raise HTTPException(status_code=400, detail="Gagal mendekode gambar.")

    return proses_deteksi(image, nama_file)


@app.post("/api/deteksi-tidur/raw")
async def deteksi_siswa_raw(request: Request):
    """
    ENDPOINT UTAMA 2 (Metode Raw Binary):
    Menerima REQUEST berupa byte biner gambar mentah langsung dari cURL atau Postman.
    """
    body = await request.body()
    if not body:
        raise HTTPException(status_code=400, detail="Body gambar kosong.")

    nparr = np.frombuffer(body, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if image is None:
        raise HTTPException(status_code=400, detail="Gagal membaca biner gambar.")

    return proses_deteksi(image, "raw_binary_upload.jpg")


# ----------------- KONTROL IOT & PRESENSI KELAS -----------------
class LoginRequest(BaseModel):
    username_atau_email: str
    password: str

class IoTControlRequest(BaseModel):
    mode_kipas: str  # 'Auto' atau 'Manual'
    kecepatan_kipas: int  # 0, 1, 2, 3

# State Simulasi IoT
iot_state = {
    "suhu": 28.8,
    "kelembaban": 64.0,
    "mode_kipas": "Auto",
    "kecepatan_kipas": 2,
    "status_ruangan": "Normal Nyaman"
}

# Database Presensi Mahasiswa Terdaftar
data_presensi_mahasiswa = [
    {
        "nim": "E41241919",
        "nama": "Abiyyu Ijlal Rasib Novamatin",
        "jam_kehadiran": "07:35 WIB",
        "status": "Hadir",
        "aktivitas_terakhir": "Memperhatikan"
    },
    {
        "nim": "E41241859",
        "nama": "Adelia Hanifa Saharani",
        "jam_kehadiran": "07:42 WIB",
        "status": "Hadir",
        "aktivitas_terakhir": "Memperhatikan"
    },
    {
        "nim": "E41242025",
        "nama": "Muhammad Rahamadhani",
        "jam_kehadiran": "07:48 WIB",
        "status": "Hadir",
        "aktivitas_terakhir": "Tertidur / Menunduk"
    },
    {
        "nim": "E41242065",
        "nama": "Muhammad Akbar Ellia Menang",
        "jam_kehadiran": "07:50 WIB",
        "status": "Hadir",
        "aktivitas_terakhir": "Memperhatikan"
    }
]

@app.post("/api/auth/login")
def login_dosen(req: LoginRequest):
    """Endpoint Login untuk Dosen."""
    user = req.username_atau_email.strip()
    pwd = req.password.strip()

    # Kredensial Default Dosen
    if (user in ["dosen@polije.ac.id", "dosen", "198501012010121001"]) and (pwd in ["dosen123", "admin123"]):
        return {
            "status": "success",
            "pesan": "Login Berhasil",
            "data_dosen": {
                "nip": "198501012010121001",
                "nama": "Dr. Ir. Dosen Pengampu, M.Kom.",
                "email": "dosen@polije.ac.id",
                "program_studi": "Teknik Informatika",
                "mata_kuliah": "Vision AI dan IoT Smart Classroom",
                "kelas_aktif": "TI-2F (Ruang Lab 3)"
            }
        }
    elif pwd in ["dosen123", "admin123"]:
        return {
            "status": "success",
            "pesan": "Login Berhasil",
            "data_dosen": {
                "nip": "198501012010121001",
                "nama": f"Dosen Pengampu ({user})",
                "email": f"{user}@polije.ac.id",
                "program_studi": "Teknik Informatika",
                "mata_kuliah": "Vision AI dan IoT Smart Classroom",
                "kelas_aktif": "TI-2F (Ruang Lab 3)"
            }
        }
    else:
        raise HTTPException(status_code=401, detail="NIP/Email atau password salah! (Email: dosen@polije.ac.id / Pass: dosen123)")

@app.get("/api/presensi")
def get_presensi():
    """Mengambil daftar presensi mahasiswa hari ini."""
    hadir = sum(1 for m in data_presensi_mahasiswa if m["status"] == "Hadir")
    return {
        "status": "success",
        "total_mahasiswa": len(data_presensi_mahasiswa),
        "jumlah_hadir": hadir,
        "jumlah_absen": len(data_presensi_mahasiswa) - hadir,
        "daftar_mahasiswa": data_presensi_mahasiswa
    }

@app.get("/api/iot/status")
def get_iot_status():
    """Membaca data suhu, kelembaban, dan status kipas ESP32."""
    return {
        "status": "success",
        "iot": iot_state
    }

@app.post("/api/iot/kontrol-kipas")
def kontrol_kipas(req: IoTControlRequest):
    """Mengatur mode dan kecepatan kipas dari aplikasi mobile."""
    if req.mode_kipas not in ["Auto", "Manual"]:
        raise HTTPException(status_code=400, detail="Mode kipas harus 'Auto' atau 'Manual'")
    if req.kecepatan_kipas not in [0, 1, 2, 3]:
        raise HTTPException(status_code=400, detail="Kecepatan kipas harus bernilai 0, 1, 2, atau 3")

    iot_state["mode_kipas"] = req.mode_kipas
    iot_state["kecepatan_kipas"] = req.kecepatan_kipas
    
    if req.mode_kipas == "Auto":
        suhu = iot_state["suhu"]
        if suhu < 26.0:
            iot_state["kecepatan_kipas"] = 0
        elif suhu <= 28.5:
            iot_state["kecepatan_kipas"] = 1
        elif suhu <= 31.0:
            iot_state["kecepatan_kipas"] = 2
        else:
            iot_state["kecepatan_kipas"] = 3

    return {
        "status": "success",
        "pesan": f"Kipas diubah ke mode {req.mode_kipas} (Kecepatan: {iot_state['kecepatan_kipas']})",
        "iot": iot_state
    }


# ----------------- ENDPOINT LIVE CAMERA STREAMING -----------------
@app.get("/api/kamera/status")
def get_camera_status():
    """Mengambil status live streaming kamera, FPS, dan metrik deteksi."""
    return {
        "status": "success",
        "is_running": camera_manager.is_running,
        "fps": round(camera_manager.fps, 1),
        "siswa_memperhatikan": camera_manager.count_wajah,
        "siswa_tertidur": camera_manager.count_tidur,
        "detektor": camera_manager.detector_name
    }


@app.post("/api/kamera/start")
def start_camera():
    """Mengaktifkan live feed kamera laptop / CCTV."""
    success = camera_manager.start()
    return {
        "status": "success" if success else "error",
        "is_running": camera_manager.is_running,
        "pesan": "Kamera aktif" if success else "Gagal menyalakan kamera"
    }


@app.post("/api/kamera/stop")
def stop_camera():
    """Menghentikan live feed kamera."""
    camera_manager.stop()
    return {"status": "success", "is_running": False, "pesan": "Kamera dimatikan"}


@app.get("/api/kamera/frame")
def get_camera_frame():
    """Mengembalikan 1 frame gambar JPEG terkini dengan bounding box untuk aplikasi mobile."""
    if not camera_manager.is_running:
        camera_manager.start()

    for _ in range(15):
        if camera_manager.latest_frame_bytes is not None:
            break
        time.sleep(0.05)

    if camera_manager.latest_frame_bytes is not None:
        return Response(content=camera_manager.latest_frame_bytes, media_type="image/jpeg")

    raise HTTPException(status_code=503, detail="Kamera belum siap atau tidak tersedia.")


@app.get("/api/video-feed")
def video_feed():
    """Endpoint MJPEG Live Video Stream untuk aplikasi mobile dan browser."""
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
    print("   MENJALANKAN SERVER EDUSENSE API & LIVE CAMERA STREAMING")
    print("   Akses Lokal Laptop   : http://127.0.0.1:8000")
    print("   Akses Jaringan Wi-Fi : http://192.168.100.78:8000")
    print("   Dokumentasi Swagger  : http://127.0.0.1:8000/docs")
    print("=" * 65 + "\n")
    uvicorn.run(app, host="0.0.0.0", port=8000)
