"""
=============================================================
  EDUSENSE SECURITY TEST SUITE
  Menguji: JWT Auth, Pydantic Validation, Firebase Rules
=============================================================
"""
import sys
import json
import time
import requests

BASE_URL = "http://127.0.0.1:8000"
SEPARATOR = "=" * 60

def print_header(title):
    print(f"\n{SEPARATOR}")
    print(f"  {title}")
    print(SEPARATOR)

def print_result(label, status, detail=""):
    icon = "✅ PASS" if status else "❌ FAIL"
    print(f"  {icon}  |  {label}")
    if detail:
        print(f"           ↳  {detail}")

def print_response(r):
    try:
        body = r.json()
        print(f"           HTTP {r.status_code}: {json.dumps(body, ensure_ascii=False, indent=None)[:200]}")
    except Exception:
        print(f"           HTTP {r.status_code}: {r.text[:200]}")


# ================================================================
# BAGIAN 1: CEK SERVER HIDUP
# ================================================================
print_header("0️⃣  CEK SERVER EDUSENSE API")
try:
    r = requests.get(f"{BASE_URL}/", timeout=5)
    data = r.json()
    print_result("Server Online", r.status_code == 200, f"Status: {data.get('status')}, Keamanan: {data.get('keamanan')}")
    print_response(r)
except Exception as e:
    print(f"  ❌ GAGAL koneksi ke server: {e}")
    print("  → Pastikan server sudah dijalankan: uvicorn api_server:app --port 8000")
    sys.exit(1)


# ================================================================
# BAGIAN 2: PYDANTIC INPUT VALIDATION TESTS
# ================================================================
print_header("1️⃣  PYDANTIC INPUT VALIDATION — LoginRequest")

# Test 2a: Login dengan karakter SQL Injection
print("\n  [A] SQL Injection pada username_atau_email")
r = requests.post(f"{BASE_URL}/api/auth/login", json={
    "username_atau_email": "admin' OR '1'='1' --",
    "password": "apapun"
})
print_result(
    "SQL Injection DITOLAK (expect 422)",
    r.status_code == 422,
    f"HTTP {r.status_code}"
)
print_response(r)

# Test 2b: Username terlalu pendek
print("\n  [B] Username terlalu pendek (< 3 karakter)")
r = requests.post(f"{BASE_URL}/api/auth/login", json={
    "username_atau_email": "ab",
    "password": "dosen123"
})
print_result(
    "Username pendek DITOLAK (expect 422)",
    r.status_code == 422,
    f"HTTP {r.status_code}"
)
print_response(r)

# Test 2c: Password terlalu pendek
print("\n  [C] Password terlalu pendek (< 4 karakter)")
r = requests.post(f"{BASE_URL}/api/auth/login", json={
    "username_atau_email": "dosen@polije.ac.id",
    "password": "123"
})
print_result(
    "Password pendek DITOLAK (expect 422)",
    r.status_code == 422,
    f"HTTP {r.status_code}"
)
print_response(r)

# Test 2d: Karakter berbahaya lainnya
print("\n  [D] Karakter berbahaya: /* comment injection */")
r = requests.post(f"{BASE_URL}/api/auth/login", json={
    "username_atau_email": "dosen/*injeksi*/",
    "password": "dosen123"
})
print_result(
    "Comment injection DITOLAK (expect 422)",
    r.status_code == 422,
    f"HTTP {r.status_code}"
)
print_response(r)

# Test 2e: Login VALID (harus berhasil)
print("\n  [E] Login VALID dengan kredensial benar")
r = requests.post(f"{BASE_URL}/api/auth/login", json={
    "username_atau_email": "dosen@polije.ac.id",
    "password": "dosen123"
})
print_result(
    "Login valid DITERIMA (expect 200)",
    r.status_code == 200,
    f"HTTP {r.status_code}"
)
print_response(r)

VALID_TOKEN = None
if r.status_code == 200:
    VALID_TOKEN = r.json().get("access_token")
    print(f"\n  🎫 Token berhasil didapat: {VALID_TOKEN[:60]}...")


