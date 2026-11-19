# EduSense: Smart Classroom Monitoring & Behavioral Analytics System 🎓

Sistem pemantauan kelas cerdas berbasis **Computer Vision (YOLOv8)**, **Face Recognition (DeepFace)**, **Backend (FastAPI)**, dan **Mobile App (Flutter & Firebase)** untuk mendeteksi kehadiran serta perilaku siswa (fokus vs tertidur) secara *real-time*.

---

## 📂 Struktur Folder Proyek yang Baru & Rapi

Seluruh berkas proyek telah ditata secara modular ke dalam 5 folder utama sesuai perannya masing-masing:

```text
EduSense/
├── 📁 backend/                # Server API, live streaming CCTV, & modul inferensi AI
│   ├── api_server.py          # FastAPI backend (stream MJPEG, deteksi tidur, absensi, IoT)
│   ├── register_wajah.py      # Registrasi foto wajah mahasiswa dengan validasi YOLO
│   ├── test_kamera_realtime.py# Pengujian kamera laptop real-time HUD (Normal/Grayscale/Multi)
│   ├── requirements.txt       # Daftar pustaka Python backend
│   └── 📁 models/             # Bobot model AI terlatih
│       └── best.pt            # Bobot custom YOLOv8s hasil pelatihan (Kelas: wajah & head_down)
│
├── 📁 frontend/               # Aplikasi mobile Flutter (EduSense Mobile)
│   ├── lib/
│   │   ├── models/            # Struktur data (UserDosen, Mahasiswa, IoTState)
│   │   ├── screens/           # Tampilan UI (Monitoring, Presensi, IoT Kipas, Login)
│   │   ├── services/          # Layanan HTTP API & Firebase Realtime Database
│   │   └── main.dart          # Titik masuk utama aplikasi mobile
│   └── pubspec.yaml           # Konfigurasi dependensi Flutter
│
├── 📁 dataset/                # Seluruh basis data citra & anotasi objek
│   ├── 📁 dataset_yolo_tidur/ # Dataset YOLO terbagi rapi (images/ & labels/ untuk train/val/test)
│   ├── 📁 dataset_absensi/    # Database foto mahasiswa per NIM untuk pencocokan wajah
│   ├── dataset.yaml           # Definisi kelas YOLO (0: wajah, 1: head_down)
│   ├── mapping_dataset_baru.csv # Log pemetaan 109 frame tambahan dari 12 subjek baru
│   └── 📁 raw/                # Data rekaman mentah & arsip cadangan
│       ├── dataset_cctv_mentah/
│       ├── dataset_cctv_tersaring/
│       ├── dataset_wajah_mentah/
│       ├── hasil_percobaan_kamera/
│       └── dataset_yolo_tidur.zip
│
├── 📁 training/               # Modul pelatihan model dan evaluasi metrik
│   ├── train_config.yaml      # Hyperparameter augmentasi (HSV, rotasi, scale, mosaic, mixup)
│   ├── split_data.py          # Pembagian data (Train 70%, Val 15%, Test 15%) bebas data leakage
│   ├── train_yolo.py          # Skrip eksekusi pelatihan YOLOv8 (bisa lokal / Google Colab)
│   └── hitung_akurasi_matriks.py # Perhitungan matematis Confusion Matrix & Akurasi (98.36%)
│
├── 📁 data_processing/        # Skrip pemrosesan, pembersihan, & kalibrasi data
│   ├── fix_dataset.py         # Memotong citra bertumpuk (368x416 -> 368x208) & kalibrasi bbox
│   ├── clean_cctv.py          # Menyaring frame CCTV berkala untuk membuang frame identik
│   ├── clean_wajah.py         # Menyaring foto wajah blur berbasis Laplacian variance
│   ├── auto_label.py          # Pembuatan label otomatis awal
│   ├── propagate_labels.py    # Propagasi anotasi sekuensial antarfram video skenario
│   └── import_new_dataset.py  # Integrasi data mahasiswa tidur baru (Person_01 - Person_12)
│
└── 📁 docs/                   # Laporan lengkap & slide presentasi proyek
    ├── LAPORAN_PROYEK_EDUSENSE.html  # Dokumen laporan resmi siap cetak
    ├── LAPORAN_PROYEK_EDUSENSE.md    # Dokumen laporan format Markdown
    ├── SLIDE_PRESENTASI_EDUSENSE.html# Slide presentasi interaktif (12 slide)
    └── PPT_PRESENTASI_EDUSENSE.md    # Naskah presentasi untuk dosen
```

