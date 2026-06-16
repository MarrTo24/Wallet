import sys
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_UNSAFE_SECRET = "change-me-in-production"

# Campos requeridos en producción — el servidor no arranca si faltan
_REQUIRED_IN_PROD = [
    "secret_key",
    "issuer_did",
    "issuer_private_key_seed",
    "issuer_public_key",
]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
        extra="ignore",
    )

    app_env: str = "local"
    app_host: str = "0.0.0.0"
    app_port: int = 8010
    public_base_url: str = "http://localhost:8010"

    database_url: str = "sqlite:///./wallet.db"

    # Orígenes permitidos en CORS (separados por coma). "*" solo si app_env != production.
    cors_origins: str = "*"

    secret_key: str = _UNSAFE_SECRET
    session_ttl_minutes: int = 15
    access_token_expire_minutes: int = 1440  # 24 horas
    offer_ttl_days: int = 7

    issuer_name: str = "Portal SSI Issuer"
    issuer_did: str = ""
    issuer_private_key_seed: str = ""
    issuer_public_key: str = ""
    issuer_verification_method: str = ""

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""

    @model_validator(mode="after")
    def _validate_production_secrets(self) -> "Settings":
        is_prod = self.app_env.lower() == "production"

        if is_prod and self.secret_key == _UNSAFE_SECRET:
            print("[FATAL] SECRET_KEY no puede ser el valor por defecto en producción.", file=sys.stderr)
            sys.exit(1)

        if is_prod and self.cors_origins.strip() == "*":
            print("[FATAL] CORS_ORIGINS no puede ser '*' en producción. Define los orígenes permitidos.", file=sys.stderr)
            sys.exit(1)

        missing = [f for f in _REQUIRED_IN_PROD if not getattr(self, f) or getattr(self, f) == _UNSAFE_SECRET]
        if is_prod and missing:
            print(f"[FATAL] Variables requeridas en producción no configuradas: {', '.join(missing)}", file=sys.stderr)
            sys.exit(1)

        # Advertencias en entornos no productivos
        if not is_prod:
            if self.secret_key == _UNSAFE_SECRET:
                print("[WARN] SECRET_KEY usa el valor por defecto. Configura uno seguro antes de producción.")
            if self.cors_origins.strip() == "*":
                print("[WARN] CORS_ORIGINS='*' — restringe los orígenes antes de producción.")

        return self

    @property
    def allowed_origins(self) -> list[str]:
        """Devuelve la lista de orígenes CORS permitidos."""
        raw = self.cors_origins.strip()
        if raw == "*":
            return ["*"]
        return [o.strip() for o in raw.split(",") if o.strip()]


settings = Settings()
