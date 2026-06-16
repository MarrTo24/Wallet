import base64
import json

from fastapi import APIRouter, File, Form, HTTPException, Request, UploadFile
from pydantic import BaseModel, EmailStr

from ..config import settings
from ..limiter import limiter
from ..logger import get_logger

log = get_logger(__name__)
from ..session_store import store
from ..services.email_service import send_upload_link
from ..services.token_service import (
    create_claim_token,
    create_upload_token,
    verify_token,
)

router = APIRouter(prefix="/api/sessions", tags=["sessions"])

_MAX_FILE_BYTES = 64 * 1024  # 64 KB por archivo


# ─────────────────────────────────────────────
# POST /api/sessions  →  crear sesión + enviar email
# ─────────────────────────────────────────────

class CreateSessionRequest(BaseModel):
    email: str
    holder_name: str
    alias: str = ""


@router.post("", status_code=201)
@limiter.limit("20/minute")
def create_session(request: Request, data: CreateSessionRequest):
    session = store.create(
        email=data.email.strip(),
        holder_name=data.holder_name.strip(),
        alias=data.alias.strip() or data.holder_name.strip(),
    )

    upload_token = create_upload_token(
        session.session_id, settings.secret_key, settings.session_ttl_minutes
    )
    claim_token = create_claim_token(
        session.session_id, settings.secret_key, settings.session_ttl_minutes
    )

    upload_url = (
        f"{settings.public_base_url}/upload.html"
        f"?s={session.session_id}&t={upload_token}"
    )

    # Payload mínimo que va en el QR (~250 chars)
    qr_payload = json.dumps(
        {
            "type": "wallet_file_session",
            "session_id": session.session_id,
            "claim_token": claim_token,
            "issuer_url": f"{settings.public_base_url}/api",
            "issuer_did": settings.issuer_did,
        },
        separators=(",", ":"),
    )

    email_sent = False
    email_error: str | None = None

    smtp_ready = all([
        settings.smtp_host,
        settings.smtp_user,
        settings.smtp_password,
    ])

    if smtp_ready:
        try:
            send_upload_link(
                to_email=data.email,
                holder_name=data.holder_name,
                upload_url=upload_url,
                expires_in_minutes=settings.session_ttl_minutes,
                smtp_host=settings.smtp_host,
                smtp_port=settings.smtp_port,
                smtp_user=settings.smtp_user,
                smtp_password=settings.smtp_password,
                smtp_from=settings.smtp_from or settings.smtp_user,
            )
            email_sent = True
        except Exception as exc:
            email_error = str(exc)
            log.warning("Email no enviado a %s: %s", data.email, exc)

    return {
        "ok": True,
        "session_id": session.session_id,
        "claim_token": claim_token,       # el móvil lo usa directamente sin QR
        "qr_payload": qr_payload,
        "expires_at": session.expires_at.isoformat() + "Z",
        "ttl_minutes": settings.session_ttl_minutes,
        "email_sent": email_sent,
        "email_error": email_error,
        "upload_url": upload_url,         # fallback si el email falla
    }


# ─────────────────────────────────────────────
# GET /api/sessions/{id}/status  →  polling de estado
# ─────────────────────────────────────────────

@router.get("/{session_id}/status")
def get_status(session_id: str):
    session = store.get(session_id)
    if not session:
        return {"status": "expired"}
    return {
        "status": session.status,
        "expires_at": session.expires_at.isoformat() + "Z",
    }


# ─────────────────────────────────────────────
# PUT /api/sessions/{id}/files  →  subir archivos (desde link del email)
# ─────────────────────────────────────────────

@router.put("/{session_id}/files")
async def upload_files(
    session_id: str,
    upload_token: str = Form(..., description="JWT de subida del link del email"),
    cer_file: UploadFile = File(..., description="Archivo de certificado .cer"),
    key_file: UploadFile = File(..., description="Archivo de llave .key"),
):
    # Validar token
    try:
        verified_id = verify_token(upload_token, settings.secret_key, "upload")
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc))

    if verified_id != session_id:
        raise HTTPException(
            status_code=401,
            detail="El token no corresponde a esta sesión.",
        )

    # Verificar que la sesión existe y está activa
    session = store.get(session_id)
    if not session:
        raise HTTPException(
            status_code=404,
            detail="Sesión no encontrada o expirada. Genera una nueva sesión.",
        )
    if session.status == "consumed":
        raise HTTPException(
            status_code=409,
            detail="Esta sesión ya fue reclamada por el dispositivo móvil.",
        )

    # Leer y validar archivos
    cer_bytes = await cer_file.read()
    key_bytes = await key_file.read()

    if not cer_bytes:
        raise HTTPException(status_code=422, detail="El archivo .cer está vacío.")
    if not key_bytes:
        raise HTTPException(status_code=422, detail="El archivo .key está vacío.")
    if len(cer_bytes) > _MAX_FILE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"El archivo .cer supera el límite de {_MAX_FILE_BYTES // 1024} KB.",
        )
    if len(key_bytes) > _MAX_FILE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"El archivo .key supera el límite de {_MAX_FILE_BYTES // 1024} KB.",
        )

    # Guardar en memoria
    try:
        store.attach_files(
            session_id=session_id,
            cer_filename=cer_file.filename or "identity.cer",
            cer_bytes=cer_bytes,
            key_filename=key_file.filename or "identity.key",
            key_bytes=key_bytes,
        )
    except (KeyError, ValueError) as exc:
        raise HTTPException(status_code=409, detail=str(exc))

    return {
        "ok": True,
        "message": "Archivos recibidos. Escanea el QR con tu app móvil.",
        "expires_at": session.expires_at.isoformat() + "Z",
    }


# ─────────────────────────────────────────────
# POST /api/sessions/{id}/claim  →  móvil reclama los archivos
# ─────────────────────────────────────────────

class ClaimRequest(BaseModel):
    claim_token: str
    holder_did: str = ""


@router.post("/{session_id}/claim")
def claim_files(session_id: str, data: ClaimRequest):
    # Validar token
    try:
        verified_id = verify_token(data.claim_token, settings.secret_key, "claim")
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc))

    if verified_id != session_id:
        raise HTTPException(
            status_code=401,
            detail="El token no corresponde a esta sesión.",
        )

    # Verificar estado antes de pop
    session = store.get(session_id)
    if not session:
        raise HTTPException(
            status_code=404,
            detail="Sesión no encontrada o expirada.",
        )

    if session.status == "waiting":
        raise HTTPException(
            status_code=425,  # Too Early
            detail=(
                "Los archivos aún no han sido subidos. "
                "Espera a que el usuario los suba desde el enlace en su correo."
            ),
        )

    if session.status != "files_ready":
        raise HTTPException(
            status_code=409,
            detail=f"Estado de sesión inesperado: '{session.status}'.",
        )

    # Reclamar y eliminar — operación atómica
    try:
        claimed = store.claim_and_delete(session_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    return {
        "ok": True,
        "cer_filename": claimed.cer_filename,
        "cer_base64": base64.b64encode(claimed.cer_bytes).decode(),
        "key_filename": claimed.key_filename,
        "key_base64": base64.b64encode(claimed.key_bytes).decode(),
        "holder_name": claimed.holder_name,
        "email": claimed.email,
        "alias": claimed.alias,
    }
