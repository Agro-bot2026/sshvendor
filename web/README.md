# SSH Vendor - Web de venta

Landing page con chatbot DeepSeek para vender el producto SSH Vendor.

## Correr
- Crear `.env` con `DEEPSEEK_API_KEY` (ver `.env.ejemplo`)
- `pip install fastapi uvicorn requests`
- `uvicorn app:app --host 127.0.0.1 --port 8200`
- Corre bajo pm2 como `sshvendor-web`, detrás de Nginx en `sshvendor.charly-tricks.dev`
