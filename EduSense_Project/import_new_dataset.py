"""
Import New Student Dataset Script (EduSense)
=============================================
Skrip untuk mengintegrasikan dataset mahasiswa tidur baru dari folder unduhan
ke dalam sistem deteksi objek YOLO EduSense.

Ketentuan:
1. Data dengan label 'uncertain' (13 file) otomatis DILEWATI/DIHAPUS untuk menjaga kualitas data.
2. Data yang diproses:
   - 'sleeping' (55 file) -> Target kelas 1 (head_down)
   - 'not_sleeping' (54 file) -> Target kelas 0 (wajah)
3. Penomoran berurutan melanjutkan file terakhir di 'dataset_cctv_tersaring' (cctv_0717.jpg dst).
4. Menghasilkan file log 'mapping_dataset_baru.csv' untuk pelacakan asal-usul data.
"""

import os
import shutil
import pandas as pd
import cv2
from typing import Dict, Any, List

# Direktori proyek EduSense
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TARGET_FOLDER = os.path.join(BASE_DIR, "dataset_cctv_tersaring")
CASCADE_PATH = os.path.join(BASE_DIR, "haarcascade_frontalface_default.xml")

# Path dataset baru di folder Downloads
SOURCE_DATASET_DIR = r"c:\Users\abiyy\Downloads\DATASET_MAHASISWA_TIDUR_BARU\dataset_mahasiswa_tidur"
ANNOTATIONS_CSV = os.path.join(SOURCE_DATASET_DIR, "annotations.csv")


def get_next_cctv_index(folder: str) -> int:
    """Mencari nomor indeks cctv_XXXX tertinggi yang sudah ada."""
    existing_files = [f for f in os.listdir(folder) if f.startswith("cctv_") and f.endswith(".jpg")]
    if not existing_files:
        return 1
    
    indices = []
    for f in existing_files:
        try:
            num = int(f.replace("cctv_", "").replace(".jpg", ""))
            indices.append(num)
        except ValueError:
            pass
            
    return max(indices) + 1 if indices else 1


