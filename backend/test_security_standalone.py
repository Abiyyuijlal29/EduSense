"""
=============================================================
  EDUSENSE SECURITY TEST SUITE (Standalone — No Server)
  Menguji langsung: Pydantic Validation & JWT Auth
  tanpa perlu server HTTP berjalan.
=============================================================
"""
import sys
import os
import json
import hmac
import hashlib
import base64
import time

# Tambahkan path project ke sys.path
sys.path.insert(0, r"c:\Users\LENOVO\EduSense\backend")

SEPARATOR = "=" * 62
PASS_COUNT = 0
FAIL_COUNT = 0

def print_header(title):
    print(f"\n{SEPARATOR}")
    print(f"  {title}")
    print(SEPARATOR)

def check(label, kondisi, detail="", expect=""):
    global PASS_COUNT, FAIL_COUNT
    icon = "✅ PASS" if kondisi else "❌ FAIL"
    if kondisi:
        PASS_COUNT += 1
    else:
        FAIL_COUNT += 1
    exp_str = f" [expect: {expect}]" if expect else ""
    print(f"  {icon}  {label}{exp_str}")
    if detail:
        print(f"           ↳ {detail}")


# ================================================================
# IMPORT MODUL EDUSENSE
# ================================================================
print_header("⚙️  MEMUAT MODUL EDUSENSE")
try:
    from security.auth import create_access_token, verify_token, get_current_user, SECRET_KEY, ALGORITHM
    check("Import security.auth (JWT)", True, "create_access_token, verify_token, get_current_user")
except Exception as e:
    check("Import security.auth", False, str(e))
    sys.exit(1)

try:
    from schemas.schemas import LoginRequest, IoTControlRequest, DeteksiRequest
    from pydantic import ValidationError
    check("Import schemas.schemas (Pydantic)", True, "LoginRequest, IoTControlRequest, DeteksiRequest")
except Exception as e:
    check("Import schemas.schemas", False, str(e))
    sys.exit(1)


# ================================================================
# BAGIAN 1: PYDANTIC — LoginRequest
# ================================================================
print_header("1️⃣  PYDANTIC — LoginRequest (Login Dosen)")

# 1a: SQL Injection
print("\n  🧪 Test A: SQL Injection pada username")
try:
    LoginRequest(username_atau_email="admin' OR '1'='1' --", password="dosen123")
    check("SQL Injection DITOLAK", False, "Seharusnya ValidationError!", "raise ValidationError")
except ValidationError as e:
    errs = e.errors()
    msg = errs[0]["msg"] if errs else str(e)
    check("SQL Injection DITOLAK ✔", True, f"ValidationError: {msg}")

# 1b: Double quote injection
print("\n  🧪 Test B: Double-quote injection")
try:
    LoginRequest(username_atau_email='dosen"DROP TABLE dosen--', password="pass1234")
    check('Double-quote injection DITOLAK', False, "Seharusnya ValidationError!")
except ValidationError as e:
    check('Double-quote injection DITOLAK ✔', True, f"ValidationError: {e.errors()[0]['msg']}")

# 1c: Comment injection /**/
print("\n  🧪 Test C: Comment injection /* */")
try:
    LoginRequest(username_atau_email="user/*inject*/", password="pass1234")
    check("Comment injection DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Comment injection DITOLAK ✔", True, f"ValidationError: {e.errors()[0]['msg']}")

# 1d: Username terlalu pendek
print("\n  🧪 Test D: Username terlalu pendek (< 3 karakter)")
try:
    LoginRequest(username_atau_email="ab", password="dosen123")
    check("Username pendek DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Username pendek DITOLAK ✔", True, f"min_length=3 ditegakkan: {e.errors()[0]['msg']}")

# 1e: Password terlalu pendek
print("\n  🧪 Test E: Password terlalu pendek (< 4 karakter)")
try:
    LoginRequest(username_atau_email="dosen@polije.ac.id", password="123")
    check("Password pendek DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Password pendek DITOLAK ✔", True, f"min_length=4 ditegakkan: {e.errors()[0]['msg']}")

# 1f: Username hanya spasi
print("\n  🧪 Test F: Username hanya spasi kosong")
try:
    LoginRequest(username_atau_email="   ", password="dosen123")
    check("Username spasi DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Username spasi DITOLAK ✔", True, f"ValidationError: {e.errors()[0]['msg']}")

