"""
BBox Reviewer & Editor (EduSense) — with Mouse Drawing
=======================================================
Viewer + editor bounding box YOLO berbasis OpenCV.
Mendukung menggambar, menghapus, dan menyimpan label YOLO.

Kontrol Keyboard:
  D / -> (kanan)  : Gambar berikutnya (auto-simpan)
  A / <- (kiri)   : Gambar sebelumnya (auto-simpan)
  W               : Pilih kelas WAJAH (0) untuk digambar  [hijau]
  H               : Pilih kelas HEAD_DOWN (1) untuk digambar  [merah]
  1               : Hapus box terakhir
  2               : Hapus SEMUA box pada gambar ini
  Z               : Undo gambar terakhir
  S               : Simpan label ke file .txt
  Q / ESC         : Keluar (auto-simpan)

Kontrol Mouse:
  Klik kiri + drag : Gambar bounding box baru (sesuai kelas aktif)

Argumen:
  --src   : Folder dataset_cctv_tersaring
  --start : Nomor cctv mulai (default: 826)
  --end   : Nomor cctv akhir (default: 1787)
"""

import argparse
import os
import sys
import cv2
import numpy as np

CLASSES = ["wajah", "head_down"]
COLORS  = [(0, 210, 0), (0, 60, 255)]   # hijau, merah

BASE_DIR     = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))
DEFAULT_SRC  = os.path.join(PROJECT_ROOT, "dataset", "raw", "dataset_cctv_tersaring")

# ──────────────────────────────────────────────────────────
# State mouse (mutable dict agar bisa diakses dari callback)
# ──────────────────────────────────────────────────────────
mouse_state = {
    "drawing": False,
    "x0": 0, "y0": 0,   # titik awal klik
    "x1": 0, "y1": 0,   # posisi mouse sekarang
}


def mouse_callback(event, x, y, flags, param):
    ms = param
    if event == cv2.EVENT_LBUTTONDOWN:
        ms["drawing"] = True
        ms["x0"] = ms["x1"] = x
        ms["y0"] = ms["y1"] = y
    elif event == cv2.EVENT_MOUSEMOVE and ms["drawing"]:
        ms["x1"] = x
        ms["y1"] = y
    elif event == cv2.EVENT_LBUTTONUP:
        ms["drawing"] = False
        ms["x1"] = x
        ms["y1"] = y
        ms["commit"] = True   # tandai untuk commit ke boxes


# ──────────────────────────────────────────────────────────
# I/O label
# ──────────────────────────────────────────────────────────
def read_labels(txt_path: str):
    boxes = []
    if not os.path.exists(txt_path):
        return boxes
    with open(txt_path, encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) == 5:
                boxes.append([int(parts[0])] + [float(x) for x in parts[1:]])
    return boxes


def save_labels(txt_path: str, boxes):
    with open(txt_path, "w", encoding="utf-8") as f:
        for b in boxes:
            f.write(f"{b[0]} {b[1]:.6f} {b[2]:.6f} {b[3]:.6f} {b[4]:.6f}\n")


