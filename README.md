# SSH Vendor

Sistema de venta automatizada de cuentas SSH (por datos/GB) a través de un bot de WhatsApp, con un servidor central de licencias que controla qué instalaciones están autorizadas.

El producto se vende como una **licencia**: cada cliente instala su propio bot en su VPS, y ese bot valida su licencia contra el servidor central antes de funcionar. El dueño de cada bot administra todo (precios, planes, archivos de configuración) desde WhatsApp, sin tocar la terminal.

---

## Arquitectura

El sistema tiene dos piezas que trabajan juntas pero viven en lugares distintos:

- **El servidor central** guarda las licencias y valida cuál está activa y a qué IP está atada. Siempre encendido: es el corazón del sistema.
- **El bot vendedor** corre en el VPS de cada cliente. Al arrancar (y periódicamente) valida su licencia contra el servidor central. Si la licencia no es válida, el bot no funciona.

La comunicación entre el bot y el servidor central se hace por **dominio** (`https://licencias.charly-tricks.dev`), no por IP. Esto permite mover el servidor central de VPS sin romper los bots de los clientes: basta con reapuntar el DNS.

---

## Dos formas de conectar a WhatsApp

Desde la versión actual, el instalador **pregunta al cliente cómo quiere conectar el bot a WhatsApp**:

| Opción | Cómo funciona | Ventajas | Requisitos |
|---|---|---|---|
| **Baileys** | Escanea un QR con WhatsApp | Gratis, simple, funciona con cualquier número | Ninguno |
| **API oficial de Meta** | Webhook con la Cloud API de WhatsApp | Estable (no se cae ni pide QR), botones interactivos, más profesional | Cuenta de Meta configurada + dominio con SSL |

Las dos comparten toda la lógica de negocio (planes, pagos, ADMRufu, HWID, comandos). Solo cambia la capa de mensajería.

### Ventajas de la API de Meta (botones interactivos)

Con la API oficial, el bot usa **botones y listas** en vez de pedir que el cliente escriba números:

- Menú de planes to lista desplegable interactiva
- Elección de tipo de cuenta to botones [Usuario y clave] / [HWID]
- Elección de pasarela to botones [Uala Bis] / [Mercado Pago]
- Link de pago to botón **"Pagar ahora"** (no muestra el link crudo, genera más confianza)

---

## Componentes

| Componente | Ubicación | Rol |
|---|---|---|
| API de licencias | Servidor central (`/opt/sshvendor`) | Valida licencias, sirve el instalador y la página de instalación |
| Base de datos | Servidor central (`sshvendor.db`, SQLite) | Guarda las licencias y su IP atada |
| Bot vendedor | VPS de cada cliente (`/opt/sshvendor-bot`) | Atiende WhatsApp, cobra por Uala/MP, crea cuentas SSH |
| ADMRufu | VPS de cada cliente | Crea y administra las cuentas SSH (via socket local) |
| Uala Bis / Mercado Pago | Externo (API) | Procesan los cobros |

---

## Infraestructura

- **Servidor central:** VPS Contabo
- **Dominio:** `licencias.charly-tricks.dev` (DNS en Cloudflare, apuntando al Contabo)
- **HTTPS:** certificado Let's Encrypt (Certbot) sobre Nginx como reverse proxy
- **La API** corre en `127.0.0.1:8100` y Nginx la expone por el dominio con SSL
- **Gestion de procesos:** pm2 (con arranque automatico configurado)

### Puertos en el VPS del cliente (con API de Meta)

Cuando el cliente elige la API de Meta, el bot necesita un webhook publico con SSL. Para **no chocar con ADMRufu** (que usa el puerto 80), el webhook se monta en el **puerto 8443** (uno de los dos puertos que Meta acepta, junto al 443):

| Puerto | Uso |
|---|---|
| 80 | ADMRufu (conexiones SSH) - no se toca |
| 8443 | Nginx to webhook del bot (HTTPS) |
| 8090 | Bot Node interno (Nginx le hace proxy) |

El instalador saca el certificado SSL pidiendo liberar los puertos 80/443 solo un momento, despues deja Nginx unicamente en el 8443 y avisa al cliente que reactive ADMRufu.

---

## El bot vendedor

Aplicacion Node.js que se instala en el VPS del cliente. Se genera completo desde el instalador (`install-bot.sh`). Segun la opcion elegida, arranca con Baileys (`index.js`) o con la API de Meta (`webhook.js` + `bot.js`).

### Planes por datos (en MB)

