import smtplib
from email.message import EmailMessage


def send_upload_link(
    *,
    to_email: str,
    holder_name: str,
    upload_url: str,
    expires_in_minutes: int,
    smtp_host: str,
    smtp_port: int,
    smtp_user: str,
    smtp_password: str,
    smtp_from: str,
) -> None:
    """
    Envía al usuario el enlace seguro para subir sus archivos .cer y .key.
    Lanza excepción si el envío falla.
    """
    msg = EmailMessage()
    msg["Subject"] = "Wallet SSI — Sube tus archivos de identidad"
    msg["From"] = smtp_from
    msg["To"] = to_email

    text = (
        f"Hola {holder_name},\n\n"
        f"Tu enlace para subir los archivos de identidad al wallet está listo.\n\n"
        f"Abre este enlace desde tu computadora:\n\n"
        f"  {upload_url}\n\n"
        f"El enlace expira en {expires_in_minutes} minutos.\n\n"
        f"Una vez subidos tus archivos .cer y .key, escanea el QR que aparece\n"
        f"en el portal con tu aplicación móvil para completar el registro.\n\n"
        f"Saludos,\nPortal Wallet SSI"
    )

    html = f"""<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"></head>
<body style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:32px;color:#1e293b">
  <div style="text-align:center;margin-bottom:24px">
    <div style="display:inline-block;background:#EFF6FF;border-radius:50%;padding:16px">
      <span style="font-size:32px">🔐</span>
    </div>
  </div>
  <h2 style="color:#0F62FE;margin:0 0 8px">Wallet SSI</h2>
  <p style="color:#64748B;margin:0 0 24px;font-size:14px">Portal de identidad autosoberana</p>
  <p>Hola <strong>{holder_name}</strong>,</p>
  <p>Tu enlace para subir los archivos de identidad está listo. Ábrelo desde tu computadora.</p>
  <div style="text-align:center;margin:32px 0">
    <a href="{upload_url}"
       style="background:#0F62FE;color:white;padding:14px 32px;
              border-radius:10px;text-decoration:none;font-size:16px;font-weight:600;
              display:inline-block">
      Subir archivos .cer y .key
    </a>
  </div>
  <div style="background:#FEF9C3;border:1px solid #FDE047;border-radius:10px;padding:14px;
              font-size:13px;color:#713F12">
    ⏱ Este enlace expira en <strong>{expires_in_minutes} minutos</strong>.<br>
    Después de subir los archivos, escanea el QR del portal con tu app móvil.
  </div>
  <hr style="border:none;border-top:1px solid #E2E8F0;margin:28px 0">
  <p style="color:#94A3B8;font-size:12px;text-align:center">
    Portal Wallet SSI · Si no solicitaste este acceso, ignora este correo.
  </p>
</body>
</html>"""

    msg.set_content(text)
    msg.add_alternative(html, subtype="html")

    with smtplib.SMTP(smtp_host, smtp_port) as server:
        server.starttls()
        server.login(smtp_user, smtp_password)
        server.send_message(msg)
