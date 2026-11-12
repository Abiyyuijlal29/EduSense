# DECK SLIDE PRESENTASI: EDUSENSE VISION AI
## Sistem Monitoring Kelas Cerdas & Presensi Real-Time Berbasis YOLOv8 dan IoT Mobile

---

### SLIDE 1: JUDUL & IDENTITAS PROYEK
* **Judul:** EduSense: Smart Classroom Vision AI & Automated Attendance
* **Sub-Judul:** Pemantauan Perilaku Siswa (Tidur vs Memperhatikan) Menggunakan YOLOv8 dan Presensi Terintegrasi Flutter Mobile
* **Penyaji:** Tim Pengembang EduSense
* **Kategori:** Computer Vision, Internet of Things (IoT), Mobile Application

> **Speaker Notes (Naskah Pembicara):**
> *"Selamat pagi/siang Bapak/Ibu Dewan Penguji dan rekan-rekan sekalian. Hari ini kami mempresentasikan EduSense, sebuah sistem cerdas end-to-end yang menggabungkan visi komputer tingkat lanjut untuk mendeteksi perilaku siswa di kelas secara real-time dan sistem presensi otomatis berbasis pengenalan wajah."*

---

### SLIDE 2: PERMASALAHAN & LATAR BELAKANG
* **Masalah 1 - Presensi Manual Tidak Efisien:** Guru menghabiskan 10–15 menit jam pelajaran hanya untuk memanggil absensi siswa satu per satu.
* **Masalah 2 - Pengawasan Kelas Terbatas:** Sulit bagi pengajar untuk memantau konsentrasi puluhan siswa sekaligus, terutama siswa di baris belakang yang tertidur.
* **Solusi EduSense:** 
  1. Presensi wajah otomatis dengan pencocokan identitas database.
  2. Deteksi perilaku kelas (*Attentive* vs *Head-Down/Tidur*) secara otomatis dan objektif sepanjang jam pelajaran.

> **Speaker Notes:**
> *"Di ruang kelas besar, presensi manual menyita waktu belajar yang berharga. Selain itu, pengajar sering tidak menyadari ketika siswa di sudut belakang tertidur di atas meja. EduSense hadir untuk mengotomatiskan kedua proses ini secara simultan tanpa menambah beban kerja pengajar."*

---

### SLIDE 3: ARSITEKTUR SISTEM MENYELURUH (END-TO-END)
* **1. Edge / CCTV Layer:** Kamera webcam laptop atau CCTV kelas menangkap video stream.
* **2. AI Engine Layer:** YOLOv8 (`models/best.pt`) memproses frame video secara real-time.
* **3. Backend Server Layer:** FastAPI (`api_server.py`) mengelola multithreading dan streaming video MJPEG.
* **4. Cloud Layer:** Firebase Realtime Database menyinkronkan status kelas seketika.
* **5. Mobile App Layer:** Aplikasi Flutter (`edusense_mobile`) menampilkan dashboard monitoring di genggaman dosen/guru.

> **Speaker Notes:**
> *"EduSense bukan sekadar model kecerdasan buatan di notebook, melainkan sistem lengkap yang terintegrasi penuh: mulai dari penangkapan video di kamera, pemrosesan AI di server FastAPI, sinkronisasi data ke cloud Firebase, hingga tayangan langsung di aplikasi mobile Flutter."*

---

### SLIDE 4: PEMETAAN DUA MODUL UTAMA
* **A. Modul Presensi Wajah (Menjawab Pertanyaan: "SIAPA SISWANYA?"):**
  * **File Kunci:** `EduSense_Project/register_wajah.py`
  * **Folder Data:** `EduSense_Project/dataset_absensi/`
  * **Cara Kerja:** Merekam 30 foto wajah per mahasiswa yang divalidasi oleh YOLOv8, kemudian diidentifikasi menggunakan ekstraksi vektor fitur wajah (DeepFace).
  * **Layar Mobile:** `edusense_mobile/lib/screens/presensi_screen.dart`
* **B. Modul Deteksi Pose Tertidur (Menjawab Pertanyaan: "APA PERILAKUNYA?"):**
  * **File Kunci:** `EduSense_Project/test_kamera_realtime.py` & `api_server.py`
  * **Model Inti:** `EduSense_Project/models/best.pt`
  * **Cara Kerja:** Mendeteksi kelas `0: wajah` (bangun) vs `1: head_down` (tertidur di meja) secara terus-menerus.
  * **Layar Mobile:** `edusense_mobile/lib/screens/monitoring_screen.dart`