---

## 🎯 Panduan Menjelaskan ke Dosen (Poin-Poin Penting)

Saat presentasi atau sidang di hadapan dosen pengampu/penguji, Anda dapat menjelaskan alur sistem secara berurutan dengan bahasa yang ringkas:

### 1. Bagian Dataset (`dataset/`)
> *"Pak/Bu, dataset kami terdiri dari 825 frame beranotasi yang dibagi menjadi 2 kelas: **0 (wajah)** untuk siswa yang memperhatikan dan **1 (head_down)** untuk siswa tertidur. Format dataset disusun rapi sesuai standar Ultralytics YOLO pada folder `dataset/dataset_yolo_tidur/`."*

### 2. Bagian Pemrosesan Data (`data_processing/`)
> *"Pada data mentah awal, terdapat rekaman citra yang bertumpuk (resolusi 368x416). Kami membuat skrip `fix_dataset.py` untuk meng-crop citra menjadi 368x208 dan mengalibrasi ulang koordinat bounding box ($y_{\text{new}} = y_{\text{old}} \times 2, h_{\text{new}} = h_{\text{old}} \times 2$). Selain itu, kami menyaring gambar blur menggunakan variansi Laplacian pada `clean_wajah.py` agar dataset presensi hanya diisi foto yang tajam."*

### 3. Bagian Pelatihan Model (`training/`)
> *"Untuk melatih model tanpa kebocoran data (*data leakage*), kami membuat skrip `split_data.py` dengan metode **Block-Temporal Splitting** (Train 568, Val 122, Test 135). Model dilatih menggunakan konfigurasi augmentasi `train_config.yaml` (kecerahan HSV, skala zoom in/out, rotasi, dan mosaik) agar tangguh terhadap kondisi ruang kelas redup maupun terang. Berdasarkan evaluasi `hitung_akurasi_matriks.py`, model mencapai **akurasi 98.36%** dan **Recall tidur 97.30%**."*

### 4. Bagian Backend Server (`backend/`)
> *"Backend dibangun menggunakan FastAPI pada `api_server.py`. Server menjalankan multi-threading untuk membaca kamera laptop/CCTV, melakukan deteksi perilaku secara real-time dengan model `models/best.pt`, serta mengalirkan video (*MJPEG stream*) dan status IoT kipas ke aplikasi mobile."*

### 5. Bagian Frontend Mobile (`frontend/`)
> *"Frontend berupa aplikasi Flutter di folder `frontend/`. Dosen dapat memantau video kelas secara live, melihat grafik jumlah siswa tertidur, memeriksa daftar kehadiran mahasiswa yang terhubung ke Firebase, serta mengatur kecepatan kipas kelas secara otomatis maupun manual."*

---

## 🚀 Cara Menjalankan Sistem

### 1. Menjalankan Backend Server
```bash
cd backend
python api_server.py
```
* Akses API di browser: `http://127.0.0.1:8000`
* Akses Dokumentasi Swagger: `http://127.0.0.1:8000/docs`

### 2. Uji Coba Kamera Laptop Real-Time (Standalone)
```bash
cd backend
python test_kamera_realtime.py
```
* Tombol `1`, `2`, `3`: Ganti mode tampilan (Normal / Grayscale / Side-by-Side).
* Tombol `+` / `-`: Naikkan / turunkan confidence threshold.
* Tombol `q`: Keluar.

### 3. Evaluasi Metrik Confusion Matrix
```bash
cd training
python hitung_akurasi_matriks.py
```

### 4. Menjalankan Aplikasi Mobile
```bash
cd frontend
flutter run
```
