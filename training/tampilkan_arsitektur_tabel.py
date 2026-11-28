"""
Skrip Menampilkan Arsitektur YOLOv8s EduSense dalam Bentuk Tabel
================================================================
Membaca langsung bobot model terlatih (backend/models/best.pt),
melakukan simulasi forward-pass (640x640), dan menampilkan tabel
arsitektur layer-by-layer di terminal.
"""

import os
import torch
import pandas as pd
from ultralytics import YOLO

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))
MODEL_PATH = os.path.join(PROJECT_ROOT, "backend", "models", "best.pt")


def main():
    if not os.path.exists(MODEL_PATH):
        print(f"[ERROR] File model tidak ditemukan di: {MODEL_PATH}")
        return

    yolo = YOLO(MODEL_PATH)
    model = yolo.model
    model.eval()

    # Catat bentuk tensor output untuk setiap blok (0..22)
    shapes = {}

    def make_hook(idx):
        def hook(_mod, _inp, out):
            if isinstance(out, torch.Tensor):
                c, h, w = out.shape[1:]
                shapes[idx] = f"{c} x {h} x {w}"
            elif isinstance(out, (list, tuple)) and len(out) > 0 and isinstance(out[0], torch.Tensor):
                shapes[idx] = str(tuple(out[0].shape[1:]))
            else:
                shapes[idx] = "-"
        return hook

    handles = [layer.register_forward_hook(make_hook(i)) for i, layer in enumerate(model.model)]
    with torch.no_grad():
        _ = model(torch.zeros(1, 3, 640, 640))
    for h in handles:
        h.remove()

    rows = []
    total_params = 0
    for i, layer in enumerate(model.model):
        bagian = "Backbone" if i <= 9 else ("Head (Output)" if i == 22 else "Neck (PANet)")
        params = sum(p.numel() for p in layer.parameters())
        total_params += params
        rows.append({
            "Index": i,
            "Bagian": bagian,
            "Modul": layer.__class__.__name__,
            "Output (C x H x W)": shapes.get(i, "-"),
            "Parameter": f"{params:,}",
        })

    df = pd.DataFrame(rows)
    print("=" * 72)
    print("   TABEL ARSITEKTUR MODEL YOLOv8s - EDUSENSE (backend/models/best.pt)")
    print(f"   Kelas: {yolo.names} | Total Parameter: {total_params:,}")
    print("=" * 72)
    print(df.to_string(index=False))
    print("=" * 72)


if __name__ == "__main__":
    main()