> **Speaker Notes:**
> *"Sangat penting untuk membedakan dua fungsi utama sistem ini: Modul Presensi bekerja mengenali identitas nama dan NIM siswa saat masuk kelas, sedangkan Modul Monitoring Perilaku bekerja terus-menerus mengenali pose apakah siswa sedang memperhatikan atau kepalanya tertelungkup tidur di meja."*

---

### SLIDE 5: REKAYASA DATASET & PEMBERSIHAN DATA
* **Tantangan Awal:** 
  * 716 citra asli bertumpuk vertikal (368x416 piksel) dengan double bounding box palsu.
  * Pembagian data lama memakai random shuffle yang menyebabkan kebocoran data (*data leakage*).
* **Solusi Rekayasa Data:**
  * **Unstacking Script (`fix_dataset.py`):** Memotong citra menjadi frame tunggal 368x208 dan merekalibrasi koordinat $y_{new} = y \times 2$.
  * **Block-Temporal Split (`split_data.py`):** Membagi video berdasarkan potongan urutan waktu (70% Train, 15% Val, 15% Test) sehingga frame yang berdekatan tidak saling bocor.
* **Hasil Akhir:** 825 dataset bersih dengan distribusi seimbang 40% Wajah dan 60% Tertidur di semua split.

> **Speaker Notes:**
> *"Kekuatan model AI bergantung pada kualitas datanya. Kami melakukan sanitasi citra bertumpuk dan menerapkan Block-Temporal Split. Ini menjamin data pengujian benar-benar data baru yang belum pernah dilihat model, sehingga evaluasi model kami dapat dipertanggungjawabkan secara ilmiah."*

---

### SLIDE 6: CARA KERJA DETEKSI YOLOV8
* **1. Preprocessing:** Frame video dinormalisasi dan diubah ke resolusi input ($640 \times 640$).
* **2. Backbone (CSPDarknet):** Mengekstraksi fitur visual (bentuk kepala, tekstur rambut, kontur punggung menunduk).
* **3. Neck (PANet):** Menggabungkan fitur multi-skala agar siswa di baris belakang (skala kecil) tetap terdeteksi.
* **4. Head (Anchor-Free):** Memprediksi titik koordinat box dan probabilitas kelas.
* **5. NMS:** Menyaring box tumpang tindih hingga tersisa satu deteksi paling presisi per siswa.

> **Speaker Notes:**
> *"YOLOv8 bekerja dengan prinsip one-stage detection. Dalam satu lintasan komputasi, model secara simultan memprediksi lokasi siswa dan status perilakunya dengan kecepatan sangat tinggi."*

---

### SLIDE 7: KOMPARASI MODEL: MENGAPA YOLOV8?
* **YOLOv8 vs Haar Cascade:**
  * Haar Cascade hanya mampu mendeteksi wajah tegak lurus frontal dan **gagal total mendeteksi orang tidur**.
  * YOLOv8 memiliki ketahanan tinggi (*robust*) terhadap variasi sudut, kemiringan kepala, dan rambut saat tertidur.
* **YOLOv8 vs DeepFace:**
  * DeepFace sangat akurat untuk mengenali identitas wajah (dipakai untuk absensi), namun komputasinya terlalu lambat untuk memproses video streaming 30 FPS.
  * YOLOv8 sangat efisien untuk streaming video kelas real-time.

> **Speaker Notes:**
> *"Kami membandingkan beberapa model: Haar Cascade terbukti gagal mengenali siswa tidur karena tidak ada fitur mata dan hidung saat menunduk. Oleh karena itu, kami menetapkan YOLOv8 sebagai mesin deteksi perilaku kelas dan DeepFace sebagai mesin presensi."*

---

### SLIDE 8: HASIL EVALUASI CONFUSION MATRIX
* **Uji Coba pada 122 Sampel Validasi:**
  * **True Positive Wajah:** 48 dari 48 siswa memperhatikan terdeteksi tepat (Recall 100%).
  * **True Positive Tertidur:** 72 dari 74 siswa tertidur terdeteksi tepat (Recall 97.30%).
  * **False Negative (Terlewat):** Hanya 2 kesalahan tebak (2 siswa tidur dikira bangun).
  * **Zero Missed Students:** Baris background bernilai 0, artinya **100% siswa di kelas berhasil terdeteksi**.

