"""
Auto-Labeling Berbasis YOLOv8-Pose + Propagasi Temporal (EduSense)
==================================================================
1. Menggunakan YOLOv8s-Pose untuk mendeteksi setiap mahasiswa secara terpisah:
   - 0 (wajah)     : mata & hidung terlihat dan kepala tidak menunduk ekstrem
   - 1 (head_down) : kepala menunduk (dy < 0.18), mata/hidung tertutup,
                     atau hanya bahu/punggung yang terdeteksi (kepala di balik laptop)
2. Propagasi Temporal per part (frames_part1, frames_part2, frames_part3):
   - Jika mahasiswa yang sedang `head_down` sesaat menghilang dari deteksi pose
     karena kepalanya turun penuh di balik laptop (gap <= 15 frame), box `head_down`
     diinterpolasi/dipertahankan dari frame terdekat di posisi kursi yang sama.

Hanya memproses gambar baru di dataset/mapping_frames_part.csv (cctv_0826-1787).
"""

import csv
import os
from typing import Dict, List, Tuple
import numpy as np
from ultralytics import YOLO

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))
TARGET_FOLDER = os.path.join(PROJECT_ROOT, "dataset", "raw", "dataset_cctv_tersaring")
MAPPING_CSV = os.path.join(PROJECT_ROOT, "dataset", "mapping_frames_part.csv")
POSE_MODEL_PATH = os.path.join(PROJECT_ROOT, "yolov8s-pose.pt")


def box_contains_center(outer: Tuple[float, float, float, float], inner: Tuple[float, float, float, float]) -> bool:
    """Cek apakah titik tengah box inner berada di dalam box outer (untuk mencegah duplikat wajah + head_down)."""
    ox1, oy1 = outer[0] - outer[2] / 2, outer[1] - outer[3] / 2
    ox2, oy2 = outer[0] + outer[2] / 2, outer[1] + outer[3] / 2
    return ox1 <= inner[0] <= ox2 and oy1 <= inner[1] <= oy2


def bbox_iou(b1: Tuple[float, float, float, float], b2: Tuple[float, float, float, float]) -> float:
    """Hitung IoU dua box format YOLO (xc, yc, w, h)."""
    x1_min, y1_min = b1[0] - b1[2] / 2, b1[1] - b1[3] / 2
    x1_max, y1_max = b1[0] + b1[2] / 2, b1[1] + b1[3] / 2
    x2_min, y2_min = b2[0] - b2[2] / 2, b2[1] - b2[3] / 2
    x2_max, y2_max = b2[0] + b2[2] / 2, b2[1] + b2[3] / 2

    ix1, iy1 = max(x1_min, x2_min), max(y1_min, y2_min)
    ix2, iy2 = min(x1_max, x2_max), min(y1_max, y2_max)
    inter = max(0.0, ix2 - ix1) * max(0.0, iy2 - iy1)
    if inter <= 0:
        return 0.0
    union = b1[2] * b1[3] + b2[2] * b2[3] - inter
    return inter / union if union > 0 else 0.0


