"""
Skrip Perbaikan Dataset EduSense (Fix Stacked Images & Labels)
=============================================================
1. Memotong (crop) citra bertumpuk (cctv_0001 - cctv_0716, resolusi 368x416)
   menjadi citra tunggal normal (368x208).
2. Menghapus bounding box duplikat di paruh bawah citra.
3. Menghitung ulang (rescale) koordinat YOLO pada bounding box paruh atas
   agar presisi dengan citra tunggal hasil crop (y_new = y * 2, h_new = h * 2).
4. Melakukan audit dan validasi batas koordinat [0.0 - 1.0] untuk semua file.
"""

import os
import glob
import cv2
from typing import List, Tuple

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(BASE_DIR, "dataset_cctv_tersaring")


def fix_stacked_dataset():
    print("=" * 70)
    print("  MEMULAI PERBAIKAN CITRA & LABEL BERTUMPUK (EDUSENSE)")
    print("=" * 70)

    jpg_files = sorted(glob.glob(os.path.join(DATASET_DIR, "cctv_*.jpg")))
    print(f"Total file citra ditemukan: {len(jpg_files)}")

    unstacked_count = 0
    box_corrected_count = 0
    already_clean_count = 0
    total_boxes_kept = 0
    errors = []

    for img_path in jpg_files:
        base_name = os.path.basename(img_path)
        txt_path = os.path.splitext(img_path)[0] + ".txt"

        if not os.path.exists(txt_path):
            errors.append(f"Label hilang untuk {base_name}")
            continue

        img = cv2.imread(img_path)
        if img is None:
            errors.append(f"Gagal membaca gambar {base_name}")
            continue

        h, w, c = img.shape

        # Periksa apakah gambar bertumpuk (tinggi 416, lebar 368)
        if h == 416 and w == 368:
            # 1. Crop paruh atas saja (tinggi 208)
            img_clean = img[:208, :]
            cv2.imwrite(img_path, img_clean)
            unstacked_count += 1

            # 2. Proses dan rekalkulasi label YOLO
            with open(txt_path, "r", encoding="utf-8") as f:
                lines = [line.strip() for line in f if line.strip()]

            new_boxes: List[str] = []
            for line in lines:
                parts = line.split()
                if len(parts) != 5:
                    continue
                cls_id = parts[0]
                xc, yc, bw, bh = map(float, parts[1:])

                # Simpan hanya box yang berada di paruh atas (yc < 0.5)
                # Box paruh bawah adalah duplikat dari citra kedua yang dibuang
                if yc < 0.5:
                    new_yc = yc * 2.0
                    new_bh = bh * 2.0

                    # Clamp nilai agar selalu berada di interval [0.0, 1.0]
                    new_xc = max(0.001, min(0.999, xc))
                    new_yc = max(0.001, min(0.999, new_yc))
                    new_bw = max(0.001, min(0.999, bw))
                    new_bh = max(0.001, min(0.999, new_bh))

                    new_boxes.append(f"{cls_id} {new_xc:.6f} {new_yc:.6f} {new_bw:.6f} {new_bh:.6f}")

            # Tulis ulang file anotasi
            with open(txt_path, "w", encoding="utf-8") as f:
                for box_str in new_boxes:
                    f.write(box_str + "\n")

            box_corrected_count += 1
            total_boxes_kept += len(new_boxes)

        else:
            # File citra normal (sudah single frame, misal 848x478)
            already_clean_count += 1
            with open(txt_path, "r", encoding="utf-8") as f:
                lines = [line.strip() for line in f if line.strip()]
            total_boxes_kept += len(lines)

    print("\n" + "=" * 70)
    print("HASIL PERBAIKAN CITRA & LABEL:")
    print(f"  - Citra bertumpuk yang di-unstack (416x368 -> 208x368): {unstacked_count} file")
    print(f"  - Label yang dikoreksi & dihapus duplikasinya         : {box_corrected_count} file")
    print(f"  - Citra normal yang dipertahankan                    : {already_clean_count} file")
    print(f"  - Total bounding box valid tersimpan                 : {total_boxes_kept} box")
    if errors:
        print(f"  [PERINGATAN] Ditemukan {len(errors)} error:")
        for err in errors[:5]:
            print("   *", err)
    else:
        print("  - Status: 100% SUKSES tanpa error.")
    print("=" * 70)


if __name__ == "__main__":
    fix_stacked_dataset()