> **Speaker Notes:**
> *"Ini adalah hasil Confusion Matrix resmi model kami. Dari 122 sampel pengujian, model berhasil mendeteksi 120 siswa dengan benar. Menariknya, nilai True Positive wajah mencapai 48 dari 48, dan True Positive tidur mencapai 72 dari 74."*

---

### SLIDE 9: PERHITUNGAN AKURASI MATEMATIS
* **Akurasi Klasifikasi Target:**
  $$\text{Accuracy} = \frac{48 + 72}{48 + 74} = \frac{120}{122} = \mathbf{98.36\%}$$
* **Recall Rata-Rata (*Macro Recall*):**
  $$\text{mRecall} = \frac{100\% + 97.30\%}{2} = \mathbf{98.65\%}$$
* **F1-Score Model:**
  * Kelas Wajah: **97.96%**
  * Kelas Tertidur: **98.63%**
* **Solusi False Alarm Background:** Mengatur ambang batas $\text{conf}=0.40$ pada sistem kamera secara otomatis membuang 100% deteksi palsu di meja/kursi.

> **Speaker Notes:**
> *"Melalui rumus standar confusion matrix, model kami mencatatkan skor akurasi 98.36% dengan F1-Score di atas 97% untuk kedua kelas. Ini membuktikan model memiliki tingkat kepercayaan yang sangat tinggi untuk diimplementasikan."*

---

### SLIDE 10: BACKEND FASTAPI & MULTITHREADING STREAMING
* **Implementasi Backend (`api_server.py`):**
  * **Class `CameraManager`:** Menggunakan `threading.Lock()` dan `threading.Thread` terpisah agar pembacaan frame kamera tidak menghambat server API.
  * **Streaming MJPEG:** Mengirimkan visual deteksi kotak AI langsung ke jaringan dalam format *Multipart StreamingResponse*.
  * **Frame Skipping Adaptif:** Menjalankan inferensi AI setiap 2 frame untuk menjaga performa kamera lokal tetap stabil pada **25–30 FPS** di prosesor CPU laptop.

> **Speaker Notes:**
> *"Di sisi backend, kami membangun arsitektur asynchronous berbasis FastAPI. Dengan teknik multithreading dan frame-skipping, video feed tetap mengalir lancar di 30 FPS tanpa terjadi lag atau overheat pada CPU laptop."*

---

### SLIDE 11: IMPLEMENTASI MOBILE FLUTTER & FIREBASE
* **Aplikasi Mobile (`edusense_mobile`):**
  * **Monitoring Screen (`monitoring_screen.dart`):** Dosen dapat melihat tayangan CCTV kelas dan grafik live jumlah siswa tertidur.
  * **Presensi Screen (`presensi_screen.dart`):** Rekapitulasi daftar hadir real-time (`Hadir`, `Izin`, `Alpa`).
  * **Firebase Service:** Sinkronisasi cloud dua arah (data presensi dan metrik perilaku kelas) yang langsung ter-update di layar smartphone dalam hitungan milidetik.

> **Speaker Notes:**
> *"Pengajar tidak perlu membuka laptop di depan kelas. Cukup melalui smartphone menggunakan aplikasi Flutter EduSense, pengajar dapat memantau siaran langsung kelas dan melihat rekap presensi yang otomatis terhubung ke Firebase."*

---

### SLIDE 12: KESIMPULAN & NILAI LEBIH PROYEK
* **1. Solusi Utuh (End-to-End):** Menghubungkan AI Vision, Backend API, Cloud Database, dan Mobile App.
* **2. Akurasi Tinggi & Ilmiah:** Akurasi klasifikasi **98.36%** dengan metodologi pemisahan dataset bebas data leakage.
* **3. Ringan & Efisien:** Bebas dari dependensi usang (Haar Cascade), murni Deep Learning modern yang hemat daya di CPU.
* **Pengembangan Masa Depan:** Integrasi notifikasi getar pada HP dosen jika siswa tidur lebih dari 5 menit berturut-turut.

> **Speaker Notes:**
> *"Sebagai kesimpulan, EduSense berhasil membuktikan bahwa sistem pemantauan kelas cerdas berbasis AI dapat dibangun secara efisien, akurat, dan siap pakai. Terima kasih atas perhatian Bapak/Ibu, kami membuka sesi tanya jawab."*

---
*Naskah presentasi ini dirancang khusus untuk memandu presentasi lisan dan pembuatan slide visual PowerPoint/Canva.*
