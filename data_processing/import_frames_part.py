"""
Import & Auto-Label Frames Part 1-3 (EduSense)
==============================================
Menyalin gambar dari folder frames_part1, frames_part2, dan frames_part3
ke dataset/raw/dataset_cctv_tersaring/ dengan penomoran berurutan (cctv_XXXX.jpg)
serta membuat file anotasi YOLO (.txt) awal untuk kelas 0 (wajah) menggunakan
Haar Cascade agar siap dicek/dilabeli kelas 1 (head_down) di LabelImg.

Catatan: File lama (cctv_0001 s/d indeks terakhir sebelumnya) tidak diubah.
"""

import csv
import os
import shutil
import cv2

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))
TARGET_FOLDER = os.path.join(PROJECT_ROOT, "dataset", "raw", "dataset_cctv_tersaring")
MAPPING_CSV = os.path.join(PROJECT_ROOT, "dataset", "mapping_frames_part.csv")

SOURCE_PARTS = [
    ("frames_part1", os.path.join(PROJECT_ROOT, "frames_part1", "frames")),
    ("frames_part2", os.path.join(PROJECT_ROOT, "frames_part2", "frames")),
    ("frames_part3", os.path.join(PROJECT_ROOT, "frames_part3", "frames")),
]


def load_face_cascade() -> cv2.CascadeClassifier:
    cascade_local = os.path.join(BASE_DIR, "haarcascade_frontalface_default.xml")
    cascade_cv2 = os.path.join(getattr(cv2.data, "haarcascades", ""), "haarcascade_frontalface_default.xml")

    if os.path.exists(cascade_local):
        cascade_path = cascade_local
    elif os.path.exists(cascade_cv2):
        cascade_path = cascade_cv2
    else:
        raise FileNotFoundError("haarcascade_frontalface_default.xml tidak ditemukan.")

    face_cascade = cv2.CascadeClassifier(cascade_path)
    if face_cascade.empty():
        raise RuntimeError(f"Gagal memuat CascadeClassifier dari: {cascade_path}")
    return face_cascade


def get_next_cctv_index(folder: str) -> int:
    indices = []
    for f in os.listdir(folder):
        if f.startswith("cctv_") and f.lower().endswith(".jpg"):
            try:
                indices.append(int(f[5:-4]))
            except ValueError:
                pass
    return max(indices) + 1 if indices else 1


def main() -> None:
    os.makedirs(TARGET_FOLDER, exist_ok=True)
    face_cascade = load_face_cascade()
    next_idx = get_next_cctv_index(TARGET_FOLDER)
    start_idx = next_idx

    total_copied = 0
    total_with_faces = 0
    total_boxes = 0
    mapping_rows = []

    for part_name, src_dir in SOURCE_PARTS:
        if not os.path.isdir(src_dir):
            print(f"[WARN] Folder tidak ditemukan: {src_dir}")
            continue

        files = sorted(
            f for f in os.listdir(src_dir)
            if f.lower().endswith((".jpg", ".jpeg", ".png"))
        )
        print(f"[{part_name}] Ditemukan {len(files)} gambar")

        for fname in files:
            src_path = os.path.join(src_dir, fname)
            cctv_name = f"cctv_{next_idx:04d}"
            dest_img = os.path.join(TARGET_FOLDER, f"{cctv_name}.jpg")
            dest_txt = os.path.join(TARGET_FOLDER, f"{cctv_name}.txt")

            img = cv2.imread(src_path)
            if img is None:
                print(f"  [WARN] Gagal membaca gambar: {src_path}")
                continue

            if src_path.lower().endswith(".jpg"):
                shutil.copy2(src_path, dest_img)
            else:
                cv2.imwrite(dest_img, img)

            h, w, _ = img.shape
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            faces = face_cascade.detectMultiScale(
                gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30)
            )

            with open(dest_txt, "w", encoding="utf-8") as f_txt:
                for (fx, fy, fw, fh) in faces:
                    xc = (fx + fw / 2) / w
                    yc = (fy + fh / 2) / h
                    nw = fw / w
                    nh = fh / h
                    f_txt.write(f"0 {xc:.6f} {yc:.6f} {nw:.6f} {nh:.6f}\n")

            if len(faces) > 0:
                total_with_faces += 1
                total_boxes += len(faces)

            mapping_rows.append([f"{cctv_name}.jpg", part_name, fname, len(faces)])
            total_copied += 1
            next_idx += 1

    with open(MAPPING_CSV, "w", newline="", encoding="utf-8") as f_csv:
        writer = csv.writer(f_csv)
        writer.writerow(["cctv_file", "source_part", "source_file", "faces_detected"])
        writer.writerows(mapping_rows)

    print("\n=== RINGKASAN ===")
    print(f"Rentang file baru   : cctv_{start_idx:04d}.jpg s/d cctv_{next_idx - 1:04d}.jpg")
    print(f"Total gambar disalin: {total_copied}")
    print(f"Terdeteksi wajah (0): {total_with_faces} gambar ({total_boxes} bounding box)")
    print(f"Label .txt kosong   : {total_copied - total_with_faces} gambar")
    print(f"Log mapping         : {MAPPING_CSV}")


if __name__ == "__main__":
    main()