# 1g: Input VALID
print("\n  🧪 Test G: Input login VALID")
try:
    req = LoginRequest(username_atau_email="dosen@polije.ac.id", password="dosen123")
    check("Input valid DITERIMA ✔", True, f"username='{req.username_atau_email}', password='{req.password}'")
except ValidationError as e:
    check("Input valid DITERIMA", False, str(e))

# 1h: Whitespace di-strip otomatis
print("\n  🧪 Test H: Username dengan whitespace → auto-strip")
try:
    req = LoginRequest(username_atau_email="  dosen@polije.ac.id  ", password="dosen123")
    stripped = req.username_atau_email
    check("Whitespace di-strip otomatis ✔", stripped == "dosen@polije.ac.id", f"Hasil: '{stripped}'")
except ValidationError as e:
    check("Whitespace di-strip", False, str(e))


# ================================================================
# BAGIAN 2: PYDANTIC — IoTControlRequest
# ================================================================
print_header("2️⃣  PYDANTIC — IoTControlRequest (Kontrol Kipas IoT)")

# 2a: Mode tidak valid
print("\n  🧪 Test A: Mode kipas tidak valid: 'Turbo'")
try:
    IoTControlRequest(mode_kipas="Turbo", kecepatan_kipas=1)
    check("Mode 'Turbo' DITOLAK", False, "Seharusnya ValidationError!")
except (ValidationError, Exception) as e:
    check("Mode 'Turbo' DITOLAK ✔", True, f"Error: {str(e)[:80]}")

# 2b: Mode tidak valid: "Mati"
print("\n  🧪 Test B: Mode kipas tidak valid: 'Mati'")
try:
    IoTControlRequest(mode_kipas="Mati", kecepatan_kipas=0)
    check("Mode 'Mati' DITOLAK", False, "Seharusnya ValidationError!")
except (ValidationError, Exception) as e:
    check("Mode 'Mati' DITOLAK ✔", True, f"Error: {str(e)[:80]}")

# 2c: Kecepatan di atas batas
print("\n  🧪 Test C: Kecepatan = 99 (di atas batas le=3)")
try:
    IoTControlRequest(mode_kipas="Manual", kecepatan_kipas=99)
    check("Kecepatan 99 DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Kecepatan 99 DITOLAK ✔", True, f"le=3 ditegakkan: {e.errors()[0]['msg']}")

# 2d: Kecepatan negatif
print("\n  🧪 Test D: Kecepatan = -5 (di bawah batas ge=0)")
try:
    IoTControlRequest(mode_kipas="Auto", kecepatan_kipas=-5)
    check("Kecepatan -5 DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Kecepatan -5 DITOLAK ✔", True, f"ge=0 ditegakkan: {e.errors()[0]['msg']}")

# 2e: Mode 'auto' lowercase → auto-capitalize
print("\n  🧪 Test E: Mode 'auto' (lowercase) → auto-normalize ke 'Auto'")
try:
    req = IoTControlRequest(mode_kipas="auto", kecepatan_kipas=1)
    check("'auto' dinormalisasi ke 'Auto' ✔", req.mode_kipas == "Auto", f"Hasil mode: '{req.mode_kipas}'")
except (ValidationError, Exception) as e:
    check("'auto' dinormalisasi ke 'Auto'", False, str(e)[:80])

# 2f: Input VALID
print("\n  🧪 Test F: Input kontrol kipas VALID: Manual, speed=2")
try:
    req = IoTControlRequest(mode_kipas="Manual", kecepatan_kipas=2)
    check("Kontrol kipas valid DITERIMA ✔", True, f"mode='{req.mode_kipas}', kecepatan={req.kecepatan_kipas}")
except ValidationError as e:
    check("Kontrol kipas valid DITERIMA", False, str(e))

# 2g: Kecepatan boundary 0 (mati)
print("\n  🧪 Test G: Kecepatan boundary = 0 (Mati)")
try:
    req = IoTControlRequest(mode_kipas="Manual", kecepatan_kipas=0)
    check("Kecepatan 0 DITERIMA ✔", req.kecepatan_kipas == 0, "Boundary value 0 valid")
except ValidationError as e:
    check("Kecepatan 0 DITERIMA", False, str(e))

