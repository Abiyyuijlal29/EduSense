import os
import shutil
import random

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 1. Folder asal (tempat Anda melabeli) dan folder tujuan (format YOLO)
source_dir = os.path.join(BASE_DIR, 'dataset_cctv_tersaring')
base_out_dir = os.path.join(BASE_DIR, 'dataset_yolo_tidur')

# 2. Buat hierarki folder standar YOLO secara otomatis
for split in ['train', 'val', 'test']:
    os.makedirs(os.path.join(base_out_dir, 'images', split), exist_ok=True)
    os.makedirs(os.path.join(base_out_dir, 'labels', split), exist_ok=True)

# 3. Kumpulkan semua gambar dan acak urutannya (Shuffle)
# Pengacakan sangat penting agar model tidak belajar secara urut/menghafal
all_images = [f for f in os.listdir(source_dir) if f.endswith(('.jpg', '.jpeg', '.png'))]
random.seed(42) # Seed tetap agar hasil acakan konsisten jika diulang
random.shuffle(all_images)

# 4. Hitung persentase pembagian (70% Train, 20% Val, 10% Test)
total = len(all_images)
train_end = int(total * 0.70)
val_end = int(total * 0.90)

train_imgs = all_images[:train_end]
val_imgs = all_images[train_end:val_end]
test_imgs = all_images[val_end:]

def copy_files(img_list, split_name):
    count = 0
    for img in img_list:
        txt_file = os.path.splitext(img)[0] + '.txt'
        img_path = os.path.join(source_dir, img)
        txt_path = os.path.join(source_dir, txt_file)
        
        # Hanya pindahkan jika file gambar MEMILIKI pasangan file .txt
        if os.path.exists(txt_path):
            shutil.copy(img_path, os.path.join(base_out_dir, 'images', split_name, img))
            shutil.copy(txt_path, os.path.join(base_out_dir, 'labels', split_name, txt_file))
            count += 1
    return count

print("Memulai pemecahan dataset YOLO...")
train_count = copy_files(train_imgs, 'train')
val_count = copy_files(val_imgs, 'val')
test_count = copy_files(test_imgs, 'test')

print("=========================================")
print("DATA SPLITTING BERHASIL!")
print(f"Data Latih (Train) : {train_count} pasang")
print(f"Data Validasi (Val): {val_count} pasang")
print(f"Data Uji (Test)    : {test_count} pasang")
print("=========================================")
print(f"Semua data telah disalin rapi ke dalam folder '{base_out_dir}'")
