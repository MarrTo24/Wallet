"""
Router de autenticación: registro, login y perfil.
Los tokens JWT duran 30 días para evitar interrupciones en el uso móvil.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from ..database import get_db
from ..limiter import limiter
from ..logger import get_logger

log = get_logger(__name__)
from ..models.activity import ActivityLog
from ..services.auth_service import (
    authenticate_user,
    create_access_token,
    get_current_user_email,
    register_user,
    update_holder_did,
)
from ..models.user import User

router = APIRouter(prefix="/api/auth", tags=["auth"])


# ── Schemas de request/response ────────────────────────────────────────────

class RegisterRequest(BaseModel):
    """Datos necesarios para registrar un nuevo usuario."""
    name: str
    email: str
    alias: str = ""
    password: str


class LoginRequest(BaseModel):
    """Credenciales para iniciar sesión."""
    email: str
    password: str


class UpdateDidRequest(BaseModel):
    """Solicitud para registrar el DID del holder."""
    holder_did: str


class TokenResponse(BaseModel):
    """Respuesta con el JWT y datos básicos del usuario."""
    access_token: str
    token_type: str = "bearer"
    user_id: str
    name: str
    email: str
    alias: str


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.post("/register", response_model=TokenResponse, status_code=201)
@limiter.limit("5/minute")
def register(request: Request, data: RegisterRequest, db: Session = Depends(get_db)):
    """
    Registra un nuevo usuario en el portal.

    Proceso:
      1. Valida que el correo no esté en uso
      2. Crea el usuario con contraseña hasheada (bcrypt)
      3. Genera un JWT de acceso
      4. Registra el evento en el log de actividad

    Returns:
        TokenResponse con el JWT y datos básicos del usuario.
    """
    try:
        user = register_user(
            db,
            name=data.name,
            email=data.email,
            alias=data.alias or data.name,
            password=data.password,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))

    # Registrar evento de creación de cuenta
    db.add(ActivityLog(
        id=str(uuid.uuid4()),
        user_email=user.email,
        event_type="register",
        description="Cuenta creada en el portal",
    ))
    db.commit()

    log.info("Usuario registrado: %s", user.email)
    token = create_access_token(user.id, user.email)
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        name=user.name,
        email=user.email,
        alias=user.alias,
    )


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
def login(request: Request, data: LoginRequest, db: Session = Depends(get_db)):
    """
    Autentica un usuario existente y devuelve un JWT fresco.

    Proceso:
      1. Verifica email + contraseña contra el hash en DB
      2. Genera un nuevo JWT (invalida el anterior implícitamente)
      3. Registra el evento de login

    Returns:
        TokenResponse con el JWT renovado.
    """
    try:
        user = authenticate_user(db, data.email, data.password)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc))

    # Registrar evento de inicio de sesión
    db.add(ActivityLog(
        id=str(uuid.uuid4()),
        user_email=user.email,
        event_type="login",
        description="Inicio de sesión exitoso",
    ))
    db.commit()

    log.info("Login exitoso: %s", user.email)
    token = create_access_token(user.id, user.email)
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        name=user.name,
        email=user.email,
        alias=user.alias,
    )


@router.get("/me")
def get_me(
    authorization: Annotated[str | None, Header()] = None,
    db: Session = Depends(get_db),
):
    """
    Devuelve el perfil del usuario autenticado.
    Requiere header: Authorization: Bearer <token>

    Returns:
        Datos del usuario sin información sensible (sin password_hash).
    """
    token = _extract_bearer(authorization)
    email = _require_auth(token)

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado.")
    return {"ok": True, "user": user.to_dict()}


@router.put("/me/did")
def update_did(
    data: UpdateDidRequest,
    authorization: Annotated[str | None, Header()] = None,
    db: Session = Depends(get_db),
):
    """
    Asocia el DID del holder al perfil del usuario.
    Se llama desde el móvil después de generar la identidad Ed25519.

    Args:
        data.holder_did: DID en formato did:key:z...

    Returns:
        Confirmación del registro.
    """
    token = _extract_bearer(authorization)
    email = _require_auth(token)

    update_holder_did(db, email, data.holder_did)
    return {"ok": True, "message": "DID registrado correctamente."}


# ── Helpers privados ───────────────────────────────────────────────────────

def _extract_bearer(authorization: str | None) -> str | None:
    """Extrae el token JWT del header Authorization: Bearer <token>."""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    return authorization.removeprefix("Bearer ").strip()


def _require_auth(token: str | None) -> str:
    """
    Valida el token y devuelve el email del usuario.
    Lanza 401 si el token falta o es inválido.
    """
    if not token:
        raise HTTPException(status_code=401, detail="Se requiere autenticación.")
    try:
        return get_current_user_email(token)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
