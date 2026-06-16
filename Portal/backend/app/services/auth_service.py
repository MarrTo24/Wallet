"""
Servicio de autenticación: registro, login y JWT.
Las contraseñas se hashean con bcrypt (via passlib).
Los tokens son JWT firmados con SECRET_KEY del .env.
"""

import uuid
from datetime import datetime, timedelta, timezone

import base64
import hashlib
import hmac
import os as _os

from jose import JWTError, jwt
from sqlalchemy.orm import Session

from ..config import settings
from ..models.user import User

_ALGORITHM = "HS256"
_PBKDF2_ITERATIONS = 260_000  # OWASP 2024 recommendation para PBKDF2-SHA256


# ── Contraseñas ────────────────────────────────────────────────────────────

def hash_password(plain: str) -> str:
    """
    Hashea la contraseña con PBKDF2-SHA256 y salt aleatorio de 16 bytes.
    Usa únicamente la stdlib de Python — sin dependencias externas.
    Formato almacenado: base64(salt[16] + hash[32])
    """
    salt = _os.urandom(16)
    key = hashlib.pbkdf2_hmac("sha256", plain.encode("utf-8"), salt, _PBKDF2_ITERATIONS)
    return base64.b64encode(salt + key).decode("ascii")


def verify_password(plain: str, stored: str) -> bool:
    """
    Verifica una contraseña contra su hash PBKDF2.
    Usa hmac.compare_digest para evitar timing attacks.
    """
    try:
        data = base64.b64decode(stored.encode("ascii"))
        salt, stored_key = data[:16], data[16:]
        key = hashlib.pbkdf2_hmac("sha256", plain.encode("utf-8"), salt, _PBKDF2_ITERATIONS)
        return hmac.compare_digest(key, stored_key)
    except Exception:
        return False


# ── JWT ────────────────────────────────────────────────────────────────────

def create_access_token(user_id: str, email: str) -> str:
    """
    Genera un JWT firmado con la clave secreta del servidor.
    TTL configurado en ACCESS_TOKEN_EXPIRE_MINUTES del .env (default 1440 = 24 h).
    """
    payload = {
        "sub": user_id,
        "email": email,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=_ALGORITHM)


def decode_token(token: str) -> dict:
    """
    Decodifica y valida un JWT.
    Lanza JWTError si el token es inválido o expirado.
    """
    return jwt.decode(token, settings.secret_key, algorithms=[_ALGORITHM])


def get_current_user_email(token: str) -> str:
    """Extrae el email del JWT. Lanza ValueError si no es válido."""
    try:
        payload = decode_token(token)
        email = payload.get("email")
        if not email:
            raise ValueError("Token sin email.")
        return email
    except JWTError as exc:
        raise ValueError(f"Token inválido: {exc}") from exc


# ── Registro / Login ───────────────────────────────────────────────────────

def register_user(
    db: Session,
    name: str,
    email: str,
    alias: str,
    password: str,
) -> User:
    """
    Crea un nuevo usuario en la base de datos.
    Lanza ValueError si el correo ya está registrado.
    """
    existing = db.query(User).filter(User.email == email.lower().strip()).first()
    if existing:
        raise ValueError("Ya existe una cuenta con ese correo electrónico.")

    user = User(
        id=str(uuid.uuid4()),
        name=name.strip(),
        email=email.lower().strip(),
        alias=alias.strip() or name.strip(),
        password_hash=hash_password(password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, email: str, password: str) -> User:
    """
    Verifica credenciales y devuelve el usuario si son correctas.
    Lanza ValueError si el correo no existe o la contraseña es incorrecta.
    """
    user = db.query(User).filter(User.email == email.lower().strip()).first()
    if not user or not verify_password(password, user.password_hash):
        # Mensaje genérico para no revelar si el correo existe
        raise ValueError("Correo o contraseña incorrectos.")
    if not user.is_active:
        raise ValueError("Esta cuenta está desactivada.")
    return user


# ── Dependencia FastAPI ────────────────────────────────────────────────────

from fastapi import Header, HTTPException
from typing import Annotated


def require_portal_user(
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    """
    Dependencia FastAPI: extrae y valida el JWT del header Authorization.
    Devuelve el email del usuario autenticado o lanza HTTP 401.

    Uso en un endpoint:
        @router.post("/ruta")
        def mi_endpoint(current_user: str = Depends(require_portal_user)):
            ...
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Se requiere autenticación de portal.")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        return get_current_user_email(token)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


def update_holder_did(db: Session, email: str, holder_did: str) -> None:
    """
    Asocia el DID del holder al usuario registrado.
    Se llama después de que el móvil genera su identidad Ed25519.
    """
    user = db.query(User).filter(User.email == email.lower().strip()).first()
    if user:
        user.holder_did = holder_did
        db.commit()
