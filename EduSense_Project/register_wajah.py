import cv2
from deepface import DeepFace  # type: ignore[import-untyped]
import os
import numpy as np

# =============================================
# KONFIGURASI
# =============================================
DATASET_DIR = os.path.join(os.path.dirname(__file__), "dataset_absensi")

MAHASISWA = {
    "1": {"nama": "Abiyyu Ijlal Rasib Novamatin", "nim": "E41241919", "folder": "E41241919_Abiyyu_Ijlal_Rasib_Novamatin"},
    "2": {"nama": "Adelia Hanifa Saharani",        "nim": "E41241859", "folder": "E41241859_Adelia_Hanifa_Saharani"},
    "3": {"nama": "Muhammad Rahamadhani",           "nim": "E41242025", "folder": "E41242025_Muhammad_Rahamadhani"},
    "4": {"nama": "Muhammad Akbar Ellia Menang",    "nim": "E41242065", "folder": "E41242065_Muhammad_Akbar_Ellia_Menang"},
}

JUMLAH_FOTO = 30  # Jumlah foto yang diambil per mahasiswa


def pilih_mahasiswa():
    """Menampilkan menu pilihan mahasiswa."""
    print("\n" + "="*50)
    print("  SISTEM REGISTRASI WAJAH - EduSense")
    print("="*50)
    print("Pilih mahasiswa yang akan didaftarkan:\n")
    for key, data in MAHASISWA.items():
        print(f"  [{key}] {data['nim']} - {data['nama']}")
    print("\n  [0] Keluar")
    print("="*50)

    pilihan = input("Masukkan pilihan: ").strip()
    return pilihan


def register_wajah(mahasiswa_info):
    """Mengambil foto wajah dan menyimpannya ke folder dataset."""
    nama   = mahasiswa_info["nama"]
    nim    = mahasiswa_info["nim"]
    folder = os.path.join(DATASET_DIR, mahasiswa_info["folder"])

    os.makedirs(folder, exist_ok=True)

    # Cek foto yang sudah ada
    existing = [f for f in os.listdir(folder) if f.endswith(".jpg")]
    start_idx = len(existing)

    print(f"\n[INFO] Memulai registrasi untuk: {nama} ({nim})")
    print(f"[INFO] Foto sudah ada: {start_idx} | Target: {JUMLAH_FOTO}")
    print("[INFO] Tekan 'q' untuk berhenti, 's' untuk skip frame\n")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[ERROR] Kamera tidak dapat dibuka!")
        return

    # Cari file haarcascade: coba path lokal dulu, lalu cv2.data
    cascade_local = os.path.join(os.path.dirname(__file__), "haarcascade_frontalface_default.xml")
    cascade_cv2   = os.path.join(cv2.data.haarcascades, "haarcascade_frontalface_default.xml")

    if os.path.exists(cascade_local):
        cascade_path = cascade_local
    elif os.path.exists(cascade_cv2):
        cascade_path = cascade_cv2
    else:
        print("[ERROR] File haarcascade_frontalface_default.xml tidak ditemukan!")
        print("        Letakkan file tersebut di folder yang sama dengan register_wajah.py")
        cap.release()
        return

    face_cascade = cv2.CascadeClassifier(cascade_path)
    if face_cascade.empty():
        print(f"[ERROR] Gagal memuat cascade classifier dari: {cascade_path}")
        cap.release()
        return

    print(f"[INFO] Cascade classifier dimuat dari: {cascade_path}")

    foto_diambil = start_idx
    frame_count  = 0
    INTERVAL     = 3  # Ambil foto setiap N frame

    while foto_diambil < JUMLAH_FOTO:
        ret, frame = cap.read()
        if not ret:
            print("[ERROR] Gagal membaca frame kamera!")
            break

        frame_count += 1
        display = frame.copy()
        gray    = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces   = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(80, 80))

        # Gambar kotak di sekitar wajah
        for (x, y, w, h) in faces:
            cv2.rectangle(display, (x, y), (x+w, y+h), (0, 255, 0), 2)

        # Info overlay
        progress = foto_diambil - start_idx
        sisa     = JUMLAH_FOTO - foto_diambil
        cv2.putText(display, f"{nama}", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        cv2.putText(display, f"Foto: {progress}/{JUMLAH_FOTO - start_idx} | Sisa: {sisa}", (10, 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        cv2.putText(display, "q=Keluar | s=Skip", (10, display.shape[0] - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

        # Simpan foto secara otomatis jika wajah terdeteksi dan interval terpenuhi
        if len(faces) > 0 and frame_count % INTERVAL == 0:
            filename = os.path.join(folder, f"{nim}_{foto_diambil + 1:03d}.jpg")
            cv2.imwrite(filename, frame)
            foto_diambil += 1
            print(f"  [+] Foto tersimpan: {os.path.basename(filename)} ({foto_diambil}/{JUMLAH_FOTO})")

        cv2.imshow(f"Registrasi Wajah - {nama}", display)

        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            print("\n[INFO] Registrasi dihentikan oleh pengguna.")
            break
        elif key == ord('s'):
            frame_count = 0  # Reset interval

    cap.release()
    cv2.destroyAllWindows()

    total_baru = foto_diambil - start_idx
    print(f"\n[SELESAI] {total_baru} foto baru disimpan untuk {nama} ({nim})")
    print(f"[SELESAI] Total foto di folder: {foto_diambil}")


def main():
    print("\n[INIT] Memeriksa struktur folder dataset...")
    for data in MAHASISWA.values():
        folder = os.path.join(DATASET_DIR, data["folder"])
        os.makedirs(folder, exist_ok=True)
    print("[INIT] Semua folder siap.\n")

    while True:
        pilihan = pilih_mahasiswa()

        if pilihan == "0":
            print("\n[INFO] Program selesai. Sampai jumpa!\n")
            break
        elif pilihan in MAHASISWA:
            register_wajah(MAHASISWA[pilihan])
        else:
            print("[WARNING] Pilihan tidak valid. Coba lagi.")


if __name__ == "__main__":
    main()
