import os
import cv2
import base64
import numpy as np
from typing import Optional
from fastapi import FastAPI, Request, HTTPException
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
