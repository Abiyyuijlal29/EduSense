"""
Skrip Pembagian Dataset YOLO EduSense (Bebas Data Leakage)
=========================================================
Skrip ini membagi data cctv_tersaring ke format dataset YOLO (train/val/test).
Menggunakan strategi 'Block Temporal & Sequence Splitting' per sesi/skenario
dan per subjek (bukan random shuffle antarfram berturutan).

Keuntungan:
1. Menghilangkan data leakage karena frame berdekatan dari video yang sama
   tidak tercampur antara Train dan Val/Test.
2. Mempertahankan proporsi kelas yang sangat seimbang (~70% Train, 15% Val, 15% Test).
3. Evaluasi metrik mAP pada data Val/Test mencerminkan akurasi sesungguhnya.
"""

import os
import shutil
import pandas as pd
from collections import Counter
from typing import Dict, List, Tuple

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_DIR = os.path.join(BASE_DIR, "dataset_cctv_tersaring")
BASE_OUT_DIR = os.path.join(BASE_DIR, "dataset_yolo_tidur")
MAPPING_CSV = os.path.join(BASE_DIR, "mapping_dataset_baru.csv")

# 8 Skenario Utama CCTV
SCENARIOS: List[Tuple[str, int, int]] = [
    ("Abi memperhatikan", 1, 105),
    ("Abi tertidur", 106, 207),
    ("Adel memperhatikan", 208, 263),
    ("Adel tertidur", 264, 374),
    ("Akbar memperhatikan", 375, 450),
    ("Akbar tertidur", 451, 551),
    ("Dheni memperhatikan", 552, 615),
    ("Dheni tertidur", 616, 716),
]


def split_dataset():
    print("=" * 70)
    print("  MEMULAI PEMBAGIAN DATASET YOLO (BEBAS DATA LEAKAGE)")
    print("=" * 70)

    # 1. Bersihkan dan siapkan struktur folder target
    for split in ["train", "val", "test"]:
        img_dir = os.path.join(BASE_OUT_DIR, "images", split)
        lbl_dir = os.path.join(BASE_OUT_DIR, "labels", split)

        # Bersihkan folder jika sudah ada
        if os.path.exists(img_dir):
            shutil.rmtree(img_dir)
        if os.path.exists(lbl_dir):
            shutil.rmtree(lbl_dir)

        os.makedirs(img_dir, exist_ok=True)
        os.makedirs(lbl_dir, exist_ok=True)

    splits: Dict[str, List[str]] = {"train": [], "val": [], "test": []}

    # 2. Bagi 8 skenario video utama secara Block-Temporal
    print("\n[1] Membagi 8 skenario video berurutan:")
    for name, start, end in SCENARIOS:
        files = [f"cctv_{i:04d}.jpg" for i in range(start, end + 1)]
        # Hanya ambil file yang benar-benar ada di disk
        existing = [f for f in files if os.path.exists(os.path.join(SOURCE_DIR, f))]
        n = len(existing)
        if n == 0:
            continue

        n_train = int(n * 0.70)
        n_val = int(n * 0.85)

        train_part = existing[:n_train]
        val_part = existing[n_train:n_val]
        test_part = existing[n_val:]

        splits["train"].extend(train_part)
        splits["val"].extend(val_part)
        splits["test"].extend(test_part)

        print(f"  - {name:<20}: Total {n:3d} frame -> Train: {len(train_part):3d}, Val: {len(val_part):2d}, Test: {len(test_part):2d}")

    # 3. Bagi dataset baru (Person_01 s/d Person_12)
    if os.path.exists(MAPPING_CSV):
        print("\n[2] Membagi dataset tambahan berdasarkan Person ID:")
        df = pd.read_csv(MAPPING_CSV)
        for pid, group in df.groupby("person_id"):
            files = [f for f in group["cctv_file"].tolist() if os.path.exists(os.path.join(SOURCE_DIR, f))]
            n = len(files)
            if n == 0:
                continue

            n_train = max(1, int(n * 0.70)) if n > 2 else 1
            n_val = max(n_train + 1, int(n * 0.85)) if n > 3 else n_train

            train_part = files[:n_train]
            val_part = files[n_train:n_val]
            test_part = files[n_val:]

            splits["train"].extend(train_part)
            splits["val"].extend(val_part)
            splits["test"].extend(test_part)

            print(f"  - Subjek {pid:<10}: Total {n:2d} frame -> Train: {len(train_part):2d}, Val: {len(val_part):2d}, Test: {len(test_part):2d}")

    # 4. Salin file ke folder images dan labels
    print("\n[3] Menyalin file citra & label ke dataset_yolo_tidur...")
    counts: Dict[str, int] = {"train": 0, "val": 0, "test": 0}
    class_dist: Dict[str, Counter] = {"train": Counter(), "val": Counter(), "test": Counter()}

    for split_name, file_list in splits.items():
        dest_img_dir = os.path.join(BASE_OUT_DIR, "images", split_name)
        dest_lbl_dir = os.path.join(BASE_OUT_DIR, "labels", split_name)

        for img_name in file_list:
            src_img_path = os.path.join(SOURCE_DIR, img_name)
            txt_name = os.path.splitext(img_name)[0] + ".txt"
            src_txt_path = os.path.join(SOURCE_DIR, txt_name)

            if os.path.exists(src_img_path) and os.path.exists(src_txt_path):
                shutil.copy(src_img_path, os.path.join(dest_img_dir, img_name))
                shutil.copy(src_txt_path, os.path.join(dest_lbl_dir, txt_name))
                counts[split_name] += 1

                with open(src_txt_path, "r", encoding="utf-8") as f_lbl:
                    for line in f_lbl:
                        line = line.strip()
                        if line:
                            cls_id = line.split()[0]
                            class_dist[split_name][cls_id] += 1

    print("\n" + "=" * 70)
    print("HASIL PEMBAGIAN DATASET FINAL:")
    print(f"  - Train Set : {counts['train']:3d} frame | Distribusi: {dict(class_dist['train'])}")
    print(f"  - Val Set   : {counts['val']:3d} frame | Distribusi: {dict(class_dist['val'])}")
    print(f"  - Test Set  : {counts['test']:3d} frame | Distribusi: {dict(class_dist['test'])}")
    print(f"  - Total     : {sum(counts.values()):3d} frame")
    print("=" * 70)
    print("Dataset siap digunakan untuk pelatihan YOLOv8!")


if __name__ == "__main__":
    split_dataset()
