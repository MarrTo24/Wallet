from pydantic_settings import BaseSettings, SettingsConfigDict


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

    secret_key: str = "change-me-in-production"
    session_ttl_minutes: int = 15

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


settings = Settings()
