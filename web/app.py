import os, requests
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse

app = FastAPI(title="SSH Vendor - Web")

# Cargar API key de DeepSeek desde .env
def cargar_env():
    env = {}
    try:
        with open(os.path.join(os.path.dirname(__file__), '.env')) as f:
            for linea in f:
                if '=' in linea and not linea.strip().startswith('#'):
                    k, v = linea.strip().split('=', 1)
                    env[k] = v
    except: pass
    return env

ENV = cargar_env()
DEEPSEEK_KEY = ENV.get('DEEPSEEK_API_KEY', '')
WHATSAPP = "5492634841144"

# Contexto del producto para el chatbot
CONTEXTO = """Sos el asistente de ventas de SSH Vendor, un producto que se vende por licencia.

QUE ES: SSH Vendor es un bot de WhatsApp que vende cuentas SSH de forma automatica. El comprador le escribe al bot, elige un plan de datos (GB), paga con Uala, y el bot le entrega la cuenta SSH al instante. Funciona 24 horas sin intervencion del dueno.

VENTAJA PRINCIPAL - MODELO POR GB: No se vende por tiempo sino por datos. El cliente compra GB (10, 25, 50, 100 GB). Cuando se le acaban, escribe "renovar", el bot lo reconoce automaticamente y le recarga sobre su misma cuenta. Esto genera clientes que vuelven una y otra vez.

COMO SE ADMINISTRA: El dueno maneja todo desde WhatsApp con comandos simples (cambiar precios, planes, mensajes, subir archivos de configuracion .hc). No necesita saber programacion.

INSTALACION: Se instala en el VPS del cliente con un solo comando. El dueno recibe una licencia y un enlace de instalacion.

SEGURIDAD: El bot funciona solo por chat privado. Si lo agregan a un grupo, se sale solo.

COBROS: Automaticos con Uala Bis. El bot genera el link de pago y verifica cuando el cliente paga.

REQUISITOS: El VPS del cliente necesita ADMRufu instalado con su API activa (se coordina de forma personalizada al comprar).

PRECIO: No des un precio especifico. Para consultar precios y comprar, deriva SIEMPRE al WhatsApp: https://wa.me/5492634841144

INSTRUCCIONES:
- Responde en espanol argentino, de forma amable, clara y breve.
- Enfocate en vender: destaca los beneficios.
- Cuando pregunten precio o como comprar, deriva al WhatsApp.
- Si preguntan algo que no sabes, deriva al WhatsApp.
- No inventes datos tecnicos que no esten aca."""

@app.get("/", response_class=HTMLResponse)
def home():
    return PAGINA.replace("__WHATSAPP__", WHATSAPP)

@app.post("/chat")
async def chat(req: Request):
    data = await req.json()
    pregunta = data.get("mensaje", "").strip()
    if not pregunta:
        return JSONResponse({"respuesta": "Escribime tu consulta 😊"})
    if not DEEPSEEK_KEY:
        return JSONResponse({"respuesta": f"Para consultas escribinos al WhatsApp: https://wa.me/{WHATSAPP}"})
    try:
        r = requests.post(
            "https://api.deepseek.com/chat/completions",
            headers={"Authorization": f"Bearer {DEEPSEEK_KEY}", "Content-Type": "application/json"},
            json={
                "model": "deepseek-chat",
                "messages": [
                    {"role": "system", "content": CONTEXTO},
                    {"role": "user", "content": pregunta}
                ],
                "temperature": 0.7,
                "max_tokens": 500
            },
            timeout=30
        )
        respuesta = r.json()["choices"][0]["message"]["content"]
        return JSONResponse({"respuesta": respuesta})
    except Exception as e:
        return JSONResponse({"respuesta": f"Disculpá, tuve un problema. Escribinos directo al WhatsApp: https://wa.me/{WHATSAPP}"})



