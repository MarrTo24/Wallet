import threading
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional


@dataclass
class FileSession:
    session_id: str
    email: str
    holder_name: str
    alias: str
    created_at: datetime
    expires_at: datetime
    status: str = "waiting"  # waiting | files_ready | consumed
    cer_filename: Optional[str] = None
    cer_bytes: Optional[bytes] = None
    key_filename: Optional[str] = None
    key_bytes: Optional[bytes] = None


class SessionStore:
    """
    Almacén de sesiones en memoria con TTL.
    Los archivos .cer y .key viven aquí temporalmente —
    nunca se escriben a disco ni a base de datos.
    Al hacer claim se eliminan inmediatamente.
    """

    def __init__(self, ttl_minutes: int = 15) -> None:
        self._sessions: dict[str, FileSession] = {}
        self._ttl = timedelta(minutes=ttl_minutes)
        self._lock = threading.Lock()

    def create(self, email: str, holder_name: str, alias: str) -> FileSession:
        session_id = uuid.uuid4().hex[:8]
        now = datetime.utcnow()
        session = FileSession(
            session_id=session_id,
            email=email,
            holder_name=holder_name,
            alias=alias or holder_name,
            created_at=now,
            expires_at=now + self._ttl,
        )
        with self._lock:
            self._sessions[session_id] = session
        return session

    def get(self, session_id: str) -> Optional[FileSession]:
        with self._lock:
            session = self._sessions.get(session_id)
            if session is None:
                return None
            if datetime.utcnow() > session.expires_at:
                del self._sessions[session_id]
                return None
            return session

    def attach_files(
        self,
        session_id: str,
        cer_filename: str,
        cer_bytes: bytes,
        key_filename: str,
        key_bytes: bytes,
    ) -> None:
        with self._lock:
            session = self._sessions.get(session_id)
            if session is None:
                raise KeyError(f"Sesión '{session_id}' no encontrada o expirada.")
            if datetime.utcnow() > session.expires_at:
                del self._sessions[session_id]
                raise KeyError(f"Sesión '{session_id}' expirada.")
            if session.status == "consumed":
                raise ValueError("La sesión ya fue consumida por el móvil.")
            session.cer_filename = cer_filename
            session.cer_bytes = cer_bytes
            session.key_filename = key_filename
            session.key_bytes = key_bytes
            session.status = "files_ready"

    def claim_and_delete(self, session_id: str) -> FileSession:
        """Devuelve los archivos y borra la sesión al instante."""
        with self._lock:
            session = self._sessions.pop(session_id, None)
            if session is None:
                raise KeyError(f"Sesión '{session_id}' no encontrada o ya consumida.")
            if datetime.utcnow() > session.expires_at:
                raise KeyError(f"Sesión '{session_id}' expirada.")
            return session

    def cleanup_expired(self) -> int:
        """Elimina sesiones expiradas. Llamar desde tarea periódica."""
        now = datetime.utcnow()
        with self._lock:
            expired = [k for k, v in self._sessions.items() if v.expires_at < now]
            for k in expired:
                del self._sessions[k]
        return len(expired)


# Singleton compartido por todos los routers
store = SessionStore()
