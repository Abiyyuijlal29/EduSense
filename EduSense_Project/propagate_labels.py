import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FOLDER_GAMBAR = os.path.join(BASE_DIR, 'dataset_cctv_tersaring')

# Definisi 8 rentang skenario berdasarkan urutan pengambilan dari dataset_cctv_mentah
SCENARIOS = [
    {
        "id": 1,
        "nama": "Abi memperhatikan",
        "kelas_target": "0 (wajah)",
        "start": 1,
        "end": 105,
        "default_template": "cctv_0050.txt"
    },
    {
        "id": 2,
        "nama": "Abi tertidur",
        "kelas_target": "1 (head_down)",
        "start": 106,
        "end": 207,
        "default_template": "cctv_0150.txt"
    },
    {
        "id": 3,
        "nama": "Adel memperhatikan",
        "kelas_target": "0 (wajah)",
        "start": 208,
        "end": 263,
        "default_template": "cctv_0230.txt"
    },
    {
        "id": 4,
        "nama": "Adel tertidur",
        "kelas_target": "1 (head_down)",
        "start": 264,
        "end": 374,
        "default_template": "cctv_0300.txt"
    },
    {
        "id": 5,
        "nama": "Akbar memperhatikan",
        "kelas_target": "0 (wajah)",
        "start": 375,
        "end": 450,
        "default_template": "cctv_0400.txt"
    },
    {
        "id": 6,
        "nama": "Akbar tertidur",
        "kelas_target": "1 (head_down)",
        "start": 451,
        "end": 551,
        "default_template": "cctv_0500.txt"
    },
    {
        "id": 7,
        "nama": "Dheni memperhatikan",
        "kelas_target": "0 (wajah)",
        "start": 552,
        "end": 615,
        "default_template": "cctv_0580.txt"
    },
    {
        "id": 8,
        "nama": "Dheni tertidur",
        "kelas_target": "1 (head_down)",
        "start": 616,
        "end": 716,
        "default_template": "cctv_0660.txt"
    }
]


def find_valid_template(sc):
    """
    Mencari file template yang sudah berisi label.
    Prioritas: default_template. Jika kosong, cari file lain dalam rentang yang tidak kosong.
    """
    default_path = os.path.join(FOLDER_GAMBAR, sc["default_template"])
    if os.path.exists(default_path):
        with open(default_path, "r", encoding="utf-8") as f:
            content = f.read().strip()
        if content:
            return sc["default_template"], content

    # Cari alternatif jika default belum diisi
    for i in range(sc["start"], sc["end"] + 1):
        txt_name = f"cctv_{i:04d}.txt"
        txt_path = os.path.join(FOLDER_GAMBAR, txt_name)
        if os.path.exists(txt_path):
            with open(txt_path, "r", encoding="utf-8") as f:
                content = f.read().strip()
            if content:
                return txt_name, content

    return None, None


def main():
    print("=" * 70)
    print("  SKRIP PROPAGASI LABEL YOLO - EduSense")
    print("=" * 70)

    if not os.path.exists(FOLDER_GAMBAR):
        print(f"[ERROR] Folder tidak ditemukan: {FOLDER_GAMBAR}")
        return

    siap_diproses = True
    template_data = {}

    print("\n[1] Memeriksa ketersediaan label template untuk 8 skenario:\n")
    for sc in SCENARIOS:
        template_file, content = find_valid_template(sc)
        rentang_str = f"cctv_{sc['start']:04d} - cctv_{sc['end']:04d}"
        
        if template_file:
            baris = [b for b in content.splitlines() if b.strip()]
            print(f"  [OK] Skenario {sc['id']}: {sc['nama']} ({rentang_str})")
            print(f"       -> Template ditemukan: {template_file} ({len(baris)} bounding box)")
            template_data[sc["id"]] = content
        else:
            print(f"  [BELUM ADA] Skenario {sc['id']}: {sc['nama']} ({rentang_str})")
            print(f"              -> Silakan beri label pada file: {sc['default_template']} (Kelas: {sc['kelas_target']})")
            siap_diproses = False

    if not siap_diproses:
        print("\n" + "=" * 70)
        print("[PERINGATAN] Ada skenario yang belum memiliki label template.")
        print("Silakan buka aplikasi LabelImg, buka folder 'dataset_cctv_tersaring',")
        print("lalu beri label pada file template yang bertanda [BELUM ADA] di atas.")
        print("Setelah disimpan di LabelImg, jalankan kembali skrip ini.")
        print("=" * 70)
        return

    print("\n[2] Semua 8 template terdeteksi! Memulai propagasi ke seluruh 716 file...\n")
    total_diperbarui = 0

    for sc in SCENARIOS:
        content_to_apply = template_data[sc["id"]]
        if not content_to_apply.endswith("\n"):
            content_to_apply += "\n"

        jumlah_rentang = sc["end"] - sc["start"] + 1
        for i in range(sc["start"], sc["end"] + 1):
            txt_name = f"cctv_{i:04d}.txt"
            txt_path = os.path.join(FOLDER_GAMBAR, txt_name)

            with open(txt_path, "w", encoding="utf-8") as f:
                f.write(content_to_apply)

            total_diperbarui += 1

        print(f"  -> Skenario {sc['id']} ({sc['nama']}): {jumlah_rentang} file berhasil dilabeli.")

    print("\n" + "=" * 70)
    print(f"[SELESAI] Total {total_diperbarui} file .txt telah berhasil dipropagasi!")
    print("\nLangkah selanjutnya:")
    print("1. Jalankan 'python split_data.py' untuk memperbarui folder dataset_yolo_tidur.")
    print("2. Dataset Anda kini 100% lengkap dan siap dilatih di Google Colab.")
    print("=" * 70)


if __name__ == "__main__":
    main()
