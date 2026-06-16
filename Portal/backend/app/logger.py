"""
Logging estructurado para el Portal Wallet SSI.

- Entorno local:      texto legible  →  2026-06-15 10:30:00 [INFO] app.main: mensaje
- Entorno production: JSON por línea →  {"ts":"...","level":"INFO","logger":"...","msg":"..."}

Uso en cualquier módulo:
    from .logger import get_logger
    log = get_logger(__name__)
    log.info("Enrollment creado: %s", enrollment_id)
    log.warning("Email no enviado: %s", exc)
    log.error("Error de DB: %s", exc, exc_info=True)
"""

import json
import logging
import sys


class _JsonFormatter(logging.Formatter):
    """Formatea cada registro como una línea JSON parseable por ELK / CloudWatch."""

    def format(self, record: logging.LogRecord) -> str:
        obj: dict = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        if record.exc_info:
            obj["exc"] = self.formatException(record.exc_info)
        if hasattr(record, "extra"):
            obj.update(record.extra)  # type: ignore[arg-type]
        return json.dumps(obj, ensure_ascii=False)


class _TextFormatter(logging.Formatter):
    """Formato legible para desarrollo local. Colores solo si la salida es un terminal."""

    _COLORS = {
        "DEBUG":    "\033[36m",
        "INFO":     "\033[32m",
        "WARNING":  "\033[33m",
        "ERROR":    "\033[31m",
        "CRITICAL": "\033[35m",
    }
    _RESET = "\033[0m"

    def __init__(self) -> None:
        super().__init__()
        self._use_color = sys.stdout.isatty()

    def format(self, record: logging.LogRecord) -> str:
        ts = self.formatTime(record, "%Y-%m-%d %H:%M:%S")
        if self._use_color:
            color = self._COLORS.get(record.levelname, "")
            level = f"{color}[{record.levelname}]{self._RESET}"
        else:
            level = f"[{record.levelname}]"
        base = f"{ts} {level} {record.name}: {record.getMessage()}"
        if record.exc_info:
            base += "\n" + self.formatException(record.exc_info)
        return base


def setup_logging(app_env: str = "local") -> None:
    """
    Configura el sistema de logging de la aplicación.
    Debe llamarse una sola vez, al inicio de main.py antes de procesar requests.

    Args:
        app_env: "local" usa texto con colores; cualquier otro valor usa JSON.
    """
    is_prod = app_env.lower() != "local"
    level = logging.INFO

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(_JsonFormatter() if is_prod else _TextFormatter())

    root = logging.getLogger()
    root.setLevel(level)
    # Limpiar handlers previos (p.ej. los de uvicorn que ya configuró basicConfig)
    root.handlers.clear()
    root.addHandler(handler)

    # Silenciar loggers ruidosos de terceros que no aportan valor en producción
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.error").setLevel(logging.INFO)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    """Obtiene un logger con el nombre del módulo que lo llama."""
    return logging.getLogger(name)
