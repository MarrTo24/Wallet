"""Modelo ORM para el registro de actividad del wallet."""

from datetime import datetime, timezone

from sqlalchemy import DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from ..database import Base


class ActivityLog(Base):
    """
    Registro de auditoría de eventos del wallet.
    Cada acción significativa (login, emisión de credencial, QR compartido)
    queda registrada aquí con su contexto.
    """

    __tablename__ = "activity_log"

    id: Mapped[str] = mapped_column(String(50), primary_key=True)

    # Correo del usuario asociado al evento (puede ser None para eventos de sistema)
    user_email: Mapped[str | None] = mapped_column(String(200), nullable=True, index=True)

    # Tipo de evento: login, logout, credential_issued, qr_shared, etc.
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)

    # Descripción legible del evento
    description: Mapped[str] = mapped_column(String(500), nullable=False)

    # Metadatos adicionales en JSON (ej. enrollment_id, credential_id)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )

    def to_dict(self) -> dict:
        """Serializa el evento para respuestas de API y para el móvil."""
        return {
            "id": self.id,
            "event_type": self.event_type,
            "description": self.description,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
