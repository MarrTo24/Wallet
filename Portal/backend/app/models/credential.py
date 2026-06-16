"""Modelo ORM para credenciales verificables emitidas."""

from datetime import datetime, timezone

from sqlalchemy import DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from ..database import Base


class IssuedCredential(Base):
    """
    Almacena el JSON completo de cada Verifiable Credential emitida.
    El VC incluye la firma Ed25519 del emisor y es inmutable una vez emitido.
    """

    __tablename__ = "issued_credentials"

    # ID del VC (urn:uuid:... según W3C VC spec)
    id: Mapped[str] = mapped_column(String(200), primary_key=True)

    # Referencia al enrolamiento que originó esta credencial
    enrollment_id: Mapped[str] = mapped_column(String(50), nullable=False, index=True)

    # DIDs del holder y del emisor
    holder_did: Mapped[str] = mapped_column(String(300), nullable=False)
    issuer_did: Mapped[str] = mapped_column(String(300), nullable=False)

    # Tipo de credencial (ej. "IdentityCredential")
    vc_type: Mapped[str] = mapped_column(String(100), nullable=False)

    # JSON completo del VC incluyendo prueba criptográfica
    vc_json: Mapped[str] = mapped_column(Text, nullable=False)

    # Estado de la credencial
    status: Mapped[str] = mapped_column(String(50), default="active")

    # Fechas de vigencia
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
