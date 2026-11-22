# Panduan Menghubungkan Perangkat Keras IoT ESP32 (EduSense)

Firmware ini digunakan untuk menghubungkan modul mikrokontroler ESP32 dengan sensor suhu DHT22 dan aktuator kipas angin ke ekosistem **EduSense Mobile App** & **Firebase Realtime Database**.

---

## 1. Skema Pengkabelan (Wiring Pinout)

| Komponen Hardware | Pin Komponen | Pin ESP32 | Keterangan |
| :--- | :--- | :--- | :--- |
| **Sensor DHT22 / DHT11** | VCC | 3.3V / 5V | Sumber daya sensor |
| | DATA | **GPIO 4** | Pin data sensor suhu & kelembaban |
| | GND | GND | Ground bersama |
| **Modul Kipas / Driver MOSFET** | PWM In / Gate | **GPIO 18** | Pin sinyal PWM pengatur kecepatan (0 - 3) |
| | VCC Kipas | 12V / 5V Eksternal | Tegangan motor kipas |
| | GND Kipas | GND Eksternal + ESP32 | Ground wajib disambung (Common Ground) |
| **LED Indikator Onboard** | - | **GPIO 2** | Menyala konstan saat Wi-Fi terhubung |

---

## 2. Cara Kerja Sistem Otomatisasi (Prompt 5 & 6)

### A. Mode Otomatis (`Auto`)
Sistem secara mandiri mengatur tingkat kecepatan kipas berdasarkan pembacaan suhu DHT22:
- **Suhu < 26.0 °C** $\rightarrow$ Kipas **Mati** (Level 0 / PWM 0%)
- **26.0 °C – 28.5 °C** $\rightarrow$ Kipas **Pelan** (Level 1 / PWM 33%)
- **28.6 °C – 31.0 °C** $\rightarrow$ Kipas **Sedang** (Level 2 / PWM 66%)
- **Suhu > 31.0 °C** $\rightarrow$ Kipas **Maksimal** (Level 3 / PWM 100%)

### B. Mode Manual (`Manual`)
Dosen memilih kecepatan langsung dari aplikasi mobile (Mati, 1, 2, 3). ESP32 akan langsung mengabaikan pembacaan suhu dan mengunci kecepatan sesuai perintah dosen.

---

## 3. Langkah-Langkah Flashing ke ESP32

1. Buka Arduino IDE.
2. Pasang library berikut melalui **Library Manager** (`Ctrl + Shift + I`):
   - `DHT sensor library` by Adafruit
   - `Adafruit Unified Sensor`
   - `ArduinoJson` (v6 atau v7)
3. Buka berkas `edusense_esp32.ino`.
4. Sesuaikan konstanta:
   - `WIFI_SSID` & `WIFI_PASSWORD`: Nama dan sandi hotspot HP / Wi-Fi Anda.
   - `FASTAPI_SERVER_IP`: Alamat IP laptop (contoh: `192.168.1.10`).
5. Pilih Board: **ESP32 Dev Module** dan Port COM yang sesuai.
6. Klik **Upload**.
7. Buka Serial Monitor pada baud rate `115200` untuk memantau koneksi Wi-Fi dan transmisi data telemetri.

