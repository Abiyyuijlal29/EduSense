/*
 * ==============================================================================
 * EDUSENSE SMART CLASSROOM - ESP32 FIRMWARE IOT KIPAS OTOMATIS
 * ==============================================================================
 * Fungsi:
 * 1. Membaca data suhu & kelembaban dari sensor DHT22 / DHT11.
 * 2. Terhubung ke Wi-Fi dan menyinkronkan data ke Firebase Realtime Database
 *    (URL: https://classvision-iot-default-rtdb.asia-southeast1.firebasedatabase.app)
 *    serta REST API FastAPI backend (http://<IP_LAPTOP>:8000/api/iot/telemetri).
 * 3. Mengontrol kecepatan kipas secara OTOMATIS berdasar suhu DHT22:
 *    - Suhu < 26.0 °C  -> Kipas Mati (Kecepatan 0, PWM 0%)
 *    - 26.0 - 28.5 °C  -> Kipas Pelan (Kecepatan 1, PWM 33%)
 *    - 28.6 - 31.0 °C  -> Kipas Sedang (Kecepatan 2, PWM 66%)
 *    - Suhu > 31.0 °C  -> Kipas Maksimal (Kecepatan 3, PWM 100%)
 * 4. Mendukung MODE MANUAL dari aplikasi mobile dosen (mengunci kecepatan 0-3).
 * ==============================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "DHT.h"

// ================= KONFIGURASI WI-FI =================
// Sesuaikan dengan SSID dan Password Hotspot HP / Wi-Fi ruangan kelas
const char* WIFI_SSID     = "EduSense_ClassLab";
const char* WIFI_PASSWORD = "password1234";

// ================= KONFIGURASI SERVER & FIREBASE =================
// Masukkan IP laptop yang menjalankan server FastAPI (lihat di profil app mobile)
const char* FASTAPI_SERVER_IP = "192.168.1.10"; 
const int   FASTAPI_PORT      = 8000;

// URL Firebase Realtime Database EduSense
const char* FIREBASE_HOST = "https://classvision-iot-default-rtdb.asia-southeast1.firebasedatabase.app";

// ================= PINOUT HARDWARE =================
#define DHTPIN        4       // Pin Data Sensor DHT22 / DHT11 (GPIO 4)
#define DHTTYPE       DHT22   // Ganti ke DHT11 jika menggunakan sensor biru DHT11
#define FAN_PWM_PIN   18      // Pin PWM Kontrol Kecepatan Kipas (GPIO 18)
#define LED_INDICATOR 2       // Onboard LED indikator koneksi (GPIO 2)

// Konfigurasi PWM ESP32
const int PWM_FREQ     = 25000; // 25 kHz standar kipas 4-wire / MOSFET
const int PWM_CHANNEL  = 0;
const int PWM_RES      = 8;     // Resolusi 8-bit (0 - 255)

DHT dht(DHTPIN, DHTTYPE);

// State IoT Saat Ini
float suhu_aktual = 28.0;
float kelembaban_aktual = 60.0;
String mode_kipas = "Auto";    // "Auto" atau "Manual"
int kecepatan_kipas = 1;       // 0, 1, 2, atau 3
unsigned long last_telemetry_time = 0;
const unsigned long TELEMETRY_INTERVAL = 3000; // Kirim telemetri setiap 3 detik

// Fungsi Menghitung Kecepatan Kipas Otomatis Berdasar Suhu (Prompt 5)
int hitungKecepatanOtomatis(float suhu) {
  if (suhu < 26.0) return 0;       // Mati
  if (suhu <= 28.5) return 1;      // Pelan
  if (suhu <= 31.0) return 2;      // Sedang
  return 3;                        // Cepat / Maksimal
}

// Mengatur Output PWM ke Kipas
void setDutyCycleKipas(int speedLevel) {
  int duty = 0;
  switch (speedLevel) {
    case 0: duty = 0; break;       // 0% (Mati)
    case 1: duty = 85; break;      // ~33% (Pelan)
    case 2: duty = 170; break;     // ~66% (Sedang)
    case 3: duty = 255; break;     // 100% (Maksimal)
    default: duty = 0; break;
  }
  ledcWrite(PWM_CHANNEL, duty);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n[EDUSENSE] Memulai Modul IoT Kipas Pintar ESP32...");

  pinMode(LED_INDICATOR, OUTPUT);
  digitalWrite(LED_INDICATOR, LOW);

  // Inisialisasi PWM Kipas
  ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RES);
  ledcAttachPin(FAN_PWM_PIN, PWM_CHANNEL);
  setDutyCycleKipas(0);

  // Inisialisasi Sensor DHT22
  dht.begin();
  Serial.println("[DHT22] Sensor suhu & kelembaban siap.");

  // Koneksi ke Wi-Fi
  Serial.printf("[WIFI] Menghubungkan ke: %s\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 25) {
    delay(500);
    Serial.print(".");
    retry++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Berhasil terhubung!");
    Serial.print("[WIFI] Alamat IP ESP32: ");
    Serial.println(WiFi.localIP());
    digitalWrite(LED_INDICATOR, HIGH);
  } else {
    Serial.println("\n[WIFI] Peringatan: Wi-Fi belum terhubung. Beroperasi dalam mode standalone offline.");
  }
}

// 1. Kirim & Ambil Data dari Firebase Realtime Database
void syncWithFirebase() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(FIREBASE_HOST) + "/iot.json";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // Jika mode Auto, hitung kecepatan berdasar suhu
  if (mode_kipas == "Auto") {
    kecepatan_kipas = hitungKecepatanOtomatis(suhu_aktual);
  }

  // Buat payload JSON telemetri
  StaticJsonDocument<256> doc;
  doc["suhu"] = serialized(String(suhu_aktual, 1));
  doc["kelembaban"] = serialized(String(kelembaban_aktual, 1));
  doc["mode_kipas"] = mode_kipas;
  doc["kecepatan_kipas"] = kecepatan_kipas;
  doc["status_ruangan"] = (mode_kipas == "Auto") ? "Otomatis Suhu" : "Manual Dosen";

  String requestBody;
  serializeJson(doc, requestBody);

  // Kirim data via PATCH
  int httpCode = http.PATCH(requestBody);
  if (httpCode == 200) {
    // Ambil respon perintah kontrol terbaru
    String response = http.getString();
    StaticJsonDocument<256> resDoc;
    DeserializationError error = deserializeJson(resDoc, response);
    if (!error) {
      if (resDoc.containsKey("mode_kipas")) {
        mode_kipas = resDoc["mode_kipas"].as<String>();
      }
      if (resDoc.containsKey("kecepatan_kipas") && mode_kipas == "Manual") {
        kecepatan_kipas = resDoc["kecepatan_kipas"].as<int>();
      }
    }
  }
  http.end();
}

// 2. Kirim Telemetri ke Backend FastAPI (Sebagai Jalur Cadangan / REST API)
void syncWithFastAPI() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = "http://" + String(FASTAPI_SERVER_IP) + ":" + String(FASTAPI_PORT) + "/api/iot/telemetri";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<256> doc;
  doc["suhu"] = suhu_aktual;
  doc["kelembaban"] = kelembaban_aktual;
  doc["mode_kipas"] = mode_kipas;
  doc["kecepatan_kipas"] = kecepatan_kipas;
  doc["id_perangkat"] = "ESP32_Smart_Classroom";

  String requestBody;
  serializeJson(doc, requestBody);

  int httpCode = http.POST(requestBody);
  if (httpCode == 200) {
    String response = http.getString();
    StaticJsonDocument<256> resDoc;
    if (!deserializeJson(resDoc, response)) {
      if (resDoc.containsKey("mode_kipas")) {
        mode_kipas = resDoc["mode_kipas"].as<String>();
      }
      if (resDoc.containsKey("kecepatan_kipas") && mode_kipas == "Manual") {
        kecepatan_kipas = resDoc["kecepatan_kipas"].as<int>();
      }
    }
  }
  http.end();
}

void loop() {
  // 1. Baca Sensor DHT22
  float t = dht.readTemperature();
  float h = dht.readHumidity();

  if (!isnan(t) && !isnan(h)) {
    suhu_aktual = t;
    kelembaban_aktual = h;
  }

  // 2. Kontrol Kecepatan Kipas
  if (mode_kipas == "Auto") {
    kecepatan_kipas = hitungKecepatanOtomatis(suhu_aktual);
  }
  setDutyCycleKipas(kecepatan_kipas);

  // 3. Kirim Telemetri Berkala ke Firebase & Server
  unsigned long now = millis();
  if (now - last_telemetry_time >= TELEMETRY_INTERVAL) {
    last_telemetry_time = now;

    Serial.printf("[IOT] Suhu: %.1f °C | Kelembaban: %.1f %% | Mode: %s | Kipas: Level %d\n",
                  suhu_aktual, kelembaban_aktual, mode_kipas.c_str(), kecepatan_kipas);

    // Sinkronisasi ganda: Firebase RTDB & Server FastAPI
    syncWithFirebase();
    syncWithFastAPI();
  }

  delay(200);
}

