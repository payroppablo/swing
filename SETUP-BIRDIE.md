# SwingLens — Birdie backend & producción

## ¿Qué hace cada modo?

| Modo | Cómo se ve | API key |
|------|-----------|---------|
| **Prototipo** (actual) | `BIRDIE_PROXY = ''` en `index.html` | El usuario escribe su propia key (se guarda en su teléfono) |
| **Con Worker** | `BIRDIE_PROXY = 'https://...workers.dev'` | Escondida en el servidor; el usuario NO la escribe |

## Activar el Worker (esconder la key)

1. `dash.cloudflare.com` → **Workers & Pages** → **Create** → **Worker** → nómbralo `swinglens-birdie` → **Deploy**.
2. **Edit code** → pega todo `worker.js` → **Deploy**.
3. **Settings → Variables and Secrets**:
   - Secret: `ANTHROPIC_API_KEY` = `sk-ant-...`
   - (opcional) Variable: `ALLOWED_ORIGIN` = `https://payroppablo.github.io`
4. Copia la URL del worker y pégala en `index.html`:
   ```js
   const BIRDIE_PROXY = 'https://swinglens-birdie.TUCUENTA.workers.dev';
   ```
5. Commit + push. Ya Birdie funciona sin pedir key.

## Producción real (suscripción de pago)

Esto necesita cuentas de usuario y cobro — pasos cuando quieras dar el salto:

1. **Pagos:** Stripe Checkout / Payment Link para la suscripción ($9.99/mes).
2. **Identidad:** login simple (email mágico, o Sign in with Apple).
3. **Estado Pro + conteo de usos:** guardarlo del lado servidor (Cloudflare KV o
   D1), no en `localStorage` (el usuario puede borrarlo). El Worker valida que
   el usuario sea Pro antes de llamar a Anthropic.
4. **Webhook de Stripe** → marca al usuario como Pro al pagar / lo quita al cancelar.

El `worker.js` actual ya es la base: solo hay que añadirle el chequeo de
sesión/Pro antes de reenviar a Anthropic.
