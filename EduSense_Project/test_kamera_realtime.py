# -*- coding: utf-8 -*-
"""
Aplikasi Uji Coba Kamera Laptop Real-Time (EduSense Vision AI)
============================================================
Fitur Utama:
1. Live Camera Feed (Webcam laptop indeks 0).
2. Inferensi Deteksi Perilaku YOLOv8 (best.pt) / Fallback Haar Cascade.
3. Live Pengolahan Citra:
   - Mode 1: Tampilan Normal (Raw Color + Bounding Box).
   - Mode 2: Tampilan Grayscale (Hitam-Putih + Bounding Box).
   - Mode 3: Tampilan Side-by-Side (Raw | Grayscale | Bounding Box) secara simultan.
4. Live Metrics HUD:
   - Real-time FPS (Frame per Detik).
   - Real-time Laplacian Sharpness Score (Skor Ketajaman Citra).
   - Status Perilaku (Memperhatikan vs Tertidur/Menunduk).
5. Tombol Kontrol:
   - '1', '2', '3': Ganti mode tampilan visual.
   - 's': Ambil foto cuplikan (screenshot) ke folder 'hasil_percobaan_kamera'.
   - 'q': Keluar dari kamera.
"""

import os
import sys
import time
from datetime import datetime
import cv2
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "models", "best.pt")
CASCADE_PATH = os.path.join(BASE_DIR, "haarcascade_frontalface_default.xml")
SAVE_DIR = os.path.join(BASE_DIR, "hasil_percobaan_kamera")
os.makedirs(SAVE_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. INISIALISASI MODEL AI (YOLO / HAAR CASCADE FALLBACK)
# -------------------------------------------------------------
model_yolo = None
use_yolo = False

try:
    from ultralytics import YOLO
    if os.path.exists(MODEL_PATH):
        print(f"[INIT] Memuat model YOLO custom dari: {MODEL_PATH}")
        model_yolo = YOLO(MODEL_PATH)
        use_yolo = True
        print("[INIT] Berhasil memuat YOLOv8s EduSense!")
    else:
        print(f"[WARN] File '{MODEL_PATH}' belum ditemukan.")
except Exception as e:
    print(f"[INFO] Model YOLO tidak aktif: {e}")
    print("[INFO] Menggunakan model deteksi OpenCV Haar Cascade...")

face_cascade = None
if os.path.exists(CASCADE_PATH):
    face_cascade = cv2.CascadeClassifier(CASCADE_PATH)
    if face_cascade.empty():
        print(f"[WARN] Gagal memuat CascadeClassifier dari {CASCADE_PATH}")
        face_cascade = None
else:
    cascade_cv2 = os.path.join(getattr(cv2.data, 'haarcascades', ''), "haarcascade_frontalface_default.xml")
    if os.path.exists(cascade_cv2):
        face_cascade = cv2.CascadeClassifier(cascade_cv2)


def calculate_sharpness(gray_img: np.ndarray) -> float:
    """Menghitung nilai ketajaman fokus citra menggunakan operator Laplacian (dioptimalkan)."""
    # Downscale untuk kalkulasi kilat (<2ms)
    small_gray = cv2.resize(gray_img, (160, 90))
    return float(cv2.Laplacian(small_gray, cv2.CV_64F).var())


def draw_hud(img: np.ndarray, mode_name: str, fps: float, sharpness: float, count_wajah: int, count_tidur: int, conf_thresh: float = 0.25, detector_info: str = "YOLO") -> None:
    """Menggambar panel metrik HUD informatif pada frame kamera."""
    h, w, _ = img.shape
    
    # Overlay semi-transparan untuk header HUD
    header_overlay = img.copy()
    cv2.rectangle(header_overlay, (0, 0), (w, 55), (20, 24, 33), -1)
    cv2.addWeighted(header_overlay, 0.75, img, 0.25, 0, img)

    # Info Teks Header
    cv2.putText(img, f"EDUSENSE VISION AI - MODE: {mode_name.upper()}", (15, 24),
                cv2.FONT_HERSHEY_SIMPLEX, 0.65, (56, 189, 248), 2)
    cv2.putText(img, f"FPS: {fps:.1f} | Fokus: {sharpness:.1f} | Detektor: {detector_info} | Conf Thresh: {conf_thresh:.2f}", (15, 46),
                cv2.FONT_HERSHEY_SIMPLEX, 0.48, (148, 163, 184), 1)

    # Status Siswa
    status_text = f"Memperhatikan: {count_wajah}  |  Tertidur: {count_tidur}"
    cv2.putText(img, status_text, (w - 330, 35),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (74, 222, 128) if count_tidur == 0 else (248, 113, 113), 2)

    # Footer Petunjuk Tombol
    footer_overlay = img.copy()
    cv2.rectangle(footer_overlay, (0, h - 30), (w, h), (20, 24, 33), -1)
    cv2.addWeighted(footer_overlay, 0.75, img, 0.25, 0, img)
    cv2.putText(img, "[1] Normal | [2] Gray | [3] Side-by-Side | [+/-] Conf | [s] Screenshot | [q] Keluar",
                (15, h - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (203, 213, 225), 1)


def main():
    print("=" * 65)
    print("   SISTEM UJI COBA REAL-TIME KAMERA LAPTOP - EDUSENSE")
    print("=" * 65)
    print("Model AI Aktif :", "YOLOv8s Custom (best.pt)" if use_yolo else "Haar Cascade Fallback")
    print("Kontrol:")
    print("  [1] Tampilan Normal (RGB + Bounding Box)")
    print("  [2] Tampilan Grayscale (Hitam-Putih + Bounding Box)")
    print("  [3] Tampilan Side-by-Side (3 Panel)")
    print("  [+] / [-] Naikkan / Turunkan Ambang Batas Akurasi (Confidence)")
    print("  [s] Ambil Screenshot")
    print("  [q] Keluar")
    print("=" * 65)

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[ERROR] Kamera laptop (indeks 0) tidak dapat dibuka!")
        return

    # Atur resolusi kamera (640x480 untuk performa realtime tinggi di CPU)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    mode = 1
    prev_time = time.time()
    fps = 30.0
    conf_threshold = 0.20
    frame_counter = 0
    FRAME_SKIP = 2  # Jalankan inferensi AI setiap 2 frame agar kamera tetap 25-30 FPS

    # Cache hasil deteksi terakhir
    cached_boxes = []
    cached_count_wajah = 0
    cached_count_tidur = 0
    cached_detector = "Menunggu..."

    window_name = "EduSense - Real-Time Vision AI Camera"
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)

    while True:
        ret, frame = cap.read()
        if not ret:
            print("[ERROR] Gagal membaca frame dari webcam!")
            break

        frame_counter += 1
        current_time = time.time()
        fps = 1.0 / max(current_time - prev_time, 1e-5)
        prev_time = current_time

        # Salinan citra
        raw_rgb = frame.copy()
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        sharpness = calculate_sharpness(gray)
        gray_3ch = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

        # ---------------------------------------------------------
        # INFERENSI AI (DENGAN FRAME-SKIPPING & IMGSZ=320 UNTUK CPU)
        # ---------------------------------------------------------
        if frame_counter % FRAME_SKIP == 0:
            current_boxes = []
            count_wajah = 0
            count_tidur = 0
            detector_used = "Tidak Ada"

            # 1. Inferensi YOLOv8s dengan imgsz=320 (Kecepatan 5x lipat pada CPU)
            if use_yolo and model_yolo is not None:
                results = model_yolo.predict(raw_rgb, conf=conf_threshold, imgsz=320, verbose=False)
                for r in results:
                    for box in r.boxes:
                        cls_id = int(box.cls[0])
                        conf = float(box.conf[0])
                        label_nama = model_yolo.names.get(cls_id, f"class_{cls_id}")
                        x1, y1, x2, y2 = [int(v) for v in box.xyxy[0].tolist()]

                        if label_nama == "head_down":
                            count_tidur += 1
                            color = (0, 0, 255) # Merah
                            label_display = f"Tertidur ({conf:.2f})"
                        else:
                            count_wajah += 1
                            color = (0, 255, 0) # Hijau
                            label_display = f"Memperhatikan ({conf:.2f})"

                        current_boxes.append((x1, y1, x2, y2, color, label_display))

                if count_wajah > 0 or count_tidur > 0:
                    detector_used = "YOLOv8s"

            # 2. Fallback adaptif Haar Cascade jika YOLO kosong (dipercepat dengan downscaling 0.5x)
            if (count_wajah == 0 and count_tidur == 0) and face_cascade is not None:
                gray_small = cv2.resize(gray, (0, 0), fx=0.5, fy=0.5)
                faces = face_cascade.detectMultiScale(gray_small, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30))
                if len(faces) > 0:
                    count_wajah = len(faces)
                    detector_used = "Haar (Close-up)"
                    for (x, y, w, h) in faces:
                        # Skalakan kembali koordinat ke resolusi penuh
                        x1, y1, x2, y2 = x * 2, y * 2, (x + w) * 2, (y + h) * 2
                        label_display = "Memperhatikan (Wajah)"
                        color = (0, 255, 0)
                        current_boxes.append((x1, y1, x2, y2, color, label_display))

            # Simpan hasil ke cache
            cached_boxes = current_boxes
            cached_count_wajah = count_wajah
            cached_count_tidur = count_tidur
            cached_detector = detector_used

        # ---------------------------------------------------------
        # RENDERING BOUNDING BOX
        # ---------------------------------------------------------
        bbox_frame = frame.copy()
        for (x1, y1, x2, y2, color, label_display) in cached_boxes:
            cv2.rectangle(bbox_frame, (x1, y1), (x2, y2), color, 2)
            cv2.rectangle(bbox_frame, (x1, max(0, y1 - 24)), (x1 + len(label_display) * 11, y1), color, -1)
            cv2.putText(bbox_frame, label_display, (x1 + 4, max(12, y1 - 6)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

        count_wajah = cached_count_wajah
        count_tidur = cached_count_tidur
        detector_used = cached_detector

        # ---------------------------------------------------------
        # MODE TAMPILAN
        # ---------------------------------------------------------
        if mode == 1:
            # Mode Normal (Raw Color + Bounding Box + HUD)
            display_img = bbox_frame
            draw_hud(display_img, "Normal (Raw + AI Box)", fps, sharpness, count_wajah, count_tidur, conf_threshold, detector_used)

        elif mode == 2:
            # Mode Grayscale (Hitam-Putih + Bounding Box + HUD)
            display_img = gray_3ch.copy()
            mask = cv2.absdiff(bbox_frame, raw_rgb)
            mask_gray = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY)
            display_img[mask_gray > 10] = bbox_frame[mask_gray > 10]
            draw_hud(display_img, "Grayscale (Hitam-Putih + AI Box)", fps, sharpness, count_wajah, count_tidur, conf_threshold, detector_used)

        elif mode == 3:
            # Mode Side-by-Side (Raw | Grayscale | Bounding Box)
            sub_w = 426
            sub_h = 240
            
            p1 = cv2.resize(raw_rgb, (sub_w, sub_h))
            cv2.putText(p1, "1. RAW COLOR", (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (56, 189, 248), 2)

            p2 = cv2.resize(gray_3ch, (sub_w, sub_h))
            cv2.putText(p2, "2. GRAYSCALE", (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (167, 139, 250), 2)

            p3 = cv2.resize(bbox_frame, (sub_w, sub_h))
            cv2.putText(p3, "3. DETEKSI AI", (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (74, 222, 128), 2)

            display_img = np.hstack([p1, p2, p3])
            draw_hud(display_img, "Side-by-Side (3 Panel Komparasi)", fps, sharpness, count_wajah, count_tidur, conf_threshold, detector_used)

        cv2.imshow(window_name, display_img)

        # Tombol aksi
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            print("\n[INFO] Menutup kamera...")
            break
        elif key == ord('1'):
            mode = 1
            print("[MODE] Berpindah ke Mode 1: Tampilan Normal")
        elif key == ord('2'):
            mode = 2
            print("[MODE] Berpindah ke Mode 2: Tampilan Grayscale")
        elif key == ord('3'):
            mode = 3
            print("[MODE] Berpindah ke Mode 3: Tampilan Side-by-Side")
        elif key == ord('+') or key == ord('='):
            conf_threshold = min(0.95, conf_threshold + 0.05)
            print(f"[CONF] Confidence threshold dinaikkan ke: {conf_threshold:.2f}")
        elif key == ord('-') or key == ord('_'):
            conf_threshold = max(0.05, conf_threshold - 0.05)
            print(f"[CONF] Confidence threshold diturunkan ke: {conf_threshold:.2f}")
        elif key == ord('s'):
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            save_path = os.path.join(SAVE_DIR, f"screenshot_{timestamp}_mode{mode}.jpg")
            cv2.imwrite(save_path, display_img)
            print(f"[SCREENSHOT] Berhasil disimpan di: {save_path}")

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
