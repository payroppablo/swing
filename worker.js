// SwingLens — Birdie backend (Cloudflare Worker)
// ---------------------------------------------------------------------------
// Proxy que esconde las API keys del lado servidor y soporta DOS proveedores:
//   - Claude  (Anthropic)
//   - Gemini  (Google) — más barato, con capa gratis (ideal para la prueba)
//
// La app (web o iOS) SIEMPRE manda el mismo payload estilo Anthropic
// ({ model, max_tokens, messages:[{role, content:[{type:'text'|'image', ...}]}] })
// y el worker traduce a Gemini si hace falta. La respuesta SIEMPRE se devuelve
// en forma { content: [{ type:'text', text }] } para que el cliente no cambie.
//
// VARIABLES (Settings -> Variables and Secrets):
//   PROVIDER          = 'claude' | 'gemini'   (default 'claude')
//   ANTHROPIC_API_KEY = sk-ant-...   (secret, si usas claude)
//   GEMINI_API_KEY    = AIza...      (secret, si usas gemini)
//   ALLOWED_ORIGIN    = https://payroppablo.github.io   (opcional)
//
// Despliegue: dash.cloudflare.com -> Workers -> Create -> pega esto -> Deploy.
// ---------------------------------------------------------------------------

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const GEMINI_MODEL = 'gemini-2.0-flash';

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
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    if (request.method !== 'POST') return json({ error: { message: 'Use POST' } }, 405, cors);
    if (allowed !== '*' && origin && origin !== allowed)
      return json({ error: { message: 'Origin not allowed' } }, 403, cors);

    let body;
    try { body = await request.json(); }
    catch { return json({ error: { message: 'Invalid JSON' } }, 400, cors); }

    const provider = (env.PROVIDER || 'claude').toLowerCase();
    try {
      if (provider === 'gemini') return await callGemini(body, env, cors);
      return await callClaude(body, env, cors);
    } catch (e) {
      return json({ error: { message: 'Proxy error: ' + e.message } }, 502, cors);
    }
  },
};

async function callClaude(body, env, cors) {
  if (!env.ANTHROPIC_API_KEY) return json({ error: { message: 'Missing ANTHROPIC_API_KEY' } }, 500, cors);
  const r = await fetch(ANTHROPIC_URL, {
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
  const data = await r.text();
  // Claude ya devuelve { content:[{type:'text',text}] } -> passthrough
  return new Response(data, { status: r.status, headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function callGemini(body, env, cors) {
  if (!env.GEMINI_API_KEY) return json({ error: { message: 'Missing GEMINI_API_KEY' } }, 500, cors);

  // Traducir messages estilo Anthropic -> parts de Gemini
  const parts = [];
  for (const m of (body.messages || [])) {
    const content = Array.isArray(m.content) ? m.content : [{ type: 'text', text: String(m.content) }];
    for (const block of content) {
      if (block.type === 'text') parts.push({ text: block.text });
      else if (block.type === 'image' && block.source && block.source.type === 'base64') {
        parts.push({ inline_data: { mime_type: block.source.media_type || 'image/jpeg', data: block.source.data } });
      }
    }
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${env.GEMINI_API_KEY}`;
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts }],
      generationConfig: { maxOutputTokens: Math.min(body.max_tokens || 900, 2000) },
    }),
  });
  const g = await r.json();
  if (g.error) return json({ error: { message: g.error.message || 'Gemini error' } }, r.status, cors);

  const text = (g.candidates?.[0]?.content?.parts || []).map(p => p.text || '').join('');
  // Normalizar a la forma que espera el cliente
  return json({ content: [{ type: 'text', text }] }, 200, cors);
}

function json(obj, status, cors) {
  return new Response(JSON.stringify(obj), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
}
