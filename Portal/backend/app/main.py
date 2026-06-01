import asyncio
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import settings
from .routers.health import router as health_router
from .routers.sessions import router as sessions_router
from .session_store import store

app = FastAPI(
    title="Wallet Portal",
    version="2.0.0",
    description="Portal intermediario de archivos de identidad para Wallet SSI.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(sessions_router)


# ─── Tarea de limpieza en background ──────────────────────────
async def _cleanup_loop() -> None:
    """Elimina sesiones expiradas cada 60 segundos."""
    while True:
        await asyncio.sleep(60)
        removed = store.cleanup_expired()
        if removed:
            print(f"[cleanup] {removed} sesión(es) expirada(s) eliminada(s).")


@app.on_event("startup")
async def _startup() -> None:
    asyncio.create_task(_cleanup_loop())
    print(f"[startup] Wallet Portal v2 corriendo en {settings.public_base_url}")
    print(f"[startup] TTL de sesiones: {settings.session_ttl_minutes} minutos")


# ─── Servir el frontend ───────────────────────────────────────
_FRONTEND_DIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "..", "frontend")
)

app.mount("/", StaticFiles(directory=_FRONTEND_DIR, html=True), name="frontend")
