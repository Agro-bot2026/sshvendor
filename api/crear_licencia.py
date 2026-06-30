import secrets
from database import SessionLocal
import models

# Cambiá esto por la dirección pública de tu servidor central cuando tengas dominio.
# Por ahora, si el cliente instala desde internet, necesitás la IP pública del VPS:
API_BASE = "http://93.127.139.4:10058"

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
print("\n--- COMANDO PARA PASARLE AL CLIENTE ---\n")
print(f"bash <(curl -s {API_BASE}/install/{token})")
print("\n" + "="*50)
