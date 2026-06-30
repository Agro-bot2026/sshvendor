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