# 2h: Kecepatan boundary 3 (tinggi)
print("\n  🧪 Test H: Kecepatan boundary = 3 (Tinggi)")
try:
    req = IoTControlRequest(mode_kipas="Auto", kecepatan_kipas=3)
    check("Kecepatan 3 DITERIMA ✔", req.kecepatan_kipas == 3, "Boundary value 3 valid")
except ValidationError as e:
    check("Kecepatan 3 DITERIMA", False, str(e))


# ================================================================
# BAGIAN 3: PYDANTIC — DeteksiRequest (Anti Path Traversal)
# ================================================================
print_header("3️⃣  PYDANTIC — DeteksiRequest (Anti Directory Traversal)")

# 3a: Path traversal klasik
print("\n  🧪 Test A: Path traversal: '../../Windows/System32/cmd.exe'")
try:
    DeteksiRequest(path_gambar="../../Windows/System32/cmd.exe")
    check("Path traversal DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Path traversal DITOLAK ✔", True, f"ValidationError: {e.errors()[0]['msg']}")

# 3b: Absolute path Unix
print("\n  🧪 Test B: Absolute path Unix: '/etc/passwd'")
try:
    DeteksiRequest(path_gambar="/etc/passwd")
    check("Unix absolute path DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Unix absolute path DITOLAK ✔", True, f"ValidationError: {e.errors()[0]['msg']}")

# 3c: Absolute path Windows (C:\)
print("\n  🧪 Test C: Absolute path Windows: 'C:\\secret\\passwords.txt'")
try:
    DeteksiRequest(path_gambar="C:\\secret\\passwords.txt")
    check("Windows absolute path DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Windows absolute path DITOLAK ✔", True, f"ValidationError: {e.errors()[0]['msg']}")

# 3d: Path traversal tersembunyi
print("\n  🧪 Test D: Path traversal tersembunyi: 'img/../../../etc/shadow'")
try:
    DeteksiRequest(path_gambar="img/../../../etc/shadow")
    check("Path traversal tersembunyi DITOLAK", False, "Seharusnya ValidationError!")
except ValidationError as e:
    check("Path traversal tersembunyi DITOLAK ✔", True, f"ValidationError: {e.errors()[0]['msg']}")

# 3e: Path relatif VALID
print("\n  🧪 Test E: Path relatif valid: 'dataset_cctv_tersaring/cctv_0150.jpg'")
try:
    req = DeteksiRequest(path_gambar="dataset_cctv_tersaring/cctv_0150.jpg")
    check("Path relatif valid DITERIMA ✔", True, f"path='{req.path_gambar}'")
except ValidationError as e:
    check("Path relatif valid DITERIMA", False, str(e))

# 3f: Base64 string VALID
print("\n  🧪 Test F: gambar_base64 string valid")
try:
    req = DeteksiRequest(gambar_base64="/9j/4AAQSkZJRgABAQEASABIAAD/...")
    check("gambar_base64 DITERIMA ✔", True, f"base64 len={len(req.gambar_base64)}")
except ValidationError as e:
    check("gambar_base64 DITERIMA", False, str(e))


# ================================================================
# BAGIAN 4: JWT AUTH TESTS
# ================================================================
print_header("4️⃣  JWT AUTHENTICATION — create_access_token & verify_token")

import jwt as pyjwt
from fastapi import HTTPException

# 4a: Buat token valid
print("\n  🧪 Test A: Buat JWT Token (create_access_token)")
token_valid = None
try:
    token_valid = create_access_token(data={
        "sub": "198501012010121001",
        "email": "dosen@polije.ac.id",
        "nama": "Dr. Ir. Dosen Pengampu, M.Kom.",
        "role": "dosen"
    })
    check("Token dibuat berhasil ✔", isinstance(token_valid, str) and len(token_valid) > 50,
          f"Token (60 char pertama): {token_valid[:60]}...")
except Exception as e:
    check("Token dibuat berhasil", False, str(e))

# 4b: Decode token valid
print("\n  🧪 Test B: Verifikasi token valid (verify_token)")
try:
    payload = verify_token(token_valid)
    check("Token valid DITERIMA ✔", True,
          f"sub={payload.get('sub')}, role={payload.get('role')}, email={payload.get('email')}")
except Exception as e:
    check("Token valid DITERIMA", False, str(e))

