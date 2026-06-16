"""
Router de enrolamientos: crea ofertas de credencial, registra DIDs y emite VCs.

Flujo completo:
  1. POST /api/enrollments          → crea oferta, genera QR para el móvil
  2. GET  /api/enrollments/{id}     → móvil obtiene detalles del enrolamiento
  3. POST /api/enrollments/{id}/register-did    → móvil registra su DID
  4. POST /api/enrollments/{id}/issue-credential → emite el VC firmado
"""

import json
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..logger import get_logger

log = get_logger(__name__)
from ..models.activity import ActivityLog
from ..models.credential import IssuedCredential
from ..models.enrollment import Enrollment
from ..services.auth_service import get_current_user_email, require_portal_user
from ..services.credential_service import build_and_sign_vc

router = APIRouter(prefix="/api/enrollments", tags=["enrollments"])


# ── Schemas ────────────────────────────────────────────────────────────────

class CreateEnrollmentRequest(BaseModel):
    """Datos para crear una nueva oferta de enrolamiento."""
    holder_name: str
    email: str
    alias: str = ""
    account_type: str = "personal"
    cer_sha256: str = ""
    key_sha256: str = ""


class RegisterDidRequest(BaseModel):
    """DID e información de clave pública del holder."""
    holder_did: str
    holder_public_key_base64url: str = ""


class IssueCredentialRequest(BaseModel):
    """Solicitud de emisión de credencial desde el móvil."""
    holder_did: str
    holder_public_key_base64url: str = ""
    offer_nonce: str = ""


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.post("", status_code=201)
def create_enrollment(
    data: CreateEnrollmentRequest,
    db: Session = Depends(get_db),
    current_user: str = Depends(require_portal_user),
):
    """
    Crea una nueva oferta de enrolamiento y genera el QR para el móvil.

    Proceso:
      1. Genera un enrollment_id único y un nonce de seguridad
      2. Persiste el enrolamiento en DB
      3. Construye el payload del QR con los endpoints del backend
      4. Devuelve el payload JSON serializado para mostrar en QR

    El QR resultante es compatible con WalletEnrollmentService del móvil.
    Su tamaño es ~800 bytes — viable como QR código.

    Returns:
        Dict con enrollment_id, qr_payload (JSON string) y expires_at.
    """
    enrollment_id = str(uuid.uuid4()).replace("-", "")[:18]
    nonce = secrets.token_hex(16)
    now = datetime.now(timezone.utc)
    expires = now + timedelta(days=int(settings.offer_ttl_days))

    enrollment = Enrollment(
        id=enrollment_id,
        user_email=data.email.lower().strip(),
        holder_name=data.holder_name.strip(),
        alias=data.alias.strip() or data.holder_name.strip(),
        account_type=data.account_type or "personal",
        cer_sha256=data.cer_sha256 or None,
        key_sha256=data.key_sha256 or None,
        offer_nonce=nonce,
        expires_at=expires,
        status="pending",
    )
    db.add(enrollment)
    db.add(ActivityLog(
        id=str(uuid.uuid4()),
        user_email=current_user,
        event_type="enrollment_created",
        description=f"Enrolamiento creado para {data.holder_name} ({data.email})",
        metadata_json=json.dumps({"enrollment_id": enrollment_id, "created_by": current_user}),
    ))
    db.commit()
    log.info("Enrollment creado: %s para %s por %s", enrollment_id, data.email, current_user)

    # Construir payload del QR compatible con WalletEnrollmentService
    base = settings.public_base_url
    qr_payload = {
        "type": "ssi_wallet_access_invitation",
        "wallet_action": "scan_to_register_account_and_get_access",
        "enrollment_id": enrollment_id,
        "offer_nonce": nonce,
        "allowed_curve": "Ed25519",
        "created_at": now.isoformat(),
        "expires_at": expires.isoformat(),
        "issuer_did": settings.issuer_did,
        "issuer": {"did": settings.issuer_did, "name": settings.issuer_name},
        "claims_preview": {
            "name": data.holder_name,
            "email": data.email,
            "alias": data.alias or data.holder_name,
            "accountType": data.account_type or "personal",
            "certificateSha256": data.cer_sha256 or "",
            "keySha256": data.key_sha256 or "",
        },
        "did_registration": {
            "required": True,
            "auto_register_on_complete": False,
            "register_endpoint": f"{base}/api/enrollments/{enrollment_id}/register-did",
        },
        "endpoints": {
            "complete_signup": f"{base}/api/enrollments/{enrollment_id}/issue-credential",
            "credential_status": f"{base}/api/enrollments/{enrollment_id}",
        },
        "complete_signup_endpoint": f"{base}/api/enrollments/{enrollment_id}/issue-credential",
        "credential_request_endpoint": f"{base}/api/enrollments/{enrollment_id}/issue-credential",
        "did_registration_endpoint": f"{base}/api/enrollments/{enrollment_id}/register-did",
        "status_endpoint": f"{base}/api/enrollments/{enrollment_id}",
    }

    return {
        "ok": True,
        "enrollment_id": enrollment_id,
        "qr_payload": json.dumps(qr_payload, separators=(",", ":")),
        "expires_at": expires.isoformat() + "Z",
    }


