const fs = require('fs'), path = require('path');
const guard = require('./guard');
const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } = require('@whiskeysockets/baileys');
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
      if (!texto) return;
      const t = texto.toLowerCase();

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
