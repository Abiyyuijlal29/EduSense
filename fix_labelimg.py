"""
Script otomatis untuk memperbaiki bug crash LabelImg pada Python 3.10 - 3.12 (PyQt5 float->int)
dan memastikan file classes.txt dataset EduSense memiliki kedua kelas (wajah & head_down).

Cara menjalankan:
    python fix_labelimg.py
"""

import os
import sys


def patch_file(filepath: str, replacements: list[tuple[str, str]]) -> bool:
    if not os.path.exists(filepath):
        print(f"[SKIP] File tidak ditemukan: {filepath}")
        return False

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    original = content
    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
        elif new in content:
            pass  # Sudah dipatch sebelumnya
        else:
            print(f"[INFO] Pola tidak ditemukan di {os.path.basename(filepath)}: {old}")

    if content != original:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"[OK] Berhasil memperbaiki: {filepath}")
        return True
    else:
        print(f"[OK] Sudah sesuai (tidak perlu diubah): {filepath}")
        return False


def main():
    print("=== Memperbaiki Bug Crash LabelImg untuk Python 3.10+ ===\n")

    try:
        import labelImg
        import libs.canvas as canvas_mod
        import libs.shape as shape_mod
    except ImportError as e:
        print(f"[ERROR] Gagal mengimpor labelImg: {e}")
        print("Pastikan labelImg sudah terpasang: pip install labelImg")
        sys.exit(1)

    labelimg_py = os.path.join(os.path.dirname(labelImg.__file__), "labelImg.py")
    canvas_py = canvas_mod.__file__
    shape_py = shape_mod.__file__

    # 1. Patch libs/canvas.py (crash saat menggambar bounding box & crosshair)
    patch_file(
        canvas_py,
        [
            (
                "p.drawRect(left_top.x(), left_top.y(), rect_width, rect_height)",
                "p.drawRect(int(left_top.x()), int(left_top.y()), int(rect_width), int(rect_height))",
            ),
            (
                "p.drawLine(self.prev_point.x(), 0, self.prev_point.x(), self.pixmap.height())",
                "p.drawLine(int(self.prev_point.x()), 0, int(self.prev_point.x()), int(self.pixmap.height()))",
            ),
            (
                "p.drawLine(0, self.prev_point.y(), self.pixmap.width(), self.prev_point.y())",
                "p.drawLine(0, int(self.prev_point.y()), int(self.pixmap.width()), int(self.prev_point.y()))",
            ),
        ],
    )

    # 2. Patch libs/shape.py (crash saat menampilkan teks label pada bounding box)
    patch_file(
        shape_py,
        [
            (
                "painter.drawText(min_x, min_y, self.label)",
                "painter.drawText(int(min_x), int(min_y), self.label)",
            ),
        ],
    )

    # 3. Patch labelImg/labelImg.py (crash saat scroll & zoom gambar)
    patch_file(
        labelimg_py,
        [
            (
                "bar.setValue(bar.value() + bar.singleStep() * units)",
                "bar.setValue(int(bar.value() + bar.singleStep() * units))",
            ),
            (
                "self.zoom_widget.setValue(value)",
                "self.zoom_widget.setValue(int(value))",
            ),
            (
                "h_bar.setValue(new_h_bar_value)",
                "h_bar.setValue(int(new_h_bar_value))",
            ),
            (
                "v_bar.setValue(new_v_bar_value)",
                "v_bar.setValue(int(new_v_bar_value))",
            ),
        ],
    )

    # 4. Pastikan classes.txt memiliki 2 kelas sesuai dataset.yaml (0: wajah, 1: head_down)
    base_dir = os.path.dirname(os.path.abspath(__file__))
    classes_content = "wajah\nhead_down\n"
    target_dirs = [
        os.path.join(base_dir, "dataset", "raw", "dataset_cctv_tersaring"),
        os.path.join(base_dir, "dataset", "dataset_yolo_tidur", "labels", "train"),
        os.path.join(base_dir, "dataset", "dataset_yolo_tidur", "labels", "val"),
        os.path.join(base_dir, "dataset", "dataset_yolo_tidur", "labels", "test"),
    ]

    print("\n=== Memastikan File classes.txt Lengkap (wajah & head_down) ===")
    for folder in target_dirs:
        if os.path.isdir(folder):
            classes_path = os.path.join(folder, "classes.txt")
            with open(classes_path, "w", encoding="utf-8") as f:
                f.write(classes_content)
            print(f"[OK] classes.txt diperbarui: {classes_path}")

    print("\nSelesai! Sekarang jalankan perintah berikut untuk membuka LabelImg:")
    print('  labelImg "dataset/raw/dataset_cctv_tersaring" "dataset/raw/dataset_cctv_tersaring/classes.txt"')


if __name__ == "__main__":
    main()

