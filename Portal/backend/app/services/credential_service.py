"""
Servicio de emisión de Verifiable Credentials (VC) W3C.

Construye el VC completo, lo firma con Ed25519 usando la clave privada
del emisor almacenada en .env, y devuelve el JSON listo para guardar
en la base de datos y entregar al wallet móvil.
"""

import base64
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from ..config import settings


def _urlsafe_b64decode(s: str) -> bytes:
    """Decodifica base64url agregando el padding necesario."""
    padding = (4 - len(s) % 4) % 4
    return base64.urlsafe_b64decode(s + "=" * padding)


def _urlsafe_b64encode(data: bytes) -> str:
    """Codifica bytes a base64url sin padding."""
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _canonical_json(obj: dict) -> str:
    """
    Genera JSON canónico (claves ordenadas, sin espacios).
    Es determinístico para que la firma siempre sea la misma sobre el mismo payload.
    """
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _sign_payload(payload: dict) -> str:
    """
    Firma un diccionario con la clave privada Ed25519 del emisor.
    Devuelve la firma en base64url.

    Proceso:
      1. Serializa el payload a JSON canónico
      2. Carga la clave privada desde la semilla en .env
      3. Firma con Ed25519
      4. Devuelve la firma en base64url
    """
    seed = _urlsafe_b64decode(settings.issuer_private_key_seed)
    private_key = Ed25519PrivateKey.from_private_bytes(seed)

    canonical = _canonical_json(payload).encode("utf-8")
    signature = private_key.sign(canonical)

    return _urlsafe_b64encode(signature)


def build_and_sign_vc(
    enrollment_id: str,
    holder_did: str,
    holder_name: str,
    email: str,
    alias: str,
    account_type: str,
    cer_sha256: Optional[str] = None,
    key_sha256: Optional[str] = None,
    validity_days: int = 365,
) -> dict:
    """
    Construye y firma una Verifiable Credential W3C 1.0.

    El flujo completo:
      1. Construye el VC sin prueba (payload)
      2. Firma el payload con Ed25519 usando la clave del emisor
      3. Agrega el bloque `proof` con la firma
      4. Devuelve el VC completo listo para almacenar y enviar al móvil

    Args:
        enrollment_id: ID único del enrolamiento.
        holder_did:     DID del titular (generado en el móvil).
        holder_name:    Nombre completo del titular.
        email:          Correo del titular.
        alias:          Alias del wallet.
        account_type:   "personal" o "business".
        cer_sha256:     Hash SHA-256 del certificado (opcional, para auditoría).
        key_sha256:     Hash SHA-256 del archivo .key (opcional, para auditoría).
        validity_days:  Días de vigencia de la credencial (default 365).

    Returns:
        VC completo como dict con bloque `proof` firmado.
    """
    now = datetime.now(timezone.utc)
    expires = now + timedelta(days=validity_days)
    credential_id = f"urn:uuid:{uuid.uuid4()}"

    # ── Construir credentialSubject ────────────────────────────────────────
    subject: dict = {
        "id": holder_did,
        "enrollmentId": enrollment_id,
        "name": holder_name,
        "email": email,
        "alias": alias,
        "accountType": account_type,
        "credentialStatus": "active",
        "assuranceLevel": "Alto",
        "accessScopes": ["mobile_app:signup", "wallet:access"],
    }
    if cer_sha256:
        subject["certificateSha256"] = cer_sha256
    if key_sha256:
        subject["keySha256"] = key_sha256

    # ── Construir VC sin prueba ────────────────────────────────────────────
    vc_without_proof: dict = {
        "@context": [
            "https://www.w3.org/2018/credentials/v1",
            "https://w3id.org/security/suites/ed25519-2020/v1",
        ],
        "id": credential_id,
        "type": [
            "VerifiableCredential",
            "IdentityCredential",
            "SystemAccessCredential",
        ],
        "issuer": settings.issuer_did,
        "issuanceDate": now.isoformat(),
        "expirationDate": expires.isoformat(),
        "credentialSubject": subject,
    }

    # ── Firmar el payload ──────────────────────────────────────────────────
    proof_value = _sign_payload(vc_without_proof)

    # ── Agregar bloque proof ───────────────────────────────────────────────
    vc_without_proof["proof"] = {
        "type": "Ed25519Signature2020",
        "created": now.isoformat(),
        "verificationMethod": settings.issuer_verification_method,
        "proofPurpose": "assertionMethod",
        "proofValue": proof_value,
        "publicKeyBase64Url": settings.issuer_public_key,
    }

    return vc_without_proof