@router.get("/{enrollment_id}")
def get_enrollment(enrollment_id: str, db: Session = Depends(get_db)):
    """
    Devuelve el estado actual del enrolamiento.
    El móvil llama a este endpoint para sincronizar la invitación con el portal.

    Returns:
        access_invitation con todos los campos del enrolamiento.
    """
    enrollment = db.query(Enrollment).filter(Enrollment.id == enrollment_id).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrolamiento no encontrado.")

    payload = enrollment.to_dict()
    # Agregar endpoints al payload devuelto (para que el móvil los tenga)
    base = settings.public_base_url
    payload.update({
        "issuer_did": settings.issuer_did,
        "issuer": {"did": settings.issuer_did, "name": settings.issuer_name},
        "complete_signup_endpoint": f"{base}/api/enrollments/{enrollment_id}/issue-credential",
        "credential_request_endpoint": f"{base}/api/enrollments/{enrollment_id}/issue-credential",
        "did_registration_endpoint": f"{base}/api/enrollments/{enrollment_id}/register-did",
        "did_registration": {
            "required": True,
            "auto_register_on_complete": False,
            "register_endpoint": f"{base}/api/enrollments/{enrollment_id}/register-did",
        },
    })

    return {"ok": True, "access_invitation": payload}


@router.post("/{enrollment_id}/register-did")
def register_did(
    enrollment_id: str,
    data: RegisterDidRequest,
    db: Session = Depends(get_db),
):
    """
    Registra el DID del holder móvil para este enrolamiento.

    El móvil llama a este endpoint justo después de generar su identidad Ed25519.
    Guarda el DID y la clave pública en DB para usarlos en la emisión del VC.

    Args:
        data.holder_did:                DID en formato did:key:z...
        data.holder_public_key_base64url: Clave pública Ed25519 en base64url.

    Returns:
        Confirmación del registro del DID.
    """
    enrollment = db.query(Enrollment).filter(Enrollment.id == enrollment_id).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrolamiento no encontrado.")

    if enrollment.status == "credential_issued":
        # Ya fue emitida la credencial — el DID ya está registrado
        return {"ok": True, "message": "DID ya registrado. Credencial ya emitida."}

    enrollment.holder_did = data.holder_did
    enrollment.holder_public_key = data.holder_public_key_base64url
    enrollment.status = "did_registered"
    enrollment.updated_at = datetime.now(timezone.utc)
    db.commit()
    log.info("DID registrado en enrollment %s: %s", enrollment_id, data.holder_did[:30])

    return {"ok": True, "message": "DID registrado correctamente."}


@router.post("/{enrollment_id}/issue-credential")
def issue_credential(
    enrollment_id: str,
    data: IssueCredentialRequest,
    db: Session = Depends(get_db),
):
    """
    Emite una Verifiable Credential firmada con Ed25519 para el holder.

    Proceso completo:
      1. Valida que el enrolamiento exista y no haya expirado
      2. Usa el DID del request o el ya registrado en DB
      3. Llama a build_and_sign_vc() para construir y firmar el VC
      4. Persiste el VC en issued_credentials
      5. Actualiza el estado del enrolamiento a "credential_issued"
      6. Devuelve el VC completo al móvil

    Args:
        data.holder_did:    DID del titular.
        data.offer_nonce:   Nonce de la oferta (para validación futura).

    Returns:
        Dict con ok=True y el VC completo (incluyendo proof Ed25519).
    """
    enrollment = db.query(Enrollment).filter(Enrollment.id == enrollment_id).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrolamiento no encontrado.")

    # Verificar que no haya expirado
    if enrollment.expires_at and datetime.now(timezone.utc) > enrollment.expires_at:
        raise HTTPException(status_code=410, detail="El enrolamiento ha expirado.")

    # Determinar el DID a usar
    holder_did = data.holder_did or enrollment.holder_did
    if not holder_did:
        raise HTTPException(
            status_code=422,
            detail="El DID del holder no está disponible. Registra el DID primero.",
        )

    # Si la credencial ya fue emitida, devolverla de nuevo (idempotente)
    if enrollment.status == "credential_issued" and enrollment.credential_id:
        existing = db.query(IssuedCredential).filter(
            IssuedCredential.id == enrollment.credential_id
        ).first()
        if existing:
            return {"ok": True, "credential": json.loads(existing.vc_json)}

    # Actualizar DID si no estaba registrado
    if not enrollment.holder_did:
        enrollment.holder_did = holder_did
        enrollment.holder_public_key = data.holder_public_key_base64url

    # Construir y firmar el VC
    vc = build_and_sign_vc(
        enrollment_id=enrollment_id,
        holder_did=holder_did,
        holder_name=enrollment.holder_name,
        email=enrollment.user_email,
        alias=enrollment.alias,
        account_type=enrollment.account_type,
        cer_sha256=enrollment.cer_sha256,
        key_sha256=enrollment.key_sha256,
    )

    # Parsear fecha de expiración del VC generado
    expires_at = None
    try:
        expires_at = datetime.fromisoformat(vc["expirationDate"])
    except (KeyError, ValueError):
        pass

    # Persistir el VC
    issued = IssuedCredential(
        id=vc["id"],
        enrollment_id=enrollment_id,
        holder_did=holder_did,
        issuer_did=settings.issuer_did,
        vc_type="IdentityCredential",
        vc_json=json.dumps(vc),
        expires_at=expires_at,
    )
    db.add(issued)

    # Actualizar estado del enrolamiento
    enrollment.status = "credential_issued"
    enrollment.credential_id = vc["id"]
    enrollment.updated_at = datetime.now(timezone.utc)

    # Registrar en el log de actividad
    db.add(ActivityLog(
        id=str(uuid.uuid4()),
        user_email=enrollment.user_email,
        event_type="credential_issued",
        description=f"Credencial emitida para {enrollment.holder_name}",
        metadata_json=json.dumps({"enrollment_id": enrollment_id, "vc_id": vc["id"]}),
    ))

    db.commit()
    log.info("Credencial emitida: enrollment=%s holder=%s", enrollment_id, holder_did[:30])

    return {"ok": True, "credential": vc}