El bot maneja todo internamente en **MB enteros** (ADMRufu no acepta decimales). Los planes se definen en MB y se muestran de forma legible (ej: 10240 MB to "10 GB"). El dueño puede crear planes en GB o MB con `/agregarplan`.

### Flujo de venta

1. Un comprador escribe `comprar` (o `hola`, `menu`) al bot.
2. El bot muestra los planes de datos con sus precios (lista interactiva en Meta).
3. El comprador elige un plan.
4. Si es cliente nuevo, elige el tipo de cuenta: **usuario y contraseña** o **HWID**.
5. Si el dueño tiene las dos pasarelas, el comprador elige **Uala Bis** o **Mercado Pago**.
6. El bot genera el link de pago (boton "Pagar ahora" en Meta).
7. Al confirmarse el pago, el bot crea la cuenta SSH (via ADMRufu) y la entrega automaticamente.

### Recarga

Cuando un cliente existente renueva, el bot **resetea el uso a 0** y pone el limite en lo nuevo (empieza limpio en cada recarga), tanto para cuentas de usuario/contraseña como HWID.

### Metodos de pago

El instalador pregunta con que cobrar: solo Uala, solo Mercado Pago, o los dos (el comprador elige la pasarela al pagar). MP genera mas confianza (marca conocida) y permite pagar con saldo sin tarjeta. La verificacion de pagos es por polling (el bot consulta cada 20s).

### Archivos importantes del bot (en el VPS del cliente)

| Archivo | Contenido |
|---|---|
| `config.json` | Negocio, planes (en MB), precios, dias, mensaje de bienvenida |
| `.license` | Token de la licencia |
| `.apibase` | URL del servidor central |
| `admin.txt` | Numero de WhatsApp del dueño (admin) |
| `capa-wpp.txt` | Capa de mensajeria (1=Baileys, 2=Meta) |
| `metodo-pago.txt` | Metodo de cobro (1=Uala, 2=MP, 3=ambos) |
| `uala-credenciales.json` | Credenciales de Uala Bis (chmod 600) |
| `mp-token.txt` | Access Token de Mercado Pago (chmod 600) |
| `.env` | Credenciales de Meta: token, Phone ID, WABA, verify token (solo capa Meta, chmod 600) |
| `dominio-webhook.txt` | Dominio del webhook (solo capa Meta) |
| `auth/` | Sesion de WhatsApp (solo Baileys) |
| `hc_files/` | Archivos .hc que el bot entrega a los compradores |

---

## Guia de uso: crear y entregar una licencia

**1. Crear la licencia (en el servidor central):**

    cd /opt/sshvendor
    source venv/bin/activate
    python3 crear_licencia.py

El script pide un nombre de cliente y genera un token con el link para pasarle al cliente.

**2. El cliente instala el bot:**

El cliente abre el link, copia el comando y lo pega en su VPS como root. El instalador le pregunta:

- Metodo de cobro (Uala / MP / ambos) y las credenciales
- Su numero de WhatsApp personal (admin)
- Como conectar a WhatsApp (Baileys o API de Meta)
- Si elige Meta: dominio del webhook, token, Phone Number ID, WABA ID y verify token

**3a. Si eligio Baileys:**

    sshbot          (muestra el QR)
    sshbot fondo    (deja el bot corriendo 24hs)

**3b. Si eligio API de Meta:**

El instalador configura el webhook con SSL automaticamente (puerto 8443) y arranca el bot. Solo resta configurar la URL del webhook en el panel de Meta (el instalador la muestra al final) y suscribirse al campo `messages`.

---

## Comandos del dueño del bot (desde WhatsApp)

Solo el numero guardado en `admin.txt` puede usar estos comandos.

| Comando | Que hace | Ejemplo |
|---|---|---|
| `/config` | Muestra la configuracion y la lista de comandos | `/config` |
| `/precio [id] [valor]` | Cambia el precio de un plan | `/precio 1 3000` |
| `/nombre [id] [texto]` | Cambia el nombre de un plan | `/nombre 1 10 GB Premium` |
| `/agregarplan [cant] [GB/MB] [precio]` | Crea un plan nuevo | `/agregarplan 100 MB 500` |
| `/borrarplan [id]` | Elimina un plan | `/borrarplan 3` |
| `/dias [numero]` | Cambia los dias de validez | `/dias 30` |
| `/negocio [texto]` | Cambia el nombre del negocio | `/negocio Mi SSH Store` |
| `/mensaje [texto]` | Cambia el mensaje de bienvenida | `/mensaje Hola!` |

### Archivos .hc (HTTP Custom)

