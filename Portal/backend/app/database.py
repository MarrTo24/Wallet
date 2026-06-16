"""
Configuración de la base de datos con SQLAlchemy.

Soporta MySQL (producción) y SQLite (desarrollo local).
Configura DATABASE_URL en .env:
  MySQL:  mysql+pymysql://user:pass@host:3306/wallet_db
  SQLite: sqlite:///./wallet.db  (solo para dev)
"""

from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import settings
from .logger import get_logger

log = get_logger(__name__)

# ── URL de la base de datos ────────────────────────────────────────────────
_DATABASE_URL = settings.database_url
_is_sqlite = _DATABASE_URL.startswith("sqlite")
_is_mysql  = _DATABASE_URL.startswith("mysql")

# ── Argumentos de conexión por motor ──────────────────────────────────────
_connect_args: dict = {}
_engine_kwargs: dict = {"echo": False}

if _is_sqlite:
    _connect_args = {"check_same_thread": False}

if _is_mysql:
    # Pool de conexiones para MySQL en producción
    _engine_kwargs.update({
        "pool_size": 10,
        "max_overflow": 20,
        "pool_recycle": 1800,   # reconecta cada 30 min (evita "server gone away")
        "pool_pre_ping": True,  # verifica conexión antes de usarla
    })

# ── Motor y sesión ─────────────────────────────────────────────────────────
engine = create_engine(_DATABASE_URL, connect_args=_connect_args, **_engine_kwargs)

# MySQL: forzar utf8mb4 y modo estricto en cada conexión
if _is_mysql:
    @event.listens_for(engine, "connect")
    def _set_mysql_pragmas(dbapi_conn, _):
        cursor = dbapi_conn.cursor()
        cursor.execute("SET NAMES utf8mb4")
        cursor.execute("SET time_zone = '+00:00'")
        cursor.close()

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """Clase base de la que heredan todos los modelos ORM."""
    pass


def get_db():
    """
    Generador de sesión de DB para usar como dependencia de FastAPI.
    Garantiza que la sesión se cierre incluso si ocurre una excepción.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """
    Crea todas las tablas definidas en los modelos si no existen.
    Seguro de llamar múltiples veces (idempotente).
    """
    from .models import user, enrollment, credential, activity  # noqa: F401
    Base.metadata.create_all(bind=engine)
    log.info("Motor de BD: %s", "MySQL/MariaDB" if _is_mysql else "SQLite")
