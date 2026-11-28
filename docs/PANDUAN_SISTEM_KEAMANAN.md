# 🛡️ Panduan Sistem Keamanan EduSense

Dokumentasi implementasi 3 lapis keamanan pada proyek **EduSense**:
1. **Firebase Security Rules** (Keamanan Cloud Database)
2. **JWT Authentication** (Keamanan REST API FastAPI)
3. **Pydantic Input Validation** (Validasi Format Data & Pencegahan Injeksi)

---

## 📁 Struktur Folder Keamanan (Backend)

Struktur folder backend dibuat modular dan rapi:
```text
backend/
├── security/
│   ├── __init__.py
│   └── auth.py             <-- Logika pembuatan & verifikasi JWT Token
├── schemas/
│   ├── __init__.py
│   └── schemas.py          <-- Model validasi input Pydantic (v2)
├── models/
│   └── best.pt             <-- Bobot model YOLOv8 EduSense
├── api_server.py           <-- Endpoint FastAPI terintegrasi JWT & Pydantic
├── firebase_rules.json     <-- File konfigurasi rules Firebase Realtime Database
└── requirements.txt        <-- Dependencies (termasuk pyjwt)
```

---

## 1. ☁️ Firebase Security Rules (Keamanan Database)

### Cara Kerja:
Firebase Realtime Database menerapkan aturan keamanan sisi server Google. Setiap permintaan `read` (baca) atau `write` (tulis) dari aplikasi Flutter akan diperiksa status login-nya (`auth != null`).

- Jika pengguna **belum login**: Firebase langsung memblokir akses (*Permission Denied*).
- Jika pengguna **sudah login**: Firebase mengizinkan membaca data profil, presensi, telemetri IoT, dan hasil monitoring.

### Cara Memasang di Firebase Console:
1. Buka [Firebase Console](https://console.firebase.google.com/).
2. Pilih proyek EduSense Anda.
3. Di panel kiri, klik **Build** -> **Realtime Database**.
4. Klik tab **Rules**.
5. Salin isi file `firebase_rules.json` di root proyek dan tempel di editor tersebut.
6. Klik tombol **Publish**.
7. Node `/dosen/{NIP}` mengizinkan akun Firebase Auth membuat atau mengubah profilnya sendiri berdasarkan `uid`; pastikan rules terbaru sudah dipublikasikan.
8. Setelah OTP pendaftaran valid, aplikasi membuat akun Firebase Authentication dan menyimpan profil ke `/dosen/{NIP}`. Password hanya disimpan Firebase Authentication, bukan di Realtime Database.

---

## 2. 🔑 JWT Authentication (Keamanan REST API)

### Cara Kerja:
1. **Login Dosen (`POST /api/auth/login`)**:
   - Dosen memasukkan email/NIP dan password.
   - Server memvalidasi kredensial.
   - Jika benar, server membuat **JSON Web Token (JWT)** yang ditandatangani dengan `SECRET_KEY` dan algoritma `HS256`.
   - Token ini membawa payload identitas: NIP, nama, email, dan role (`dosen`).
2. **Akses Endpoint Terproteksi**:
   - Aplikasi mobile atau browser mengirim token pada Header HTTP:
     ```http
     Authorization: Bearer <TOKEN_JWT>
     ```
   - Untuk stream video CCTV/frame, token juga didukung via query parameter URL:
     ```http
     GET /api/kamera/frame?token=<TOKEN_JWT>
     ```
3. **Verifikasi Otomatis (`Depends(get_current_user)`)**:
   - FastAPI memverifikasi tanda tangan digital token.
   - Jika token kedaluwarsa atau dimanipulasi, server merespons `HTTP 401 Unauthorized`.

---

## 3. 🔍 Pydantic Input Validation (Validasi & Sanitasi Data)

### Cara Kerja:
FastAPI memanfaatkan Pydantic v2 untuk memvalidasi setiap data JSON yang masuk sebelum dieksekusi oleh fungsi Python:

1. **Anti Injeksi pada Login (`LoginRequest`)**:
   - Menghapus spasi kosong berlebih (*whitespace strip*).
   - Memblokir karakter berbahaya seperti kutip tunggal (`'`), titik koma (`;`), dan tanda komentar SQL (`--`).
2. **Validasi Batas Nilai IoT (`IoTControlRequest`)**:
   - `mode_kipas` hanya menerima `"Auto"` atau `"Manual"`.
   - `kecepatan_kipas` dibatasi hanya angka `0`, `1`, `2`, atau `3` (`ge=0, le=3`). Nilai di luar batas otomatis ditolak dengan `HTTP 422 Unprocessable Entity`.
3. **Pencegahan Directory Traversal (`DeteksiRequest`)**:
   - Memeriksa `path_gambar` agar tidak mengandung karakter traversal `..` atau absolute drive path (misal `C:\Windows`) untuk melindungi file sistem server.

---

## 4. 📧 Pengiriman OTP Email

OTP pendaftaran, kirim ulang, dan pemulihan kata sandi dikirim oleh backend melalui SMTP.
Agar tidak perlu mengatur PowerShell setiap menjalankan server, lakukan sekali:

1. Masuk ke folder `backend` dan jalankan `python -m pip install -r requirements.txt` (cukup sekali).
2. Salin `backend/.env.example` menjadi `backend/.env` (cukup sekali).
3. Isi `SMTP_USERNAME` dengan Gmail pengirim dan `SMTP_PASSWORD` dengan App Password Gmail.
4. Jalankan backend seperti biasa. Backend membaca `.env` otomatis saat mulai.

Jika konfigurasi tidak ada atau pengiriman gagal, API mengembalikan error dan
tidak menyatakan OTP berhasil dikirim. OTP acak berlaku selama 5 menit.

Contoh variabel yang diisi pada `backend/.env`:

```dotenv
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=pengirim@gmail.com
SMTP_PASSWORD=app-password-16-karakter
SMTP_FROM_EMAIL=pengirim@gmail.com
SMTP_USE_SSL=false
```

Jangan commit file `backend/.env` atau membagikan App Password. Pengaturan
pengirim ini cukup sekali; setiap pengguna yang mendaftar menerima OTP ke email
masing-masing tanpa perlu mengatur apa pun di akunnya.

Untuk memperbarui password Firebase Authentication setelah OTP lupa-password
valid, backend juga memerlukan Firebase Admin SDK. Pasang dependency backend
dari `requirements.txt` dan atur `GOOGLE_APPLICATION_CREDENTIALS` ke file
service account Firebase yang memiliki izin mengelola Authentication. Jangan
commit file service account ke repository. Jika kredensial tidak tersedia,
API menolak reset dan tidak memberi respons sukses palsu.

Lokasi service account juga dapat ditambahkan sebagai `GOOGLE_APPLICATION_CREDENTIALS`
di `backend/.env`; jangan salin file service account ke repository.

---

## 🧪 Cara Pengujian Melalui Swagger UI

1. Jalankan backend:
   ```bash
   cd backend
   python api_server.py
   ```
2. Buka browser di laptop: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
3. Coba akses endpoint `GET /api/presensi` tanpa token -> Akan muncul error **401 Unauthorized**.
4. Buka endpoint `POST /api/auth/login`, klik **Try it out**, masukkan username `dosen@polije.ac.id` dan password `dosen123` -> Dapatkan token JWT.
5. Klik tombol hijau **Authorize** di bagian kanan atas Swagger UI, tempel token, lalu klik **Authorize**.
6. Sekarang semua endpoint terproteksi dapat diakses dengan sukses!
