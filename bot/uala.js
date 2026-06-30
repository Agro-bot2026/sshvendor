const axios = require('axios');
const fs = require('fs');

const AUTH_URL = "https://auth.developers.ar.ua.la/v2/api/auth/token";
const CHECKOUT_URL = "https://checkout.developers.ar.ua.la/v2/api/checkout";
const ORDERS_URL = "https://checkout.developers.ar.ua.la/v2/api/orders";

// Lee credenciales de Ualá desde archivo local (las pone el cliente al instalar)
function cargarCredenciales() {
  const raw = fs.readFileSync(__dirname + '/uala-credenciales.json', 'utf8');
  return JSON.parse(raw);
}

// Obtener token de autenticación
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
    username: c.username,
    client_id: c.client_id,
    client_secret_id: c.client_secret,
    grant_type: "client_credentials"
  }, { headers: { "Content-Type": "application/json" }, timeout: 20000 });
  return r.data.access_token;
}

// Crear orden de pago -> devuelve { checkout_link, uuid }
async function crearOrden(monto, descripcion, referencia) {
  const token = await getToken();
  const r = await axios.post(CHECKOUT_URL, {
    amount: String(monto),
    description: descripcion,
    callback_success: urlWhatsappBot(),
    callback_fail: urlWhatsappBot(),
    notification_url: "https://connect-vpn.top/noop",
    external_reference: referencia
  }, { headers: { "Content-Type": "application/json", "Authorization": `Bearer ${token}` }, timeout: 30000 });
  const data = r.data;
  return {
    checkout_link: data.links.checkout_link,
    uuid: data.uuid || data.id || (data.links && data.links.uuid) || ""
  };
}

// Consultar estado de una orden por uuid -> devuelve el status (APPROVED/PROCESSED/REJECTED)
async function consultarOrden(uuid) {
  const token = await getToken();
  const r = await axios.get(`${ORDERS_URL}/${uuid}`, {
    headers: { "Authorization": `Bearer ${token}` }, timeout: 20000
  });
  return r.data.status || "";
}

module.exports = { crearOrden, consultarOrden, getToken };
