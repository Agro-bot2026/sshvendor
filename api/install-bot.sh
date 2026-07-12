#!/usr/bin/env bash
set -e
TOKEN="__TOKEN__"
API_BASE="__API_BASE__"
BOT_DIR="/opt/sshvendor-bot"
AZUL="\033[1;36m"; VERDE="\033[1;32m"; ROJO="\033[1;31m"; AMARILLO="\033[1;33m"; NC="\033[0m"

echo "=================================================="
echo "   INSTALADOR - BOT VENDEDOR DE SSH (por datos)"
echo "=================================================="

echo "==> Validando licencia..."
RESP=$(curl -s "$API_BASE/api/validate/$TOKEN")
echo "$RESP" | grep -q '"ok":true' || { echo "Licencia/IP no autorizada: $RESP"; exit 1; }
echo "Licencia validada."

echo "==> Instalando dependencias del sistema..."
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y curl netcat-openbsd ca-certificates >/dev/null 2>&1 || true
command -v node >/dev/null 2>&1 || { curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs; }
command -v pm2 >/dev/null 2>&1 || npm install -g pm2 >/dev/null 2>&1

mkdir -p "$BOT_DIR" && cd "$BOT_DIR"
echo "$TOKEN"    > .license
echo "$API_BASE" > .apibase

# ===== ELECCION DE CAPA DE MENSAJERIA =====
echo ""
echo "=================================================="
echo "   CONEXION A WHATSAPP"
echo "=================================================="
echo -e "${AZUL}  Como queres conectar el bot a WhatsApp?${NC}"
echo -e "${AZUL}    1) Baileys (escanear QR, gratis, mas simple)${NC}"
echo -e "${AZUL}    2) API oficial de Meta (mas estable, con botones)${NC}"
echo ""
read -p "$(echo -e ${VERDE}"  Elegi 1 o 2: "${NC})" CAPA_WPP < /dev/tty
CAPA_WPP=$(echo "$CAPA_WPP" | tr -cd "0-9")
if [ "$CAPA_WPP" != "2" ]; then CAPA_WPP="1"; fi
echo "$CAPA_WPP" > "$BOT_DIR/capa-wpp.txt"

if [ "$CAPA_WPP" = "2" ]; then
  echo ""
  echo -e "${AZUL}  --- Datos de la API oficial de Meta ---${NC}"
  echo -e "${AZUL}  (Los obtenes en developers.facebook.com -> tu app -> WhatsApp)${NC}"
  echo ""
  read -p "$(echo -e ${AZUL}"  Dominio del webhook (ej: botssh.tudominio.com): "${NC})" META_DOMINIO < /dev/tty
  read -p "$(echo -e ${AZUL}"  Token de acceso (permanente): "${NC})" META_TOKEN_IN < /dev/tty
  read -p "$(echo -e ${AZUL}"  Phone Number ID: "${NC})" META_PHONE_ID < /dev/tty
  read -p "$(echo -e ${AZUL}"  WhatsApp Business Account ID (WABA): "${NC})" META_WABA_ID < /dev/tty
  echo -e "${AZUL}  Verify token: inventa una palabra secreta (la vas a poner tambien en Meta)${NC}"
  read -p "$(echo -e ${AZUL}"  Verify token: "${NC})" META_VERIFY < /dev/tty
  read -p "$(echo -e ${AZUL}"  Tu numero de WhatsApp admin (ej: 549XXXXXXXXXX): "${NC})" META_ADMIN < /dev/tty
  META_ADMIN=$(echo "$META_ADMIN" | tr -cd "0-9")
  # Guardar .env del bot Meta
  cat > "$BOT_DIR/.env" <<METAENV
META_TOKEN=$META_TOKEN_IN
PHONE_NUMBER_ID=$META_PHONE_ID
WABA_ID=$META_WABA_ID
VERIFY_TOKEN=$META_VERIFY
PORT=8090
METAENV
  chmod 600 "$BOT_DIR/.env"
  echo "$META_DOMINIO" > "$BOT_DIR/dominio-webhook.txt"
  echo "$META_ADMIN"   > "$BOT_DIR/admin.txt"
  echo -e "${VERDE}  Datos de Meta guardados.${NC}"
fi

echo ""
echo "=================================================="
echo "   METODO DE COBRO"
echo "=================================================="
echo "  Con que queres cobrarles a tus clientes?"
echo "    1) Uala Bis"
echo "    2) Mercado Pago"
echo "    3) Los dos (el cliente elige al pagar)"
echo ""
read -p "  Elegi 1, 2 o 3: " METODO_PAGO < /dev/tty
METODO_PAGO=$(echo "$METODO_PAGO" | tr -cd "0-9")
if [ "$METODO_PAGO" != "2" ]; then echo "$METODO_PAGO" | grep -q "3" || [ "$METODO_PAGO" = "1" ] || METODO_PAGO="1"; fi
UALA_USER=""; UALA_CID=""; UALA_SECRET=""; MP_TOKEN=""
if [ "$METODO_PAGO" = "1" ] || [ "$METODO_PAGO" = "3" ]; then
  echo ""
  echo "  --- Credenciales de Uala Bis ---"
  read -p "  Username: " UALA_USER < /dev/tty
  read -p "  Client ID: " UALA_CID < /dev/tty
  read -p "  Client Secret: " UALA_SECRET < /dev/tty
fi
if [ "$METODO_PAGO" = "2" ] || [ "$METODO_PAGO" = "3" ]; then
  echo ""
  echo "  --- Token de Mercado Pago ---"
  echo "  (Access Token de produccion, desde tu panel de MP)"
  read -p "  MP Access Token: " MP_TOKEN < /dev/tty
fi
echo ""
echo ""
echo "  =========================================="
echo "  NUMERO DE ADMINISTRADOR"
echo "  =========================================="
echo "  Ingresa TU numero personal de WhatsApp (NO el del bot)."
echo "  Es el numero desde el que vas a manejar el bot y cambiar"
echo "  precios, dias, etc. escribiendole comandos al bot."
echo "  Formato: codigo de pais + numero, sin espacios ni signos."
echo "  Ejemplo: 54911XXXXXXXX"
echo ""
read -p "  Tu numero personal de WhatsApp (admin): " ADMIN_NUM < /dev/tty
ADMIN_NUM=$(echo "$ADMIN_NUM" | tr -cd "0-9")
echo "$ADMIN_NUM" > /opt/sshvendor-bot/admin.txt

cat > uala-credenciales.json <<UALACRED
{
  "username": "$UALA_USER",
  "client_id": "$UALA_CID",
  "client_secret": "$UALA_SECRET"
}
UALACRED
chmod 600 uala-credenciales.json
# Guardar token de Mercado Pago (si se cargo)
echo "$MP_TOKEN" > /opt/sshvendor-bot/mp-token.txt
chmod 600 /opt/sshvendor-bot/mp-token.txt
# Guardar el metodo de pago elegido
echo "$METODO_PAGO" > /opt/sshvendor-bot/metodo-pago.txt
echo "Credenciales de cobro guardadas (archivos protegidos)."

cat > package.json <<'PKG'
{ "name":"sshvendor-bot","version":"1.0.0","main":"index.js",
  "dependencies":{"@whiskeysockets/baileys":"^6.7.9","@hapi/boom":"^10.0.1","qrcode-terminal":"^0.12.0","pino":"^9.5.0","axios":"^1.7.0","express":"^4.21.0","dotenv":"^16.4.5","form-data":"^4.0.1"} }
PKG

cat > config.json <<'CFGJSON'
{
  "negocio": "Mi Servicio SSH",
  "moneda": "$",
  "modo": "datos",
  "planes": [
    { "id": 1, "nombre": "10 GB",  "mb": 10240,  "precio": 2500 },
    { "id": 2, "nombre": "25 GB",  "mb": 25600,  "precio": 5000 },
    { "id": 3, "nombre": "50 GB",  "mb": 51200,  "precio": 8000 },
    { "id": 4, "nombre": "100 GB", "mb": 102400, "precio": 13000 }
  ],
  "dias_cuenta": 30,
  "usar_hwid": false,
  "comando_archivo": "/archivo hwid",
  "admrufu_socket": "/tmp/admAPI.sock",
  "conexiones_por_cuenta": 1,
  "mensaje_bienvenida": "Hola! Bienvenido. Escribi *comprar* para ver los planes de datos disponibles."
}
CFGJSON

# ---- Registrar este VPS en ADMRufu (automatico) ----
echo ""
echo "=================================================="
echo "   CONFIGURACION DE ADMRUFU"
echo "=================================================="
ADM_SOCKET="/tmp/admAPI.sock"
if [ ! -S "$ADM_SOCKET" ]; then
  echo "ADVERTENCIA: No se encontro el socket de ADMRufu en $ADM_SOCKET"
  echo "Asegurate de tener ADMRufu instalado y su API activada (menu ADMRufu -> API)."
else
  echo "ADMRufu detectado. Necesito registrar este servidor para crear cuentas."
  echo ""
  read -p "  Contrasena root de este VPS: " ROOTPASS < /dev/tty
  SRVNAME="botssh"
  SSHPORT=$(grep -iE "^Port " /etc/ssh/sshd_config 2>/dev/null | head -1 | awk "{print \$2}")
  if [ -z "$SSHPORT" ]; then SSHPORT=22; fi
  echo "==> Registrando servidor en ADMRufu (puerto SSH: $SSHPORT)..."
  echo "/server add 127.0.0.1 $SSHPORT root $ROOTPASS $SRVNAME" | nc -U "$ADM_SOCKET" -q 5
  sleep 1
  NUM=$(echo "/server list" | nc -U "$ADM_SOCKET" -q 3 | grep "$SRVNAME" | grep -oE "^[0-9]+" | head -1)
  if [ -n "$NUM" ]; then
    echo "/server set $NUM" | nc -U "$ADM_SOCKET" -q 3 >/dev/null
    echo "Servidor registrado y activado en ADMRufu (numero $NUM)."
  else
    echo "ADVERTENCIA: No se pudo detectar el servidor. Registralo manualmente."
  fi
fi

