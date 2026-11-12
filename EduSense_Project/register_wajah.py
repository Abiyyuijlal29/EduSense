import os
import cv2
import numpy as np
from typing import Dict, Any

# =============================================
# KONFIGURASI
# =============================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(BASE_DIR, "dataset_absensi")
MODEL_CUSTOM = os.path.join(BASE_DIR, "models", "best.pt")

MAHASISWA = {
    "1": {"nama": "Abiyyu Ijlal Rasib Novamatin", "nim": "E41241919", "folder": "E41241919_Abiyyu_Ijlal_Rasib_Novamatin"},
    "2": {"nama": "Adelia Hanifa Saharani",        "nim": "E41241859", "folder": "E41241859_Adelia_Hanifa_Saharani"},
    "3": {"nama": "Muhammad Rahamadhani",           "nim": "E41242025", "folder": "E41242025_Muhammad_Rahamadhani"},
    "4": {"nama": "Muhammad Akbar Ellia Menang",    "nim": "E41242065", "folder": "E41242065_Muhammad_Akbar_Ellia_Menang"},
}

JUMLAH_FOTO = 30  # Jumlah foto yang diambil per mahasiswa

# Muat Model YOLOv8 (Murni tanpa Haar Cascade)
try:
    from ultralytics import YOLO
    if os.path.exists(MODEL_CUSTOM):
        print(f"[INIT] Memuat model deteksi wajah YOLO dari: {MODEL_CUSTOM}")
        yolo_model = YOLO(MODEL_CUSTOM)
    else:
        print("[INIT] Model custom belum ada, memuat 'yolov8n.pt' untuk deteksi wajah...")
        yolo_model = YOLO("yolov8n.pt")
except ImportError:
    raise ImportError("Pustaka 'ultralytics' belum terpasang. Jalankan: pip install ultralytics")


def pilih_mahasiswa() -> str:
    """Menampilkan menu pilihan mahasiswa."""
    print("\n" + "=" * 50)
    print("  SISTEM REGISTRASI WAJAH - EduSense (YOLOv8)")
    print("=" * 50)
    print("Pilih mahasiswa yang akan didaftarkan:\n")
    for key, data in MAHASISWA.items():
        print(f"  [{key}] {data['nim']} - {data['nama']}")
    print("\n  [0] Keluar")
    print("=" * 50)

    pilihan = input("Masukkan pilihan: ").strip()
    return pilihan


def register_wajah(mahasiswa_info: Dict[str, str]) -> None:
    """Mengambil foto wajah dan menyimpannya ke folder dataset menggunakan deteksi YOLOv8."""
    nama = mahasiswa_info["nama"]
    nim = mahasiswa_info["nim"]
    folder = os.path.join(DATASET_DIR, mahasiswa_info["folder"])

    os.makedirs(folder, exist_ok=True)

    # Cek foto yang sudah ada
    existing = [f for f in os.listdir(folder) if f.endswith(".jpg")]
    start_idx = len(existing)

    print(f"\n[INFO] Memulai registrasi wajah untuk: {nama} ({nim})")
    print(f"[INFO] Foto sudah ada: {start_idx} | Target: {JUMLAH_FOTO}")
    print("[INFO] Tekan 'q' untuk berhenti, 's' untuk skip frame\n")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[ERROR] Kamera laptop tidak dapat dibuka!")
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    foto_diambil = start_idx
    frame_count = 0
    INTERVAL = 3  # Ambil foto setiap N frame jika wajah terdeteksi stabil

    while foto_diambil < JUMLAH_FOTO:
        ret, frame = cap.read()
        if not ret:
            print("[ERROR] Gagal membaca frame kamera!")
            break

        frame_count += 1
        display = frame.copy()

        # Deteksi Wajah menggunakan YOLOv8 (conf >= 0.45)
        results = yolo_model(frame, conf=0.45, imgsz=320, verbose=False)[0]
        faces = []

        for box in results.boxes:
            cls_id = int(box.cls[0])
            label_name = yolo_model.names.get(cls_id, "")
            # Deteksi kelas 'wajah' pada best.pt atau 'person' pada yolov8n
            if label_name in ["wajah", "person"] or cls_id == 0:
                x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
                w = x2 - x1
                h = y2 - y1
                faces.append((x1, y1, w, h))

        # Gambar kotak hijau di sekitar wajah yang terdeteksi
        for (x, y, w, h) in faces:
            cv2.rectangle(display, (x, y), (x + w, y + h), (0, 255, 0), 2)
            cv2.putText(display, "Wajah Terdeteksi (YOLOv8)", (x, max(20, y - 8)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 0), 2)

        # Info overlay HUD
        progress = foto_diambil - start_idx
        sisa = JUMLAH_FOTO - foto_diambil
        cv2.putText(display, f"{nama}", (15, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        cv2.putText(display, f"Foto: {progress}/{JUMLAH_FOTO - start_idx} | Sisa: {sisa}", (15, 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        cv2.putText(display, "q=Keluar | s=Skip", (15, display.shape[0] - 15),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

        # Simpan foto secara otomatis jika wajah terdeteksi dan interval terpenuhi
        if len(faces) > 0 and frame_count % INTERVAL == 0:
            filename = os.path.join(folder, f"{nim}_{foto_diambil + 1:03d}.jpg")
            cv2.imwrite(filename, frame)
            foto_diambil += 1
            print(f"  [+] Foto tersimpan: {os.path.basename(filename)} ({foto_diambil}/{JUMLAH_FOTO})")

        cv2.imshow(f"Registrasi Wajah - {nama} (YOLOv8)", display)

        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            print("\n[INFO] Registrasi dihentikan oleh pengguna.")
            break
        elif key == ord('s'):
            frame_count = 0  # Reset interval

    cap.release()
    cv2.destroyAllWindows()

    total_baru = foto_diambil - start_idx
    print(f"\n[SELESAI] {total_baru} foto baru disimpan untuk {nama} ({nim})")
    print(f"[SELESAI] Total foto di folder: {foto_diambil}")


def main():
    print("\n[INIT] Memeriksa struktur folder dataset presensi...")
    for data in MAHASISWA.values():
        folder = os.path.join(DATASET_DIR, data["folder"])
        os.makedirs(folder, exist_ok=True)
    print("[INIT] Semua folder siap.\n")

    while True:
        pilihan = pilih_mahasiswa()

        if pilihan == "0":
            print("\n[INFO] Program selesai. Sampai jumpa!\n")
            break
        elif pilihan in MAHASISWA:
            register_wajah(MAHASISWA[pilihan])
        else:
            print("[WARNING] Pilihan tidak valid. Coba lagi.")


if __name__ == "__main__":
    main()