| Accion | Como | Quien |
|---|---|---|
| Subir un .hc | Enviarle el archivo .hc al bot | Solo el dueño |
| Recibir los .hc | Escribir `/hc` | Cualquiera |
| Borrar los .hc | Escribir `/borrarhc` | Solo el dueño |

---

## Comandos de mantenimiento (terminal, en el VPS del cliente)

| Comando | Que hace |
|---|---|
| `sshbot` | Arranca el bot (QR en Baileys, o webhook en Meta) |
| `sshbot fondo` | Deja el bot corriendo 24hs |
| `sshbot update` | Actualiza el bot (conserva config, admin, .hc y sesion) |
| `sshbot stop` | Detiene el bot |
| `sshbot logs` | Muestra los logs en vivo |
| `sshbot reset` | Borra la sesion de WhatsApp (Baileys) |
| `sshbot hwid on/off` | Activa/desactiva el modo HWID global |
| `sshbot pago` | Configura o cambia el metodo de cobro (clientes ya instalados) |
| `sshbot ssl` | Reintenta sacar el certificado SSL del webhook (capa Meta) |

---

## Requisitos previos (ADMRufu)

El bot crea las cuentas SSH conectandose a ADMRufu a traves de un socket local (`/tmp/admAPI.sock`). Para que funcione:

1. El VPS del cliente debe tener ADMRufu instalado.
2. La API de ADMRufu (el socket) debe estar activa.

El instalador registra el servidor en ADMRufu durante la instalacion (por eso pide la contraseña root), pero asume que ADMRufu ya esta presente con su API encendida.

**Convivencia de puertos:** si el cliente usa la API de Meta, el webhook va en el puerto 8443 para no interferir con ADMRufu (puerto 80).

---

## Migrar el servidor central

Si hay que mover el servidor central a otro VPS:

1. Instalar dependencias: git, Node 20, pm2, Python 3 + venv, Nginx, Certbot.
2. Clonar el repo y ubicar la API en `/opt/sshvendor`.
3. Restaurar la base de datos (`sshvendor.db`) desde el respaldo.
4. Crear el venv e instalar: fastapi uvicorn sqlalchemy.
5. Apuntar el subdominio al nuevo VPS en Cloudflare (DNS-only).
6. Configurar Nginx como reverse proxy a `127.0.0.1:8100` y sacar el certificado con Certbot.
7. Arrancar la API con pm2 y guardar (pm2 save + pm2 startup).

Como los bots validan por dominio, al reapuntar el DNS siguen funcionando sin cambios.

---

## Respaldos

- Codigo: repositorio privado en GitHub (Agro-bot2026/sshvendor).
- Base de datos de licencias: respaldo periodico a Google Drive.
- Configuracion de cada cliente: vive en su propio VPS; el `sshbot update` la conserva.

---

## Estructura del repositorio

    sshvendor/
    api/                    Servidor central (API de licencias)
      main.py               FastAPI: validacion, instalacion y pagina
      crear_licencia.py     Script para generar licencias nuevas
      database.py           Conexion a la base
      models.py             Modelo de la tabla de licencias
      install-bot.sh        Instalador que genera el bot en el VPS del cliente

    bot/                    Codigo fuente del bot vendedor
      index.js              Logica principal con Baileys
      webhook.js            Servidor del webhook (capa API de Meta)
      bot.js                Logica del bot con la API de Meta (botones, flujo, comandos)
      enviar.js             Envio por la API de Meta (texto, botones, listas, documentos, boton CTA)
      guard.js              Validacion de licencia
      admrufu.js            Comunicacion con ADMRufu (en MB)
      uala.js               Integracion con Uala Bis
      mercadopago.js        Integracion con Mercado Pago
      config.json           Configuracion por defecto
      package.json          Dependencias Node

---

## Historial de cambios destacados

- **Refactor a MB:** todos los planes y limites en MB enteros (compatibilidad con ADMRufu).
- **Eleccion de tipo de cuenta por compra:** el comprador elige usuario/contraseña o HWID.
- **Recarga que resetea:** al renovar, el uso vuelve a 0 y el limite se pone en lo nuevo.
- **Mercado Pago:** integracion completa junto a Uala, con eleccion de pasarela.
- **Migracion a la API oficial de Meta:** capa alternativa a Baileys, con botones interactivos y boton CTA de pago.
- **Instalador con eleccion Baileys/Meta:** webhook + SSL automatico (puerto 8443) para convivir con ADMRufu, con avisos en colores y resumen final verificado.
- **Fix entrega de .hc:** corregido el envio de archivos .hc por la API de Meta (content-type text/plain, Meta rechazaba el anterior).