cat > guard.js <<'GUARDEOF'
const fs=require('fs'), axios=require('axios');
const token=fs.readFileSync(__dirname+'/.license','utf8').trim();
const api=fs.readFileSync(__dirname+'/.apibase','utf8').trim();
const BOT_VERSION="1.0.0";
module.exports=async function guard(){
  try{
    const r=await axios.get(`${api}/api/validate/${token}?v=${BOT_VERSION}`,{timeout:10000});
    if(!r.data.ok){console.error('❌ Licencia no válida:',r.data.reason);process.exit(1);}
    console.log('✅ Licencia válida');
  }catch(e){console.error('❌ No se pudo validar la licencia:',e.message);process.exit(1);}
  setInterval(async function(){
    try{
      const rr=await axios.get(`${api}/api/validate/${token}?v=${BOT_VERSION}`,{timeout:10000});
      if(!rr.data.ok){process.exit(1);}
    }catch(e){}
  }, 60*60*1000);
};
GUARDEOF

cat > admrufu.js <<'ADMRUFUEOF'
const { execFile } = require('child_process');
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync(__dirname + '/config.json', 'utf8'));
const SOCKET = cfg.admrufu_socket || '/tmp/admAPI.sock';
const CONEXIONES = cfg.conexiones_por_cuenta || 1;
const DIAS_CUENTA = cfg.dias_cuenta || 30;

function generarPassword(longitud = 10) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  let p = '';
  for (let i = 0; i < longitud; i++) p += chars[Math.floor(Math.random() * chars.length)];
  return p;
}

function ejecutarComando(comando) {
  return new Promise((resolve) => {
    execFile('bash', ['-c', `echo -e '${comando}' | nc -U ${SOCKET} -q 3`],
      { timeout: 30000 }, (err, stdout) => {
        if (err) { resolve(''); return; }
        resolve((stdout || '').trim());
      });
  });
}

// Lee el límite actual de una cuenta y lo devuelve en MB (number entero).
function formatDatos(mb) {
  if (mb >= 1024 && mb % 1024 === 0) return (mb / 1024) + ' GB';
  if (mb >= 1024) return (Math.round((mb / 1024) * 100) / 100) + ' GB';
  return Math.round(mb) + ' MB';
}
function parseMB(info) {
  const m = info.match(/Limit:\s*([\d.]+)\s*(GB|MB|TB)/i);
  if (!m) return 0;
  let val = parseFloat(m[1]);
  const unidad = m[2].toUpperCase();
  if (unidad === 'GB') val = val * 1024;
  else if (unidad === 'TB') val = val * 1024 * 1024;
  return Math.round(val); // en MB entero
}

// ---- CUENTAS SSH (usuario/contraseña) ----
async function crearCuentaDatos(usuario, mb) {
  const password = generarPassword();
  const comando = `/ssh add ${usuario} ${password} ${CONEXIONES} ${DIAS_CUENTA}`;
  const respuesta = await ejecutarComando(comando);
  const ok = /creado|success/i.test(respuesta);
  if (!ok) return { success: false, error: respuesta };
  await ejecutarComando(`/ssh set limit ${usuario} ${Math.round(mb)} MB`);
  return { success: true, user: usuario, password, mb };
}

async function leerLimiteMB(usuario) {
  const info = await ejecutarComando(`/ssh info ${usuario}`);
  return parseMB(info);
}

async function recargarDatos(usuario, mbNuevos) {
  const nuevoTotalMB = Math.round(mbNuevos);
  await ejecutarComando(`/ssh set use ${usuario}`);
  const respuesta = await ejecutarComando(`/ssh set limit ${usuario} ${nuevoTotalMB} MB`);
  const ok = /l[ií]mite|limit/i.test(respuesta);
  const rExp = await ejecutarComando(`/ssh set expire ${usuario} ${DIAS_CUENTA}`);
  if (!/unlok/i.test(rExp)) {
    const info = await ejecutarComando(`/ssh info ${usuario}`);
    if (/[^n]Loked/i.test(info) && !/Unloked/i.test(info)) {
      await ejecutarComando(`/ssh set status ${usuario}`);
    }
  }
  return { success: ok, totalMB: nuevoTotalMB, dias: DIAS_CUENTA, respuesta };
}

async function infoCuenta(usuario) { return await ejecutarComando(`/ssh info ${usuario}`); }

// ---- CUENTAS POR HWID ----
async function crearCuentaHwid(hwid, nombre, mb) {
  const comando = `/hwid add ${hwid} ${nombre} ${DIAS_CUENTA}`;
  const respuesta = await ejecutarComando(comando);
  if (/already exists|ya existe/i.test(respuesta)) {
    const r = await recargarHwid(hwid, mb);
    if (r.success) return { success: true, hwid, nombre, mb, recargada: true };
    return { success: false, error: 'No se pudo recargar la cuenta existente: ' + r.respuesta };
  }
  const ok = /creat|success|creado/i.test(respuesta);
  if (!ok) return { success: false, error: respuesta };
  await ejecutarComando(`/hwid set limit ${hwid} ${Math.round(mb)} MB`);
  return { success: true, hwid, nombre, mb };
}

async function leerLimiteHwidMB(hwid) {
  const info = await ejecutarComando(`/hwid info ${hwid}`);
  return parseMB(info);
}

async function recargarHwid(hwid, mbNuevos) {
  const nuevoTotalMB = Math.round(mbNuevos);
  await ejecutarComando(`/hwid set use ${hwid}`);
  const respuesta = await ejecutarComando(`/hwid set limit ${hwid} ${nuevoTotalMB} MB`);
  const ok = /l[ií]mite|limit/i.test(respuesta);
  await ejecutarComando(`/hwid set expire ${hwid} ${DIAS_CUENTA}`);
  return { success: ok, totalMB: nuevoTotalMB, dias: DIAS_CUENTA, respuesta };
}

function validarHwid(hwid) {
  return /^[a-fA-F0-9]{32}$/.test((hwid || '').trim());
}

module.exports = { crearCuentaDatos, recargarDatos, leerLimiteMB, infoCuenta, generarPassword, ejecutarComando, crearCuentaHwid, recargarHwid, leerLimiteHwidMB, validarHwid };
ADMRUFUEOF

cat > uala.js <<'UALAEOF'
const axios = require('axios');
const fs = require('fs');
const AUTH_URL = "https://auth.developers.ar.ua.la/v2/api/auth/token";
const CHECKOUT_URL = "https://checkout.developers.ar.ua.la/v2/api/checkout";
const ORDERS_URL = "https://checkout.developers.ar.ua.la/v2/api/orders";
function cargarCredenciales() {
  return JSON.parse(fs.readFileSync(__dirname + '/uala-credenciales.json', 'utf8'));
}
function urlWhatsappBot() {
  try {
    const num = fs.readFileSync(__dirname + '/mi-numero.txt', 'utf8').trim();
    if (num && /^[0-9]+$/.test(num)) return `https://wa.me/${num}`;
  } catch (e) {}
  return "https://wa.me";
}

async function getToken() {
  const c = cargarCredenciales();
  const r = await axios.post(AUTH_URL, {
    username: c.username, client_id: c.client_id,
    client_secret_id: c.client_secret, grant_type: "client_credentials"
  }, { headers: { "Content-Type": "application/json" }, timeout: 20000 });
  return r.data.access_token;
}
async function crearOrden(monto, descripcion, referencia) {
  const token = await getToken();
  const r = await axios.post(CHECKOUT_URL, {
    amount: String(monto), description: descripcion,
    callback_success: urlWhatsappBot(),
    callback_fail: urlWhatsappBot(),
    notification_url: "https://connect-vpn.top/noop",
    external_reference: referencia
  }, { headers: { "Content-Type": "application/json", "Authorization": `Bearer ${token}` }, timeout: 30000 });
  const data = r.data;
  return { checkout_link: data.links.checkout_link, uuid: data.uuid || data.id || (data.links && data.links.uuid) || "" };
}
async function consultarOrden(uuid) {
  const token = await getToken();
  const r = await axios.get(`${ORDERS_URL}/${uuid}`, { headers: { "Authorization": `Bearer ${token}` }, timeout: 20000 });
  return r.data.status || "";
}
module.exports = { crearOrden, consultarOrden, getToken };
UALAEOF

