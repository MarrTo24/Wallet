from datetime import datetime, timedelta

from jose import JWTError, jwt

_ALGORITHM = "HS256"


def _make_token(session_id: str, role: str, secret_key: str, ttl_minutes: int) -> str:
    payload = {
        "sub": session_id,
        "role": role,
        "exp": datetime.utcnow() + timedelta(minutes=ttl_minutes),
    }
    return jwt.encode(payload, secret_key, algorithm=_ALGORITHM)


def create_upload_token(session_id: str, secret_key: str, ttl_minutes: int = 15) -> str:
    """Token que va en el link del email. Solo sirve para subir archivos."""
    return _make_token(session_id, "upload", secret_key, ttl_minutes)


def create_claim_token(session_id: str, secret_key: str, ttl_minutes: int = 15) -> str:
    """Token que va en el QR. Solo sirve para reclamar archivos desde el móvil."""
    return _make_token(session_id, "claim", secret_key, ttl_minutes)


def verify_token(token: str, secret_key: str, expected_role: str) -> str:
    """
    Verifica el token y devuelve el session_id.
    Lanza ValueError si el token es inválido, expirado o de rol incorrecto.
    """
    try:
        payload = jwt.decode(token, secret_key, algorithms=[_ALGORITHM])
    except JWTError as exc:
        raise ValueError(f"Token inválido o expirado: {exc}") from exc

    role = payload.get("role")
    if role != expected_role:
        raise ValueError(
            f"Token de rol incorrecto: se esperaba '{expected_role}', llegó '{role}'."
        )

    session_id = payload.get("sub")
    if not session_id:
        raise ValueError("Token sin identificador de sesión.")

    return session_id
