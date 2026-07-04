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

## Componentes

| Componente | Ubicación | Rol |
|---|---|---|
| API de licencias | Servidor central (`/opt/sshvendor`) | Valida licencias, sirve el instalador y la página de instalación |
| Base de datos | Servidor central (`sshvendor.db`, SQLite) | Guarda las licencias y su IP atada |
| Bot vendedor | VPS de cada cliente (`/opt/sshvendor-bot`) | Atiende WhatsApp, cobra por Ualá, crea cuentas SSH |
| ADMRufu | VPS de cada cliente | Crea y administra las cuentas SSH (vía socket local) |
| Ualá Bis | Externo (API) | Procesa los cobros |

---

## Infraestructura

- **Servidor central:** VPS Contabo
- **Dominio:** `licencias.charly-tricks.dev` (DNS en Cloudflare, apuntando al Contabo)
- **HTTPS:** certificado Let's Encrypt (Certbot) sobre Nginx como reverse proxy
- **La API** corre en `127.0.0.1:8100` y Nginx la expone por el dominio con SSL
- **Gestión de procesos:** pm2 (con arranque automático configurado)

---

## El servidor central (API de licencias)

Aplicación FastAPI (Python) que corre bajo pm2 como `sshvendor-api`.

### Endpoints

| Endpoint | Método | Descripción |
|---|---|---|
| `/` | GET | Estado del servicio (health check) |
| `/api/validate/{token}` | GET | Valida una licencia. Ata la licencia a la IP en la primera consulta |
| `/install/{token}` | GET | Devuelve el script de instalación del bot para esa licencia |
| `/i/{token}` | GET | Página web amigable (con Open Graph) que muestra el comando de instalación y una guía ilustrada |

### Lógica de validación

- Si la licencia no existe, error.
- Si la licencia no tiene IP atada, se ata a la IP que consulta (primera vez).
- Si la IP que consulta no coincide con la atada, `ip_mismatch` (bloquea).
- Si coincide, válida.

Esto evita que una misma licencia se use en varios VPS a la vez.

---

## El bot vendedor

Aplicación Node.js (Baileys para WhatsApp) que se instala en el VPS del cliente. Se genera completo desde el instalador (`install-bot.sh`), que escribe todos sus archivos.

### Flujo de venta

1. Un comprador escribe `comprar` (o `hola`, `menu`) al bot.
2. El bot muestra los planes de datos con sus precios.
3. El comprador elige un número de plan.
4. El bot genera un link de pago de Ualá Bis por el precio del plan.
5. Al confirmarse el pago, el bot crea la cuenta SSH (vía ADMRufu) y la entrega.

### Archivos importantes del bot (en el VPS del cliente)

| Archivo | Contenido |
|---|---|
| `config.json` | Negocio, planes, precios, días, modo HWID, mensaje de bienvenida |
| `.license` | Token de la licencia |
| `.apibase` | URL del servidor central |
| `admin.txt` | Número de WhatsApp del dueño (admin) |
| `auth/` | Sesión de WhatsApp (para no re-vincular) |
| `hc_files/` | Archivos .hc de configuración que el bot entrega a los compradores |

---

## Guía de uso: crear y entregar una licencia

**1. Crear la licencia (en el servidor central):**

    cd /opt/sshvendor
    source venv/bin/activate
    python3 crear_licencia.py

El script pide un nombre de cliente y genera un token. Al final muestra el link para pasarle al cliente por WhatsApp, que se ve con imagen y guía ilustrada al compartirlo.

**2. El cliente instala el bot:**

El cliente abre el link, copia el comando y lo pega en su VPS como root. El instalador le pide: credenciales de Ualá Bis, su número de WhatsApp personal (admin), y la contraseña root del VPS (para registrar el servidor en ADMRufu).

**3. El cliente vincula WhatsApp:**

    sshbot          (muestra el QR)
    sshbot fondo    (deja el bot corriendo 24hs)

---

## Guía de uso: comandos del dueño del bot

