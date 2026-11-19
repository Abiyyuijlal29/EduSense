"""
Model Validasi Input Menggunakan Pydantic (v2)
Melindungi API dari data kosong, tipe data salah, batas nilai ilegal, dan injeksi karakter berbahaya.
"""
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


class DataDosen(BaseModel):
    nip: str
    nama: str
    email: str
    program_studi: str
    mata_kuliah: str
    kelas_aktif: str


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
