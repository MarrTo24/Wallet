"""
Registro de emisores de confianza.

GET /api/trust-registry  →  lista pública de DIDs de emisores autorizados.
El móvil consulta este endpoint al verificar una VC para saber si el emisor
es reconocido por el portal.

En producción esta lista puede moverse a una tabla de BD administrable.
Por ahora se alimenta desde la configuración del servidor.
"""

from fastapi import APIRouter

from ..config import settings
from ..logger import get_logger

router = APIRouter(prefix="/api/trust-registry", tags=["trust-registry"])
log = get_logger(__name__)

# Lista de emisores de confianza.
# Incluye el DID del propio portal + cualquier otro que se configure.
# En el futuro: leer de una tabla `trusted_issuers` en BD.
_TRUSTED_ISSUERS: list[dict] = [
    {
        "did": settings.issuer_did,
        "name": settings.issuer_name,
        "category": "Portal de enrolamiento",
    },
]


@router.get("")
def get_trust_registry():
    """
    Devuelve la lista de emisores de confianza del portal.

    El móvil consume este endpoint durante la verificación de VCs para
    determinar si el emisor del credential está registrado como entidad
    confiable. Sin autenticación requerida — es información pública.

    Returns:
        Dict con la lista de issuers y la versión del registro.
    """
    # Filtramos DIDs vacíos (si el portal no está configurado)
    active = [i for i in _TRUSTED_ISSUERS if i["did"]]
    log.info("Trust registry consultado: %d emisores", len(active))
    return {
        "ok": True,
        "version": "1.0",
        "issuers": active,
    }