El dueño administra todo desde WhatsApp, escribiéndole a su propio bot desde su número de admin. Solo el número guardado en `admin.txt` puede usar estos comandos.

### Configuración

| Comando | Qué hace | Ejemplo |
|---|---|---|
| `/config` | Muestra toda la configuración actual y la lista de comandos | `/config` |
| `/precio [id] [valor]` | Cambia el precio de un plan | `/precio 1 3000` |
| `/nombre [id] [texto]` | Cambia el nombre de un plan | `/nombre 1 10 GB Premium` |
| `/dias [numero]` | Cambia los días de validez de las cuentas | `/dias 30` |
| `/negocio [texto]` | Cambia el nombre del negocio | `/negocio Mi SSH Store` |
| `/mensaje [texto]` | Cambia el mensaje de bienvenida | `/mensaje Hola!` |

Los cambios se aplican al instante: se reflejan en el menú que ven los compradores y en el cobro de Ualá.

### Archivos de configuración .hc (HTTP Custom)

| Acción | Cómo | Quién |
|---|---|---|
| Subir un .hc | Enviarle el archivo .hc al bot por WhatsApp | Solo el dueño |
| Recibir los .hc | Escribir `/hc` | Cualquiera |
| Borrar los .hc | Escribir `/borrarhc` (para actualizarlos) | Solo el dueño |

---

## Comandos de mantenimiento (terminal)

Se ejecutan en el VPS del cliente, por SSH:

| Comando | Qué hace |
|---|---|
| `sshbot` | Muestra el QR para vincular WhatsApp |
| `sshbot fondo` | Deja el bot corriendo 24hs (segundo plano) |
| `sshbot update` | Actualiza el bot (conserva config, número admin, archivos .hc y la sesión de WhatsApp) |
| `sshbot stop` | Detiene el bot |
| `sshbot logs` | Muestra los logs en vivo (Ctrl+C para salir) |
| `sshbot reset` | Borra la sesión de WhatsApp (para revincular con QR nuevo) |
| `sshbot hwid on/off` | Activa/desactiva el modo HWID (cuentas atadas al dispositivo) |

Nota: `sshbot update` actualiza solo el bot, no ADMRufu.

---

## Requisitos previos (ADMRufu)

El bot crea las cuentas SSH conectándose a ADMRufu a través de un socket local (`/tmp/admAPI.sock`). Para que funcione:

1. El VPS del cliente debe tener ADMRufu instalado.
2. La API de ADMRufu (el socket) debe estar activa.

La API de ADMRufu no viene activa por defecto: hay que activarla. Este paso se coordina de forma personalizada al entregar la licencia.

El instalador del bot ya registra el servidor en ADMRufu durante la instalación (por eso pide la contraseña root), pero eso asume que ADMRufu ya está presente con su API encendida.

---

## Cómo reinstalar / migrar el servidor central

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

- Código: repositorio privado en GitHub (Agro-bot2026/sshvendor).
- Base de datos de licencias: respaldo periódico a Google Drive.
- Configuración de cada cliente: vive en su propio VPS; el `sshbot update` la conserva.

---

## Estructura del repositorio

    sshvendor/
    ├── api/                    Servidor central (API de licencias)
    │   ├── main.py             FastAPI: validación, instalación y página
    │   ├── crear_licencia.py   Script para generar licencias nuevas
    │   ├── database.py         Conexión a la base
    │   ├── models.py           Modelo de la tabla de licencias
    │   └── install-bot.sh      Instalador que genera el bot en el VPS del cliente
    │
    └── bot/                    Código fuente del bot vendedor
        ├── index.js            Lógica principal (WhatsApp, ventas, comandos, .hc)
        ├── guard.js            Validación de licencia
        ├── admrufu.js          Comunicación con ADMRufu (crear cuentas SSH)
        ├── uala.js             Integración con Ualá Bis (cobros)
        ├── config.json         Configuración por defecto
        └── package.json        Dependencias Node