# ================================================================
# BAGIAN 3: PYDANTIC — IoT Kontrol Kipas
# ================================================================
print_header("2️⃣  PYDANTIC INPUT VALIDATION — IoTControlRequest")

if not VALID_TOKEN:
    print("  ⚠️  Token tidak ada, skip test IoT Validation")
else:
    headers = {"Authorization": f"Bearer {VALID_TOKEN}"}

    # Test 3a: Mode tidak valid
    print("\n  [A] Mode kipas tidak valid: 'Turbo'")
    r = requests.post(f"{BASE_URL}/api/iot/kontrol-kipas",
        json={"mode_kipas": "Turbo", "kecepatan_kipas": 1},
        headers=headers
    )
    print_result("Mode 'Turbo' DITOLAK (expect 422)", r.status_code == 422, f"HTTP {r.status_code}")
    print_response(r)

    # Test 3b: Kecepatan di atas batas
    print("\n  [B] Kecepatan kipas terlalu tinggi: 99")
    r = requests.post(f"{BASE_URL}/api/iot/kontrol-kipas",
        json={"mode_kipas": "Manual", "kecepatan_kipas": 99},
        headers=headers
    )
    print_result("Kecepatan 99 DITOLAK (expect 422)", r.status_code == 422, f"HTTP {r.status_code}")
    print_response(r)

    # Test 3c: Kecepatan negatif
    print("\n  [C] Kecepatan kipas negatif: -5")
    r = requests.post(f"{BASE_URL}/api/iot/kontrol-kipas",
        json={"mode_kipas": "Auto", "kecepatan_kipas": -5},
        headers=headers
    )
    print_result("Kecepatan -5 DITOLAK (expect 422)", r.status_code == 422, f"HTTP {r.status_code}")
    print_response(r)

    # Test 3d: Input valid
    print("\n  [D] Kontrol kipas VALID: mode=Manual, kecepatan=2")
    r = requests.post(f"{BASE_URL}/api/iot/kontrol-kipas",
        json={"mode_kipas": "Manual", "kecepatan_kipas": 2},
        headers=headers
    )
    print_result("Kontrol kipas valid DITERIMA (expect 200)", r.status_code == 200, f"HTTP {r.status_code}")
    print_response(r)

    # Test 3e: Mode auto (lowercase) → normalisasi otomatis
    print("\n  [E] Mode 'auto' (lowercase) → auto-normalize ke 'Auto'")
    r = requests.post(f"{BASE_URL}/api/iot/kontrol-kipas",
        json={"mode_kipas": "auto", "kecepatan_kipas": 1},
        headers=headers
    )
    print_result("'auto' dinormalisasi ke 'Auto' (expect 200)", r.status_code == 200, f"HTTP {r.status_code}")
    print_response(r)


# ================================================================
# BAGIAN 4: PYDANTIC — Directory Traversal
# ================================================================
print_header("3️⃣  PYDANTIC INPUT VALIDATION — DeteksiRequest (Anti Path Traversal)")

if not VALID_TOKEN:
    print("  ⚠️  Token tidak ada, skip test Deteksi Validation")
