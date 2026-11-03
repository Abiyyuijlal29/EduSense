import cv2
import os

# Base directory skrip ini berada
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 1. Folder tempat ratusan foto Anda berada
folder_gambar = os.path.join(BASE_DIR, 'dataset_cctv_tersaring')

if not os.path.exists(folder_gambar):
    raise FileNotFoundError(f"Folder gambar tidak ditemukan: {folder_gambar}")

# Menggunakan model pendeteksi wajah bawaan OpenCV / file lokal
cascade_local = os.path.join(BASE_DIR, 'haarcascade_frontalface_default.xml')
cascade_cv2 = os.path.join(getattr(cv2.data, 'haarcascades', ''), 'haarcascade_frontalface_default.xml')

if os.path.exists(cascade_local):
    cascade_path = cascade_local
elif os.path.exists(cascade_cv2):
    cascade_path = cascade_cv2
else:
    raise FileNotFoundError(
        "File haarcascade_frontalface_default.xml tidak ditemukan!\n"
        f"Pastikan file tersebut berada di folder: {BASE_DIR}"
    )

face_cascade = cv2.CascadeClassifier(cascade_path)
if face_cascade.empty():
    raise RuntimeError(f"Gagal memuat CascadeClassifier dari: {cascade_path}")

print("Memulai Auto-Labeling untuk kelas 'wajah'...")

# Ambil semua file gambar
gambar_list = [f for f in os.listdir(folder_gambar) if f.endswith(('.jpg', '.png', '.jpeg'))]

count_labeled = 0

for nama_file in gambar_list:
    jalur_gambar = os.path.join(folder_gambar, nama_file)
    jalur_txt = os.path.join(folder_gambar, os.path.splitext(nama_file)[0] + '.txt')
    
    # Baca gambar
    img = cv2.imread(jalur_gambar)
    if img is None:
        continue
        
    tinggi_img, lebar_img, _ = img.shape
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Deteksi wajah di gambar tersebut
    wajah_terdeteksi = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))
    
    # Jika tidak ada wajah, buat file txt kosong (aturan YOLO untuk gambar background)
    if len(wajah_terdeteksi) == 0:
        open(jalur_txt, 'w').close()
        continue
        
    # Tulis koordinat wajah ke dalam format YOLO .txt
    with open(jalur_txt, 'w') as f:
        for (x, y, w, h) in wajah_terdeteksi:
            # Konversi koordinat piksel OpenCV ke format desimal YOLO (0.0 - 1.0)
            x_center = (x + w / 2) / lebar_img
            y_center = (y + h / 2) / tinggi_img
            width = w / lebar_img
            height = h / tinggi_img
            
            # Format penulisan YOLO: <class_id> <x_center> <y_center> <width> <height>
            # Kelas 0 adalah untuk 'wajah'
            f.write(f"0 {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}\n")
            
    count_labeled += 1

print(f"Selesai! {count_labeled} gambar telah dilabeli secara otomatis.")
print("Sekarang buka folder tersebut menggunakan aplikasi LabelImg untuk mengecek/menambah label siswa tidur.")
