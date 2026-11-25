import cv2
import time
from face_recognizer_manual import face_recognizer

def main():
    print("=" * 60)
    print("  LIVE DEMO PRESENSI WAJAH REAL-TIME")
    print("  Metode: YOLOv8 Face Crop + MobileFaceNet ONNX + NumPy Math")
    print("=" * 60)
    print("Tekan 'q' pada jendela video untuk keluar.\n")

    # Pastikan database centroid termuat
    face_recognizer.bangun_database_mahasiswa()

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[ERROR] Kamera hardware tidak dapat dibuka!")
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    prev_time = time.time()
    last_recognition = {"nama": "Mencari Wajah...", "nim": "", "cosine_sim": 0.0, "dikenal": False}
    frame_count = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_count += 1
        h, w = frame.shape[:2]

        # Lakukan inferensi pengenalan setiap 3 frame agar FPS tetap tinggi
        if frame_count % 3 == 0:
            last_recognition = face_recognizer.kenali_wajah(frame, threshold_cosine=0.40, auto_crop=True)

        # Hitung FPS
        curr_time = time.time()
        fps = 1.0 / (curr_time - prev_time) if (curr_time - prev_time) > 0 else 30.0
        prev_time = curr_time

        # Gambar HUD Tampilan
        is_match = last_recognition.get("dikenal", False)
        box_color = (0, 200, 0) if is_match else (0, 140, 255)

        # Panel Banner Atas
        cv2.rectangle(frame, (0, 0), (w, 55), (20, 20, 20), -1)
        cv2.putText(frame, "EduSense Smart Attendance (MobileFaceNet + NumPy)", (15, 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)
        cv2.putText(frame, f"FPS: {fps:.1f}", (w - 100, 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)

        # Banner Bawah Status Mahasiswa
        cv2.rectangle(frame, (0, h - 65), (w, h), (25, 25, 25), -1)
        if is_match:
            cv2.putText(frame, f"[HADIR] {last_recognition['nama']} ({last_recognition['nim']})",
                        (15, h - 35), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 255, 0), 2)
            cv2.putText(frame, f"Cosine Sim: {last_recognition['cosine_sim']:.4f} (Cocok)",
                        (15, h - 12), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (180, 255, 180), 1)
        else:
            cv2.putText(frame, f"Status: {last_recognition['nama']}",
                        (15, h - 35), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 165, 255), 1)
            cv2.putText(frame, f"Skor Terbaik: {last_recognition['cosine_sim']:.4f} (Ambang Batas: >= 0.40)",
                        (15, h - 12), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (180, 180, 180), 1)

        cv2.imshow("EduSense - Presensi Wajah Real-Time", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