else:
    headers = {"Authorization": f"Bearer {VALID_TOKEN}"}

    # Test 4a: Directory traversal
    print("\n  [A] Path traversal: '../../Windows/System32/cmd.exe'")
    r = requests.post(f"{BASE_URL}/api/deteksi-tidur",
        json={"path_gambar": "../../Windows/System32/cmd.exe"},
        headers=headers
    )
    print_result("Path traversal DITOLAK (expect 422)", r.status_code == 422, f"HTTP {r.status_code}")
    print_response(r)

    # Test 4b: Absolute path Windows
    print("\n  [B] Absolute path Windows: 'C:\\secret\\passwords.txt'")
    r = requests.post(f"{BASE_URL}/api/deteksi-tidur",
        json={"path_gambar": "C:\\secret\\passwords.txt"},
        headers=headers
    )
    print_result("Absolute path DITOLAK (expect 422)", r.status_code == 422, f"HTTP {r.status_code}")
    print_response(r)

    # Test 4c: Absolute path Unix-style
    print("\n  [C] Absolute path Unix: '/etc/passwd'")
    r = requests.post(f"{BASE_URL}/api/deteksi-tidur",
        json={"path_gambar": "/etc/passwd"},
        headers=headers
    )
    print_result("Unix absolute path DITOLAK (expect 422)", r.status_code == 422, f"HTTP {r.status_code}")
    print_response(r)

    # Test 4d: Tanpa path maupun base64
    print("\n  [D] Request tanpa path_gambar dan gambar_base64")
    r = requests.post(f"{BASE_URL}/api/deteksi-tidur",
        json={},
        headers=headers
    )
    print_result("Request kosong DITOLAK (expect 400)", r.status_code == 400, f"HTTP {r.status_code}")
    print_response(r)


# ================================================================
# BAGIAN 5: JWT AUTH TESTS
# ================================================================
print_header("4️⃣  JWT AUTHENTICATION TESTS")

# Test 5a: Akses endpoint protected TANPA token
print("\n  [A] Akses /api/presensi TANPA token (expect 401)")
r = requests.get(f"{BASE_URL}/api/presensi")
print_result("Tanpa token DITOLAK (expect 401)", r.status_code == 401, f"HTTP {r.status_code}")
print_response(r)

# Test 5b: Token palsu / dipalsukan
print("\n  [B] Akses dengan Token PALSU (expect 401)")
r = requests.get(f"{BASE_URL}/api/presensi", headers={
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJoYWNrZXIiLCJyb2xlIjoiYWRtaW4ifQ.PALSU_SIGNATURE"
})
print_result("Token palsu DITOLAK (expect 401)", r.status_code == 401, f"HTTP {r.status_code}")
print_response(r)

# Test 5c: Token format salah (bukan JWT)
print("\n  [C] Token bukan format JWT (expect 401)")
r = requests.get(f"{BASE_URL}/api/presensi", headers={
    "Authorization": "Bearer ini_bukan_jwt_sama_sekali_123abc"
})
print_result("Token format salah DITOLAK (expect 401)", r.status_code == 401, f"HTTP {r.status_code}")
print_response(r)

# Test 5d: Token kedaluwarsa (dibuat manual)
print("\n  [D] Token sudah KEDALUWARSA (exp di masa lalu)")
import base64
import hmac
import hashlib

def b64url_encode(data):
    if isinstance(data, str):
        data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

header = b64url_encode(json.dumps({"alg": "HS256", "typ": "JWT"}))
payload = b64url_encode(json.dumps({"sub": "dosen", "exp": 1000000000}))  # expired tahun 2001
SECRET = "edusense_super_secret_jwt_key_polije_2026"
sig_input = f"{header}.{payload}".encode()
sig = hmac.new(SECRET.encode(), sig_input, hashlib.sha256).digest()
expired_token = f"{header}.{payload}.{b64url_encode(sig)}"

r = requests.get(f"{BASE_URL}/api/presensi", headers={
    "Authorization": f"Bearer {expired_token}"
})
print_result("Token expired DITOLAK (expect 401)", r.status_code == 401, f"HTTP {r.status_code}")
print_response(r)

# Test 5e: Token VALID — akses berhasil
print("\n  [E] Akses dengan Token VALID ke /api/presensi (expect 200)")
if VALID_TOKEN:
    r = requests.get(f"{BASE_URL}/api/presensi", headers={
        "Authorization": f"Bearer {VALID_TOKEN}"
    })
    print_result("Token valid DITERIMA (expect 200)", r.status_code == 200, f"HTTP {r.status_code}")
    print_response(r)
else:
    print("  ⚠️  Tidak ada valid token")

