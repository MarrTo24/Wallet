"""Modelo ORM para usuarios del wallet."""

from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from ..database import Base


class User(Base):
    """
    Representa un usuario registrado en el portal.
    Cada usuario tiene un DID único generado en el dispositivo móvil.
    """

    __tablename__ = "users"

    # Identificador único (UUID generado en la capa de servicio)
    id: Mapped[str] = mapped_column(String(36), primary_key=True)

    # Datos personales
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    email: Mapped[str] = mapped_column(String(200), unique=True, nullable=False, index=True)
    alias: Mapped[str] = mapped_column(String(100), nullable=False)

    # Contraseña hasheada con bcrypt (NUNCA en texto plano)
    password_hash: Mapped[str] = mapped_column(String(300), nullable=False)

    # DID del holder — se llena cuando el móvil registra su identidad
    holder_did: Mapped[str | None] = mapped_column(String(300), nullable=True)

    # Estado de la cuenta
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )

    def to_dict(self) -> dict:
        """Serializa el usuario para respuestas de API (sin password_hash)."""
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "alias": self.alias,
            "holder_did": self.holder_did,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
