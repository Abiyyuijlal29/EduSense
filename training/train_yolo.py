"""
Skrip Pelatihan YOLOv8 EduSense (Smart Classroom Monitoring)
===========================================================
Skrip ini digunakan untuk melatih model deteksi objek YOLOv8
untuk mendeteksi 2 kelas perilaku siswa:
  - Kelas 0: wajah (Siswa Memperhatikan)
  - Kelas 1: head_down (Siswa Tertidur / Menunduk)

Dapat dijalankan secara lokal di laptop atau di Google Colab.
"""

import os
import sys

# 1. Menentukan path direktori proyek
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))

# Path konfigurasi dataset dan hyperparameter
DATASET_YAML = os.path.join(PROJECT_ROOT, "dataset", "dataset.yaml")
TRAIN_CONFIG = os.path.join(BASE_DIR, "train_config.yaml")

def main():
    print("=" * 65)
    print("      MEMULAI PELATIHAN MODEL YOLOV8 - EDUSENSE")
    print("=" * 65)
    
    # 2. Cek ketersediaan Ultralytics
    try:
        from ultralytics import YOLO
    except ImportError:
        print("[ERROR] Library ultralytics belum terpasang!")
        print("Silakan jalankan: pip install ultralytics")
        sys.exit(1)

    # 3. Cek keberadaan dataset.yaml
    if not os.path.exists(DATASET_YAML):
        print(f"[ERROR] File dataset.yaml tidak ditemukan di: {DATASET_YAML}")
        sys.exit(1)

    print(f"[*] Menggunakan file konfigurasi dataset: {DATASET_YAML}")
    if os.path.exists(TRAIN_CONFIG):
        print(f"[*] Menggunakan hyperparameter augmentasi: {TRAIN_CONFIG}")
    
    # 4. Inisialisasi Model Pretrained YOLOv8 Small (yolov8s.pt)
    # Model small dipilih karena memiliki akurasi tinggi namun tetap ringan untuk real-time inference
    print("\n[STEP 1] Mengunduh / memuat bobot dasar pre-trained 'yolov8s.pt'...")
    model = YOLO("yolov8s.pt")

    # 5. Eksekusi Proses Pelatihan (Training)
    print("\n[STEP 2] Memulai iterasi pelatihan (Training Loop)...")
    print("Tekan Ctrl+C jika ingin membatalkan.\n")
    
    # Parameter utama pelatihan
    results = model.train(
        data=DATASET_YAML,       # Path file dataset.yaml
        epochs=40,               # Jumlah putaran pelatihan (40 epoch optimal untuk konvergensi)
        patience=10,             # Early stopping: berhenti jika 10 epoch tidak ada kenaikan mAP
        imgsz=640,               # Ukuran resolusi citra input (640x640)
        batch=16,                # Ukuran batch per iterasi
        optimizer="AdamW",       # Optimizer AdamW untuk stabilitas bobot
        lr0=0.001,               # Initial learning rate
        lrf=0.01,                # Final learning rate
        hsv_v=0.4,               # Augmentasi kecerahan cahaya (+/- 40%)
        hsv_s=0.7,               # Augmentasi kejenuhan warna (+/- 70%)
        degrees=10.0,            # Augmentasi rotasi (+/- 10 derajat)
        scale=0.5,               # Augmentasi skala jarak (zoom in/out 50%)
        fliplr=0.5,              # Augmentasi flip horizontal (tidur kiri/kanan)
        mosaic=1.0,              # Augmentasi mosaik 4 frame (skenario kelas ramai)
        device="0" if os.environ.get("CUDA_VISIBLE_DEVICES") else "cpu",
        plots=True,              # Otomatis buat grafik loss, PR-curve, confusion matrix
        name="edusense_yolov8s"  # Nama folder hasil training
    )

    print("\n" + "=" * 65)
    print("      PELATIHAN SELESAI DENGAN SUKSES!")
    print("=" * 65)
    print("Bobot terbaik tersimpan di: runs/detect/edusense_yolov8s/weights/best.pt")
    print("Salin file best.pt tersebut ke folder: backend/models/best.pt")

if __name__ == "__main__":
    main()
