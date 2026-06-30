from fastapi import FastAPI, Request, Depends, HTTPException
from fastapi.responses import PlainTextResponse
from sqlalchemy.orm import Session
from datetime import datetime
from database import get_db, init_db
import models

app = FastAPI(title="SSH Vendor - Central")

init_db()

def client_ip(req: Request):
    fwd = req.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[0].strip()
    return req.client.host

@app.get("/")
def home():
    return {"service": "SSHVendor", "status": "ok"}

@app.get("/api/validate/{token}")
def validate(token: str, request: Request, db: Session = Depends(get_db), v: str = ""):
    lic = db.query(models.Licencia).filter(models.Licencia.token == token).first()
    if not lic:
        raise HTTPException(404, "Licencia inexistente")
    lic.last_seen = datetime.utcnow()
    if v:
        lic.bot_version = v
    db.commit()
    if lic.status == "revoked":
        return {"ok": False, "reason": "revoked"}
    ip = client_ip(request)
    if not lic.ip_bound:
        lic.ip_bound = ip
        db.commit()
        return {"ok": True, "bound": lic.ip_bound, "first": True}
    if ip != lic.ip_bound:
        return {"ok": False, "reason": "ip_mismatch", "bound": lic.ip_bound, "seen": ip}
    return {"ok": True, "bound": lic.ip_bound}


@app.get("/install/{token}", response_class=PlainTextResponse)
def install(token: str, request: Request, db: Session = Depends(get_db)):
    lic = db.query(models.Licencia).filter(models.Licencia.token == token).first()
    if not lic or lic.status != "active":
        raise HTTPException(403, "Licencia invalida")
    try:
        plantilla = open("/opt/sshvendor/install-bot.sh").read()
    except:
        raise HTTPException(500, "Instalador no disponible")
    # Reemplazar los placeholders con los datos reales
    base = str(request.base_url).rstrip("/")
    script = plantilla.replace("__TOKEN__", token).replace("__API_BASE__", base)
    return script
