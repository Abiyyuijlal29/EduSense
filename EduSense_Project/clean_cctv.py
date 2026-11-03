import os
import shutil

# Folder sumber (yang berisi banyak sub-folder)
source_dir = 'dataset_cctv_mentah/'
# Folder tujuan (hasil akhir akan ditaruh di sini tanpa sub-folder)
output_dir = 'dataset_cctv_tersaring/'

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# 1. Mengumpulkan SEMUA jalur foto dari dalam semua sub-folder
semua_foto = []
for root, dirs, files in os.walk(source_dir):
    for file in files:
        if file.lower().endswith(('.jpg', '.jpeg', '.png')):
            # Simpan jalur lengkap ke file tersebut
            semua_foto.append(os.path.join(root, file))

# Urutkan agar pengambilan sampel berurutan secara waktu
semua_foto.sort()

print(f"Ditemukan total {len(semua_foto)} foto dari seluruh sub-folder.")

# 2. Proses penyaringan (Ambil 1 setiap 10 foto)
interval = 10
count = 0

print("Memulai proses penyaringan dan penyatuan...")

for i in range(0, len(semua_foto), interval):
    jalur_asal = semua_foto[i]
    
    # Ekstrak format file asli (misal: .jpg)
    ekstensi = os.path.splitext(jalur_asal)[1]
    
    # BUAT NAMA BARU YANG RAPI (cctv_0001.jpg, cctv_0002.jpg, dst)
    # Ini mencegah file saling menimpa jika nama aslinya sama
    nama_baru = f"cctv_{count+1:04d}{ekstensi}"
    jalur_tujuan = os.path.join(output_dir, nama_baru)
    
    # Salin file ke folder tujuan
    shutil.copy(jalur_asal, jalur_tujuan)
    count += 1

print(f"Selesai! Dari {len(semua_foto)} foto mentah, kini tersisa {count} foto pilihan.")
print(f"Semua foto sudah disatukan dan diganti namanya dengan rapi di folder '{output_dir}'.")