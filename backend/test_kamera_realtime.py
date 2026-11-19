# -*- coding: utf-8 -*-
"""
Aplikasi Uji Coba Kamera Laptop Real-Time (EduSense Vision AI - Pure YOLOv8)
===========================================================================
Fitur Utama:
1. Live Camera Feed (Webcam laptop indeks 0).
2. Inferensi Deteksi Perilaku Murni YOLOv8 (best.pt / yolov8n.pt).
3. Live Pengolahan Citra:
   - Mode 1: Tampilan Normal (Raw Color + Bounding Box).
   - Mode 2: Tampilan Grayscale (Hitam-Putih + Bounding Box).
   - Mode 3: Tampilan Side-by-Side (Raw | Grayscale | Bounding Box) secara simultan.
4. Live Metrics HUD:
   - Real-time FPS (Frame per Detik).
   - Real-time Laplacian Sharpness Score (Skor Ketajaman Citra).
   - Status Siswa: Memperhatikan vs Tertidur (Head Down).
5. Tombol Kontrol:
   - '1', '2', '3': Ganti mode visualisasi.
   - '+', '-': Naikkan / turunkan ambang batas kepercayaan (confidence).
   - 's': Ambil screenshot ke folder 'hasil_percobaan_kamera'.
   - 'q': Keluar dari kamera.
"""

import os
import sys
import time
from datetime import datetime
import cv2
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))

MODEL_CUSTOM = os.path.join(BASE_DIR, "models", "best.pt")
SAVE_DIR = os.path.join(PROJECT_ROOT, "dataset", "raw", "hasil_percobaan_kamera")
if not os.path.exists(os.path.dirname(SAVE_DIR)):
    SAVE_DIR = os.path.join(BASE_DIR, "hasil_percobaan_kamera")
