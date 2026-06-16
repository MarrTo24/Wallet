"""
Punto de entrada de la aplicación FastAPI del Portal Wallet SSI v2.2

Incluye:
  - Autenticación JWT (register/login)
  - Enrolamientos y emisión de VCs con firma Ed25519
  - Sesiones de archivos en memoria (file relay para .cer/.key)
  - Frontend estático servido desde /

Arranque:
  cd Portal/backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8010
"""

import asyncio
import os
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from .config import settings
from .limiter import limiter
from .logger import get_logger, setup_logging
from .database import init_db
from .routers.auth import router as auth_router
from .routers.enrollments import router as enrollments_router
from .routers.health import router as health_router
from .routers.sessions import router as sessions_router
from .routers.trust_registry import router as trust_registry_router
from .session_store import store

# Configurar logging antes que cualquier otra cosa
setup_logging(settings.app_env)
log = get_logger(__name__)

# ── Instancia de la aplicación ─────────────────────────────────────────────
app = FastAPI(
    title="Wallet Portal SSI",
    version="2.2.0",
    description=(
        "Portal intermediario para enrolamiento SSI, emisión de Verifiable Credentials "
        "y relay seguro de archivos de identidad (.cer/.key)."
    ),
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── CORS ───────────────────────────────────────────────────────────────────
_allow_all = settings.allowed_origins == ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=not _allow_all,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
)


# ── Middleware de logging HTTP ─────────────────────────────────────────────
@app.middleware("http")
async def _log_requests(request: Request, call_next):
    start = time.monotonic()
    response = await call_next(request)
    ms = (time.monotonic() - start) * 1000
    client_ip = request.client.host if request.client else "-"
    log.info(
        "%s %s %d %.0fms [%s]",
        request.method,
        request.url.path,
        response.status_code,
        ms,
        client_ip,
    )
    return response


# ── Routers ────────────────────────────────────────────────────────────────
app.include_router(health_router)
app.include_router(auth_router)
app.include_router(enrollments_router)
app.include_router(sessions_router)
app.include_router(trust_registry_router)


# ── Eventos de ciclo de vida ───────────────────────────────────────────────

@app.on_event("startup")
async def _on_startup() -> None:
    init_db()
    asyncio.create_task(_cleanup_loop())
    log.info("Wallet Portal v2.2 arriba en %s", settings.public_base_url)
    log.info("BD: %s", settings.database_url)
    log.info("TTL sesiones: %d min | JWT: %d min", settings.session_ttl_minutes, settings.access_token_expire_minutes)


async def _cleanup_loop() -> None:
    while True:
        await asyncio.sleep(60)
        removed = store.cleanup_expired()
        if removed:
            log.info("Sesiones expiradas eliminadas: %d", removed)


# ── Frontend estático ──────────────────────────────────────────────────────
_FRONTEND_DIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "..", "frontend")
)

if os.path.isdir(_FRONTEND_DIR):
    app.mount("/", StaticFiles(directory=_FRONTEND_DIR, html=True), name="frontend")
