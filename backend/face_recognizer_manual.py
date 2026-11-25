import os
import cv2
import numpy as np
from typing import Dict, Tuple, Optional, Any

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, ".."))

MODEL_ONNX_PATH = os.path.join(BASE_DIR, "models", "mobilefacenet.onnx")
MODEL_YOLO_PATH = os.path.join(BASE_DIR, "models", "best.pt")
CACHE_CENTROIDS_PATH = os.path.join(BASE_DIR, "models", "face_database_centroids.npz")


class ManualFaceRecognizer:
    """
    Sistem Pengenalan Wajah Presensi Mahasiswa Berbasis
    Deep Metric Learning & Komputasi Aljabar Linier Manual (NumPy).
    
    Pipeline:
    1. Face Detection & Crop: YOLOv8 (best.pt) untuk lokalisasi koordinat wajah.
    2. Feature Extractor: MobileFaceNet (ONNX) 512-dimensi via OpenCV DNN (Tanpa DeepFace).
    3. Normalisasi Vektor: L2-Norm manual pada unit hypersphere.
    4. Database Mahasiswa: Prototype Centroid Vektor per NIM.
    5. Pengenalan Real-Time: Perhitungan Cosine Similarity manual via NumPy dot product.
    """

    def __init__(
        self,
        onnx_model_path: str = MODEL_ONNX_PATH,
        yolo_model_path: str = MODEL_YOLO_PATH
    ):
        if not os.path.exists(onnx_model_path):
            raise FileNotFoundError(
                f"Model MobileFaceNet ONNX tidak ditemukan di: {onnx_model_path}\n"
                "Pastikan file model sudah diunduh ke backend/models/mobilefacenet.onnx"
            )

        print(f"[INIT] Memuat arsitektur MobileFaceNet ONNX dari: {onnx_model_path}")
        self.net = cv2.dnn.readNetFromONNX(onnx_model_path)

        # Inisialisasi detector YOLOv8 untuk pemotongan wajah presisi
        self.yolo_model = None
        if os.path.exists(yolo_model_path):
            try:
                from ultralytics import YOLO
                self.yolo_model = YOLO(yolo_model_path)
                print(f"[INIT] Detektor wajah YOLOv8 dimuat dari: {yolo_model_path}")
            except Exception as e:
                print(f"[WARNING] Gagal memuat YOLOv8 untuk face crop: {e}")

        # Database centroid di memori: {nim: vektor_centroid_512d}
        self.centroids: Dict[str, np.ndarray] = {}
        self.nama_map: Dict[str, str] = {}

        # Muat cache centroid jika ada
        self._load_cache()

    def crop_wajah_yolo(self, img_bgr: np.ndarray) -> np.ndarray:
        """
        Memotong area wajah menggunakan deteksi YOLOv8 agar latar belakang ruangan
        tidak mengganggu ekstraksi fitur wajah.
        """
        if self.yolo_model is None or img_bgr is None:
            return img_bgr

        h, w = img_bgr.shape[:2]
        # Jika gambar sudah berupa potongan kecil (misal crop < 200x200), langsung gunakan
        if w < 220 and h < 220:
            return img_bgr

        try:
            results = self.yolo_model(img_bgr, conf=0.30, imgsz=320, verbose=False)[0]
            for box in results.boxes:
                cls_id = int(box.cls[0])
                label_name = self.yolo_model.names.get(cls_id, "")
                # Deteksi kelas wajah
                if label_name in ["wajah", "person"] or cls_id == 0:
                    x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
                    # Berikan sedikit margin (padding 5%) agar seluruh wajah utuh
                    pad_w = int((x2 - x1) * 0.05)
                    pad_h = int((y2 - y1) * 0.05)
                    x1 = max(0, x1 - pad_w)
                    y1 = max(0, y1 - pad_h)
                    x2 = min(w, x2 + pad_w)
                    y2 = min(h, y2 + pad_h)
                    crop = img_bgr[y1:y2, x1:x2]
                    if crop.size > 0:
                        return crop
        except Exception:
            pass

        return img_bgr

    def ekstraksi_embedding(self, face_img_bgr: np.ndarray, auto_crop: bool = True) -> np.ndarray:
        """
        Mengubah citra wajah menjadi vektor embedding 512 dimensi.
        Termasuk tahap crop, preprocessing, forward pass, dan L2-Normalization manual.
        """
        if auto_crop:
            face_crop = self.crop_wajah_yolo(face_img_bgr)
        else:
            face_crop = face_img_bgr

        # 1. Preprocessing manual: Ubah ukuran ke 112x112 piksel standar MobileFaceNet
        resized = cv2.resize(face_crop, (112, 112))

        # 2. Normalisasi piksel: (I - 127.5) / 128.0 (Rentang [-1.0, 1.0])
        blob = cv2.dnn.blobFromImage(
            resized,
            scalefactor=1.0 / 128.0,
            size=(112, 112),
            mean=(127.5, 127.5, 127.5),
            swapRB=True  # BGR ke RGB
        )

        # 3. Forward pass CNN
        self.net.setInput(blob)
        raw_output = self.net.forward()  # Output shape: (1, 512)
        v = raw_output.flatten().astype(np.float64)

        # 4. RUMUS 1: L2 Normalization manual
        #    v_hat = v / sqrt(sum(v_i ^ 2))
        norm_l2 = np.sqrt(np.sum(v ** 2))
        if norm_l2 == 0:
            return v
        return v / norm_l2

    def bangun_database_mahasiswa(self, force_recompute: bool = False) -> None:
        """
        RUMUS 2: Menghitung Prototype Centroid per Mahasiswa
        c_k = (1 / N) * sum(v_j)
        c_hat = c_k / ||c_k||_2
        """
        if self.centroids and not force_recompute:
            print(f"[INFO] Menggunakan cache centroid tersimpan ({len(self.centroids)} mahasiswa).")
            return

        candidate_dirs = [
            os.path.join(PROJECT_ROOT, "dataset", "dataset_absensi"),
            os.path.join(PROJECT_ROOT, "EduSense_Project", "dataset_absensi"),
            os.path.join(BASE_DIR, "dataset_absensi"),
        ]

        dataset_dir = None
        for d in candidate_dirs:
            if os.path.isdir(d):
                dataset_dir = d
                break

        if not dataset_dir:
            print("[WARNING] Folder dataset_absensi tidak ditemukan!")
            return

        print(f"\n[PROSES] Membangun Vektor Centroid Mahasiswa dari: {dataset_dir}")
        self.centroids.clear()
        self.nama_map.clear()

        for folder in sorted(os.listdir(dataset_dir)):
            folder_path = os.path.join(dataset_dir, folder)
            if not os.path.isdir(folder_path):
                continue

            parts = folder.split("_")
            nim = parts[0]
            nama = " ".join(parts[1:]).replace("_", " ")
            self.nama_map[nim] = nama

            list_embeddings = []
            files = sorted([f for f in os.listdir(folder_path) if f.lower().endswith(('.jpg', '.jpeg', '.png'))])

            # Gunakan hingga 30 sampel foto terbaik
            for fname in files[:30]:
                fpath = os.path.join(folder_path, fname)
                img = cv2.imread(fpath)
                if img is not None:
                    emb = self.ekstraksi_embedding(img, auto_crop=True)
                    list_embeddings.append(emb)

            if list_embeddings:
                # Perhitungan Rata-rata Centroid
                matriks_emb = np.array(list_embeddings)  # Shape: (N, 512)
                centroid = np.mean(matriks_emb, axis=0)

                # L2-Norm ulang
                centroid_norm = centroid / np.sqrt(np.sum(centroid ** 2))
                self.centroids[nim] = centroid_norm

                print(f"  [+] NIM {nim} ({nama}): {len(list_embeddings)} foto wajah berhasil di-crop & dihitung.")

        self._save_cache()
        print(f"[SELESAI] Database centroid siap ({len(self.centroids)} mahasiswa terdaftar).\n")

    def kenali_wajah(
        self,
        face_img_bgr: np.ndarray,
        threshold_cosine: float = 0.40,
        auto_crop: bool = True
    ) -> Dict[str, Any]:
        """
        RUMUS 3: Komputasi Cosine Similarity & Euclidean Distance
        Cosine Similarity: Sim(x, c_k) = dot_product(x_hat, c_hat)
        Euclidean Distance: d_E = sqrt(sum((x_i - c_i)^2))
        """
        if not self.centroids:
            return {
                "dikenal": False,
                "nim": None,
                "nama": "Database Kosong",
                "cosine_sim": 0.0,
                "euclidean_dist": 2.0,
                "status": "Database belum dibangun"
            }

        v_input = self.ekstraksi_embedding(face_img_bgr, auto_crop=auto_crop)

        terbaik_sim = -1.0
        terbaik_nim = None
        terbaik_dist = 2.0

        for nim, v_db in self.centroids.items():
            # Dot Product manual antar-vektor 512 dimensi
            dot_prod = float(np.dot(v_input, v_db))
            euc_dist = float(np.sqrt(np.sum((v_input - v_db) ** 2)))

            if dot_prod > terbaik_sim:
                terbaik_sim = dot_prod
                terbaik_nim = nim
                terbaik_dist = euc_dist

        is_dikenal = terbaik_sim >= threshold_cosine
        nama_hasil = self.nama_map.get(terbaik_nim, terbaik_nim) if is_dikenal else "Wajah Tidak Dikenal"

        return {
            "dikenal": is_dikenal,
            "nim": terbaik_nim if is_dikenal else None,
            "nama": nama_hasil,
            "cosine_sim": round(terbaik_sim, 4),
            "euclidean_dist": round(terbaik_dist, 4),
            "ambang_batas": threshold_cosine
        }

    def _save_cache(self) -> None:
        try:
            np.savez_compressed(
                CACHE_CENTROIDS_PATH,
                nims=list(self.centroids.keys()),
                centroids=list(self.centroids.values()),
                namas=[self.nama_map.get(k, k) for k in self.centroids.keys()]
            )
        except Exception as e:
            print(f"[CACHE] Gagal menyimpan cache centroid: {e}")

    def _load_cache(self) -> None:
        if os.path.exists(CACHE_CENTROIDS_PATH):
            try:
                data = np.load(CACHE_CENTROIDS_PATH, allow_pickle=True)
                nims = data["nims"]
                centroids = data["centroids"]
                namas = data["namas"]
                for i in range(len(nims)):
                    nim = str(nims[i])
                    self.centroids[nim] = centroids[i]
                    self.nama_map[nim] = str(namas[i])
                print(f"[INIT] Berhasil memuat {len(self.centroids)} centroid mahasiswa dari cache.")
            except Exception:
                pass