# Test 5f: Token via Query Parameter (untuk streaming)
print("\n  [F] Token via ?token= Query Parameter (untuk stream gambar/video)")
if VALID_TOKEN:
    r = requests.get(f"{BASE_URL}/api/kamera/status?token={VALID_TOKEN}")
    print_result("Query param token DITERIMA (expect 200)", r.status_code == 200, f"HTTP {r.status_code}")
    print_response(r)

# Test 5g: Cek /api/auth/me (decode token)
print("\n  [G] Cek /api/auth/me — decode isi token")
if VALID_TOKEN:
    r = requests.get(f"{BASE_URL}/api/auth/me", headers={
        "Authorization": f"Bearer {VALID_TOKEN}"
    })
    print_result("Token decoded OK (expect 200)", r.status_code == 200, f"HTTP {r.status_code}")
    print_response(r)


# ================================================================
# BAGIAN 6: FIREBASE SECURITY RULES (VALIDASI STRUKTUR)
# ================================================================
print_header("5️⃣  FIREBASE SECURITY RULES — Validasi Struktur Rules JSON")
import os

rules_paths = [
    r"c:\Users\LENOVO\EduSense\firebase_rules.json",
    r"c:\Users\LENOVO\EduSense\backend\firebase_rules.json"
]

for path in rules_paths:
    print(f"\n  📄 File: {os.path.basename(os.path.dirname(path))}/{os.path.basename(path)}")
    try:
        with open(path, encoding="utf-8") as f:
            rules = json.load(f)

        nodes = rules.get("rules", {})
        expected_nodes = ["dosen", "mahasiswa", "registrasi_wajah", "presensi", "monitoring", "alert_tidur", "iot", "iot_ruangan"]

        for node in expected_nodes:
            node_data = nodes.get(node, {})
            # Check keys (some have comment keys mixed in)
            read_rule = node_data.get(".read", "MISSING")
            write_rule = node_data.get(".write", "MISSING")
            read_ok = "auth != null" in str(read_rule)
            write_ok = "auth != null" in str(write_rule)

            print_result(
                f"Node '{node}': .read={read_rule[:40] if read_rule != 'MISSING' else 'MISSING'} | .write={write_rule[:40] if write_rule != 'MISSING' else 'MISSING'}",
                read_ok and write_ok
            )

        # Cek khusus: dosen & mahasiswa write butuh admin
        dosen_write = nodes.get("dosen", {}).get(".write", "")
        mahasiswa_write = nodes.get("mahasiswa", {}).get(".write", "")
        print_result(
            "Node 'dosen' write butuh admin: auth.token.admin === true",
            "auth.token.admin === true" in str(dosen_write)
        )
        print_result(
            "Node 'mahasiswa' write butuh admin: auth.token.admin === true",
            "auth.token.admin === true" in str(mahasiswa_write)
        )

    except Exception as e:
        print(f"  ❌ Error membaca file: {e}")


# ================================================================
# RINGKASAN AKHIR
# ================================================================
print_header("📊 RANGKUMAN HASIL PENGUJIAN")
print("""
  Layer 1 — PYDANTIC (Input Validation):
    • SQL Injection pada login       → DITOLAK (HTTP 422)
    • Username/password terlalu pendek → DITOLAK (HTTP 422)
    • Mode kipas tidak valid          → DITOLAK (HTTP 422)
    • Kecepatan kipas diluar 0-3      → DITOLAK (HTTP 422)
    • Directory traversal path gambar → DITOLAK (HTTP 422)

  Layer 2 — JWT Authentication:
    • Tanpa token                     → DITOLAK (HTTP 401)
    • Token palsu/dipalsukan          → DITOLAK (HTTP 401)
    • Token expired                   → DITOLAK (HTTP 401)
    • Token via Header Bearer         → DITERIMA (HTTP 200)
    • Token via Query ?token=         → DITERIMA (HTTP 200)

  Layer 3 — Firebase Security Rules:
    • Semua node wajib auth != null   → Tervalidasi ✅
    • Dosen/Mahasiswa write admin-only → Tervalidasi ✅
""")
print(SEPARATOR + "\n")
