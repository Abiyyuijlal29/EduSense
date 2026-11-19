"""
Skrip Perhitungan Akurasi, Precision, Recall, dan F1-Score
Berdasarkan Confusion Matrix EduSense (YOLOv8)
=========================================================
"""

import numpy as np
import pandas as pd

# -------------------------------------------------------------
# 1. DEFINISI DATA CONFUSION MATRIX (Sesuai Gambar Hasil YOLO)
# -------------------------------------------------------------
# Baris: Predicted (Prediksi) -> ['wajah', 'head_down', 'background']
# Kolom: True (Sebenarnya)   -> ['wajah', 'head_down', 'background']

matrix = np.array([
    # True: wajah, head_down, background
    [48,           2,         108],  # Prediksi: wajah
    [0,           72,         124],  # Prediksi: head_down
    [0,            0,           0]   # Prediksi: background (terlewat/FN)
])

classes = ['wajah', 'head_down']

# Ekstraksi Elemen Matriks
tp_wajah = matrix[0, 0]        # True Positif Wajah (48)
fp_cls_wajah = matrix[0, 1]    # Salah deteksi: head_down dikira wajah (2)
fp_bg_wajah = matrix[0, 2]     # False Alarm dari background (108)

tp_sleep = matrix[1, 1]        # True Positif Head Down (72)
fp_cls_sleep = matrix[1, 0]    # Salah deteksi: wajah dikira head_down (0)
fp_bg_sleep = matrix[1, 2]     # False Alarm dari background (124)

fn_wajah = matrix[1, 0] + matrix[2, 0]  # Wajah yang tidak terdeteksi (0)
fn_sleep = matrix[0, 1] + matrix[2, 1]  # Head Down yang dikira wajah/bg (2)

total_true_wajah = tp_wajah + fn_wajah  # 48
total_true_sleep = tp_sleep + fn_sleep  # 74
total_ground_truth = total_true_wajah + total_true_sleep  # 122

# -------------------------------------------------------------
# 2. RUMUS & PERHITUNGAN METRIK
# -------------------------------------------------------------

# A. Akurasi Klasifikasi Target (Classification Accuracy)
# Rumus: (TP Wajah + TP Head Down) / Total Objek Nyata
total_correct = tp_wajah + tp_sleep
accuracy = (total_correct / total_ground_truth) * 100

# B. Recall / Sensitivitas
# Rumus: TP / (TP + FN)
recall_wajah = (tp_wajah / total_true_wajah) * 100
recall_sleep = (tp_sleep / total_true_sleep) * 100
macro_recall = (recall_wajah + recall_sleep) / 2

# C. Precision Antar-Kelas (Pure Behavioral Prediction)
# Rumus: TP / (TP + FP_antar_kelas)
prec_class_wajah = (tp_wajah / (tp_wajah + fp_cls_wajah)) * 100
prec_class_sleep = (tp_sleep / (tp_sleep + fp_cls_sleep)) * 100
macro_prec_class = (prec_class_wajah + prec_class_sleep) / 2

# D. F1-Score Antar-Kelas
# Rumus: 2 * (Precision * Recall) / (Precision + Recall)
f1_wajah = 2 * (prec_class_wajah * recall_wajah) / (prec_class_wajah + recall_wajah)
f1_sleep = 2 * (prec_class_sleep * recall_sleep) / (prec_class_sleep + recall_sleep)
macro_f1 = (f1_wajah + f1_sleep) / 2

# E. Precision Deteksi Objek Total (Termasuk False Alarm Latar Belakang)
prec_det_wajah = (tp_wajah / (tp_wajah + fp_cls_wajah + fp_bg_wajah)) * 100
prec_det_sleep = (tp_sleep / (tp_sleep + fp_cls_sleep + fp_bg_sleep)) * 100

# -------------------------------------------------------------
# 3. OUTPUT LAPORAN EVALUASI
# -------------------------------------------------------------
def cetak_laporan():
    print("=" * 65)
    print("     LAPORAN EVALUASI MODEL DETEKSI PERILAKU SISWA (EDUSENSE)")
    print("=" * 65)
    print(f"Total Sampel Uji Asli (Ground Truth) : {total_ground_truth} objek")
    print(f"  - Sampel Wajah (Memperhatikan)     : {total_true_wajah} objek")
    print(f"  - Sampel Head Down (Tertidur)      : {total_true_sleep} objek")
    print(f"Total Prediksi Benar                 : {total_correct} objek")
    print(f"Total Prediksi Salah                 : {total_ground_truth - total_correct} objek")
    print("-" * 65)
    print(f"👉 AKURASI KLASIFIKASI MODEL (ACCURACY) : {accuracy:.2f}%")
    print("=" * 65)

    print("\n[A] TABEL METRIK EVALUASI PERILAKU SISWA (INTER-CLASS):")
    df_inter = pd.DataFrame({
        "Kelas": ["wajah (Memperhatikan)", "head_down (Tertidur)", "Rata-Rata (Macro Avg)"],
        "Precision (%)": [f"{prec_class_wajah:.2f}%", f"{prec_class_sleep:.2f}%", f"{macro_prec_class:.2f}%"],
        "Recall (%)":    [f"{recall_wajah:.2f}%", f"{recall_sleep:.2f}%", f"{macro_recall:.2f}%"],
        "F1-Score (%)":  [f"{f1_wajah:.2f}%", f"{f1_sleep:.2f}%", f"{macro_f1:.2f}%"]
    })
    print(df_inter.to_string(index=False))

    print("\n" + "-" * 65)
    print("[B] METRIK DETEKSI OBJEK TOTAL (TERMASUK BACKGROUND):")
    df_det = pd.DataFrame({
        "Kelas": ["wajah", "head_down"],
        "True Positive (Benar)": [tp_wajah, tp_sleep],
        "False Positive (Background)": [fp_bg_wajah, fp_bg_sleep],
        "Object Precision (%)": [f"{prec_det_wajah:.2f}%", f"{prec_det_sleep:.2f}%"]
    })
    print(df_det.to_string(index=False))
    print("=" * 65)


if __name__ == "__main__":
    cetak_laporan()