# 4c: Token palsu (signature salah)
print("\n  🧪 Test C: Token PALSU (signature dimanipulasi)")
try:
    parts = token_valid.split(".")
    fake_token = parts[0] + "." + parts[1] + ".PALSU_SIGNATURE_XYZ123"
    verify_token(fake_token)
    check("Token palsu DITOLAK", False, "Seharusnya raise HTTPException 401!")
except HTTPException as e:
    check("Token palsu DITOLAK ✔", e.status_code == 401, f"HTTP {e.status_code}: {e.detail}")
except Exception as e:
    check("Token palsu DITOLAK ✔", True, f"Exception: {str(e)[:80]}")

# 4d: Token acak sama sekali
print("\n  🧪 Test D: Token bukan JWT (random string)")
try:
    verify_token("ini_bukan_jwt_1234567890abcdef")
    check("Random string DITOLAK", False, "Seharusnya raise exception!")
except (HTTPException, Exception) as e:
    detail = e.detail if hasattr(e, 'detail') else str(e)
    check("Random string DITOLAK ✔", True, f"Error: {detail[:80]}")

# 4e: Token expired (exp di masa lalu)
print("\n  🧪 Test E: Token KEDALUWARSA (exp = tahun 2001)")
try:
    def b64url_encode(data):
        if isinstance(data, str): data = data.encode()
        return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

    header_enc = b64url_encode(json.dumps({"alg": "HS256", "typ": "JWT"}))
    payload_enc = b64url_encode(json.dumps({
        "sub": "dosen", "role": "dosen", "exp": 1000000000  # Tahun 2001 (sudah expired)
    }))
    sig_input = f"{header_enc}.{payload_enc}".encode()
    sig = hmac.new(SECRET_KEY.encode(), sig_input, hashlib.sha256).digest()
    expired_token = f"{header_enc}.{payload_enc}.{b64url_encode(sig)}"

    verify_token(expired_token)
    check("Token expired DITOLAK", False, "Seharusnya raise HTTPException 401!")
except HTTPException as e:
    check("Token expired DITOLAK ✔", e.status_code == 401, f"HTTP {e.status_code}: {e.detail}")
except Exception as e:
    check("Token expired DITOLAK ✔", True, f"Exception: {str(e)[:80]}")

# 4f: Token dengan SECRET_KEY berbeda (dipalsukan)
print("\n  🧪 Test F: Token dibuat dengan SECRET_KEY BERBEDA (server lain)")
try:
    fake_token = pyjwt.encode(
        {"sub": "hacker", "role": "admin", "exp": time.time() + 86400},
        "KUNCI_RAHASIA_PALSU_DARI_SERVER_LAIN",
        algorithm="HS256"
    )
    verify_token(fake_token)
    check("Token key lain DITOLAK", False, "Seharusnya raise HTTPException 401!")
except HTTPException as e:
    check("Token key lain DITOLAK ✔", e.status_code == 401, f"HTTP {e.status_code}: {e.detail}")
except Exception as e:
    check("Token key lain DITOLAK ✔", True, f"Exception: {str(e)[:80]}")

# 4g: Cek payload isi token
print("\n  🧪 Test G: Verifikasi isi payload token (sub, role, exp, iat)")
try:
    payload = verify_token(token_valid)
    has_sub = "sub" in payload
    has_role = "role" in payload
    has_exp = "exp" in payload
    has_iat = "iat" in payload
    check("Payload berisi sub, role, exp, iat ✔",
          all([has_sub, has_role, has_exp, has_iat]),
          f"sub={payload.get('sub')}, role={payload.get('role')}, exp ada={has_exp}, iat ada={has_iat}")
except Exception as e:
    check("Payload check", False, str(e))

# 4h: Token bisa dibaca tapi isi role diacak (payload tampering)
print("\n  🧪 Test H: Payload tampering (ganti role jadi 'admin' di base64)")
try:
    parts = token_valid.split(".")
    # Decode payload, ubah role, re-encode, tapi biarkan signature lama
    padding = 4 - len(parts[1]) % 4
    orig_payload = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * padding))
    orig_payload["role"] = "admin"  # Tamper!
    tampered_payload = base64.urlsafe_b64encode(
        json.dumps(orig_payload).encode()
    ).rstrip(b"=").decode()
    tampered_token = f"{parts[0]}.{tampered_payload}.{parts[2]}"  # Signature lama tidak match
    
    verify_token(tampered_token)
    check("Payload tampered DITOLAK", False, "Seharusnya raise exception 401!")
