"""Modelo ORM para enrolamientos de identidad."""

from datetime import datetime, timezone

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from ..database import Base


class Enrollment(Base):
    """
    Representa un proceso de enrolamiento SSI.

    Ciclo de vida del status:
      pending → did_registered → credential_issued
                              ↘ revoked (en cualquier punto)
    """

    __tablename__ = "enrollments"

    # Identificador único del enrolamiento (UUID corto, va en el QR)
    id: Mapped[str] = mapped_column(String(50), primary_key=True)

    # Correo del titular — usado para buscar o crear su cuenta
    user_email: Mapped[str] = mapped_column(String(200), nullable=False, index=True)
    holder_name: Mapped[str] = mapped_column(String(200), nullable=False)
    alias: Mapped[str] = mapped_column(String(100), nullable=False)
    account_type: Mapped[str] = mapped_column(String(50), default="personal")

    # Identidad del holder (se llena cuando el móvil registra su DID)
    holder_did: Mapped[str | None] = mapped_column(String(300), nullable=True)
    holder_public_key: Mapped[str | None] = mapped_column(String(200), nullable=True)

    # Estado actual del proceso
    status: Mapped[str] = mapped_column(String(50), default="pending")

    # Hashes SHA-256 de los archivos de certificado (para auditoría)
    cer_sha256: Mapped[str | None] = mapped_column(String(100), nullable=True)
    key_sha256: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Nonce de seguridad para el flujo de emisión de credencial
    offer_nonce: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # ID de la credencial emitida (referencia a IssuedCredential.id)
    credential_id: Mapped[str | None] = mapped_column(String(200), nullable=True)

    # Vigencia del enrolamiento
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    def to_dict(self) -> dict:
        """Serializa el enrolamiento para respuestas de API."""
        return {
            "type": "ssi_wallet_access_invitation",
            "wallet_action": "scan_to_register_account_and_get_access",
            "enrollment_id": self.id,
            "offer_nonce": self.offer_nonce,
            "allowed_curve": "Ed25519",
            "claims_preview": {
                "name": self.holder_name,
                "email": self.user_email,
                "alias": self.alias,
                "accountType": self.account_type,
                "certificateSha256": self.cer_sha256 or "",
                "keySha256": self.key_sha256 or "",
            },
            "account": {
                "name": self.holder_name,
                "email": self.user_email,
                "alias": self.alias,
                "account_type": self.account_type,
            },
            "access": {
                "status": self.status,
                "scopes": ["mobile_app:signup", "wallet:access"],
            },
            "certificate": {"sha256": self.cer_sha256 or ""},
            "key_proof": {"sha256": self.key_sha256 or ""},
            "holder_did": self.holder_did,
            "credential_id": self.credential_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
        }