# Instance singleton global
face_recognizer = ManualFaceRecognizer()


if __name__ == "__main__":
    print("=" * 65)
    print("  UJI COBA SISTEM PENGENALAN WAJAH MANUAL (YOLOv8 + MOBILEFACENET + NUMPY)")
    print("=" * 65)

    face_recognizer.bangun_database_mahasiswa(force_recompute=True)

    test_dir = os.path.join(PROJECT_ROOT, "dataset", "dataset_absensi")
    sample_subfolders = sorted([f for f in os.listdir(test_dir) if os.path.isdir(os.path.join(test_dir, f))])

    print("\n--- PENGUJIAN AKURASI KEMIRIPAN (SELF-TEST RECOGNITION) ---")
    for sub in sample_subfolders:
        sub_path = os.path.join(test_dir, sub)
        sample_photos = sorted([f for f in os.listdir(sub_path) if f.lower().endswith(('.jpg', '.png'))])
        if sample_photos:
            # Gunakan foto kedua untuk menguji generalisasi
            test_img_path = os.path.join(sub_path, sample_photos[min(1, len(sample_photos) - 1)])
            img = cv2.imread(test_img_path)
            hasil = face_recognizer.kenali_wajah(img, threshold_cosine=0.40, auto_crop=True)
            print(f"Foto Uji : {sub[:30]}...")
            print(f"  ↳ Terprediksi : {hasil['nama']} ({hasil['nim']})")
            print(f"  ↳ Cosine Sim  : {hasil['cosine_sim']} (>= 0.40: {'Cocok ✅' if hasil['dikenal'] else 'Gagal ❌'})")
            print(f"  ↳ Euclidean   : {hasil['euclidean_dist']}\n")
    print("=" * 65)
