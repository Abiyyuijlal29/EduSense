# Presentasi: Arsitektur Model YOLOv8s pada Proyek EduSense
*(Berdasarkan Kode Aktual & Letak Berkas di Proyek)*

---

## Slide 1: Judul
* **Judul:** Arsitektur Model YOLOv8s pada Sistem EduSense
* **Subjudul:** Bedah Arsitektur, Spesifikasi Teknis, dan Letak Kode pada Proyek
* **Konteks:** Smart Classroom Monitoring (Deteksi Fokus `wajah` vs Tertidur `head_down`)

---

## Slide 2: Spesifikasi Teknis YOLOv8s di Proyek EduSense
Berdasarkan inspeksi langsung terhadap file bobot terlatih [`backend/models/best.pt`](file:///d:/Project%20from%20github/EduSense/backend/models/best.pt):
* **Varian Arsitektur:** YOLOv8 Small (`yolov8s`)
* **Jumlah Layer:** 129 layers
* **Jumlah Parameter:** 11.136.374 parameter (~11,1 Juta)
* **Beban Komputasi:** 28.6 GFLOPs
* **Output Kelas (`nc: 2`):**
  * `0`: `wajah` (Siswa Memperhatikan)
  * `1`: `head_down` (Siswa Tertidur / Menunduk)

---

## Slide 3: Peta Letak Kode Arsitektur YOLOv8s
| Tahap | File Proyek | Baris Kode | Fungsi |
| :--- | :--- | :--- | :--- |
| **Definisi Output Head** | [`dataset/dataset.yaml`](file:///d:/Project%20from%20github/EduSense/dataset/dataset.yaml) | Baris 11–18 | Menentukan `nc: 2` dan label kelas (`wajah`, `head_down`). |
| **Hyperparameter & Augmentasi** | [`training/train_config.yaml`](file:///d:/Project%20from%20github/EduSense/training/train_config.yaml) | Baris 8–30 | Mengatur HSV, rotasi, scale, mosaic, mixup, AdamW, lr. |
| **Inisialisasi & Training** | [`training/train_yolo.py`](file:///d:/Project%20from%20github/EduSense/training/train_yolo.py#L48-L71) | Baris 48 & 55 | Memuat `YOLO("yolov8s.pt")` dan menjalankan `model.train(...)`. |
| **Bobot Hasil Training** | [`backend/models/best.pt`](file:///d:/Project%20from%20github/EduSense/backend/models/best.pt) | File Biner | Menyimpan arsitektur 129 layer + bobot terlatih. |
| **Server API & Live CCTV** | [`backend/api_server.py`](file:///d:/Project%20from%20github/EduSense/backend/api_server.py#L87-L108) | Baris 87, 103, 257, 389 | Memuat `best.pt` & menjalankan `model.predict(...)`. |
| **Registrasi Wajah** | [`backend/register_wajah.py`](file:///d:/Project%20from%20github/EduSense/backend/register_wajah.py#L19-L96) | Baris 19, 35, 96 | Memuat `best.pt` untuk validasi wajah (`conf=0.45`). |
| **Uji Kamera Laptop** | [`backend/test_kamera_realtime.py`](file:///d:/Project%20from%20github/EduSense/backend/test_kamera_realtime.py#L33-L49) | Baris 33 & 49 | Memuat `best.pt` untuk demo webcam HUD real-time. |

---

## Slide 4: Alur Arsitektur YOLOv8s (Input $\rightarrow$ Output)
1. **Input Layer:**
   * Training: `imgsz=640` ($640 \times 640 \times 3$ RGB) — diatur di `training/train_yolo.py` baris 59.
   * Live Inference: `imgsz=320` ($320 \times 320 \times 3$ RGB) — diatur di `api_server.py` baris 257 agar FPS tinggi.
2. **Backbone (CSPDarknet + Modul C2f & SPPF):**
   * Mengekstraksi fitur visual dari citra kelas (kontur wajah, tekstur rambut, posisi kepala menunduk di meja).
3. **Neck (PANet / FPN):**
   * Menggabungkan fitur multi-skala sehingga siswa di barisan depan (objek besar) dan barisan belakang (objek kecil) sama-sama terdeteksi.
4. **Head (Decoupled Anchor-Free Head):**
   * Memisahkan cabang prediksi lokasi (*Bounding Box*) dan klasifikasi kelas (`0: wajah`, `1: head_down`) tanpa *anchor box* manual.

---

## Slide 5: Kode Definisi Kelas & Konfigurasi Training
* **Letak:** [`dataset/dataset.yaml`](file:///d:/Project%20from%20github/EduSense/dataset/dataset.yaml#L11-L18)
  ```yaml
  nc: 2
  names:
    0: wajah
    1: head_down
  ```
* **Letak:** [`training/train_config.yaml`](file:///d:/Project%20from%20github/EduSense/training/train_config.yaml#L8-L30)
  * Augmentasi: `hsv_v: 0.4`, `hsv_s: 0.7`, `degrees: 10.0`, `scale: 0.5`, `fliplr: 0.5`, `mosaic: 1.0`, `mixup: 0.15`, `erasing: 0.2`.
  * Optimizer: `AdamW`, `lr0: 0.001`, `lrf: 0.01`.

---

## Slide 6: Kode Inisialisasi & Training YOLOv8s
* **Letak:** [`training/train_yolo.py`](file:///d:/Project%20from%20github/EduSense/training/train_yolo.py#L48-L71)
  ```python
  model = YOLO("yolov8s.pt")  # Baris 48: Memuat arsitektur dasar YOLOv8s
  results = model.train(      # Baris 55: Melatih arsitektur pada dataset EduSense
      data=DATASET_YAML,
      epochs=40,
      patience=10,
      imgsz=640,
      batch=16,
      optimizer="AdamW"
  )
  ```

---

## Slide 7: Kode Pemuatan Arsitektur di Backend
* **Letak:** [`backend/api_server.py`](file:///d:/Project%20from%20github/EduSense/backend/api_server.py#L87-L108)
  ```python
  MODEL_CUSTOM = os.path.join(BASE_DIR, "models", "best.pt")  # Baris 87
  if os.path.exists(MODEL_CUSTOM):
      model = YOLO(MODEL_CUSTOM)                              # Baris 103
      nama_model_aktif = "best.pt (Custom EduSense)"
  ```
* **Fallback:** Jika `best.pt` tidak ada, server otomatis memuat `yolov8n.pt` (Baris 108).

---

## Slide 8: Kode Inferensi di Tiga Modul Berbeda
1. **Live Streaming CCTV** ([`backend/api_server.py`](file:///d:/Project%20from%20github/EduSense/backend/api_server.py#L257)):
   `results = model.predict(raw_rgb, conf=0.40, imgsz=320, verbose=False)`
2. **Endpoint Deteksi Gambar API** ([`backend/api_server.py`](file:///d:/Project%20from%20github/EduSense/backend/api_server.py#L389)):
   `results = model.predict(image, conf=0.35, verbose=False)`
3. **Validasi Registrasi Wajah** ([`backend/register_wajah.py`](file:///d:/Project%20from%20github/EduSense/backend/register_wajah.py#L96)):
   `results = yolo_model(frame, conf=0.45, imgsz=320, verbose=False)[0]`

---

## Slide 9: Hasil Evaluasi Performa Arsitektur YOLOv8s
* **Letak Perhitungan:** [`training/hitung_akurasi_matriks.py`](file:///d:/Project%20from%20github/EduSense/training/hitung_akurasi_matriks.py)
* **Metrik Uji (122 Ground Truth Validasi):**
  * **Classification Accuracy:** **98.36%**
  * **Recall `head_down` (Tidur):** **97.30%**
  * **Precision `head_down`:** **100.00%**
  * **F1-Score `head_down`:** **98.63%**

---

## Slide 10: Poin Kunci untuk Dijelaskan ke Dosen
1. Arsitektur YOLOv8s tidak memakai file `.cfg` manual seperti YOLOv3/v4, melainkan terintegrasi di paket `ultralytics` dan tersimpan dalam [`backend/models/best.pt`](file:///d:/Project%20from%20github/EduSense/backend/models/best.pt) (129 layer, 11,1 juta parameter, 28.6 GFLOPs).
2. Pemilihan varian **Small (`yolov8s`)** merupakan titik tengah optimal antara akurasi tinggi (98,36%) dan kecepatan *real-time* di laptop/server (`imgsz=320` pada live stream).
3. Ambang batas `conf=0.40` dipilih pada `api_server.py` untuk mengeliminasi *false alarm* latar belakang secara efektif.
