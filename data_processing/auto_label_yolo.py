"""
Auto-Labeling YOLO untuk Dataset Baru (EduSense)
================================================
Menggunakan model YOLO terlatih (best.pt) untuk mengisi file anotasi .txt
pada gambar baru yang tercatat di dataset/mapping_frames_part.csv
(cctv_0826.jpg s/d cctv_1787.jpg) tanpa menyentuh label lama (cctv_0001-0825).
"""

import argparse
import csv
import os
from ultralytics import YOLO

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))
TARGET_FOLDER = os.path.join(PROJECT_ROOT, "dataset", "raw", "dataset_cctv_tersaring")
MAPPING_CSV = os.path.join(PROJECT_ROOT, "dataset", "mapping_frames_part.csv")


def auto_label(model_path: str, conf: float = 0.25) -> None:
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model tidak ditemukan: {model_path}")
    if not os.path.exists(MAPPING_CSV):
        raise FileNotFoundError(f"Mapping CSV tidak ditemukan: {MAPPING_CSV}")

    with open(MAPPING_CSV, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    img_names = [r["cctv_file"] for r in rows]
    img_paths = [os.path.join(TARGET_FOLDER, name) for name in img_names if os.path.exists(os.path.join(TARGET_FOLDER, name))]

    print(f"Memuat model: {model_path}")
    model = YOLO(model_path)
    print(f"Kelas model: {model.names}")
    print(f"Memproses {len(img_paths)} gambar (conf={conf})...")

    total_with_boxes = 0
    total_empty = 0
    class_counts = {0: 0, 1: 0}

    results = []
    for idx, img_path in enumerate(img_paths, start=1):
        res_list = model.predict(source=img_path, conf=conf, imgsz=640, verbose=False)
        res = res_list[0]
        if idx % 100 == 0 or idx == len(img_paths):
            print(f"  Progress: {idx}/{len(img_paths)}")
        txt_path = os.path.splitext(img_path)[0] + ".txt"
        boxes = res.boxes
        lines = []
        if boxes is not None and len(boxes) > 0:
            for box in boxes:
                cls_id = int(box.cls[0].item())
                xc, yc, bw, bh = box.xywhn[0].tolist()
                xc = max(0.0, min(1.0, xc))
                yc = max(0.0, min(1.0, yc))
                bw = max(0.0, min(1.0, bw))
                bh = max(0.0, min(1.0, bh))
                lines.append(f"{cls_id} {xc:.6f} {yc:.6f} {bw:.6f} {bh:.6f}\n")
                class_counts[cls_id] = class_counts.get(cls_id, 0) + 1
            total_with_boxes += 1
        else:
            total_empty += 1

        with open(txt_path, "w", encoding="utf-8") as f_txt:
            f_txt.writelines(lines)

    print("\n=== RINGKASAN AUTO-LABEL YOLO ===")
    print(f"Total gambar diproses : {len(img_paths)}")
    print(f"Gambar berlabel       : {total_with_boxes}")
    print(f"Gambar kosong         : {total_empty}")
    print(f"Total box wajah (0)   : {class_counts.get(0, 0)}")
    print(f"Total box head_down(1): {class_counts.get(1, 0)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, help="Path ke file best.pt")
    parser.add_argument("--conf", type=float, default=0.25, help="Confidence threshold")
    args = parser.parse_args()
    auto_label(args.model, args.conf)