os.makedirs(SAVE_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. INISIALISASI MODEL AI (MURNI YOLOV8)
# -------------------------------------------------------------
model_yolo = None
nama_model_aktif = "Tidak Aktif"

try:
    from ultralytics import YOLO
    if os.path.exists(MODEL_CUSTOM):
        print(f"[INIT] Memuat model YOLOv8 custom dari: {MODEL_CUSTOM}")
        model_yolo = YOLO(MODEL_CUSTOM)
        nama_model_aktif = "YOLOv8s (Custom EduSense)"
    else:
        print(f"[WARN] File '{MODEL_CUSTOM}' belum ditemukan.")
        print("[INIT] Memuat model 'yolov8n.pt' untuk pengujian kamera...")
        model_yolo = YOLO("yolov8n.pt")
        nama_model_aktif = "YOLOv8n (Pre-trained Fallback)"
except Exception as e:
    print(f"[ERROR] Gagal memuat library Ultralytics YOLO: {e}")
    sys.exit(1)


def calculate_sharpness(gray_img: np.ndarray) -> float:
    """Menghitung nilai ketajaman fokus citra menggunakan operator Laplacian."""
    small_gray = cv2.resize(gray_img, (160, 90))
    return float(cv2.Laplacian(small_gray, cv2.CV_64F).var())


def draw_hud(
    img: np.ndarray,
    mode_name: str,
    fps: float,
    sharpness: float,
    count_wajah: int,
    count_tidur: int,
    conf_thresh: float = 0.40,
    detector_info: str = "YOLOv8"
) -> None:
    """Menggambar panel metrik HUD informatif pada frame kamera."""
    h, w, _ = img.shape

    # Header Overlay
    header_overlay = img.copy()
    cv2.rectangle(header_overlay, (0, 0), (w, 55), (20, 24, 33), -1)
    cv2.addWeighted(header_overlay, 0.75, img, 0.25, 0, img)

    # Info Teks Header
    cv2.putText(img, f"EDUSENSE VISION AI - MODE: {mode_name.upper()}", (15, 24),
                cv2.FONT_HERSHEY_SIMPLEX, 0.65, (56, 189, 248), 2)
    cv2.putText(img, f"FPS: {fps:.1f} | Fokus: {sharpness:.1f} | Model: {detector_info} | Conf: {conf_thresh:.2f}", (15, 46),
                cv2.FONT_HERSHEY_SIMPLEX, 0.48, (148, 163, 184), 1)

    # Status Siswa
    status_text = f"Memperhatikan: {count_wajah}  |  Tertidur: {count_tidur}"
    cv2.putText(img, status_text, (max(15, w - 340), 35),
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
    print(f"Model AI Aktif : {nama_model_aktif}")
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

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    mode = 1
    prev_time = time.time()
    fps = 30.0
    conf_threshold = 0.40  # Ambang batas optimal (bersih dari background noise)
    frame_counter = 0
    FRAME_SKIP = 2  # Inferensi setiap 2 frame agar tetap lancar di CPU

    cached_boxes = []
    cached_count_wajah = 0
    cached_count_tidur = 0

    window_name = "EduSense - Real-Time Vision AI Camera (YOLOv8)"
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

        raw_rgb = frame.copy()
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        sharpness = calculate_sharpness(gray)
        gray_3ch = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

        # ---------------------------------------------------------
        # INFERENSI MURNI YOLOV8
        # ---------------------------------------------------------
        if frame_counter % FRAME_SKIP == 0 and model_yolo is not None:
            current_boxes = []
            count_wajah = 0
            count_tidur = 0

            results = model_yolo.predict(raw_rgb, conf=conf_threshold, imgsz=320, verbose=False)
            for r in results:
                for box in r.boxes:
                    cls_id = int(box.cls[0])
                    conf = float(box.conf[0])
                    label_nama = model_yolo.names.get(cls_id, f"class_{cls_id}")
                    x1, y1, x2, y2 = [int(v) for v in box.xyxy[0].tolist()]

                    if label_nama == "head_down":
                        count_tidur += 1
                        color = (0, 0, 255)  # Merah: Tertidur
                        label_display = f"Tertidur ({conf:.2f})"
                    else:
                        count_wajah += 1
                        color = (0, 255, 0)  # Hijau: Memperhatikan
                        label_display = f"Memperhatikan ({conf:.2f})"

                    current_boxes.append((x1, y1, x2, y2, color, label_display))

            cached_boxes = current_boxes
            cached_count_wajah = count_wajah
            cached_count_tidur = count_tidur

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

        # ---------------------------------------------------------
        # MODE TAMPILAN
        # ---------------------------------------------------------
        if mode == 1:
            display_img = bbox_frame
            draw_hud(display_img, "Normal (Raw + YOLOv8)", fps, sharpness, count_wajah, count_tidur, conf_threshold, nama_model_aktif)

        elif mode == 2:
            display_img = gray_3ch.copy()
            mask = cv2.absdiff(bbox_frame, raw_rgb)
            mask_gray = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY)
            display_img[mask_gray > 10] = bbox_frame[mask_gray > 10]
            draw_hud(display_img, "Grayscale (Hitam-Putih + YOLOv8)", fps, sharpness, count_wajah, count_tidur, conf_threshold, nama_model_aktif)

        elif mode == 3:
            h_s, w_s = 240, 320
            p1 = cv2.resize(raw_rgb, (w_s, h_s))
            cv2.putText(p1, "[1] Raw RGB Feed", (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)

            p2 = cv2.resize(gray_3ch, (w_s, h_s))
            cv2.putText(p2, f"[2] Grayscale (Fokus: {sharpness:.1f})", (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)

            p3 = cv2.resize(bbox_frame, (w_s, h_s))
            cv2.putText(p3, f"[3] YOLOv8 (Tidur: {count_tidur})", (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)

            panel_top = np.hstack([p1, p2])
            panel_bot = np.hstack([p3, p1.copy()])
            display_img = np.vstack([panel_top, panel_bot])
            draw_hud(display_img, "Side-by-Side Panel", fps, sharpness, count_wajah, count_tidur, conf_threshold, nama_model_aktif)

        cv2.imshow(window_name, display_img)

        # ---------------------------------------------------------
        # KONTROL KEYBOARD
        # ---------------------------------------------------------
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            print("\n[INFO] Menutup kamera...")
            break
        elif key == ord('1'):
            mode = 1
        elif key == ord('2'):
            mode = 2
        elif key == ord('3'):
            mode = 3
        elif key in (ord('+'), ord('=')):
            conf_threshold = min(0.95, conf_threshold + 0.05)
            print(f"[KONTROL] Ambang Batas Conf dinaikkan: {conf_threshold:.2f}")
        elif key in (ord('-'), ord('_')):
            conf_threshold = max(0.10, conf_threshold - 0.05)
            print(f"[KONTROL] Ambang Batas Conf diturunkan: {conf_threshold:.2f}")
        elif key == ord('s'):
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = os.path.join(SAVE_DIR, f"screenshot_{timestamp}.jpg")
            cv2.imwrite(filename, display_img)
            print(f"[SCREENSHOT] Disimpan: {filename}")

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
