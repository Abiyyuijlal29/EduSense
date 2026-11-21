"""
Model Validasi Input Menggunakan Pydantic (v2)
Melindungi API dari data kosong, tipe data salah, batas nilai ilegal, dan injeksi karakter berbahaya.
"""
import re
from typing import Optional, Literal
from pydantic import BaseModel, Field, field_validator


# ==============================================================================
# 1. VALIDASI LOGIN DOSEN
# ==============================================================================
class LoginRequest(BaseModel):
    username_atau_email: str = Field(
        ...,
        min_length=3,
        max_length=100,
        description="NIP atau Email resmi dosen (contoh: dosen@polije.ac.id)",
        examples=["dosen@polije.ac.id"]
    )
    password: str = Field(
        ...,
        min_length=4,
        max_length=128,
        description="Kata sandi akun dosen (minimal 4 karakter)",
        examples=["dosen123"]
    )

    @field_validator("username_atau_email")
    @classmethod
    def bersihkan_dan_validasi_username(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Username atau email tidak boleh hanya berisi spasi kosong.")
        
        # Mencegah karakter berbahaya / SQL injection sederhana
        karakter_terlarang = ["'", '"', ";", "--", "/*", "*/"]
        if any(char in cleaned for char in karakter_terlarang):
            raise ValueError("Karakter khusus tidak diizinkan pada username/email.")
            
        return cleaned


# ==============================================================================
# VALIDASI REGISTRASI DOSEN (ATURAN POIN 8)
# ==============================================================================
def validasi_password_poin_8(pwd: str) -> str:
    """
    Validasi Kata Sandi Mengikuti Aturan Prompt 8:
    1. Minimal 8 karakter
    2. Huruf kapital (A-Z)
    3. Huruf kecil (a-z)
    4. Angka (0-9)
    5. Tanpa spasi
    """
    if len(pwd) < 8:
        raise ValueError("Kata sandi minimal 8 karakter.")
    if " " in pwd:
        raise ValueError("Kata sandi tidak boleh mengandung spasi.")
    if not re.search(r"[A-Z]", pwd):
        raise ValueError("Kata sandi harus mengandung minimal satu huruf kapital (A-Z).")
    if not re.search(r"[a-z]", pwd):
        raise ValueError("Kata sandi harus mengandung minimal satu huruf kecil (a-z).")
    if not re.search(r"[0-9]", pwd):
        raise ValueError("Kata sandi harus mengandung minimal satu angka (0-9).")
    return pwd


class RegisterDosenRequest(BaseModel):
    nama: str = Field(..., min_length=3, max_length=120, description="Nama lengkap beserta gelar dosen")
    nip: str = Field(..., description="NIP Dosen tepat 18 digit angka")
    email: str = Field(..., description="Email resmi dosen")
    password: str = Field(..., description="Kata sandi baru sesuai aturan poin 8")

    @field_validator("nip")
    @classmethod
    def validasi_nip(cls, v: str) -> str:
        nip_clean = v.strip()
        if not nip_clean.isdigit():
            raise ValueError("NIP hanya boleh berisi angka.")
        if len(nip_clean) != 18:
            raise ValueError(f"NIP wajib 18 digit angka (diterima {len(nip_clean)} digit).")
        return nip_clean

    @field_validator("email")
    @classmethod
    def validasi_email(cls, v: str) -> str:
        email_clean = v.strip().lower()
        regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(regex, email_clean):
            raise ValueError("Format email tidak valid.")
        return email_clean

    @field_validator("password")
    @classmethod
    def validasi_pwd(cls, v: str) -> str:
        return validasi_password_poin_8(v)


class VerifyOtpRequest(BaseModel):
    email: str = Field(..., description="Email tujuan kode OTP")
    otp: str = Field(..., min_length=6, max_length=6, description="Kode OTP 6 digit angka")

    @field_validator("otp")
    @classmethod
    def validasi_kode_otp(cls, v: str) -> str:
        v_clean = v.strip()
        if not v_clean.isdigit() or len(v_clean) != 6:
            raise ValueError("Kode OTP harus terdiri dari 6 digit angka.")
        return v_clean


class ResendOtpRequest(BaseModel):
    email: str = Field(..., description="Email untuk pengiriman ulang kode OTP")


class ForgotPasswordRequest(BaseModel):
    email: str = Field(..., description="Email akun yang ingin dipulihkan")


class ResetPasswordRequest(BaseModel):
    email: str = Field(..., description="Email akun")
    otp: str = Field(..., min_length=6, max_length=128, description="Kode OTP verifikasi pemulihan")
    new_password: str = Field(..., description="Kata sandi baru sesuai aturan poin 8")

    @field_validator("new_password")
    @classmethod
    def validasi_new_pwd(cls, v: str) -> str:
        return validasi_password_poin_8(v)


class DataDosen(BaseModel):
    nip: str
    nama: str
    email: str
    program_studi: Optional[str] = "Teknik Informatika"
    mata_kuliah: Optional[str] = "Vision AI dan IoT Smart Classroom"
    kelas_aktif: Optional[str] = "TI-2F"
    foto_url: Optional[str] = None


class UpdateProfileRequest(BaseModel):
    nama: str = Field(..., min_length=3, max_length=120, description="Nama lengkap dosen")
    email: str = Field(..., description="Email resmi dosen")
    foto_url: Optional[str] = Field(default=None, description="URL foto profil")

    @field_validator("email")
    @classmethod
    def validasi_email(cls, v: str) -> str:
        email_clean = v.strip().lower()
        regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(regex, email_clean):
            raise ValueError("Format email tidak valid.")
        return email_clean


class ChangePasswordRequest(BaseModel):
    old_password: str = Field(..., min_length=4, description="Kata sandi saat ini")
    new_password: str = Field(..., description="Kata sandi baru sesuai aturan Prompt 8")

    @field_validator("new_password")
    @classmethod
    def validasi_new_pwd(cls, v: str) -> str:
        return validasi_password_poin_8(v)


class TokenResponse(BaseModel):
    status: str = "success"
    pesan: str = "Login Berhasil"
    access_token: str
    token_type: str = "bearer"
    expires_in_hours: int = 24
    data_dosen: DataDosen


# ==============================================================================
# 2. VALIDASI KONTROL IOT KIPAS
# ==============================================================================
class IoTControlRequest(BaseModel):
    mode_kipas: Literal["Auto", "Manual"] = Field(
        ...,
        description="Mode operasi kipas smart classroom: hanya 'Auto' atau 'Manual'"
    )
    kecepatan_kipas: int = Field(
        ...,
        ge=0,
        le=3,
        description="Tingkat kecepatan kipas: 0 (Mati), 1 (Rendah), 2 (Sedang), 3 (Tinggi)"
    )

    @field_validator("mode_kipas", mode="before")
    @classmethod
    def normalisasi_mode(cls, value: str) -> str:
        if isinstance(value, str):
            val_clean = value.strip().capitalize()
            if val_clean in ["Auto", "Manual"]:
                return val_clean
        raise ValueError("Mode kipas hanya boleh 'Auto' atau 'Manual'")


class IoTTelemetryRequest(BaseModel):
    suhu: float = Field(..., ge=-20.0, le=100.0, description="Suhu sensor DHT22 (°C)")
    kelembaban: float = Field(..., ge=0.0, le=100.0, description="Kelembaban sensor DHT22 (%)")
    mode_kipas: Optional[Literal["Auto", "Manual"]] = Field(default="Auto", description="Mode kipas saat ini")
    kecepatan_kipas: Optional[int] = Field(default=None, ge=0, le=3, description="Kecepatan kipas aktual")
    id_perangkat: Optional[str] = Field(default="ESP32_Lab", description="Identitas unik modul IoT")


# ==============================================================================
# 3. VALIDASI INPUT INFERENSI / DETEKSI SISWA
# ==============================================================================
class DeteksiRequest(BaseModel):
    path_gambar: Optional[str] = Field(
        default=None,
        description="Path relatif file gambar uji pada server (contoh: dataset_cctv_tersaring/cctv_0150.jpg)"
    )
    gambar_base64: Optional[str] = Field(
        default=None,
        description="String gambar berformat Base64 jika dikirim langsung dari klien mobile"
    )

    @field_validator("path_gambar")
    @classmethod
    def cegah_directory_traversal(cls, value: Optional[str]) -> Optional[str]:
        if value:
            # Mencegah serangan Directory Traversal (misal: ../../Windows/System32)
            if ".." in value or value.startswith("/") or (len(value) > 1 and value[1] == ":"):
                raise ValueError("Path gambar tidak boleh mengandung traversal '..' atau absolute path sistem.")
        return value