def main(conf: float = 0.25, dy_threshold: float = 0.18, max_gap: int = 15) -> None:
    if not os.path.exists(MAPPING_CSV):
        raise FileNotFoundError(f"Mapping CSV tidak ditemukan: {MAPPING_CSV}")

    with open(MAPPING_CSV, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    model_src = POSE_MODEL_PATH if os.path.exists(POSE_MODEL_PATH) else "yolov8s-pose.pt"
    print(f"Memuat model pose: {model_src}")
    model = YOLO(model_src)
    print(f"Pass 1: Deteksi pose pada {len(rows)} gambar (conf={conf}, imgsz=640)...")

    # Simpan deteksi per part agar propagasi tidak nyebrang antar-video
    part_frames: Dict[str, List[Tuple[str, List[List[float]]]]] = {}

    for idx, row in enumerate(rows, start=1):
        fname = row["cctv_file"]
        part = row["source_part"]
        img_path = os.path.join(TARGET_FOLDER, fname)
        if not os.path.exists(img_path):
            continue

        res = model.predict(source=img_path, conf=conf, imgsz=640, verbose=False)[0]
        h, w = res.orig_shape
        boxes_yolo: List[List[float]] = []

        if res.boxes is not None and res.keypoints is not None:
            for box, kpts in zip(res.boxes, res.keypoints.data):
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                bconf = float(box.conf[0].item())
                k = kpts.cpu().numpy()

                head_pts = [k[i] for i in range(5) if k[i][2] > 0.25]
                sh_pts = [k[i] for i in (5, 6) if k[i][2] > 0.25]

                # Jika kepala tidak terlihat tapi bahu/badan terdeteksi -> head_down
                if not head_pts:
                    if not sh_pts and bconf < 0.35:
                        continue
                    is_down = True
                    sh_w = (x2 - x1) * 0.6
                elif not sh_pts:
                    continue
                else:
                    head_y = float(np.mean([p[1] for p in head_pts]))
                    sh_y = float(np.mean([p[1] for p in sh_pts]))
                    sh_w = (
                        abs(float(k[5][0] - k[6][0]))
                        if (k[5][2] > 0.25 and k[6][2] > 0.25)
                        else (x2 - x1) * 0.6
                    )
                    eye_vis = (k[1][2] > 0.4 or k[2][2] > 0.4) and k[0][2] > 0.4
                    dy = (sh_y - head_y) / max(sh_w, 15.0)
                    is_down = (dy < dy_threshold) or (not eye_vis and dy < 0.35)

                if not is_down:
                    cls_id = 0
                    xs = [float(p[0]) for p in head_pts]
                    ys = [float(p[1]) for p in head_pts]
                    cx, cy = float(np.mean(xs)), float(np.mean(ys))
                    sz = max(max(xs) - min(xs), max(ys) - min(ys), sh_w * 0.45) * 1.45
                    bx1 = max(0.0, cx - sz / 2)
                    by1 = max(0.0, cy - sz * 0.55)
                    bx2 = min(float(w), cx + sz / 2)
                    by2 = min(float(h), cy + sz * 0.45)
                else:
                    cls_id = 1
                    bx1, by1 = max(0.0, x1), max(0.0, y1)
                    bx2, by2 = min(float(w), x2), min(float(h), y2)

                bw = (bx2 - bx1) / w
                bh = (by2 - by1) / h
                if bw < 0.01 or bh < 0.01:
                    continue
                xc = ((bx1 + bx2) / 2) / w
                yc = ((by1 + by2) / 2) / h
                boxes_yolo.append([cls_id, xc, yc, bw, bh])

        part_frames.setdefault(part, []).append((fname, boxes_yolo))
        if idx % 100 == 0 or idx == len(rows):
            print(f"  Progress Pass 1: {idx}/{len(rows)}")

    # Pass 2: Propagasi temporal untuk head_down yang hilang sesaat di balik laptop
    print("Pass 2: Propagasi temporal head_down antar-frame berdekatan...")
    interpolated_count = 0
    for part, frames in part_frames.items():
        n = len(frames)
        for i in range(n):
            _, cur_boxes = frames[i]
            # Cari head_down di frame sebelumnya dalam jarak <= max_gap
            for prev_idx in range(max(0, i - max_gap), i):
                for pb in frames[prev_idx][1]:
                    if int(pb[0]) != 1:
                        continue
                    pb_coord = (pb[1], pb[2], pb[3], pb[4])
                    # Apakah posisi ini sudah ada di frame i (baik wajah di dalamnya maupun head_down)?
                    already = any(
                        bbox_iou(pb_coord, (cb[1], cb[2], cb[3], cb[4])) > 0.25
                        or box_contains_center(pb_coord, (cb[1], cb[2], cb[3], cb[4]))
                        for cb in cur_boxes
                    )
                    if already:
                        continue
                    # Pastikan juga muncul lagi sebagai head_down di frame setelahnya (<= max_gap)
                    found_after = False
                    for next_idx in range(i + 1, min(n, i + max_gap + 1)):
                        for nb in frames[next_idx][1]:
                            if int(nb[0]) == 1 and bbox_iou(pb_coord, (nb[1], nb[2], nb[3], nb[4])) > 0.30:
                                found_after = True
                                break
                        if found_after:
                            break
                    if found_after:
                        cur_boxes.append([1, pb[1], pb[2], pb[3], pb[4]])
                        interpolated_count += 1

    # Tulis semua file .txt
    total_labeled = 0
    total_empty = 0
    counts = {0: 0, 1: 0}
    for part, frames in part_frames.items():
        for fname, boxes_yolo in frames:
            txt_path = os.path.join(TARGET_FOLDER, os.path.splitext(fname)[0] + ".txt")
            with open(txt_path, "w", encoding="utf-8") as f_txt:
                for b in boxes_yolo:
                    cls_id = int(b[0])
                    f_txt.write(f"{cls_id} {b[1]:.6f} {b[2]:.6f} {b[3]:.6f} {b[4]:.6f}\n")
                    counts[cls_id] = counts.get(cls_id, 0) + 1
            if boxes_yolo:
                total_labeled += 1
            else:
                total_empty += 1

    total_imgs = total_labeled + total_empty
    print("\n=== RINGKASAN AUTO-LABEL POSE + PROPAGASI ===")
    print(f"Total gambar diproses  : {total_imgs}")
    print(f"Gambar berlabel        : {total_labeled}")
    print(f"Gambar kosong          : {total_empty}")
    print(f"Total box wajah (0)    : {counts[0]}")
    print(f"Total box head_down (1): {counts[1]} (termasuk {interpolated_count} hasil propagasi)")


if __name__ == "__main__":
    main()
