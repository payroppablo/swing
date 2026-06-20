// SwingLens — Birdie backend (Cloudflare Worker)
// ---------------------------------------------------------------------------
// Esconde tu ANTHROPIC_API_KEY del lado del servidor para que la app NO tenga
// que pedirle la key al usuario. La app (index.html) le hace POST con el mismo
// payload de /v1/messages y este Worker le agrega la key real y reenvía a
// Anthropic, devolviendo la respuesta con los headers CORS necesarios.
//
// DESPLIEGUE (rápido, sin instalar nada):
//   1. Entra a https://dash.cloudflare.com  ->  Workers & Pages  ->  Create  ->  Worker
//   2. Ponle nombre (ej. swinglens-birdie)  ->  Deploy
//   3. Edit code  ->  pega TODO este archivo  ->  Deploy
//   4. Settings  ->  Variables and Secrets  ->  Add  ->  tipo "Secret":
//        Name:  ANTHROPIC_API_KEY     Value: tu key sk-ant-...
//      (opcional) otra variable normal:
//        Name:  ALLOWED_ORIGIN        Value: https://payroppablo.github.io
//   5. Copia la URL del worker (https://swinglens-birdie.TUCUENTA.workers.dev)
//      y pégala en index.html en la constante BIRDIE_PROXY.
//
// NOTA: esto cubre (a) esconder la key y (b) que Birdie funcione sin pedirla.
// El COBRO real de la suscripción (Stripe) y el conteo de usos por usuario
// necesitan cuentas/login y se montan aparte — ver README sección "Producción".
// ---------------------------------------------------------------------------

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const allowed = env.ALLOWED_ORIGIN || '*';
    const cors = {
      'Access-Control-Allow-Origin': allowed === '*' ? '*' : origin,
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400',
      'Vary': 'Origin',
    };

    // Preflight
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });

    if (request.method !== 'POST') {
      return json({ error: { message: 'Use POST' } }, 405, cors);
    }

    // (opcional) bloquea orígenes que no sean el tuyo
    if (allowed !== '*' && origin && origin !== allowed) {
      return json({ error: { message: 'Origin not allowed' } }, 403, cors);
    }

    if (!env.ANTHROPIC_API_KEY) {
      return json({ error: { message: 'Server missing ANTHROPIC_API_KEY' } }, 500, cors);
    }

    let body;
    try { body = await request.json(); }
    catch { return json({ error: { message: 'Invalid JSON' } }, 400, cors); }

    // Límite básico de tamaño (evita abusos)
    const approxSize = JSON.stringify(body).length;
    if (approxSize > 8 * 1024 * 1024) {
      return json({ error: { message: 'Payload too large' } }, 413, cors);
    }

    // Reenvía a Anthropic con la key real
    let upstream;
    try {
      upstream = await fetch(ANTHROPIC_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: body.model || 'claude-sonnet-4-6',
          max_tokens: Math.min(body.max_tokens || 900, 2000),
          messages: body.messages || [],
        }),
      });
    } catch (e) {
      return json({ error: { message: 'Upstream error: ' + e.message } }, 502, cors);
    }

    const data = await upstream.text();
    return new Response(data, {
      status: upstream.status,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });
  },
};

function json(obj, status, cors) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}
