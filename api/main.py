from fastapi import FastAPI, Request, Depends, HTTPException
from fastapi.responses import PlainTextResponse, HTMLResponse
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




@app.get("/i/{token}", response_class=HTMLResponse)
def pagina_instalacion(token: str, request: Request, db: Session = Depends(get_db)):
    """Página amigable con Open Graph + galería de pasos ilustrados."""
    lic = db.query(models.Licencia).filter(models.Licencia.token == token).first()
    existe = lic is not None
    base = str(request.base_url).rstrip("/")
    comando = f"bash <(curl -s {base}/install/{token})"
    og_image = "https://i.postimg.cc/GmF4JTC3/file-0000000097c4720ea4bafcc8022b70d7.jpg"
    titulo = "Instalá tu Bot SSH"
    descripcion = "Seguí los pasos para activar tu bot vendedor de SSH en tu servidor."

    aviso = "" if existe else '<p style="color:#f87171;text-align:center;font-weight:bold;">⚠️ Esta licencia no es válida o expiró. Contactá a soporte.</p>'

    pasos_img = "".join(
        f'<img src="https://i.postimg.cc/{p}" alt="paso" loading="lazy">'
        for p in [
            "s20KyN0Z/step-01.png", "05SZRZGy/step-02.png", "xTyRqC48/step-03.png",
            "QMPgvWFL/step-04.png", "tJdh1SDN/step-05.png", "GhQFdf4d/step-06.png",
            "Dwp1bbd3/step-07.png", "j5Pf93VY/step-08.png", "qvq30vf1/step-09.png",
            "FRyfGfcQ/step-10.png", "Gtz4wZXB/step-11.png", "4NNKbx3m/step-12.png",
        ]
    )

    return f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{titulo}</title>
<meta property="og:title" content="{titulo}">
<meta property="og:description" content="{descripcion}">
<meta property="og:image" content="{og_image}">
<meta property="og:type" content="website">
<meta name="twitter:card" content="summary_large_image">
<style>
  * {{ box-sizing:border-box; }}
  body {{ font-family: system-ui, -apple-system, sans-serif; background:#0a0f1e; color:#e2e8f0; max-width:680px; margin:0 auto; padding:0 0 40px; }}
  .hero {{ width:100%; display:block; }}
  .wrap {{ padding:0 20px; }}
  h1 {{ font-size:26px; text-align:center; color:#10b981; margin:24px 0 8px; }}
  .sub {{ text-align:center; color:#94a3b8; margin:0 0 24px; }}
  .paso {{ background:#141c30; padding:18px; border-radius:14px; margin:14px 0; box-shadow:0 2px 10px rgba(0,0,0,.3); }}
  .num {{ display:inline-block; background:#10b981; color:#0a0f1e; width:28px; height:28px; border-radius:50%; text-align:center; line-height:28px; font-weight:bold; margin-right:10px; }}
  .cmd {{ background:#020617; border:1px solid #1e293b; border-radius:10px; padding:14px; font-family:monospace; font-size:13px; color:#4ade80; word-break:break-all; margin:12px 0; }}
  button {{ width:100%; padding:15px; background:#10b981; color:#0a0f1e; border:none; border-radius:10px; font-size:16px; font-weight:bold; cursor:pointer; transition:background .2s; }}
  button:active {{ background:#059669; }}
  .galeria {{ margin-top:34px; }}
  .galeria h2 {{ text-align:center; color:#10b981; font-size:20px; margin-bottom:16px; }}
  .galeria img {{ width:100%; display:block; border-radius:12px; margin:14px 0; box-shadow:0 3px 14px rgba(0,0,0,.4); }}
  .foot {{ text-align:center; color:#64748b; font-size:14px; margin-top:30px; }}
</style>
</head>
<body>
<img class="hero" src="{og_image}" alt="Instalá tu Bot SSH">
<div class="wrap">
  <h1>🤖 Instalá tu Bot SSH</h1>
  <p class="sub">{descripcion}</p>
  {aviso}
  <div class="paso"><span class="num">1</span> Conectate a tu servidor (VPS) por SSH como root.</div>
  <div class="paso">
    <span class="num">2</span> Copiá y pegá este comando en tu terminal:
    <div class="cmd" id="cmd">{comando}</div>
    <button onclick="copiar()">📋 Copiar comando</button>
  </div>
  <div class="paso"><span class="num">3</span> Seguí las instrucciones en pantalla (te va a pedir tus datos de Ualá para los cobros).</div>

  <div class="galeria">
    <h2>📖 Guía paso a paso</h2>
    {pasos_img}
  </div>

  <p class="foot">¿Problemas? Contactá a soporte.</p>
</div>
<script>
function copiar(){{
  const t=document.getElementById('cmd').textContent;
  navigator.clipboard.writeText(t).then(()=>{{
    const b=document.querySelector('button'); b.textContent='✅ ¡Copiado!';
    setTimeout(()=>b.textContent='📋 Copiar comando',2000);
  }});
}}
</script>
</body>
</html>"""
