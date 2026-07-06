#!/usr/bin/env bash
set -e
TOKEN="__TOKEN__"
API_BASE="__API_BASE__"
BOT_DIR="/opt/sshvendor-bot"

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

echo ""
echo "=================================================="
echo "   CONFIGURACION DE UALA BIS (cobros)"
echo "=================================================="
echo "Ingresa tus credenciales de Uala Bis:"
echo ""
read -p "  Username: " UALA_USER < /dev/tty
read -p "  Client ID: " UALA_CID < /dev/tty
read -p "  Client Secret: " UALA_SECRET < /dev/tty
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
echo "Credenciales de Uala guardadas (archivo protegido)."

cat > package.json <<'PKG'
{ "name":"sshvendor-bot","version":"1.0.0","main":"index.js",
  "dependencies":{"@whiskeysockets/baileys":"^6.7.9","@hapi/boom":"^10.0.1","qrcode-terminal":"^0.12.0","pino":"^9.5.0","axios":"^1.7.0"} }
PKG

cat > config.json <<'CFGJSON'
{
  "negocio": "Mi Servicio SSH",
  "moneda": "$",
  "modo": "datos",
  "planes": [
    { "id": 1, "nombre": "10 GB",  "gb": 10,  "precio": 2500 },
    { "id": 2, "nombre": "25 GB",  "gb": 25,  "precio": 5000 },
    { "id": 3, "nombre": "50 GB",  "gb": 50,  "precio": 8000 },
    { "id": 4, "nombre": "100 GB", "gb": 100, "precio": 13000 }
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

// Lee el límite actual de una cuenta y lo devuelve en GB (number).
function parseGB(info) {
  const m = info.match(/Limit:\s*([\d.]+)\s*(GB|MB|TB)/i);
  if (!m) return 0;
  let val = parseFloat(m[1]);
  const unidad = m[2].toUpperCase();
  if (unidad === 'MB') val = val / 1024;
  else if (unidad === 'TB') val = val * 1024;
  return val; // en GB
}

// ---- CUENTAS SSH (usuario/contraseña) ----
async function crearCuentaDatos(usuario, gb) {
  const password = generarPassword();
  const comando = `/ssh add ${usuario} ${password} ${CONEXIONES} ${DIAS_CUENTA}`;
  const respuesta = await ejecutarComando(comando);
  const ok = /creado|success/i.test(respuesta);
  if (!ok) return { success: false, error: respuesta };
  await ejecutarComando(`/ssh set limit ${usuario} ${gb} GB`);
  return { success: true, user: usuario, password, gb };
}

async function leerLimiteGB(usuario) {
  const info = await ejecutarComando(`/ssh info ${usuario}`);
  return parseGB(info);
}

async function recargarDatos(usuario, gbNuevos) {
  const limiteActualGB = await leerLimiteGB(usuario);
  const nuevoTotalGB = Math.round((limiteActualGB + gbNuevos) * 100) / 100;
  const respuesta = await ejecutarComando(`/ssh set limit ${usuario} ${nuevoTotalGB} GB`);
  const ok = /l[ií]mite|limit/i.test(respuesta);
  const rExp = await ejecutarComando(`/ssh set expire ${usuario} ${DIAS_CUENTA}`);
  if (!/unlok/i.test(rExp)) {
    const info = await ejecutarComando(`/ssh info ${usuario}`);
    if (/[^n]Loked/i.test(info) && !/Unloked/i.test(info)) {
      await ejecutarComando(`/ssh set status ${usuario}`);
    }
  }
  return { success: ok, totalGB: nuevoTotalGB, dias: DIAS_CUENTA, respuesta };
}

async function infoCuenta(usuario) { return await ejecutarComando(`/ssh info ${usuario}`); }

// ---- CUENTAS POR HWID ----
async function crearCuentaHwid(hwid, nombre, gb) {
  const comando = `/hwid add ${hwid} ${nombre} ${DIAS_CUENTA}`;
  const respuesta = await ejecutarComando(comando);
  if (/already exists|ya existe/i.test(respuesta)) {
    const r = await recargarHwid(hwid, gb);
    if (r.success) return { success: true, hwid, nombre, gb, recargada: true };
    return { success: false, error: 'No se pudo recargar la cuenta existente: ' + r.respuesta };
  }
  const ok = /creat|success|creado/i.test(respuesta);
  if (!ok) return { success: false, error: respuesta };
  await ejecutarComando(`/hwid set limit ${hwid} ${gb} GB`);
  return { success: true, hwid, nombre, gb };
}

async function leerLimiteHwidGB(hwid) {
  const info = await ejecutarComando(`/hwid info ${hwid}`);
  return parseGB(info);
}

async function recargarHwid(hwid, gbNuevos) {
  const limiteActualGB = await leerLimiteHwidGB(hwid);
  const nuevoTotalGB = Math.round((limiteActualGB + gbNuevos) * 100) / 100;
  const respuesta = await ejecutarComando(`/hwid set limit ${hwid} ${nuevoTotalGB} GB`);
  const ok = /l[ií]mite|limit/i.test(respuesta);
  await ejecutarComando(`/hwid set expire ${hwid} ${DIAS_CUENTA}`);
  return { success: ok, totalGB: nuevoTotalGB, dias: DIAS_CUENTA, respuesta };
}

function validarHwid(hwid) {
  return /^[a-fA-F0-9]{32}$/.test((hwid || '').trim());
}

module.exports = { crearCuentaDatos, recargarDatos, leerLimiteGB, infoCuenta, generarPassword, ejecutarComando, crearCuentaHwid, recargarHwid, leerLimiteHwidGB, validarHwid };
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

cat > index.js <<'INDEXEOF'
const fs = require('fs'), path = require('path');
const guard = require('./guard');
const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion, downloadMediaMessage } = require('@whiskeysockets/baileys');
const qrcode = require('qrcode-terminal');
const { Boom } = require('@hapi/boom');
const pino = require('pino');

const admrufu = require('./admrufu');
const uala = require('./uala');

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
async function generarLinkPago(jid, plan, hwid) {
  try {
    await SOCK.sendMessage(jid, { text: '⏳ Generando tu link de pago, esperá un momento...' });
    const ref = `${jid.split('@')[0]}-${Date.now()}`;
    const orden = await uala.crearOrden(plan.precio, `${plan.nombre} - ${CFG.negocio}`, ref);
    VENTAS.ordenes[orden.uuid] = { jid, plan_id: plan.id, gb: plan.gb, precio: plan.precio, uuid: orden.uuid, ref, creada: Date.now(), estado: 'pendiente', hwid: hwid || null };
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

    if (USAR_HWID) {
      // ----- MODO HWID -----
      if (clienteExistente && clienteExistente.hwid) {
        // Recargar cuenta HWID existente
        const r = await admrufu.recargarHwid(clienteExistente.hwid, o.gb);
        if (r.success) {
          CLIENTES[o.jid].gb = (CLIENTES[o.jid].gb || 0) + o.gb;
          guardarClientes(CLIENTES);
          try { await sock.sendMessage(o.jid, { text: `✅ *¡Recarga confirmada!*\n\n📊 *Datos agregados:* ${o.gb} GB\n📅 *Validez renovada:* ${r.dias} días\n\n¡Gracias! 🚀` }); } catch(e){}
          return true;
        } else {
          try { await sock.sendMessage(o.jid, { text: `⚠️ Tu pago se confirmó pero hubo un problema con la recarga. Contactá al soporte.` }); } catch(e){}
          return false;
        }
      } else {
        // Cuenta HWID nueva (necesita el HWID)
        const nombre = generarUsuario();
        const r = await admrufu.crearCuentaHwid(hwidRecibido, nombre, o.gb);
        if (r.success) {
          CLIENTES[o.jid] = { hwid: hwidRecibido, nombre, gb: o.gb };
          guardarClientes(CLIENTES);
          try { await sock.sendMessage(o.jid, { text: `✅ *¡Cuenta activada!*\n\n📊 *Datos:* ${o.gb} GB\n📅 *Validez:* ${CFG.dias_cuenta} días\n\n📲 Pedí tu archivo de configuración en el grupo con el comando *${CFG.comando_archivo || '/archivo hwid'}*\n\n¡Gracias por tu compra! 🚀` }); } catch(e){}
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
        const r = await admrufu.recargarDatos(clienteExistente.usuario, o.gb);
        if (r.success) {
          CLIENTES[o.jid].gb = (CLIENTES[o.jid].gb || 0) + o.gb;
          guardarClientes(CLIENTES);
          try { await sock.sendMessage(o.jid, { text: `✅ *¡Recarga confirmada!*\n\n👤 *Usuario:* ${clienteExistente.usuario}\n📊 *Datos agregados:* ${o.gb} GB\n📅 *Validez renovada:* ${r.dias} días\n\n¡Gracias! 🚀` }); } catch(e){}
          return true;
        } else {
          try { await sock.sendMessage(o.jid, { text: `⚠️ Tu pago se confirmó pero hubo un problema con la recarga. Contactá al soporte.` }); } catch(e){}
          return false;
        }
      } else {
        const usuario = generarUsuario();
        const r = await admrufu.crearCuentaDatos(usuario, o.gb);
        if (r.success) {
          CLIENTES[o.jid] = { usuario: r.user, gb: o.gb };
          guardarClientes(CLIENTES);
          try { await sock.sendMessage(o.jid, { text: `✅ *¡Pago confirmado!* Tu cuenta está lista:\n\n👤 *Usuario:* ${r.user}\n🔑 *Contraseña:* ${r.password}\n📊 *Datos:* ${o.gb} GB\n📅 *Validez:* ${CFG.dias_cuenta} días\n\n¡Gracias por tu compra! 🚀` }); } catch(e){}
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
          txt += '`/precio [id] [valor]`\n`/nombre [id] [texto]`\n`/dias [numero]`\n`/negocio [texto]`\n`/mensaje [texto]`\n';
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
        await generarLinkPago(jid, ses.plan, hwid);
        return;
      }

      if (ses && ses.paso === 'eligiendo') {
        const plan = planPorId(texto);
        if (!plan) { await sock.sendMessage(jid, { text: '❌ Opción no válida. Respondé con el número del paquete.' }); return; }
        const clienteExistente = CLIENTES[jid];
        // Si usa HWID y es cliente NUEVO, pedir el HWID ANTES del pago
        if (USAR_HWID && !(clienteExistente && clienteExistente.hwid)) {
          sesiones[jid] = { paso: 'hwid_antes_pago', plan };
          await sock.sendMessage(jid, { text: `📲 Antes de pagar, necesito tu *HWID* para activar tu cuenta:\n\n1️⃣ Abrí HTTP Custom\n2️⃣ Andá al menú → *HWID*\n3️⃣ Copialo y pegalo acá 👇` });
          return;
        }
        // SSH normal, o recarga HWID (ya tiene hwid): generar link directo
        await generarLinkPago(jid, plan, (clienteExistente && clienteExistente.hwid) || null);
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
        const status = await uala.consultarOrden(o.uuid);
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
if [ "$1" = "fondo" ]; then pm2 start index.js --name sshvendor-bot && pm2 save && pm2 startup systemd -u root --hp /root >/dev/null 2>&1; exit 0; fi
if [ "$1" = "stop" ]; then pm2 stop sshvendor-bot; exit 0; fi
if [ "$1" = "logs" ]; then pm2 logs sshvendor-bot; exit 0; fi
exec node index.js
SSHBOTCMD
chmod +x /usr/local/bin/sshbot

echo "==> Instalando librerias de Node (puede tardar)..."
npm install --no-audit --no-fund >/dev/null 2>&1

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
