import os
import cv2
import shutil

def variance_of_laplacian(image):
    # Menghitung tingkat fokus/ketajaman gambar. Semakin tinggi nilainya, semakin tajam.
    return cv2.Laplacian(image, cv2.CV_64F).var()

def clean_face_dataset(source_dir, output_dir, max_photos=15, blur_threshold=100.0):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Membaca setiap folder siswa (misal: Ahmad, Budi)
    for student_name in os.listdir(source_dir):
        student_source = os.path.join(source_dir, student_name)
        student_output = os.path.join(output_dir, student_name)
        
        if not os.path.isdir(student_source):
            continue
            
        os.makedirs(student_output, exist_ok=True)
        
        # Ambil semua foto anak tersebut
        all_photos = sorted([f for f in os.listdir(student_source) if f.endswith(('.jpg', '.png'))])
        
        sharp_photos = []
        
        # TAHAP 1: FILTER BLUR
        print(f"Menyaring folder: {student_name} (Total awal: {len(all_photos)} foto)")
        for photo in all_photos:
            img_path = os.path.join(student_source, photo)
            image = cv2.imread(img_path)
            
            if image is None:
                continue
                
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            fm = variance_of_laplacian(gray)
            
            # Jika ketajaman di atas batas (tidak blur), simpan ke daftar sementara
            if fm > blur_threshold:
                sharp_photos.append(photo)

        # TAHAP 2: PENGAMBILAN SAMPEL (Maksimal 15 Foto)
        total_sharp = len(sharp_photos)
        
        if total_sharp > max_photos:
            # Mengambil foto dengan interval yang rata (misal dari 200 foto tajam, ambil setiap foto ke-13)
            interval = total_sharp // max_photos
            selected_photos = sharp_photos[0::interval][:max_photos]
        else:
            selected_photos = sharp_photos

        # TAHAP 3: PINDAHKAN FOTO TERPILIH KE FOLDER BARU
        for i, photo in enumerate(selected_photos):
            src_path = os.path.join(student_source, photo)
            # Ganti nama file agar rapi (misal: Ahmad_01.jpg)
            ext = os.path.splitext(photo)[1]
            new_name = f"{student_name}_{i+1:02d}{ext}"
            dst_path = os.path.join(student_output, new_name)
            
            shutil.copy(src_path, dst_path)
            
        print(f"  -> Selesai! Tersisa {len(selected_photos)} foto terbaik untuk {student_name}.\n")

# Eksekusi Skrip
if __name__ == "__main__":
    # Folder asal (yang berisi 400+ foto per anak)
    FOLDER_ASAL = "dataset_wajah_mentah"
    
    # Folder tujuan (dataset bersih yang akan dipakai oleh FaceNet)
    FOLDER_BERSIH = "dataset_absensi"
    
    # blur_threshold bisa dinaikkan (misal 150) jika hasilnya masih banyak yang blur
    clean_face_dataset(FOLDER_ASAL, FOLDER_BERSIH, max_photos=15, blur_threshold=100.0)