cat > mercadopago.js <<'MPEOF'
const axios = require('axios');
const fs = require('fs');
const MP_API = "https://api.mercadopago.com";
function cargarToken() {
  return fs.readFileSync(__dirname + '/mp-token.txt', 'utf8').trim();
}
function urlWhatsappBot() {
  try {
    const num = fs.readFileSync(__dirname + '/mi-numero.txt', 'utf8').trim();
    if (num && /^[0-9]+$/.test(num)) return `https://wa.me/${num}`;
  } catch (e) {}
  return "https://wa.me";
}
async function crearOrden(monto, descripcion, referencia) {
  const token = cargarToken();
  const pref = {
    items: [{ title: descripcion, quantity: 1, unit_price: Number(monto), currency_id: "ARS" }],
    external_reference: String(referencia),
    back_urls: { success: urlWhatsappBot() },
    auto_return: "approved"
  };
  const r = await axios.post(`${MP_API}/checkout/preferences`, pref, {
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${token}` },
    timeout: 30000
  });
  return { checkout_link: r.data.init_point, uuid: r.data.id || "" };
}
async function consultarOrden(referencia) {
  const token = cargarToken();
  const r = await axios.get(`${MP_API}/v1/payments/search`, {
    params: { external_reference: String(referencia), sort: "date_created", criteria: "desc" },
    headers: { "Authorization": `Bearer ${token}` },
    timeout: 20000
  });
  const resultados = (r.data && r.data.results) || [];
  for (const p of resultados) {
    if (p.status === "approved") return "APPROVED";
  }
  return "pending";
}
module.exports = { crearOrden, consultarOrden };
MPEOF

cat > enviar.js <<'ENVIAREOF'
require('dotenv').config();
const axios = require('axios');
const fs = require('fs');
const FormData = require('form-data');
const TOKEN = process.env.META_TOKEN;
const PHONE_ID = process.env.PHONE_NUMBER_ID;
const API = `https://graph.facebook.com/v21.0/${PHONE_ID}/messages`;
function headers() { return { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' }; }
async function enviarTexto(to, texto) {
  try {
    await axios.post(API, { messaging_product: 'whatsapp', to, type: 'text', text: { body: texto } }, { headers: headers() });
    return true;
  } catch (e) { console.error('Error enviarTexto:', e.response ? JSON.stringify(e.response.data) : e.message); return false; }
}
async function enviarBotones(to, texto, botones) {
  try {
    await axios.post(API, {
      messaging_product: 'whatsapp', to, type: 'interactive',
      interactive: { type: 'button', body: { text: texto },
        action: { buttons: botones.slice(0,3).map(b => ({ type: 'reply', reply: { id: b.id, title: b.titulo.slice(0,20) } })) } }
    }, { headers: headers() });
    return true;
  } catch (e) { console.error('Error enviarBotones:', e.response ? JSON.stringify(e.response.data) : e.message); return false; }
}
async function enviarLista(to, texto, tituloBoton, opciones) {
  try {
    await axios.post(API, {
      messaging_product: 'whatsapp', to, type: 'interactive',
      interactive: { type: 'list', body: { text: texto },
        action: { button: tituloBoton.slice(0,20), sections: [{ title: 'Opciones',
          rows: opciones.slice(0,10).map(o => ({ id: o.id, title: o.titulo.slice(0,24), description: (o.descripcion||'').slice(0,72) })) }] } }
    }, { headers: headers() });
    return true;
  } catch (e) { console.error('Error enviarLista:', e.response ? JSON.stringify(e.response.data) : e.message); return false; }
}
async function enviarDocumento(to, rutaArchivo, nombre) {
  try {
    const form = new FormData();
    form.append('messaging_product', 'whatsapp');
    form.append('file', fs.createReadStream(rutaArchivo), { filename: nombre, contentType: 'text/plain' });
    const up = await axios.post(`https://graph.facebook.com/v21.0/${PHONE_ID}/media`, form, {
      headers: { Authorization: `Bearer ${TOKEN}`, ...form.getHeaders() }
    });
    const mediaId = up.data.id;
    await axios.post(API, {
      messaging_product: 'whatsapp', to, type: 'document',
      document: { id: mediaId, filename: nombre }
    }, { headers: headers() });
    return true;
  } catch (e) { console.error('Error enviarDocumento:', e.response ? JSON.stringify(e.response.data) : e.message); return false; }
}
async function enviarBotonURL(to, texto, textoBoton, url) {
  try {
    await axios.post(API, {
      messaging_product: 'whatsapp', to, type: 'interactive',
      interactive: { type: 'cta_url', body: { text: texto },
        action: { name: 'cta_url', parameters: { display_text: textoBoton.slice(0,20), url: url } } }
    }, { headers: headers() });
    return true;
  } catch (e) { console.error('Error enviarBotonURL:', e.response ? JSON.stringify(e.response.data) : e.message); return false; }
}
module.exports = { enviarTexto, enviarBotones, enviarLista, enviarDocumento, enviarBotonURL };
ENVIAREOF

cat > webhook.js <<'WEBHOOKEOF'
require('dotenv').config();
const express = require('express');
const { procesarMensaje } = require('./bot');
const app = express();
app.use(express.json());
const VERIFY_TOKEN = process.env.VERIFY_TOKEN;
const PORT = process.env.PORT || 8090;
app.get('/webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];
  if (mode === 'subscribe' && token === VERIFY_TOKEN) { res.status(200).send(challenge); }
  else { res.sendStatus(403); }
});
app.post('/webhook', async (req, res) => {
  res.sendStatus(200);
  try {
    const entry = req.body.entry && req.body.entry[0];
    const change = entry && entry.changes && entry.changes[0];
    const value = change && change.value;
    const mensaje = value && value.messages && value.messages[0];
    if (!mensaje) return;
    const from = mensaje.from;
    let texto = '';
    let botonId = null;
    if (mensaje.type === 'text') { texto = mensaje.text.body; }
    else if (mensaje.type === 'interactive') {
      const inter = mensaje.interactive;
      if (inter.type === 'button_reply') { botonId = inter.button_reply.id; texto = inter.button_reply.title; }
      else if (inter.type === 'list_reply') { botonId = inter.list_reply.id; texto = inter.list_reply.title; }
    } else if (mensaje.type === 'document') { texto = '__documento__'; }
    await procesarMensaje({ from, texto, botonId, mensaje, value });
  } catch (e) { console.error('Error webhook:', e.message); }
});
app.listen(PORT, () => console.log(`Bot Cloud API escuchando en puerto ${PORT}`));
WEBHOOKEOF

cat > bot.js <<'BOTJSEOF'
require('dotenv').config();
const fs = require('fs');
const axios = require('axios');
const { enviarTexto, enviarBotones, enviarLista, enviarDocumento, enviarBotonURL } = require('./enviar');
const admrufu = require('./admrufu');
const uala = require('./uala');
const mercadopago = require('./mercadopago');

const DIR = __dirname;
let METODO_PAGO = '1';
try { METODO_PAGO = fs.readFileSync(DIR + '/metodo-pago.txt', 'utf8').trim() || '1'; } catch (e) {}

const CFG = JSON.parse(fs.readFileSync(DIR + '/config.json', 'utf8'));
const VENTAS_FILE = DIR + '/ventas.json';
const CLIENTES_FILE = DIR + '/clientes.json';

const TOKEN = process.env.META_TOKEN;
const PHONE_ID = process.env.PHONE_NUMBER_ID;

function cargarVentas() {
  try { return JSON.parse(fs.readFileSync(VENTAS_FILE, 'utf8')); }
  catch { return { ordenes: {}, procesadas: {} }; }
}
function guardarVentas(v) { fs.writeFileSync(VENTAS_FILE, JSON.stringify(v, null, 2)); }
let VENTAS = cargarVentas();

function cargarClientes() {
  try { return JSON.parse(fs.readFileSync(CLIENTES_FILE, 'utf8')); }
  catch { return {}; }
}
function guardarClientes(c) { fs.writeFileSync(CLIENTES_FILE, JSON.stringify(c, null, 2)); }
let CLIENTES = cargarClientes();

const sesiones = {};

function planPorId(id) { return CFG.planes.find(p => String(p.id) === String(id).trim()); }
function generarUsuario() { return `user${Math.floor(1000 + Math.random() * 9000)}`; }

function formatDatos(mb) {
  if (mb >= 1024 && mb % 1024 === 0) return (mb / 1024) + ' GB';
  if (mb >= 1024) return (Math.round((mb / 1024) * 100) / 100) + ' GB';
  return Math.round(mb) + ' MB';
}

function guardarConfig() { fs.writeFileSync(DIR + '/config.json', JSON.stringify(CFG, null, 2)); }

async function enviarMenuPlanes(to) {
  const opciones = CFG.planes.map(p => ({
    id: 'plan_' + p.id,
    titulo: p.nombre,
    descripcion: CFG.moneda + p.precio
  }));
  await enviarLista(to, `🛒 *${CFG.negocio}*\n\nElegí tu paquete de datos:`, 'Ver planes', opciones);
}

async function iniciarPago(to, plan, hwid) {
  if (METODO_PAGO === '3') {
    sesiones[to] = { paso: 'eligiendo_pasarela', plan, hwid: hwid || null };
    await enviarBotones(to, '💳 ¿Cómo querés pagar?', [
      { id: 'pas_uala', titulo: 'Ualá Bis' },
      { id: 'pas_mp', titulo: 'Mercado Pago' }
    ]);
    return;
  }
  await generarLinkPago(to, plan, hwid);
}

async function generarLinkPago(to, plan, hwid, pasarela) {
  try {
    await enviarTexto(to, '⏳ Generando tu link de pago, esperá un momento...');
    const ref = `${to}-${Date.now()}`;
    const pas = pasarela || (METODO_PAGO === '2' ? 'mp' : 'uala');
    const modulo = pas === 'mp' ? mercadopago : uala;
    const orden = await modulo.crearOrden(plan.precio, `${plan.nombre} - ${CFG.negocio}`, ref);
    VENTAS.ordenes[orden.uuid] = { jid: to, plan_id: plan.id, mb: plan.mb, precio: plan.precio, uuid: orden.uuid, ref, creada: Date.now(), estado: 'pendiente', hwid: hwid || null, pasarela: pas };
    guardarVentas(VENTAS);
    sesiones[to] = { paso: 'pagando', uuid: orden.uuid };
    await enviarBotonURL(to, `💳 *${plan.nombre}* — ${CFG.moneda}${plan.precio}\n\nTocá el botón para pagar de forma segura.\n\nApenas completes el pago, te activo los datos automáticamente. ⏳`, '💳 Pagar ahora', orden.checkout_link);
  } catch (e) {
    console.error('Error creando orden:', e.message);
    await enviarTexto(to, '❌ Hubo un error generando el pago. Probá de nuevo en un momento.');
  }
}

async function entregarCompra(o, hwidRecibido) {
  const to = o.jid;
  const clienteExistente = CLIENTES[to];
  const usarHwidAhora = !!(hwidRecibido || (clienteExistente && clienteExistente.hwid));

  if (usarHwidAhora) {
    if (clienteExistente && clienteExistente.hwid) {
      const r = await admrufu.recargarHwid(clienteExistente.hwid, o.mb);
      if (r.success) {
        CLIENTES[to].mb = (CLIENTES[to].mb || 0) + o.mb;
        guardarClientes(CLIENTES);
        await enviarTexto(to, `✅ *¡Recarga confirmada!*\n\n📊 *Datos agregados:* ${formatDatos(o.mb)}\n📅 *Validez renovada:* ${r.dias} días\n\n¡Gracias! 🚀`);
        return true;
      } else {
        await enviarTexto(to, '⚠️ Tu pago se confirmó pero hubo un problema con la recarga. Contactá al soporte.');
        return false;
      }
    } else {
      const nombre = generarUsuario();
      const r = await admrufu.crearCuentaHwid(hwidRecibido, nombre, o.mb);
      if (r.success) {
        CLIENTES[to] = { hwid: hwidRecibido, nombre, mb: o.mb };
        guardarClientes(CLIENTES);
        await enviarTexto(to, `✅ *¡Cuenta activada!*\n\n📊 *Datos:* ${formatDatos(o.mb)}\n📅 *Validez:* ${CFG.dias_cuenta} días\n\n📲 Pedí tu archivo de configuración escribiendo el comando */hc*\n\n¡Gracias por tu compra! 🚀`);
        return true;
      } else {
        await enviarTexto(to, '⚠️ Tu pago se confirmó pero hubo un problema activando tu cuenta. Contactá al soporte.');
        console.error('Error HWID:', r.error);
        return false;
      }
    }
  } else {
    if (clienteExistente && clienteExistente.usuario) {
      const r = await admrufu.recargarDatos(clienteExistente.usuario, o.mb);
      if (r.success) {
        CLIENTES[to].mb = (CLIENTES[to].mb || 0) + o.mb;
        guardarClientes(CLIENTES);
        await enviarTexto(to, `✅ *¡Recarga confirmada!*\n\n👤 *Usuario:* ${clienteExistente.usuario}\n📊 *Datos agregados:* ${formatDatos(o.mb)}\n📅 *Validez renovada:* ${r.dias} días\n\n¡Gracias! 🚀`);
        return true;
      } else {
        await enviarTexto(to, '⚠️ Tu pago se confirmó pero hubo un problema con la recarga. Contactá al soporte.');
        return false;
      }
    } else {
      const usuario = generarUsuario();
      const r = await admrufu.crearCuentaDatos(usuario, o.mb);
      if (r.success) {
        CLIENTES[to] = { usuario: r.user, mb: o.mb };
        guardarClientes(CLIENTES);
        await enviarTexto(to, `✅ *¡Pago confirmado!* Tu cuenta está lista:\n\n👤 *Usuario:* ${r.user}\n🔑 *Contraseña:* ${r.password}\n📊 *Datos:* ${formatDatos(o.mb)}\n📅 *Validez:* ${CFG.dias_cuenta} días\n\n¡Gracias por tu compra! 🚀`);
        return true;
      } else {
        await enviarTexto(to, '⚠️ Tu pago se confirmó pero hubo un problema creando la cuenta. Contactá al soporte.');
        console.error('Error ADMRufu:', r.error);
        return false;
      }
    }
  }
}

async function descargarMedia(mediaId) {
  const meta = await axios.get(`https://graph.facebook.com/v21.0/${mediaId}`, {
    headers: { Authorization: `Bearer ${TOKEN}` }
  });
  const url = meta.data.url;
  const bin = await axios.get(url, {
    headers: { Authorization: `Bearer ${TOKEN}` },
    responseType: 'arraybuffer'
  });
  return Buffer.from(bin.data);
}

async function procesarMensaje({ from, texto, botonId, mensaje, value }) {
  const to = from;
  const t = (texto || '').toLowerCase().trim();

  if (mensaje && mensaje.type === 'document') {
    let ADMIN_NUM = '';
    try { ADMIN_NUM = fs.readFileSync(DIR + '/admin.txt', 'utf8').trim(); } catch (e) {}
    if (ADMIN_NUM && from === ADMIN_NUM) {
      const doc = mensaje.document;
      const nombreArch = doc.filename || ('archivo_' + Date.now() + '.hc');
      if (nombreArch.toLowerCase().endsWith('.hc')) {
        try {
          const buffer = await descargarMedia(doc.id);
          if (!fs.existsSync(DIR + '/hc_files')) fs.mkdirSync(DIR + '/hc_files');
          fs.writeFileSync(DIR + '/hc_files/' + nombreArch, buffer);
          await enviarTexto(to, `✅ Archivo *${nombreArch}* guardado. Los compradores lo reciben con /hc`);
        } catch (e) {
          await enviarTexto(to, '❌ Error guardando el archivo: ' + e.message);
        }
      } else {
        await enviarTexto(to, '⚠️ Solo se aceptan archivos .hc');
      }
      return;
    }
    return;
  }

  let ADMIN_NUM = '';
  try { ADMIN_NUM = fs.readFileSync(DIR + '/admin.txt', 'utf8').trim(); } catch (e) {}
  const esAdmin = ADMIN_NUM && from === ADMIN_NUM;

  if (esAdmin && t.startsWith('/') && t !== '/hc') {
    if (t === '/config' || t === '/admin' || t === '/ayuda') {
      let txt = '⚙️ *PANEL DE CONFIGURACION*\n\n';
      txt += `🏪 Negocio: *${CFG.negocio}*\n`;
      txt += `📅 Dias por cuenta: *${CFG.dias_cuenta}*\n`;
      txt += `🔌 Conexiones: *${CFG.conexiones_por_cuenta}*\n\n`;
      txt += '📦 *PLANES:*\n';
      CFG.planes.forEach(p => { txt += `  *${p.id}.* ${p.nombre} — ${CFG.moneda}${p.precio}\n`; });
      txt += '\n📝 *COMANDOS:*\n';
      txt += '`/precio [id] [valor]`\n`/nombre [id] [texto]`\n`/agregarplan [cant] [GB/MB] [precio]`\n`/borrarplan [id]`\n`/dias [numero]`\n`/negocio [texto]`\n`/mensaje [texto]`\n`/borrarhc`';
      await enviarTexto(to, txt);
      return;
    }
    if (t.startsWith('/precio')) {
      const p = texto.split(/\s+/); const plan = planPorId(p[1]); const v = parseInt(p[2]);
      if (!plan || isNaN(v)) { await enviarTexto(to, '❌ Uso: /precio [id] [valor]\nEj: /precio 1 3000'); return; }
      plan.precio = v; guardarConfig();
      await enviarTexto(to, `✅ Precio de *${plan.nombre}* ahora es ${CFG.moneda}${v}`); return;
    }
    if (t.startsWith('/nombre')) {
      const p = texto.split(/\s+/); const plan = planPorId(p[1]); const nom = p.slice(2).join(' ');
      if (!plan || !nom) { await enviarTexto(to, '❌ Uso: /nombre [id] [texto]'); return; }
      plan.nombre = nom; guardarConfig();
      await enviarTexto(to, `✅ Nombre del plan ${p[1]} ahora es *${nom}*`); return;
    }
    if (t.startsWith('/agregarplan')) {
      const p = texto.split(/\s+/);
      const cantidad = parseFloat(p[1]);
      const unidad = (p[2] || '').toUpperCase();
      const precio = parseInt(p[3]);
      if (isNaN(cantidad) || (unidad !== 'GB' && unidad !== 'MB') || isNaN(precio)) {
        await enviarTexto(to, 'Uso: /agregarplan [cantidad] [GB/MB] [precio]\nEj: /agregarplan 100 MB 500\nEj: /agregarplan 10 GB 5000'); return;
      }
      const mbTotal = unidad === 'GB' ? Math.round(cantidad * 1024) : Math.round(cantidad);
      const nombre = cantidad + ' ' + unidad;
      const nuevoId = CFG.planes.length ? Math.max(...CFG.planes.map(p => p.id)) + 1 : 1;
      CFG.planes.push({ id: nuevoId, nombre: nombre, mb: mbTotal, precio: precio });
      guardarConfig();
      await enviarTexto(to, 'Plan agregado:\n' + nuevoId + '. ' + nombre + ' - ' + CFG.moneda + precio); return;
    }
    if (t.startsWith('/borrarplan')) {
      const p = texto.split(/\s+/);
      const id = parseInt(p[1]);
      const idx = CFG.planes.findIndex(pl => pl.id === id);
      if (isNaN(id) || idx === -1) { await enviarTexto(to, 'Uso: /borrarplan [id]\nUsa /config para ver los ids.'); return; }
      const borrado = CFG.planes.splice(idx, 1)[0];
      guardarConfig();
      await enviarTexto(to, 'Plan borrado: ' + borrado.nombre); return;
    }
    if (t.startsWith('/dias')) {
      const p = texto.split(/\s+/); const d = parseInt(p[1]);
      if (isNaN(d)) { await enviarTexto(to, '❌ Uso: /dias [numero]'); return; }
      CFG.dias_cuenta = d; guardarConfig();
      await enviarTexto(to, `✅ Dias por cuenta ahora es *${d}*`); return;
    }
    if (t.startsWith('/negocio')) {
      const nv = texto.split(/\s+/).slice(1).join(' ');
      if (!nv) { await enviarTexto(to, '❌ Uso: /negocio [texto]'); return; }
      CFG.negocio = nv; guardarConfig();
      await enviarTexto(to, `✅ Negocio ahora es *${nv}*`); return;
    }
    if (t.startsWith('/mensaje')) {
      const nv = texto.split(/\s+/).slice(1).join(' ');
      if (!nv) { await enviarTexto(to, '❌ Uso: /mensaje [texto]'); return; }
      CFG.mensaje_bienvenida = nv; guardarConfig();
      await enviarTexto(to, `✅ Mensaje de bienvenida actualizado`); return;
    }
    if (t === '/borrarhc') {
      try {
        const dir = DIR + '/hc_files';
        let n = 0;
        if (fs.existsSync(dir)) { for (const f of fs.readdirSync(dir)) { fs.unlinkSync(dir + '/' + f); n++; } }
        await enviarTexto(to, `🗑️ Se borraron ${n} archivo(s) .hc. Ya podés subir los nuevos.`);
      } catch (e) { await enviarTexto(to, '❌ Error al borrar: ' + e.message); }
      return;
    }
    await enviarTexto(to, 'Comando no reconocido. Escribí /config para ver opciones.'); return;
  }

  if (t === '/hc') {
    const dir = DIR + '/hc_files';
    let archivos = [];
    try { if (fs.existsSync(dir)) archivos = fs.readdirSync(dir).filter(f => f.toLowerCase().endsWith('.hc')); } catch (e) {}
    if (archivos.length === 0) {
      await enviarTexto(to, 'ℹ️ Todavía no hay archivos de configuración disponibles.');
      return;
    }
    await enviarTexto(to, `📲 Te envío ${archivos.length} archivo(s) de configuración:`);
    for (const nombre of archivos) {
      try { await enviarDocumento(to, dir + '/' + nombre, nombre); }
      catch (e) { console.error('Error enviando hc:', e.message); }
    }
    return;
  }

  if (botonId) { return await manejarBoton(to, botonId); }

  if (t === 'hola' || t === 'menu' || t === 'comprar' || t === 'inicio' || t === 'recargar') {
    await enviarMenuPlanes(to);
    return;
  }

  const ses = sesiones[to];
  if (ses && ses.paso === 'hwid_antes_pago') {
    const hwid = texto.trim();
    if (!admrufu.validarHwid(hwid)) {
      await enviarTexto(to, '❌ Ese HWID no parece válido. Tiene que ser un código de 32 caracteres. Abrí HTTP Custom → menú → HWID, copialo y pegalo acá.');
      return;
    }
    await iniciarPago(to, ses.plan, hwid);
    return;
  }

  await enviarTexto(to, CFG.mensaje_bienvenida);
}

async function manejarBoton(to, botonId) {
  if (botonId.startsWith('plan_')) {
    const id = botonId.replace('plan_', '');
    const plan = planPorId(id);
    if (!plan) { await enviarTexto(to, '❌ Ese plan ya no está disponible.'); return; }
    const clienteExistente = CLIENTES[to];
    if (clienteExistente && clienteExistente.hwid) { await iniciarPago(to, plan, clienteExistente.hwid); return; }
    if (clienteExistente && clienteExistente.usuario) { await iniciarPago(to, plan, null); return; }
    sesiones[to] = { paso: 'eligiendo_modo', plan };
    await enviarBotones(to, '📦 ¿Cómo querés tu cuenta?', [
      { id: 'modo_userpass', titulo: 'Usuario y clave' },
      { id: 'modo_hwid', titulo: 'HWID' }
    ]);
    return;
  }
  if (botonId === 'modo_userpass') {
    const ses = sesiones[to];
    if (!ses || !ses.plan) { await enviarMenuPlanes(to); return; }
    await iniciarPago(to, ses.plan, null);
    return;
  }
  if (botonId === 'modo_hwid') {
    const ses = sesiones[to];
    if (!ses || !ses.plan) { await enviarMenuPlanes(to); return; }
    sesiones[to] = { paso: 'hwid_antes_pago', plan: ses.plan };
    await enviarTexto(to, '📲 Necesito tu *HWID* para activar tu cuenta:\n\n1. Abrí HTTP Custom\n2. Andá al menú HWID\n3. Copialo y pegalo acá 👇');
    return;
  }
  if (botonId === 'pas_uala') {
    const ses = sesiones[to];
    if (!ses || !ses.plan) { await enviarMenuPlanes(to); return; }
    await generarLinkPago(to, ses.plan, ses.hwid, 'uala');
    return;
  }
  if (botonId === 'pas_mp') {
    const ses = sesiones[to];
    if (!ses || !ses.plan) { await enviarMenuPlanes(to); return; }
    await generarLinkPago(to, ses.plan, ses.hwid, 'mp');
    return;
  }
  await enviarTexto(to, 'Opción no reconocida. Escribí *comprar* para empezar.');
}

setInterval(async () => {
  const pendientes = Object.values(VENTAS.ordenes).filter(o => o.estado === 'pendiente');
  for (const o of pendientes) {
    if (Date.now() - o.creada > 30 * 60 * 1000) { o.estado = 'expirada'; guardarVentas(VENTAS); continue; }
    try {
      const moduloVerif = (o.pasarela === 'mp') ? mercadopago : uala;
      const idConsulta = (o.pasarela === 'mp') ? o.ref : o.uuid;
      const status = await moduloVerif.consultarOrden(idConsulta);
      if (status === 'APPROVED') {
        if (VENTAS.procesadas[o.uuid]) { o.estado = 'procesada'; guardarVentas(VENTAS); continue; }
        const clienteExistente = CLIENTES[o.jid];
        const hwidParaUsar = o.hwid || (clienteExistente && clienteExistente.hwid) || null;
        const entregado = await entregarCompra(o, hwidParaUsar);
        if (entregado) { VENTAS.procesadas[o.uuid] = true; o.estado = 'procesada'; guardarVentas(VENTAS); }
        else { console.error('Entrega falló, se reintentará:', o.uuid); }
      } else if (status === 'REJECTED') {
        o.estado = 'rechazada'; guardarVentas(VENTAS);
        await enviarTexto(o.jid, '❌ Tu pago fue rechazado. Podés intentar de nuevo escribiendo *comprar*.');
      }
    } catch (e) {}
  }
}, 20000);

module.exports = { procesarMensaje };
BOTJSEOF

cat > index.js <<'INDEXEOF'
const fs = require('fs'), path = require('path');
const guard = require('./guard');
const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion, downloadMediaMessage } = require('@whiskeysockets/baileys');
const qrcode = require('qrcode-terminal');
const { Boom } = require('@hapi/boom');
const pino = require('pino');

const admrufu = require('./admrufu');
const uala = require('./uala');
const mercadopago = require('./mercadopago');
let METODO_PAGO = '1';
try { METODO_PAGO = fs.readFileSync(__dirname + '/metodo-pago.txt', 'utf8').trim() || '1'; } catch(e) {}

const CFG = JSON.parse(fs.readFileSync(__dirname + '/config.json', 'utf8'));
const VENTAS_FILE = __dirname + '/ventas.json';
const CLIENTES_FILE = __dirname + '/clientes.json';
const USAR_HWID = CFG.usar_hwid === true;

function cargarVentas() {
  try { return JSON.parse(fs.readFileSync(VENTAS_FILE, 'utf8')); }
  catch { return { ordenes: {}, procesadas: {} }; }
}
function guardarVentas(v) { fs.writeFileSync(VENTAS_FILE, JSON.stringify(v, null, 2)); }
let VENTAS = cargarVentas();

function cargarClientes() {
  try { return JSON.parse(fs.readFileSync(CLIENTES_FILE, 'utf8')); }
  catch { return {}; }
}
function guardarClientes(c) { fs.writeFileSync(CLIENTES_FILE, JSON.stringify(c, null, 2)); }
let CLIENTES = cargarClientes();

const sesiones = {};

function menuPlanes() {
  let txt = `🛒 *${CFG.negocio}*\n\nElegí un paquete de datos respondiendo con el número:\n\n`;
  CFG.planes.forEach(p => { txt += `*${p.id}.* ${p.nombre} — ${CFG.moneda}${p.precio}\n`; });
  txt += `\n_Escribí el número del paquete que querés._`;
  return txt;
}
function planPorId(id) { return CFG.planes.find(p => String(p.id) === String(id).trim()); }
function generarUsuario() { return `user${Math.floor(1000 + Math.random() * 9000)}`; }

// Variable global para el socket (lo setea main)
let SOCK = null;

// Genera el link de pago. Si hwid viene, lo guarda en la orden para usarlo al entregar.
async function iniciarPago(jid, plan, hwid) {
  // Si el metodo es "los dos" (3), preguntar la pasarela; si no, ir directo
  if (METODO_PAGO === '3') {
    sesiones[jid] = { paso: 'eligiendo_pasarela', plan, hwid: hwid || null };
    await SOCK.sendMessage(jid, { text: '\uD83D\uDCB3 *Como queres pagar?*\n\n*1. Uala Bis*\n*2. Mercado Pago*\n\n_Responde *1* o *2*_' });
    return;
  }
  await generarLinkPago(jid, plan, hwid);
}
async function generarLinkPago(jid, plan, hwid, pasarela) {
  try {
    await SOCK.sendMessage(jid, { text: '⏳ Generando tu link de pago, esperá un momento...' });
    const ref = `${jid.split('@')[0]}-${Date.now()}`;
    const pas = pasarela || (METODO_PAGO === '2' ? 'mp' : 'uala');
    const modulo = pas === 'mp' ? mercadopago : uala;
    const orden = await modulo.crearOrden(plan.precio, `${plan.nombre} - ${CFG.negocio}`, ref);
    VENTAS.ordenes[orden.uuid] = { jid, plan_id: plan.id, mb: plan.mb, precio: plan.precio, uuid: orden.uuid, ref, creada: Date.now(), estado: 'pendiente', hwid: hwid || null, pasarela: pas };
    guardarVentas(VENTAS);
    sesiones[jid] = { paso: 'pagando', uuid: orden.uuid };
    await SOCK.sendMessage(jid, { text: `💳 *${plan.nombre}* — ${CFG.moneda}${plan.precio}\n\nPagá desde este link:\n${orden.checkout_link}\n\nCuando completes el pago, te activo los datos automáticamente. ⏳` });
  } catch (e) {
    console.error('Error creando orden:', e.message);
    try { await SOCK.sendMessage(jid, { text: '❌ Hubo un error generando el pago. Probá de nuevo en un momento.' }); } catch(er){}
  }
}

async function main() {
  await guard();

  const { state, saveCreds } = await useMultiFileAuthState(path.join(__dirname, 'auth'));
  const { version } = await fetchLatestBaileysVersion();
  const sock = makeWASocket({
    version,
    auth: state,
    logger: pino({ level: 'silent' }),
    printQRInTerminal: false,
    connectTimeoutMs: 60000,
    keepAliveIntervalMs: 25000,
    retryRequestDelayMs: 5000,
    markOnlineOnConnect: false,
    browser: ['SSHVendor', 'Chrome', '120.0.0']
  });

  SOCK = sock;
  sock.ev.on('creds.update', saveCreds);

  sock.ev.on('connection.update', (u) => {
    const { connection, lastDisconnect, qr } = u;
    if (qr) { qrcode.generate(qr, { small: true }); console.log('📲 Escaneá el QR para vincular WhatsApp'); }
    if (connection === 'close') {
      const code = (lastDisconnect?.error instanceof Boom) ? lastDisconnect.error.output.statusCode : 0;
      if (code !== DisconnectReason.loggedOut) {
        console.log('🔄 Reconectando en 5s...');
        setTimeout(() => { main(); }, 5000);
      } else { console.log('❌ Sesión cerrada. Revinculá con QR.'); }
    }
    if (connection === 'open') {
      console.log('✅ Bot conectado a WhatsApp');
      try {
        const miNum = (sock.user?.id || '').split(':')[0].split('@')[0];
        if (miNum && /^[0-9]+$/.test(miNum)) {
          fs.writeFileSync(__dirname + '/mi-numero.txt', miNum);
        }
      } catch (e) {}
    }
  });

  sock.ev.on('groups.upsert', async (grupos) => {
    for (const g of grupos) { try { await sock.groupLeave(g.id); console.log('🚪 Salí del grupo:', g.id); } catch (e) {} }
  });
  sock.ev.on('group-participants.update', async (ev) => {
    try {
      const yo = sock.user?.id?.split(':')[0];
      if (ev.action === 'add' && yo && ev.participants.some(p => p.includes(yo))) {
        await sock.groupLeave(ev.id); console.log('🚪 Me agregaron a un grupo, salí:', ev.id);
      }
    } catch (e) {}
  });

  // Procesa la entrega tras el pago (cuenta nueva o recarga), segun modo (SSH normal o HWID)
  async function entregarCompra(o, hwidRecibido) {
    const clienteExistente = CLIENTES[o.jid];

    const usarHwidAhora = !!(hwidRecibido || (clienteExistente && clienteExistente.hwid));
    if (usarHwidAhora) {
      // ----- MODO HWID -----
      if (clienteExistente && clienteExistente.hwid) {
        // Recargar cuenta HWID existente
        const r = await admrufu.recargarHwid(clienteExistente.hwid, o.mb);
        if (r.success) {
          CLIENTES[o.jid].mb = (CLIENTES[o.jid].mb || 0) + o.mb;
          guardarClientes(CLIENTES);
          try { await sock.sendMessage(o.jid, { text: `✅ *¡Recarga confirmada!*\n\n📊 *Datos agregados:* ${formatDatos(o.mb)}\n📅 *Validez renovada:* ${r.dias} días\n\n¡Gracias! 🚀` }); } catch(e){}
          return true;
        } else {
          try { await sock.sendMessage(o.jid, { text: `⚠️ Tu pago se confirmó pero hubo un problema con la recarga. Contactá al soporte.` }); } catch(e){}
          return false;
        }
      } else {
        // Cuenta HWID nueva (necesita el HWID)
        const nombre = generarUsuario();
        const r = await admrufu.crearCuentaHwid(hwidRecibido, nombre, o.mb);
        if (r.success) {
          CLIENTES[o.jid] = { hwid: hwidRecibido, nombre, mb: o.mb };
          guardarClientes(CLIENTES);
          try { await sock.sendMessage(o.jid, { text: `✅ *¡Cuenta activada!*\n\n📊 *Datos:* ${formatDatos(o.mb)}\n📅 *Validez:* ${CFG.dias_cuenta} días\n\n📲 Pedí tu archivo de configuración escribiendo el comando */hc*\n\n¡Gracias por tu compra! 🚀` }); } catch(e){}
          return true;
        } else {
          try { await sock.sendMessage(o.jid, { text: `⚠️ Tu pago se confirmó pero hubo un problema activando tu cuenta. Contactá al soporte.` }); } catch(e){}
          console.error('Error HWID:', r.error);
          return false;
        }
      }
    } else {
      // ----- MODO SSH NORMAL -----
      if (clienteExistente && clienteExistente.usuario) {
        const r = await admrufu.recargarDatos(clienteExistente.usuario, o.mb);
        if (r.success) {
          CLIENTES[o.jid].mb = (CLIENTES[o.jid].mb || 0) + o.mb;
          guardarClientes(CLIENTES);
          try { await sock.sendMessage(o.jid, { text: `✅ *¡Recarga confirmada!*\n\n👤 *Usuario:* ${clienteExistente.usuario}\n📊 *Datos agregados:* ${formatDatos(o.mb)}\n📅 *Validez renovada:* ${r.dias} días\n\n¡Gracias! 🚀` }); } catch(e){}
          return true;
        } else {
          try { await sock.sendMessage(o.jid, { text: `⚠️ Tu pago se confirmó pero hubo un problema con la recarga. Contactá al soporte.` }); } catch(e){}
          return false;
        }
      } else {
        const usuario = generarUsuario();
        const r = await admrufu.crearCuentaDatos(usuario, o.mb);
        if (r.success) {
          CLIENTES[o.jid] = { usuario: r.user, mb: o.mb };
          guardarClientes(CLIENTES);
          try { await sock.sendMessage(o.jid, { text: `✅ *¡Pago confirmado!* Tu cuenta está lista:\n\n👤 *Usuario:* ${r.user}\n🔑 *Contraseña:* ${r.password}\n📊 *Datos:* ${formatDatos(o.mb)}\n📅 *Validez:* ${CFG.dias_cuenta} días\n\n¡Gracias por tu compra! 🚀` }); } catch(e){}
          return true;
        } else {
          try { await sock.sendMessage(o.jid, { text: `⚠️ Tu pago se confirmó pero hubo un problema creando la cuenta. Contactá al soporte.` }); } catch(e){}
          console.error('Error ADMRufu:', r.error);
          return false;
        }
      }
    }
  }

  sock.ev.on('messages.upsert', async (m) => {
    try {
      const msg = m.messages[0];
      if (!msg.message || msg.key.fromMe) return;
      const jid = msg.key.remoteJid;
      if (jid.endsWith('@g.us')) return;
      const texto = (msg.message.conversation || msg.message.extendedTextMessage?.text || '').trim();
      // ===== SUBIDA DE ARCHIVOS .HC (solo admin) =====
      const docMsg = msg.message.documentMessage || msg.message.documentWithCaptionMessage?.message?.documentMessage;
      if (docMsg) {
        let ADMIN_NUM_D = '';
        try { ADMIN_NUM_D = fs.readFileSync(__dirname + '/admin.txt', 'utf8').trim(); } catch(e) {}
        const numRem_D = (msg.key.senderPn || jid).split('@')[0].split(':')[0];
        if (ADMIN_NUM_D && numRem_D === ADMIN_NUM_D) {
          const nombreArch = docMsg.fileName || ('archivo_' + Date.now() + '.hc');
          if (nombreArch.toLowerCase().endsWith('.hc')) {
            try {
              const buffer = await downloadMediaMessage(msg, 'buffer', {});
              if (!fs.existsSync(__dirname + '/hc_files')) fs.mkdirSync(__dirname + '/hc_files');
              fs.writeFileSync(__dirname + '/hc_files/' + nombreArch, buffer);
              await sock.sendMessage(jid, { text: `✅ Archivo *${nombreArch}* guardado. Los compradores lo reciben con /hc` });
            } catch(e) {
              await sock.sendMessage(jid, { text: '❌ Error guardando el archivo: ' + e.message });
            }
          } else {
            await sock.sendMessage(jid, { text: '⚠️ Solo se aceptan archivos .hc' });
          }
          return;
        }
      }
      if (!texto) return;
      const t = texto.toLowerCase();
      // ===== COMANDOS DE CONFIGURACION (solo el dueño/admin) =====
      let ADMIN_NUM = '';
      try { ADMIN_NUM = fs.readFileSync(__dirname + '/admin.txt', 'utf8').trim(); } catch(e) {}
      const numRemitente = (msg.key.senderPn || jid).split('@')[0].split(':')[0];
      const esAdmin = ADMIN_NUM && numRemitente === ADMIN_NUM;
      if (esAdmin && t.startsWith('/') && t !== '/hc') {
        function guardarConfig() { fs.writeFileSync(__dirname + '/config.json', JSON.stringify(CFG, null, 2)); }
        if (t === '/config' || t === '/admin' || t === '/ayuda') {
          let txt = '⚙️ *PANEL DE CONFIGURACION*\n\n';
          txt += `🏪 Negocio: *${CFG.negocio}*\n`;
          txt += `📅 Dias por cuenta: *${CFG.dias_cuenta}*\n`;
          txt += `🔌 Conexiones: *${CFG.conexiones_por_cuenta}*\n\n`;
          txt += '📦 *PLANES:*\n';
          CFG.planes.forEach(p => { txt += `  *${p.id}.* ${p.nombre} — ${CFG.moneda}${p.precio}\n`; });
          txt += '\n📝 *COMANDOS:*\n';
          txt += '`/precio [id] [valor]`\n`/nombre [id] [texto]`\n`/agregarplan [cant] [GB/MB] [precio]`\n`/borrarplan [id]`\n`/dias [numero]`\n`/negocio [texto]`\n`/mensaje [texto]`\n';
          await sock.sendMessage(jid, { text: txt });
          return;
        }
        if (t.startsWith('/precio')) {
          const p = texto.split(/\s+/); const plan = planPorId(p[1]); const v = parseInt(p[2]);
          if (!plan || isNaN(v)) { await sock.sendMessage(jid, { text: '❌ Uso: /precio [id] [valor]\nEj: /precio 1 3000' }); return; }
          plan.precio = v; guardarConfig();
          await sock.sendMessage(jid, { text: `✅ Precio de *${plan.nombre}* ahora es ${CFG.moneda}${v}` }); return;
        }
        if (t.startsWith('/nombre')) {
          const p = texto.split(/\s+/); const plan = planPorId(p[1]); const nom = p.slice(2).join(' ');
          if (!plan || !nom) { await sock.sendMessage(jid, { text: '❌ Uso: /nombre [id] [texto]' }); return; }
          plan.nombre = nom; guardarConfig();
          await sock.sendMessage(jid, { text: `✅ Nombre del plan ${p[1]} ahora es *${nom}*` }); return;
        }
        if (t.startsWith('/agregarplan')) {
          const p = texto.split(/\s+/);
          const cantidad = parseFloat(p[1]);
          const unidad = (p[2] || '').toUpperCase();
          const precio = parseInt(p[3]);
          if (isNaN(cantidad) || (unidad !== 'GB' && unidad !== 'MB') || isNaN(precio)) {
            await sock.sendMessage(jid, { text: 'Uso: /agregarplan [cantidad] [GB/MB] [precio]\nEj: /agregarplan 100 MB 500\nEj: /agregarplan 10 GB 5000' }); return;
          }
          const mbTotal = unidad === 'GB' ? Math.round(cantidad * 1024) : Math.round(cantidad);
          const nombre = cantidad + ' ' + unidad;
          const nuevoId = CFG.planes.length ? Math.max(...CFG.planes.map(p => p.id)) + 1 : 1;
          CFG.planes.push({ id: nuevoId, nombre: nombre, mb: mbTotal, precio: precio });
          guardarConfig();
          await sock.sendMessage(jid, { text: 'Plan agregado:\n' + nuevoId + '. ' + nombre + ' - ' + CFG.moneda + precio }); return;
        }
        if (t.startsWith('/borrarplan')) {
          const p = texto.split(/\s+/);
          const id = parseInt(p[1]);
          const idx = CFG.planes.findIndex(pl => pl.id === id);
          if (isNaN(id) || idx === -1) { await sock.sendMessage(jid, { text: 'Uso: /borrarplan [id]\nUsa /config para ver los ids.' }); return; }
          const borrado = CFG.planes.splice(idx, 1)[0];
          guardarConfig();
          await sock.sendMessage(jid, { text: 'Plan borrado: ' + borrado.nombre }); return;
        }
        if (t.startsWith('/dias')) {
          const p = texto.split(/\s+/); const d = parseInt(p[1]);
          if (isNaN(d)) { await sock.sendMessage(jid, { text: '❌ Uso: /dias [numero]' }); return; }
          CFG.dias_cuenta = d; guardarConfig();
          await sock.sendMessage(jid, { text: `✅ Dias por cuenta ahora es *${d}*` }); return;
        }
        if (t.startsWith('/negocio')) {
          const nv = texto.split(/\s+/).slice(1).join(' ');
          if (!nv) { await sock.sendMessage(jid, { text: '❌ Uso: /negocio [texto]' }); return; }
          CFG.negocio = nv; guardarConfig();
          await sock.sendMessage(jid, { text: `✅ Negocio ahora es *${nv}*` }); return;
        }
        if (t.startsWith('/mensaje')) {
          const nv = texto.split(/\s+/).slice(1).join(' ');
          if (!nv) { await sock.sendMessage(jid, { text: '❌ Uso: /mensaje [texto]' }); return; }
          CFG.mensaje_bienvenida = nv; guardarConfig();
          await sock.sendMessage(jid, { text: `✅ Mensaje de bienvenida actualizado` }); return;
        }
        if (t === '/borrarhc') {
          try {
            const dir = __dirname + '/hc_files';
            let n = 0;
            if (fs.existsSync(dir)) { for (const f of fs.readdirSync(dir)) { fs.unlinkSync(dir + '/' + f); n++; } }
            await sock.sendMessage(jid, { text: `🗑️ Se borraron ${n} archivo(s) .hc. Ya podés subir los nuevos.` });
          } catch(e) { await sock.sendMessage(jid, { text: '❌ Error al borrar: ' + e.message }); }
          return;
        }
        await sock.sendMessage(jid, { text: 'Comando no reconocido. Escribí /config para ver opciones.' }); return;
      }
      // ===== FIN COMANDOS ADMIN =====
      // ===== /hc PUBLICO (cualquiera puede pedirlo) =====
      if (t === '/hc') {
        const dir = __dirname + '/hc_files';
        let archivos = [];
        try { if (fs.existsSync(dir)) archivos = fs.readdirSync(dir).filter(f => f.toLowerCase().endsWith('.hc')); } catch(e) {}
        if (archivos.length === 0) {
          await sock.sendMessage(jid, { text: 'ℹ️ Todavía no hay archivos de configuración disponibles.' });
          return;
        }
        await sock.sendMessage(jid, { text: `📲 Te envío ${archivos.length} archivo(s) de configuración:` });
        for (const nombre of archivos) {
          try {
            const contenido = fs.readFileSync(dir + '/' + nombre);
            await sock.sendMessage(jid, { document: contenido, fileName: nombre, mimetype: 'application/octet-stream' });
          } catch(e) {}
        }
        return;
      }

      if (t === 'hola' || t === 'menu' || t === 'comprar' || t === 'inicio' || t === 'recargar') {
        sesiones[jid] = { paso: 'eligiendo' };
        await sock.sendMessage(jid, { text: menuPlanes() });
        return;
      }

      const ses = sesiones[jid];

      // Si el bot está esperando el HWID ANTES del pago
      if (ses && ses.paso === 'hwid_antes_pago') {
        const hwid = texto.trim();
        if (!admrufu.validarHwid(hwid)) {
          await sock.sendMessage(jid, { text: '❌ Ese HWID no parece válido. Tiene que ser un código de 32 caracteres. Abrí HTTP Custom → menú → HWID, copialo y pegalo acá.' });
          return;
        }
        // HWID válido: ahora sí generar el link de pago, guardando el HWID en la orden
        await iniciarPago(jid, ses.plan, hwid);
        return;
      }
      if (ses && ses.paso === 'eligiendo_pasarela') {
        const op = texto.trim();
        if (op === '1') { await generarLinkPago(jid, ses.plan, ses.hwid, 'uala'); return; }
        if (op === '2') { await generarLinkPago(jid, ses.plan, ses.hwid, 'mp'); return; }
        await sock.sendMessage(jid, { text: '❌  Respondé *1* (Uala) o *2* (Mercado Pago).' });
        return;
      }

      if (ses && ses.paso === 'eligiendo') {
        const plan = planPorId(texto);
        if (!plan) { await sock.sendMessage(jid, { text: '❌ Opción no válida. Respondé con el número del paquete.' }); return; }
        const clienteExistente = CLIENTES[jid];
        // Si usa HWID y es cliente NUEVO, pedir el HWID ANTES del pago
        if (clienteExistente && clienteExistente.hwid) {
          await iniciarPago(jid, plan, clienteExistente.hwid); return;
        }
        if (clienteExistente && clienteExistente.usuario) {
          await iniciarPago(jid, plan, null); return;
        }
        // Cliente NUEVO: preguntar como quiere la cuenta
        sesiones[jid] = { paso: 'eligiendo_modo', plan };
        await sock.sendMessage(jid, { text: '\uD83D\uDCE6 *Como queres tu cuenta?*\n\n*1. Usuario y contrasena*\nMas facil de usar.\n\n*2. HWID (por dispositivo)*\nMas seguro, se activa solo en tu celular.\n\n_Responde *1* o *2*_' });
        return;
      }
      if (ses && ses.paso === 'eligiendo_modo') {
        const op = texto.trim();
        if (op === '1') {
          await iniciarPago(jid, ses.plan, null);
          return;
        }
        if (op === '2') {
          sesiones[jid] = { paso: 'hwid_antes_pago', plan: ses.plan };
          await sock.sendMessage(jid, { text: '\uD83D\uDCF2 Necesito tu *HWID* para activar tu cuenta:\n\n1. Abri HTTP Custom\n2. Anda al menu HWID\n3. Copialo y pegalo aca' });
          return;
        }
        await sock.sendMessage(jid, { text: 'Responde *1* (usuario y contrasena) o *2* (HWID).' });
        return;
      }
      await sock.sendMessage(jid, { text: CFG.mensaje_bienvenida });
    } catch (e) { console.error('Error en mensaje:', e.message); }
  });

  setInterval(async () => {
    const pendientes = Object.values(VENTAS.ordenes).filter(o => o.estado === 'pendiente');
    for (const o of pendientes) {
      if (Date.now() - o.creada > 30 * 60 * 1000) { o.estado = 'expirada'; guardarVentas(VENTAS); continue; }
      try {
        const moduloVerif = (o.pasarela === 'mp') ? mercadopago : uala;
        const idConsulta = (o.pasarela === 'mp') ? o.ref : o.uuid;
        const status = await moduloVerif.consultarOrden(idConsulta);
        if (status === 'APPROVED') {
          // Si ya se entregó del todo, marcar y seguir
          if (VENTAS.procesadas[o.uuid]) { o.estado = 'procesada'; guardarVentas(VENTAS); continue; }

          // El HWID (si aplica) ya viene guardado en la orden desde antes del pago.
          const clienteExistente = CLIENTES[o.jid];
          const hwidParaUsar = o.hwid || (clienteExistente && clienteExistente.hwid) || null;
          const entregado = await entregarCompra(o, hwidParaUsar);
          if (entregado) {
            VENTAS.procesadas[o.uuid] = true;
            o.estado = 'procesada';
            guardarVentas(VENTAS);
          } else {
            console.error('Entrega falló, se reintentará en el próximo ciclo:', o.uuid);
          }
        } else if (status === 'REJECTED') {
          o.estado = 'rechazada'; guardarVentas(VENTAS);
          await sock.sendMessage(o.jid, { text: '❌ Tu pago fue rechazado. Podés intentar de nuevo escribiendo *comprar*.' });
        }
      } catch (e) { }
    }
  }, 20000);
}

main();
INDEXEOF

# ---- Crear el comando sshbot ----
cat > /usr/local/bin/sshbot <<'SSHBOTCMD'
#!/usr/bin/env bash
BOT_DIR="/opt/sshvendor-bot"
cd "$BOT_DIR" || { echo "Bot no instalado."; exit 1; }
if [ "$1" = "reset" ]; then rm -rf "$BOT_DIR/auth"; echo "Sesion borrada, se generara un QR nuevo."; fi
if [ "$1" = "update" ]; then
  TOK=$(cat "$BOT_DIR/.license"); APIB=$(cat "$BOT_DIR/.apibase")
  cp "$BOT_DIR/config.json" /tmp/config_cliente.json 2>/dev/null
  cp "$BOT_DIR/admin.txt" /tmp/admin_cliente.txt 2>/dev/null
  rm -rf /tmp/hc_files_cliente 2>/dev/null; cp -r "$BOT_DIR/hc_files" /tmp/hc_files_cliente 2>/dev/null
  pm2 stop sshvendor-bot 2>/dev/null
  bash <(curl -s "$APIB/install/$TOK")
  if [ -f /tmp/config_cliente.json ]; then
    node -e "
      const fs=require('fs');
      const nuevo=JSON.parse(fs.readFileSync('$BOT_DIR/config.json'));
      const viejo=JSON.parse(fs.readFileSync('/tmp/config_cliente.json'));
      const final=Object.assign({}, nuevo, viejo);
      fs.writeFileSync('$BOT_DIR/config.json', JSON.stringify(final,null,2));
    " 2>/dev/null && echo "Configuracion del cliente conservada."
  fi
  [ -f /tmp/admin_cliente.txt ] && cp /tmp/admin_cliente.txt "$BOT_DIR/admin.txt" && echo "Numero de admin conservado."
  [ -d /tmp/hc_files_cliente ] && rm -rf "$BOT_DIR/hc_files" && cp -r /tmp/hc_files_cliente "$BOT_DIR/hc_files" && echo "Archivos .hc conservados."
  pm2 start "$BOT_DIR/index.js" --name sshvendor-bot 2>/dev/null && pm2 save
  exit 0
fi
if [ "$1" = "hwid" ]; then
  if [ "$2" = "on" ]; then
    node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync('$BOT_DIR/config.json'));c.usar_hwid=true;fs.writeFileSync('$BOT_DIR/config.json',JSON.stringify(c,null,2));"
    pm2 restart sshvendor-bot >/dev/null 2>&1
    echo "Modo HWID ACTIVADO. El bot ahora pide el HWID tras el pago."
  elif [ "$2" = "off" ]; then
    node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync('$BOT_DIR/config.json'));c.usar_hwid=false;fs.writeFileSync('$BOT_DIR/config.json',JSON.stringify(c,null,2));"
    pm2 restart sshvendor-bot >/dev/null 2>&1
    echo "Modo HWID DESACTIVADO. El bot crea cuentas con usuario y contrasena."
  else
    ESTADO=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$BOT_DIR/config.json')).usar_hwid?'ACTIVADO':'DESACTIVADO')")
    echo "Modo HWID actualmente: $ESTADO"
    echo "Usa: sshbot hwid on   /   sshbot hwid off"
  fi
  exit 0
fi
if [ "$1" = "pago" ]; then
  echo "=================================================="
  echo "   CONFIGURAR METODO DE COBRO"
  echo "=================================================="
  echo "  Con que queres cobrarles a tus clientes?"
  echo "    1) Uala Bis"
  echo "    2) Mercado Pago"
  echo "    3) Los dos (el cliente elige al pagar)"
  echo ""
  read -p "  Elegi 1, 2 o 3: " MP_METODO < /dev/tty
  MP_METODO=$(echo "$MP_METODO" | tr -cd "0-9")
  if [ "$MP_METODO" != "1" ] && [ "$MP_METODO" != "2" ] && [ "$MP_METODO" != "3" ]; then echo "Opcion invalida."; exit 1; fi
  if [ "$MP_METODO" = "1" ] || [ "$MP_METODO" = "3" ]; then
    echo ""
    echo "  --- Credenciales de Uala Bis ---"
    read -p "  Username: " U_USER < /dev/tty
    read -p "  Client ID: " U_CID < /dev/tty
    read -p "  Client Secret: " U_SEC < /dev/tty
    printf '{\n  "username": "%s",\n  "client_id": "%s",\n  "client_secret": "%s"\n}\n' "$U_USER" "$U_CID" "$U_SEC" > "$BOT_DIR/uala-credenciales.json"
    chmod 600 "$BOT_DIR/uala-credenciales.json"
  fi
  if [ "$MP_METODO" = "2" ] || [ "$MP_METODO" = "3" ]; then
    echo ""
    echo "  --- Token de Mercado Pago ---"
    echo "  (Access Token de produccion, desde tu panel de MP)"
    read -p "  MP Access Token: " MP_TK < /dev/tty
    echo "$MP_TK" > "$BOT_DIR/mp-token.txt"
    chmod 600 "$BOT_DIR/mp-token.txt"
  fi
  echo "$MP_METODO" > "$BOT_DIR/metodo-pago.txt"
  pm2 restart sshvendor-bot >/dev/null 2>&1
  echo ""
  echo "Metodo de cobro configurado y bot reiniciado."
  exit 0
fi
if [ "$1" = "ssl" ]; then
  DOMINIO=$(cat "$BOT_DIR/dominio-webhook.txt" 2>/dev/null)
  if [ -z "$DOMINIO" ]; then echo "No hay dominio configurado (este bot no usa API de Meta)."; exit 1; fi
  echo "Necesito los puertos 80 y 443 libres un momento."
  echo "Si tenes ADMRufu usandolos, paralo desde su menu."
  read -p "Escribi OK cuando esten libres: " C < /dev/tty
  systemctl stop nginx >/dev/null 2>&1 || true
  pkill -9 nginx >/dev/null 2>&1 || true
  sleep 2
  certbot certonly --standalone -d "$DOMINIO" --non-interactive --agree-tos -m admin@"$DOMINIO"
  pkill -9 nginx >/dev/null 2>&1 || true
  sleep 2
  systemctl start nginx >/dev/null 2>&1
  pm2 restart sshvendor-bot >/dev/null 2>&1
  echo "Listo. Ya podes reactivar ADMRufu. El bot esta en el puerto 8443."
  exit 0
fi
if [ "$1" = "fondo" ]; then
  CAPA=$(cat "$BOT_DIR/capa-wpp.txt" 2>/dev/null || echo "1")
  if [ "$CAPA" = "2" ]; then ARRANQUE="webhook.js"; else ARRANQUE="index.js"; fi
  pm2 start "$BOT_DIR/$ARRANQUE" --name sshvendor-bot && pm2 save && pm2 startup systemd -u root --hp /root >/dev/null 2>&1; exit 0;
fi
if [ "$1" = "stop" ]; then pm2 stop sshvendor-bot; exit 0; fi
if [ "$1" = "logs" ]; then pm2 logs sshvendor-bot; exit 0; fi
CAPA=$(cat "$BOT_DIR/capa-wpp.txt" 2>/dev/null || echo "1")
if [ "$CAPA" = "2" ]; then exec node "$BOT_DIR/webhook.js"; else exec node "$BOT_DIR/index.js"; fi
SSHBOTCMD
chmod +x /usr/local/bin/sshbot

echo "==> Instalando librerias de Node (puede tardar)..."
npm install --no-audit --no-fund >/dev/null 2>&1

if [ "$CAPA_WPP" = "2" ]; then
  DOMINIO=$(cat "$BOT_DIR/dominio-webhook.txt")
  apt-get install -y nginx certbot python3-certbot-nginx >/dev/null 2>&1 || true
  echo ""
  echo -e "${AMARILLO}==================================================${NC}"
  echo -e "${AMARILLO}   ATENCION - ACCION REQUERIDA${NC}"
  echo -e "${AMARILLO}==================================================${NC}"
  echo ""
  echo -e "${AMARILLO}  Para instalar necesito los puertos 80 y 443 LIBRES${NC}"
  echo -e "${AMARILLO}  un momento. Si tenes ADMRufu u otro servicio${NC}"
  echo -e "${AMARILLO}  usandolos, PARALOS AHORA desde su menu.${NC}"
  echo ""
  echo -e "${AMARILLO}  Cuando esten libres, escribi OK para continuar.${NC}"
  echo ""
  read -p "$(echo -e ${VERDE}"  Escribi OK: "${NC})" CONFIRMA < /dev/tty
  # Liberar puertos por si quedo algo de nginx
  systemctl stop nginx >/dev/null 2>&1 || true
  pkill -9 nginx >/dev/null 2>&1 || true
  sleep 2
  echo ""
  echo "==> Sacando certificado SSL..."
  certbot certonly --standalone -d "$DOMINIO" --non-interactive --agree-tos -m admin@"$DOMINIO" >/dev/null 2>&1
  if [ ! -f "/etc/letsencrypt/live/$DOMINIO/fullchain.pem" ]; then
    echo "  ERROR: no se pudo sacar el certificado. Verifica que el dominio $DOMINIO apunte a este VPS y que el puerto 80 este libre."
    echo "  Podes reintentar despues con: sshbot ssl"
  fi
  # Configurar Nginx SOLO en 8443
  cat > /etc/nginx/sites-available/sshbot-meta <<NGINXEOF
server {
    listen 8443 ssl;
    server_name $DOMINIO;
    ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    location / {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINXEOF
  ln -sf /etc/nginx/sites-available/sshbot-meta /etc/nginx/sites-enabled/
  # Quitar el default de nginx para que no ocupe el 80
  rm -f /etc/nginx/sites-enabled/default
  nginx -t >/dev/null 2>&1
  pkill -9 nginx >/dev/null 2>&1 || true
  sleep 2
  systemctl start nginx >/dev/null 2>&1
  systemctl enable nginx >/dev/null 2>&1
  pm2 delete sshvendor-bot >/dev/null 2>&1 || true
  pm2 start "$BOT_DIR/webhook.js" --name sshvendor-bot && pm2 save >/dev/null 2>&1
  pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
  echo ""
  echo "=================================================="
  echo "   INSTALACION COMPLETA (API de Meta)"
  echo "=================================================="
  echo ""
  AZUL="\033[1;34m"; VERDE="\033[1;32m"; ROJO="\033[1;31m"; NC="\033[0m"
  echo -e "${AZUL}RESUMEN DE LA INSTALACION:${NC}"
  # Certificado SSL
  if [ -f "/etc/letsencrypt/live/$DOMINIO/fullchain.pem" ]; then
    echo -e "  ${VERDE}\xE2\x9C\x85${NC} ${AZUL}Certificado SSL${NC}"
  else
    echo -e "  ${ROJO}\xE2\x9D\x8C Certificado SSL (fallo - corre: sshbot ssl)${NC}"
  fi
  # Nginx en 8443
  if ss -tlnp 2>/dev/null | grep -q ":8443"; then
    echo -e "  ${VERDE}\xE2\x9C\x85${NC} ${AZUL}Nginx escuchando en 8443${NC}"
  else
    echo -e "  ${ROJO}\xE2\x9D\x8C Nginx en 8443 (no esta escuchando)${NC}"
  fi
  # Bot corriendo
  if pm2 list 2>/dev/null | grep -q "sshvendor-bot"; then
    echo -e "  ${VERDE}\xE2\x9C\x85${NC} ${AZUL}Bot corriendo${NC}"
  else
    echo -e "  ${ROJO}\xE2\x9D\x8C Bot no esta corriendo${NC}"
  fi
  # ADMRufu socket
  if [ -S /tmp/admAPI.sock ]; then
    echo -e "  ${VERDE}\xE2\x9C\x85${NC} ${AZUL}ADMRufu conectado${NC}"
  else
    echo -e "  ${ROJO}\xE2\x9D\x8C ADMRufu no detectado (verifica que este corriendo)${NC}"
  fi
  echo ""
  echo -e "${AMARILLO}IMPORTANTE: ya podes REACTIVAR ADMRufu (puertos 80 y 443).${NC}"
  echo -e "${AMARILLO}El bot quedo corriendo en el puerto 8443, no molesta a ADMRufu.${NC}"
  echo ""
  echo -e "${AZUL}CONFIGURA EL WEBHOOK EN META:${NC}"
  echo "  developers.facebook.com -> tu app -> WhatsApp -> Configuracion"
  echo ""
  echo "  URL de devolucion de llamada:"
  echo -e "${VERDE}     https://$DOMINIO:8443/webhook${NC}"
  echo ""
  echo "  Token de verificacion: el verify token que pusiste recien"
  echo -e "${AMARILLO}  Despues toca 'Verificar y guardar' y suscribite al campo 'messages'${NC}"
  echo ""
  echo "Cuando termines, escribile 'hola' al numero del bot para probar."
  echo ""
  echo "  sshbot logs  -> ver mensajes    sshbot stop -> parar"
  echo "=================================================="
  exit 0
fi

echo ""
echo "=================================================="
echo "   INSTALACION COMPLETA"
echo "=================================================="
echo ""
echo "PROXIMOS PASOS:"
echo "  1. (Opcional) Revisa tus planes y dias:  nano $BOT_DIR/config.json"
echo "  2. Escribi este comando para vincular tu WhatsApp:"
echo ""
echo "       sshbot"
echo ""
echo "  3. Escanea el QR que aparece con tu WhatsApp (comun, NO Business)."
echo "  4. Cuando diga conectado, corta con Ctrl+C y escribi:"
echo ""
echo "       sshbot fondo"
echo ""
echo "     (eso lo deja corriendo solo, 24hs)"
echo ""
echo "OPCIONAL - MODO HWID: si queres vender cuentas atadas al dispositivo"
echo "(HWID), edita config.json y poni \"usar_hwid\": true"
echo ""
echo "IMPORTANTE: configura la privacidad de grupos de tu WhatsApp en"
echo "Ajustes -> Privacidad -> Grupos -> Mis contactos (o Nadie)"
echo "=================================================="