PAGINA = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SSH Vendor - Vendé cuentas SSH automáticamente por WhatsApp</title>
<meta property="og:title" content="SSH Vendor - Tu negocio de SSH automatico">
<meta property="og:description" content="Bot de WhatsApp que vende cuentas SSH solo, las 24 horas. Vende por datos (GB) y genera clientes que vuelven.">
<meta property="og:image" content="https://i.postimg.cc/BnTkV6XV/og-image.jpg">
<meta property="og:type" content="website">
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
<link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@500;700;900&family=Rajdhani:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<style>
  :root{ --bg:#060a14; --panel:#0d1424; --green:#00ff9d; --green2:#10b981; --cyan:#22d3ee; --gold:#f0d68a; --txt:#c8d4e6; --dim:#6b7a95; }
  *{ box-sizing:border-box; margin:0; padding:0; }
  body{ font-family:'Rajdhani',sans-serif; background:var(--bg); color:var(--txt); line-height:1.6; overflow-x:hidden; }
  /* Fondo con grid tecnico animado */
  body::before{ content:''; position:fixed; inset:0; z-index:0;
    background-image:linear-gradient(rgba(0,255,157,.04) 1px,transparent 1px),linear-gradient(90deg,rgba(0,255,157,.04) 1px,transparent 1px);
    background-size:44px 44px; animation:gridmove 20s linear infinite; pointer-events:none; }
  @keyframes gridmove{ from{background-position:0 0;} to{background-position:44px 44px;} }
  /* Glow ambiental */
  body::after{ content:''; position:fixed; top:-20%; left:50%; transform:translateX(-50%); width:600px; height:600px; z-index:0;
    background:radial-gradient(circle,rgba(0,255,157,.10),transparent 60%); pointer-events:none; filter:blur(40px); }
  .wrap{ position:relative; z-index:1; max-width:760px; margin:0 auto; padding:0 20px; }
  /* Hero */
  .hero{ text-align:center; padding:50px 16px 24px; }
  .hero .eyebrow{ font-family:'JetBrains Mono',monospace; color:var(--green); font-size:13px; letter-spacing:3px; text-transform:uppercase; opacity:.85; margin-bottom:18px; }
  .hero .eyebrow::before{ content:'> '; }
  .hero img{ width:100%; max-width:620px; border-radius:18px; border:1px solid rgba(0,255,157,.25); box-shadow:0 0 50px rgba(0,255,157,.15),inset 0 0 30px rgba(0,255,157,.03); }
  h1{ font-family:'Orbitron',sans-serif; font-weight:900; font-size:32px; line-height:1.15; margin:26px 0 14px;
    background:linear-gradient(120deg,#fff,var(--green) 60%,var(--cyan)); -webkit-background-clip:text; -webkit-text-fill-color:transparent; background-clip:text; }
  .sub{ font-size:19px; color:var(--dim); max-width:560px; margin:0 auto 26px; }
  .btn-wa{ display:inline-flex; align-items:center; gap:8px; background:linear-gradient(135deg,#00ff9d,#10b981); color:#04120c; padding:16px 34px; border-radius:12px; font-family:'Rajdhani',sans-serif; font-size:19px; font-weight:700; text-decoration:none; box-shadow:0 0 30px rgba(0,255,157,.4); transition:transform .2s,box-shadow .2s; }
  .btn-wa:hover{ transform:translateY(-2px); box-shadow:0 0 45px rgba(0,255,157,.6); }
  .btn-wa:active{ transform:scale(.98); }
  /* Secciones */
  section{ padding:44px 0; }
  .sec-label{ font-family:'JetBrains Mono',monospace; color:var(--green); font-size:12px; letter-spacing:2px; text-align:center; margin-bottom:6px; opacity:.7; }
  h2{ font-family:'Orbitron',sans-serif; color:#fff; font-size:25px; margin-bottom:24px; text-align:center; font-weight:700; }
  /* Tarjetas */
  .card{ background:linear-gradient(160deg,rgba(13,20,36,.9),rgba(6,10,20,.9)); padding:22px; border-radius:14px; margin:14px 0; border:1px solid rgba(0,255,157,.12); position:relative; overflow:hidden; opacity:0; transform:translateY(24px); transition:opacity .6s,transform .6s; }
  .card.show{ opacity:1; transform:translateY(0); }
  .card::before{ content:''; position:absolute; left:0; top:0; bottom:0; width:3px; background:linear-gradient(var(--green),var(--cyan)); box-shadow:0 0 12px var(--green); }
  .card h3{ font-family:'Rajdhani',sans-serif; color:var(--green); font-size:20px; font-weight:700; margin-bottom:6px; }
  .card p{ color:var(--txt); font-size:16px; }
  /* Carrusel */
  .carousel{ position:relative; border-radius:16px; overflow:hidden; border:1px solid rgba(0,255,157,.2); box-shadow:0 0 40px rgba(0,255,157,.1); }
  .carousel-track{ display:flex; transition:transform .5s cubic-bezier(.22,.61,.36,1); }
  .carousel-track img{ width:100%; flex-shrink:0; display:block; }
  .carousel-btn{ position:absolute; top:50%; transform:translateY(-50%); background:rgba(6,10,20,.7); border:1px solid var(--green); color:var(--green); width:44px; height:44px; border-radius:50%; font-size:20px; cursor:pointer; display:flex; align-items:center; justify-content:center; z-index:2; transition:background .2s,box-shadow .2s; backdrop-filter:blur(4px); }
  .carousel-btn:hover{ background:var(--green); color:#04120c; box-shadow:0 0 20px var(--green); }
  .carousel-btn.prev{ left:12px; } .carousel-btn.next{ right:12px; }
  .carousel-dots{ display:flex; gap:7px; justify-content:center; margin-top:16px; flex-wrap:wrap; }
  .dot{ width:9px; height:9px; border-radius:50%; background:rgba(0,255,157,.25); cursor:pointer; transition:all .3s; }
  .dot.active{ background:var(--green); box-shadow:0 0 10px var(--green); width:24px; border-radius:5px; }
  /* Precio */
  .precio-box{ text-align:center; background:linear-gradient(160deg,rgba(13,20,36,.95),rgba(6,10,20,.95)); padding:34px 24px; border-radius:18px; margin:20px 0; border:1px solid rgba(0,255,157,.3); box-shadow:0 0 40px rgba(0,255,157,.1); position:relative; }
  .precio-box .tag{ font-family:'JetBrains Mono',monospace; color:var(--green); font-size:13px; letter-spacing:2px; }
  .precio-box h3{ font-family:'Orbitron',sans-serif; color:#fff; font-size:22px; margin:10px 0 8px; }
  .precio-box p{ font-size:16px; color:var(--dim); margin-bottom:20px; }
  .foot{ text-align:center; padding:36px 0; color:var(--dim); font-family:'JetBrains Mono',monospace; font-size:13px; }
  .foot::before{ content:'// '; color:var(--green); }
  /* Chat */
  #chat-btn{ position:fixed; bottom:22px; right:22px; background:#0d1424; width:66px; height:66px; border-radius:50%; border:2px solid #00ff9d; padding:4px; cursor:pointer; box-shadow:0 0 30px rgba(0,255,157,.5); z-index:100; transition:transform .2s; overflow:hidden; }
  #chat-btn:hover{ transform:scale(1.08); }
  #chat-box{ position:fixed; bottom:96px; right:22px; width:350px; max-width:calc(100vw - 44px); height:470px; background:var(--panel); border-radius:18px; box-shadow:0 0 50px rgba(0,0,0,.6); display:none; flex-direction:column; z-index:100; overflow:hidden; border:1px solid rgba(0,255,157,.3); }
  #chat-box.open{ display:flex; }
  .chat-head{ background:linear-gradient(135deg,#00ff9d,#10b981); color:#04120c; padding:15px; font-family:'Orbitron',sans-serif; font-weight:700; text-align:center; font-size:15px; }
  .chat-msgs{ flex:1; overflow-y:auto; padding:14px; display:flex; flex-direction:column; gap:10px; }
  .msg{ padding:10px 14px; border-radius:12px; max-width:86%; font-size:15px; }
  .msg.bot{ background:rgba(0,255,157,.08); color:var(--txt); align-self:flex-start; border:1px solid rgba(0,255,157,.15); }
  .msg.user{ background:linear-gradient(135deg,#00ff9d,#10b981); color:#04120c; align-self:flex-end; font-weight:600; }
  .chat-input{ display:flex; padding:10px; gap:8px; border-top:1px solid rgba(0,255,157,.15); }
  .chat-input input{ flex:1; padding:11px; border-radius:9px; border:1px solid rgba(0,255,157,.25); background:var(--bg); color:#fff; font-family:'Rajdhani',sans-serif; font-size:15px; }
  .chat-input input:focus{ outline:none; border-color:var(--green); }
  .chat-input button{ background:linear-gradient(135deg,#00ff9d,#10b981); color:#04120c; border:none; border-radius:9px; padding:0 18px; font-weight:700; cursor:pointer; font-size:16px; }
  @media(max-width:480px){ h1{font-size:26px;} h2{font-size:21px;} .hero{padding-top:36px;} }

  /* ===== PRELOADER ===== */
  #preloader{ position:fixed; inset:0; background:#060a14; z-index:99999; display:flex; flex-direction:column; align-items:center; justify-content:center; overflow:hidden; }
  #piso{ position:absolute; left:0; right:0; bottom:80px; height:1px; background:linear-gradient(90deg,transparent,rgba(0,255,157,.4),transparent); }
  .drop{ position:absolute; top:-30px; width:7px; height:7px; border-radius:0 50% 50% 50%; background:linear-gradient(#00ff9d,#10b981); transform:rotate(45deg); box-shadow:0 0 8px #00ff9d; }
  .splash{ position:absolute; width:4px; height:4px; border-radius:50%; background:#00ff9d; box-shadow:0 0 6px #00ff9d; }
  .logo-letras{ display:flex; justify-content:center; z-index:5; white-space:nowrap; margin-bottom:10px; }
  .logo-letras .letra{ font-family:'Orbitron',sans-serif; font-size:30px; font-weight:900; display:inline-block; background:linear-gradient(120deg,#fff,#00ff9d 55%,#22d3ee); -webkit-background-clip:text; -webkit-text-fill-color:transparent; background-clip:text; filter:drop-shadow(0 0 12px rgba(0,255,157,.6)); }
  .dev-sub{ display:flex; gap:10px; z-index:5; }
  .dev-sub .letra{ font-family:'JetBrains Mono',monospace; font-size:18px; font-weight:600; color:#22d3ee; letter-spacing:6px; text-shadow:0 0 12px rgba(34,211,238,.6); display:inline-block; }
  .pre-cargando{ position:absolute; bottom:60px; font-size:14px; letter-spacing:2px; opacity:0; font-weight:bold; font-family:'JetBrains Mono',monospace; }
  .pre-cargando span{ display:inline-block; animation:colores 3s linear infinite; }
  @keyframes colores{ 0%{color:#4285F4;} 25%{color:#EA4335;} 50%{color:#FBBC05;} 75%{color:#34A853;} 100%{color:#4285F4;} }
  @media(max-width:420px){ .logo-letras .letra{ font-size:24px; } }
</style>
</head>
<body>
<div id="preloader">
  <div id="piso"></div>
  <div class="logo-letras" id="logoLetras"></div>
  <div class="dev-sub" id="devSub"></div>
  <div class="pre-cargando" id="preCargando"></div>
</div>
<div class="wrap">
  <div class="hero">
    <div class="eyebrow">Sistema de venta automatica SSH</div>
    <img src="https://i.postimg.cc/5tZzQxm4/og-image.png" alt="SSH Vendor">
    <h1>Vende cuentas SSH en piloto automatico</h1>
    <p class="sub">Un bot de WhatsApp que atiende, cobra y entrega cuentas SSH solo, las 24 horas. Vos ganas mientras haces otra cosa.</p>
    <a class="btn-wa" href="https://wa.me/__WHATSAPP__?text=Hola!%20Quiero%20info%20sobre%20SSH%20Vendor" target="_blank">Consultar por WhatsApp</a>
  </div>

  <section>
    <div class="sec-label">[ CAPACIDADES ]</div>
    <h2>Que hace</h2>
    <div class="card"><h3>Vende solo, 24/7</h3><p>El comprador le escribe al bot, elige un plan, paga con Uala y recibe su cuenta al instante. Sin que vos hagas nada.</p></div>
    <div class="card"><h3>Vendes datos (GB), no tiempo</h3><p>El cliente compra GB. Cuando se le acaban, escribe "renovar", el bot lo reconoce y le recarga sobre su misma cuenta. Clientes que vuelven una y otra vez.</p></div>
    <div class="card"><h3>Lo manejas desde WhatsApp</h3><p>Cambias precios, planes y mensajes escribiendole al bot. Sin tocar la terminal, sin saber programar.</p></div>
    <div class="card"><h3>Cobros automaticos con Uala</h3><p>El bot genera el link de pago y verifica cuando el cliente pago. Todo automatico.</p></div>
  </section>

  <section>
    <div class="sec-label">[ EN ACCION ]</div>
    <h2>Asi funciona</h2>
    <div class="carousel">
      <div class="carousel-track" id="track">
        <img src="https://i.postimg.cc/s20KyN0Z/step-01.png" alt="1">
        <img src="https://i.postimg.cc/05SZRZGy/step-02.png" alt="2">
        <img src="https://i.postimg.cc/xTyRqC48/step-03.png" alt="3">
        <img src="https://i.postimg.cc/QMPgvWFL/step-04.png" alt="4">
        <img src="https://i.postimg.cc/tJdh1SDN/step-05.png" alt="5">
        <img src="https://i.postimg.cc/GhQFdf4d/step-06.png" alt="6">
        <img src="https://i.postimg.cc/Dwp1bbd3/step-07.png" alt="7">
        <img src="https://i.postimg.cc/j5Pf93VY/step-08.png" alt="8">
        <img src="https://i.postimg.cc/qvq30vf1/step-09.png" alt="9">
        <img src="https://i.postimg.cc/FRyfGfcQ/step-10.png" alt="10">
        <img src="https://i.postimg.cc/Gtz4wZXB/step-11.png" alt="11">
        <img src="https://i.postimg.cc/4NNKbx3m/step-12.png" alt="12">
      </div>
    </div>
    <div class="carousel-dots" id="dots"></div>
  </section>

  <section>
    <div class="precio-box">
      <div class="tag">[ ADQUIRI TU LICENCIA ]</div>
      <h3>Consulta el precio</h3>
      <p>Escribinos por WhatsApp y te contamos todo: precio, como funciona y como empezar tu negocio hoy.</p>
      <a class="btn-wa" href="https://wa.me/__WHATSAPP__?text=Hola!%20Quiero%20adquirir%20SSH%20Vendor" target="_blank">Quiero mi licencia</a>
    </div>
  </section>

  <div class="foot">SSH Vendor · Tu negocio de SSH funcionando solo</div>
</div>

<button id="chat-btn" onclick="toggleChat()"><img src="https://i.postimg.cc/3NjxRhtz/53869a70-77f1-11f1-8b37-d9243c29dc91.webp" alt="chat" style="width:100%;height:100%;object-fit:contain;border-radius:50%;"></button>
<div id="chat-box">
  <div class="chat-head">Asistente SSH Vendor</div>
  <div class="chat-msgs" id="msgs">
    <div class="msg bot">Hola! Soy el asistente de SSH Vendor. Preguntame lo que quieras sobre el producto.</div>
  </div>
  <div class="chat-input">
    <input id="chat-input" placeholder="Escribi tu pregunta..." onkeydown="if(event.key==='Enter')enviar()">
    <button onclick="enviar()">&#10148;</button>
  </div>
</div>
<script>
// ===== PRELOADER =====
(function(){
  const pre = document.getElementById('preloader');
  const pisoY = window.innerHeight - 80;
  function salpicar(x){
    const n = 5 + Math.floor(Math.random()*3);
    for(let i=0;i<n;i++){
      const s = document.createElement('div'); s.className='splash';
      s.style.left = x+'px'; s.style.top = pisoY+'px'; pre.appendChild(s);
      const ang = (Math.PI*(0.2+Math.random()*0.6))*-1;
      const dist = 15+Math.random()*25;
      gsap.to(s,{ x:Math.cos(ang)*dist*(Math.random()<0.5?1:-1), y:Math.sin(ang)*dist, opacity:0, duration:0.4+Math.random()*0.2, ease:'power2.out', onComplete:()=>s.remove() });
    }
  }
  function lanzarGota(){
    if(!document.getElementById('preloader')) return;
    const d = document.createElement('div'); d.className='drop';
    const x = Math.random()*window.innerWidth; d.style.left=x+'px'; pre.appendChild(d);
    gsap.fromTo(d,{y:-30},{y:pisoY-30, duration:1+Math.random()*0.6, ease:'power1.in', onComplete:()=>{ salpicar(x); d.remove(); }});
  }
  const gotasInt = setInterval(lanzarGota, 280);

  const texto = 'CHARLY_TRICKS';
  const cont = document.getElementById('logoLetras');
  texto.split('').forEach(l=>{ const sp=document.createElement('span'); sp.className='letra'; sp.textContent=l; cont.appendChild(sp); });
  const dev = 'DEV';
  const contDev = document.getElementById('devSub');
  dev.split('').forEach(l=>{ const sp=document.createElement('span'); sp.className='letra'; sp.textContent=l; contDev.appendChild(sp); });

  gsap.timeline()
    .fromTo('.logo-letras .letra',{ y:-180, opacity:0, scale:0.4 },{ y:0, opacity:1, scale:1, duration:1, ease:'elastic.out(1, 0.5)', stagger:0.05 })
    .fromTo('.dev-sub .letra',{ y:25, opacity:0 },{ y:0, opacity:1, duration:0.5, ease:'back.out(1.7)', stagger:0.1 }, '-=0.3')
    .to('#preCargando', { opacity:1, duration:0.4 }, '-=0.2');

  gsap.to('.logo-letras .letra', { filter:'drop-shadow(0 0 20px rgba(0,255,157,1))', duration:1.2, repeat:-1, yoyo:true, ease:'sine.inOut', stagger:{each:0.05, from:'center'}, delay:1.4 });

  const txtCarg = '> Iniciando sistema...';
  const contCarg = document.getElementById('preCargando');
  txtCarg.split('').forEach((letra,i)=>{ const sp=document.createElement('span'); sp.textContent=letra===' '?'\u00A0':letra; sp.style.animationDelay=(i*0.08)+'s'; contCarg.appendChild(sp); });

  // Desvanecer a los 7 segundos
  setTimeout(()=>{
    clearInterval(gotasInt);
    gsap.to('#preloader', { opacity:0, duration:0.8, ease:'power2.inOut', onComplete:()=>{ const p=document.getElementById('preloader'); if(p) p.remove(); } });
  }, 7000);
})();
</script>

<script>
// ===== CARRUSEL =====
let idx = 0;
const track = document.getElementById('track');
const total = track.children.length;
const dotsBox = document.getElementById('dots');
for(let i=0;i<total;i++){
  const d = document.createElement('div');
  d.className = 'dot' + (i===0?' active':'');
  d.onclick = () => { idx=i; actualizar(); reiniciarAuto(); };
  dotsBox.appendChild(d);
}
function actualizar(){
  track.style.transform = 'translateX(-' + (idx*100) + '%)';
  document.querySelectorAll('.dot').forEach((d,i)=>d.classList.toggle('active',i===idx));
}
function mover(dir){
  idx = (idx + dir + total) % total;
  actualizar(); reiniciarAuto();
}
let auto = setInterval(()=>{ idx=(idx+1)%total; actualizar(); }, 4000);
function reiniciarAuto(){ clearInterval(auto); auto=setInterval(()=>{ idx=(idx+1)%total; actualizar(); },4000); }
// Swipe tactil
let x0=null;
track.parentElement.addEventListener('touchstart',e=>x0=e.touches[0].clientX);
track.parentElement.addEventListener('touchend',e=>{ if(x0===null)return; const dx=e.changedTouches[0].clientX-x0; if(Math.abs(dx)>40) mover(dx>0?-1:1); x0=null; });

// ===== ANIMACION DE APARICION (scroll) =====
const obs = new IntersectionObserver((entries)=>{
  entries.forEach(e=>{ if(e.isIntersecting) e.target.classList.add('show'); });
},{ threshold:0.15 });
document.querySelectorAll('.card').forEach(c=>obs.observe(c));

// ===== CHAT =====
function toggleChat(){ document.getElementById('chat-box').classList.toggle('open'); }
async function enviar(){
  const inp=document.getElementById('chat-input'); const txt=inp.value.trim(); if(!txt)return;
  const msgs=document.getElementById('msgs');
  msgs.innerHTML+='<div class="msg user">'+txt+'</div>'; inp.value='';
  msgs.scrollTop=msgs.scrollHeight;
  const cargando=document.createElement('div'); cargando.className='msg bot'; cargando.textContent='...'; msgs.appendChild(cargando); msgs.scrollTop=msgs.scrollHeight;
  try{
    const r=await fetch('/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({mensaje:txt})});
    const d=await r.json(); cargando.remove();
    msgs.innerHTML+='<div class="msg bot">'+d.respuesta.replace(/\\n/g,'<br>')+'</div>';
    msgs.scrollTop=msgs.scrollHeight;
  }catch(e){ cargando.remove(); msgs.innerHTML+='<div class="msg bot">Escribinos al WhatsApp</div>'; }
}
</script>
</body>
</html>"""