except (HTTPException, Exception) as e:
    detail = e.detail if hasattr(e, 'detail') else str(e)
    check("Payload tampered DITOLAK ✔", True, f"Error: {detail[:80]}")


# ================================================================
# BAGIAN 5: FIREBASE SECURITY RULES — VALIDASI STRUKTUR
# ================================================================
print_header("5️⃣  FIREBASE SECURITY RULES — Validasi Struktur JSON")

rules_paths = [
    r"c:\Users\LENOVO\EduSense\firebase_rules.json",
    r"c:\Users\LENOVO\EduSense\backend\firebase_rules.json"
]

for path in rules_paths:
    fname = os.path.basename(os.path.dirname(path)) + "/" + os.path.basename(path)
    print(f"\n  📄 {fname}")
    try:
        with open(path, encoding="utf-8") as f:
            rules_data = json.load(f)

        nodes = rules_data.get("rules", {})

        # Cek semua node yang diharapkan ada
        expected = ["dosen", "mahasiswa", "registrasi_wajah", "presensi",
                    "monitoring", "alert_tidur", "iot", "iot_ruangan"]

        for node in expected:
            nd = nodes.get(node, {})
            read_rule  = nd.get(".read",  "MISSING")
            write_rule = nd.get(".write", "MISSING")
            read_ok    = "auth != null" in str(read_rule)
            write_ok   = "auth != null" in str(write_rule)

            status_char = "✔" if (read_ok and write_ok) else "✗"
            check(
                f"Node '{node}': .read={'auth!=null' if read_ok else 'MISSING'} | .write={'secured' if write_ok else 'MISSING'}  {status_char}",
                read_ok and write_ok
            )

        # Cek admin-only write untuk dosen & mahasiswa
        dosen_write    = str(nodes.get("dosen", {}).get(".write", ""))
        mahasiswa_write = str(nodes.get("mahasiswa", {}).get(".write", ""))

        check("'dosen' write hanya untuk ADMIN (auth.token.admin===true) ✔",
              "auth.token.admin === true" in dosen_write,
              f"Rule: {dosen_write[:80]}")

        check("'mahasiswa' write hanya untuk ADMIN (auth.token.admin===true) ✔",
              "auth.token.admin === true" in mahasiswa_write,
              f"Rule: {mahasiswa_write[:80]}")

        # Cek prinsip zero public access
        public_nodes = [n for n, v in nodes.items()
                        if not n.startswith("/*") and
                           ("auth != null" not in str(v.get(".read", "")) or
                            "auth != null" not in str(v.get(".write", "")))]
        check("Tidak ada node yang bisa diakses publik (zero public access) ✔",
              len(public_nodes) == 0,
              f"Node tanpa proteksi: {public_nodes if public_nodes else 'Tidak ada ✔'}")

    except FileNotFoundError:
        check(f"File {fname} ditemukan", False, "File tidak ada!")
    except json.JSONDecodeError as e:
        check(f"File {fname} valid JSON", False, str(e))
    except Exception as e:
        check(f"Parse {fname}", False, str(e))


# ================================================================
# RINGKASAN AKHIR
# ================================================================
total = PASS_COUNT + FAIL_COUNT
print(f"""
{SEPARATOR}
  📊 HASIL AKHIR PENGUJIAN KEAMANAN EDUSENSE
{SEPARATOR}
  Total Test  : {total}
  ✅ PASS     : {PASS_COUNT}
  ❌ FAIL     : {FAIL_COUNT}
  Score       : {PASS_COUNT}/{total} ({PASS_COUNT*100//total if total else 0}%)
{SEPARATOR}

  Lapisan yang diuji:
  1. Pydantic (LoginRequest)       — SQL Injection, min/max length, whitespace strip
  2. Pydantic (IoTControlRequest)  — Mode enum, kecepatan range 0-3, normalisasi
  3. Pydantic (DeteksiRequest)     — Directory traversal, absolute path
  4. JWT Auth                      — Token valid, palsu, expired, tampered, wrong key
  5. Firebase Security Rules       — Struktur JSON, auth!=null, admin-only write
{SEPARATOR}
""")