def import_dataset() -> None:
    print("=" * 70)
    print("  INTEGRASI DATASET MAHASISWA TIDUR BARU - EDUSENSE")
    print("=" * 70)

    if not os.path.exists(ANNOTATIONS_CSV):
        print(f"[ERROR] File anotasi tidak ditemukan: {ANNOTATIONS_CSV}")
        return

    os.makedirs(TARGET_FOLDER, exist_ok=True)
    df = pd.read_csv(ANNOTATIONS_CSV)

    # 1. FILTER DATA UNCERTAIN
    total_awal = len(df)
    df_clean = df[df["label"].isin(["sleeping", "not_sleeping"])].copy()
    total_uncertain = total_awal - len(df_clean)

    print(f"\n[1] Ringkasan Data:")
    print(f"  - Total Data Awal      : {total_awal} frame")
    print(f"  - Data 'uncertain'     : {total_uncertain} frame (DIHAPUS/DILEWATI)")
    print(f"  - Data Valid Bersih    : {len(df_clean)} frame")
    print(f"      * sleeping (Tidur) : {len(df_clean[df_clean['label'] == 'sleeping'])} frame")
    print(f"      * not_sleeping     : {len(df_clean[df_clean['label'] == 'not_sleeping'])} frame")

    # Muat Haar Cascade untuk pra-label wajah pada not_sleeping
    face_cascade = None
    if os.path.exists(CASCADE_PATH):
        face_cascade = cv2.CascadeClassifier(CASCADE_PATH)

    next_idx = get_next_cctv_index(TARGET_FOLDER)
    print(f"\n[2] Memulai Salin & Pembuatan Label (Mulai dari cctv_{next_idx:04d})...\n")

    mapping_records: List[Dict[str, Any]] = []
    total_berhasil = 0

    for _, row in df_clean.iterrows():
        src_rel_path = row["full_frame_path"]
        src_full_path = os.path.join(SOURCE_DATASET_DIR, src_rel_path)

        if not os.path.exists(src_full_path):
            print(f"  [WARN] File tidak ditemukan: {src_full_path}")
            continue

        cctv_name = f"cctv_{next_idx:04d}"
        dest_img_path = os.path.join(TARGET_FOLDER, f"{cctv_name}.jpg")
        dest_txt_path = os.path.join(TARGET_FOLDER, f"{cctv_name}.txt")

        # Salin citra ke folder target
        shutil.copy(src_full_path, dest_img_path)

        # Baca citra untuk konversi koordinat YOLO
        img = cv2.imread(src_full_path)
        img_h, img_w, _ = img.shape
        label_kategori = row["label"]

        # Buat anotasi YOLO (.txt)
        with open(dest_txt_path, "w", encoding="utf-8") as f_txt:
            if label_kategori == "not_sleeping":
                # Kelas 0: Wajah (Memperhatikan)
                # Coba deteksi wajah via Haar Cascade terlebih dahulu
                wajah_terdeteksi = []
                if face_cascade is not None:
                    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
                    wajah_terdeteksi = face_cascade.detectMultiScale(gray, 1.1, 4, minSize=(30, 30))

                if len(wajah_terdeteksi) > 0:
                    for (x, y, w, h) in wajah_terdeteksi:
                        xc = (x + w / 2) / img_w
                        yc = (y + h / 2) / img_h
                        nw = w / img_w
                        nh = h / img_h
                        f_txt.write(f"0 {xc:.6f} {yc:.6f} {nw:.6f} {nh:.6f}\n")
                else:
                    # Perkiraan area kepala bagian atas crop sebagai acuan awal
                    cx1, cy1, cx2, cy2 = row["crop_x1"], row["crop_y1"], row["crop_x2"], row["crop_y2"]
                    # Kepala berada di 40% atas crop
                    head_h = (cy2 - cy1) * 0.45
                    head_w = (cx2 - cx1) * 0.70
                    head_x = cx1 + ((cx2 - cx1) - head_w) / 2
                    head_y = cy1
                    xc = (head_x + head_w / 2) / img_w
                    yc = (head_y + head_h / 2) / img_h
                    nw = head_w / img_w
                    nh = head_h / img_h
                    f_txt.write(f"0 {xc:.6f} {yc:.6f} {nw:.6f} {nh:.6f}\n")

            elif label_kategori == "sleeping":
                # Kelas 1: Head Down (Tertidur)
                # Gunakan koordinat area kepala tertunduk di meja
                cx1, cy1, cx2, cy2 = row["crop_x1"], row["crop_y1"], row["crop_x2"], row["crop_y2"]
                # Kepala tertunduk berada di tengah-atas meja
                sleep_h = (cy2 - cy1) * 0.60
                sleep_w = (cx2 - cx1) * 0.85
                sleep_x = cx1 + ((cx2 - cx1) - sleep_w) / 2
                sleep_y = cy1 + ((cy2 - cy1) - sleep_h) * 0.35
                xc = (sleep_x + sleep_w / 2) / img_w
                yc = (sleep_y + sleep_h / 2) / img_h
                nw = sleep_w / img_w
                nh = sleep_h / img_h
                f_txt.write(f"1 {xc:.6f} {yc:.6f} {nw:.6f} {nh:.6f}\n")

        mapping_records.append({
            "cctv_file": f"{cctv_name}.jpg",
            "txt_file": f"{cctv_name}.txt",
            "person_id": row["person_id"],
            "label_asli": label_kategori,
            "kelas_yolo": 1 if label_kategori == "sleeping" else 0,
            "nama_kelas": "head_down" if label_kategori == "sleeping" else "wajah",
            "source_video": row["source_video"],
            "timestamp_sec": row["timestamp_sec"]
        })

        next_idx += 1
        total_berhasil += 1

    # Simpan mapping log
    mapping_csv_path = os.path.join(BASE_DIR, "mapping_dataset_baru.csv")
    pd.DataFrame(mapping_records).to_csv(mapping_csv_path, index=False)

    print("=" * 70)
    print("PROSES IMPOR DATASET BERHASIL!")
    print(f"Total frame baru yang disalin : {total_berhasil} file")
    print(f"Data tersimpan di             : {TARGET_FOLDER}")
    print(f"Log pemetaan disimpan di      : {mapping_csv_path}")
    print("=" * 70)
    print("\nLangkah selanjutnya:")
    print("1. Anda dapat membuka LabelImg untuk meninjau/menyempurnakan posisi kotak jika diperlukan:")
    print(f'   labelImg "{TARGET_FOLDER}" "{os.path.join(TARGET_FOLDER, "classes.txt")}"')
    print("2. Jalankan 'python split_data.py' untuk memperbarui pembagian dataset YOLO (Train/Val/Test).")


if __name__ == "__main__":
    import_dataset()
