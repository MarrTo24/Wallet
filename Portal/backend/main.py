import os
import smtplib
from email.message import EmailMessage

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

load_dotenv()

app = FastAPI(
    title="Wallet Portal",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

FRONTEND_DIR = os.path.join(
    os.path.dirname(__file__),
    "..",
    "frontend",
)


class SendPortalLinkRequest(BaseModel):
    email: str
    portal_url: str


@app.get("/api/health")
def health():
    return {
        "ok": True,
        "service": "wallet-portal",
    }


@app.post("/api/mobile/send-portal-link")
def send_portal_link(data: SendPortalLinkRequest):
    smtp_host = os.getenv("SMTP_HOST")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER")
    smtp_password = os.getenv("SMTP_PASSWORD")
    smtp_from = os.getenv("SMTP_FROM", smtp_user)

    if not smtp_host or not smtp_user or not smtp_password:
        raise HTTPException(
            status_code=500,
            detail="Configuracion SMTP incompleta.",
        )

    message = EmailMessage()
    message["Subject"] = "Portal Wallet SSI"
    message["From"] = smtp_from
    message["To"] = data.email

    message.set_content(
        f"""
Hola,

Abre este enlace desde tu computadora:

{data.portal_url}

Sube tus archivos .cer y .key,
genera el QR y escanéalo desde tu aplicación móvil.

Saludos.
"""
    )

    try:
        with smtplib.SMTP(
            smtp_host,
            smtp_port,
        ) as server:
            server.starttls()
            server.login(
                smtp_user,
                smtp_password,
            )
            server.send_message(message)

        return {
            "ok": True,
            "message": "Correo enviado correctamente.",
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"No se pudo enviar correo: {e}",
        )


app.mount(
    "/",
    StaticFiles(directory=FRONTEND_DIR, html=True),
    name="frontend",
)