# ──────────────────────────────────────────────────────────
# Render
# ──────────────────────────────────────────────────────────
def draw_frame(img, boxes, ms, cur_cls, img_name, idx, total, dirty):
    vis = img.copy()
    h, w = vis.shape[:2]

    # Gambar semua box tersimpan
    for b in boxes:
        cls, xc, yc, bw, bh = b
        x1 = int((xc - bw / 2) * w);  y1 = int((yc - bh / 2) * h)
        x2 = int((xc + bw / 2) * w);  y2 = int((yc + bh / 2) * h)
        color = COLORS[cls] if cls < len(COLORS) else (255, 255, 0)
        label = CLASSES[cls] if cls < len(CLASSES) else str(cls)
        cv2.rectangle(vis, (x1, y1), (x2, y2), color, 2)
        cv2.putText(vis, label, (x1 + 3, max(16, y1 - 5)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 2)

    # Preview box sedang digambar
    if ms["drawing"]:
        px0, py0 = min(ms["x0"], ms["x1"]), min(ms["y0"], ms["y1"])
        px1, py1 = max(ms["x0"], ms["x1"]), max(ms["y0"], ms["y1"])
        cv2.rectangle(vis, (px0, py0), (px1, py1), COLORS[cur_cls], 2)
        cv2.putText(vis, f"[{CLASSES[cur_cls]}]", (px0 + 3, max(16, py0 - 5)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, COLORS[cur_cls], 2)

    # HUD atas
    dirty_mark = "* " if dirty else ""
    info1 = (f"{dirty_mark}[{idx+1}/{total}] {img_name}  |  box:{len(boxes)}"
             f"  |  Kelas aktif: [{cur_cls}] {CLASSES[cur_cls]}")
    info2 = "W=wajah  H=head_down  |  Drag=gambar  1=hapus terakhir  2=hapus semua  Z=undo  S=simpan  A/D=prev/next  Q=keluar"
    cv2.rectangle(vis, (0, 0), (vis.shape[1], 48), (20, 20, 20), -1)
    cv2.putText(vis, info1, (8, 18), cv2.FONT_HERSHEY_SIMPLEX, 0.52, (220, 220, 220), 1)
    cv2.putText(vis, info2, (8, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.44, (160, 200, 160), 1)

    # Indikator kelas aktif (kotak kecil kanan bawah)
    h2, w2 = vis.shape[:2]
    cv2.rectangle(vis, (w2 - 180, h2 - 36), (w2, h2), (20, 20, 20), -1)
    cv2.rectangle(vis, (w2 - 178, h2 - 34), (w2 - 2, h2 - 2), COLORS[cur_cls], 2)
    cv2.putText(vis, f"KELAS: {CLASSES[cur_cls]}", (w2 - 174, h2 - 12),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, COLORS[cur_cls], 2)
    return vis


# ──────────────────────────────────────────────────────────
# Main loop
# ──────────────────────────────────────────────────────────
def run(src: str, start: int, end: int):
    img_files = []
    for i in range(start, end + 1):
        name = f"cctv_{i:04d}.jpg"
        path = os.path.join(src, name)
        if os.path.exists(path):
            img_files.append(name)

    if not img_files:
        print(f"[ERROR] Tidak ada gambar cctv_{start:04d}–cctv_{end:04d} di: {src}")
        sys.exit(1)

    print(f"Ditemukan {len(img_files)} gambar (cctv_{start:04d} – cctv_{end:04d})")
    print("Tekan W/H untuk pilih kelas, lalu klik-drag untuk menggambar box.")

    cv2.namedWindow("BBox Editor", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("BBox Editor", 1280, 740)
    cv2.setMouseCallback("BBox Editor", mouse_callback, mouse_state)

    idx      = 0
    cur_cls  = 1          # default: head_down
    dirty    = False
    undo_stack = []       # list of boxes snapshots untuk undo

    while True:
        name     = img_files[idx]
        img_path = os.path.join(src, name)
        txt_path = os.path.join(src, os.path.splitext(name)[0] + ".txt")

        img = cv2.imread(img_path)
        if img is None:
            idx = min(idx + 1, len(img_files) - 1)
            continue
        h, w = img.shape[:2]
        boxes      = read_labels(txt_path)
        dirty      = False
        undo_stack = []
        mouse_state["drawing"] = False
        mouse_state.pop("commit", None)

        while True:
            # Commit box setelah mouse release
            if mouse_state.pop("commit", False) and not mouse_state["drawing"]:
                px0 = min(mouse_state["x0"], mouse_state["x1"])
                py0 = min(mouse_state["y0"], mouse_state["y1"])
                px1 = max(mouse_state["x0"], mouse_state["x1"])
                py1 = max(mouse_state["y0"], mouse_state["y1"])
                bw_px = px1 - px0
                bh_px = py1 - py0
                if bw_px >= 5 and bh_px >= 5:   # abaikan klik tanpa drag
                    xc = (px0 + bw_px / 2) / w
                    yc = (py0 + bh_px / 2) / h
                    nw = bw_px / w
                    nh = bh_px / h
                    xc = max(0.001, min(0.999, xc))
                    yc = max(0.001, min(0.999, yc))
                    nw = max(0.001, min(0.999, nw))
                    nh = max(0.001, min(0.999, nh))
                    undo_stack.append([b[:] for b in boxes])
                    boxes.append([cur_cls, xc, yc, nw, nh])
                    dirty = True

            vis = draw_frame(img, boxes, mouse_state, cur_cls, name, idx, len(img_files), dirty)
            cv2.imshow("BBox Editor", vis)
            key = cv2.waitKey(20) & 0xFF

            # ── Navigasi ──
            if key in (ord("d"), 83):   # Next
                if dirty:
                    save_labels(txt_path, boxes)
                idx = min(idx + 1, len(img_files) - 1)
                break
            elif key in (ord("a"), 81): # Prev
                if dirty:
                    save_labels(txt_path, boxes)
                idx = max(idx - 1, 0)
                break

            # ── Pilih kelas ──
            elif key == ord("w"):
                cur_cls = 0
            elif key == ord("h"):
                cur_cls = 1

            # ── Edit ──
            elif key == ord("1"):       # Hapus box terakhir
                if boxes:
                    undo_stack.append([b[:] for b in boxes])
                    removed = boxes.pop()
                    print(f"  Hapus box terakhir: {CLASSES[removed[0]]}")
                    dirty = True

            elif key == ord("2"):       # Hapus semua
                if boxes:
                    undo_stack.append([b[:] for b in boxes])
                    boxes.clear()
                    print(f"  Semua box dihapus dari {name}")
                    dirty = True

            elif key == ord("z"):       # Undo
                if undo_stack:
                    boxes.clear()
                    boxes.extend(undo_stack.pop())
                    dirty = True
                    print("  Undo")

            elif key == ord("s"):       # Simpan
                save_labels(txt_path, boxes)
                dirty = False
                print(f"  Disimpan: {len(boxes)} box → {txt_path}")

            # ── Keluar ──
            elif key in (ord("q"), 27):
                if dirty:
                    save_labels(txt_path, boxes)
                cv2.destroyAllWindows()
                print("Selesai.")
                return

    cv2.destroyAllWindows()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="BBox Editor EduSense")
    parser.add_argument("--src",   default=DEFAULT_SRC)
    parser.add_argument("--start", type=int, default=826)
    parser.add_argument("--end",   type=int, default=1787)
    args = parser.parse_args()
    run(args.src, args.start, args.end)
