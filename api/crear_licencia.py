import secrets
from database import SessionLocal
import models

# Cambiá esto por la dirección pública de tu servidor central cuando tengas dominio.
# Por ahora, si el cliente instala desde internet, necesitás la IP pública del VPS:
API_BASE = "https://licencias.charly-tricks.dev"

db = SessionLocal()
print("=== GENERAR LICENCIA - BOT VENDEDOR DE SSH ===\n")
cliente = input("Nombre/email del cliente: ").strip()
ip = input("IP del VPS del cliente (enter si se fija sola en la instalacion): ").strip()

token = secrets.token_hex(16)
lic = models.Licencia(
    token=token,
    cliente=cliente,
    ip_registered=ip or None,
    status="active"
)
db.add(lic); db.commit()
db.close()

print("\n" + "="*50)
print("LICENCIA CREADA")
print("="*50)
print(f"Cliente: {cliente}")
print(f"IP:      {ip or '(se fija en la primera instalacion)'}")
print(f"Token:   {token}")
print("\n--- LINK PARA PASARLE AL CLIENTE (se ve lindo en WhatsApp) ---\n")
print(f"{API_BASE}/i/{token}")
print("\n--- (o el comando directo, si lo necesitas) ---")
print(f"bash <(curl -s {API_BASE}/install/{token})")
print("\n" + "="*50)
