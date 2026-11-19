import os
import time
from datetime import datetime, timedelta, timezone
from typing import Optional
import jwt
from fastapi import Depends, HTTPException, status, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

# ==============================================================================
# KONFIGURASI JWT (JSON WEB TOKEN)
# ==============================================================================
# Kunci rahasia untuk menandatangani (sign) token agar tidak bisa dipalsukan.
# Pada lingkungan produksi, ubah atau set via environment variable: EDUSENSE_JWT_SECRET
SECRET_KEY = os.environ.get("EDUSENSE_JWT_SECRET", "edusense_super_secret_jwt_key_polije_2026")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # Token aktif selama 24 jam

# Skema Bearer Token untuk integrasi Swagger UI (/docs)
security_bearer = HTTPBearer(auto_error=False)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Membuat JWT token terenkripsi berdasarkan data identitas user (payload).
    
    Cara Kerja:
    1. Menyalin data user (misal: sub, email, role).
    2. Menambahkan waktu kedaluwarsa (exp).
    3. Mengunci dan menandatangani (sign) payload dengan SECRET_KEY menggunakan algoritma HS256.
    """
    to_encode = data.copy()
    now = datetime.now(timezone.utc)
    
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        
    to_encode.update({
        "exp": expire,
        "iat": now  # Issued at (waktu pembuatan token)
    })
    
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def verify_token(token: str) -> dict:
    """
    Memverifikasi keabsahan JWT token.
    
    Mengembalikan payload token jika valid, atau melempar HTTPException 401 jika:
    - Token sudah kedaluwarsa (ExpiredSignatureError).
    - Token tidak valid atau dimanipulasi (InvalidTokenError).
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token telah kedaluwarsa. Silakan login kembali.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tidak valid atau tanda tangan digital salah.",
            headers={"WWW-Authenticate": "Bearer"},
        )


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    token_query: Optional[str] = Query(None, alias="token", description="Token cadangan via query string (opsional)")
) -> dict:
    """
    Dependency FastAPI untuk mengamankan endpoint.
    
    Mendukung 2 cara pengiriman token:
    1. Melalui Header Authorization: "Bearer <token>" (Standar REST API)
    2. Melalui Query Parameter: "?token=<token>" (Sangat berguna untuk akses stream video/CCTV di browser/tag HTML)
    
    Jika token tidak disertakan atau tidak valid -> akses ditolak (HTTP 401).
    """
    raw_token = None
    if credentials:
        raw_token = credentials.credentials
    elif token_query:
        raw_token = token_query

    if not raw_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Akses ditolak: Memerlukan autentikasi. Silakan sertakan Bearer Token di Header Authorization atau parameter ?token=...",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = verify_token(raw_token)
    return payload
