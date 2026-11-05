'use strict';
// Servidor local: conecta al chat de Twitch, lleva el sorteo y sirve el panel
// (http://localhost:3000) y el overlay para OBS (http://localhost:3000/overlay).

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { TwitchChat, aportacionDesdeMensaje } = require('./twitch');
const { Sorteo } = require('./sorteo');

const RAIZ = path.join(__dirname, '..');
const RUTA_CONFIG = process.env.SORTEO_CONFIG || path.join(RAIZ, 'config.json');

function cargarConfig() {
  const config = JSON.parse(fs.readFileSync(RUTA_CONFIG, 'utf8'));
  const canalArg = process.argv[2];
  if (canalArg) config.canal = canalArg;
  if (!config.canal || config.canal === 'tu_canal_de_twitch') {
    console.error('\n  Pon el nombre de tu canal en config.json ("canal") o arranca con:  npm start -- tucanal\n');
    process.exit(1);
  }
  config.canal = config.canal.toLowerCase().replace(/^#/, '');
  return config;
}

const config = cargarConfig();
const sorteo = new Sorteo(config, { archivo: path.join(RAIZ, 'datos', `sorteo-${config.canal}.json`) });
const chat = new TwitchChat(config.canal);

// --- Notificaciones en vivo (Server-Sent Events) ---------------------------
const clientes = new Set();
let estadoChat = { conectado: false, aviso: 'Conectando…' };

function emitir(tipo, datos) {
  const payload = `event: ${tipo}\ndata: ${JSON.stringify(datos)}\n\n`;
  for (const res of clientes) res.write(payload);
}
const emitirEstado = () => emitir('estado', { ...sorteo.resumen(), chat: estadoChat });

// --- Chat -> sorteo -------------------------------------------------------
chat.on('estado', ({ conectado }) => {
  estadoChat = { conectado, aviso: conectado ? `Leyendo el chat de #${config.canal}` : 'Desconectado' };
  console.log(conectado ? `✔ Conectado al chat de #${config.canal}` : '✖ Desconectado del chat');
  emitirEstado();
});
chat.on('aviso', (texto) => {
  estadoChat = { ...estadoChat, aviso: texto };
  console.log(texto);
  emitirEstado();
});
chat.on('mensaje', (msg) => {
  const aportaciones = aportacionDesdeMensaje(msg, config);
  if (!aportaciones) return;
  for (const ap of aportaciones) {
    const r = sorteo.registrar(ap);
    if (r.evento) {
      console.log(`${r.contado ? '+' : '·'} ${ap.nombre}: ${ap.texto} (${ap.euros.toFixed(2)} €)${r.motivo ? ` — no cuenta: ${r.motivo}` : ''}`);
    }
  }
  emitirEstado();
});

// --- HTTP -----------------------------------------------------------------
function leerJSON(req) {
  return new Promise((resolve) => {
    let cuerpo = '';
    req.on('data', (c) => { cuerpo += c; if (cuerpo.length > 1e5) req.destroy(); });
    req.on('end', () => { try { resolve(cuerpo ? JSON.parse(cuerpo) : {}); } catch { resolve({}); } });
  });
}

function json(res, codigo, datos) {
  res.writeHead(codigo, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(datos));
}

function servirArchivo(res, nombre) {
  const ruta = path.join(RAIZ, 'public', nombre);
  fs.readFile(ruta, (err, datos) => {
    if (err) { res.writeHead(404); return res.end('No encontrado'); }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(datos);
  });
}

const SIMULACIONES = {
  bits: (u) => ({ login: u, nombre: u, tipo: 'bits', cantidad: 500, euros: 500 * config.valores.bit, texto: '500 bits (prueba)' }),
  sub: (u) => ({ login: u, nombre: u, tipo: 'sub', cantidad: 1, euros: config.valores.subTier1, texto: 'Sub Tier 1 (prueba)' }),
  regalo: (u) => ({ login: u, nombre: u, tipo: 'regalo', cantidad: 1, euros: config.valores.subTier1, texto: 'Regala sub Tier 1 (prueba)' }),
  hypechat: (u) => ({ login: u, nombre: u, tipo: 'hypechat', cantidad: 5, euros: 5, texto: 'Hype Chat 5 EUR (prueba)' }),
};

const servidor = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const ruta = url.pathname;

  if (req.method === 'GET') {
    if (ruta === '/') return servirArchivo(res, 'index.html');
    if (ruta === '/overlay') return servirArchivo(res, 'overlay.html');
    if (ruta === '/api/estado') return json(res, 200, { ...sorteo.resumen(), chat: estadoChat });
    if (ruta === '/api/eventos') {
      res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
      res.write(`event: estado\ndata: ${JSON.stringify({ ...sorteo.resumen(), chat: estadoChat })}\n\n`);
      clientes.add(res);
      const latido = setInterval(() => res.write(': ping\n\n'), 25000);
      req.on('close', () => { clearInterval(latido); clientes.delete(res); });
      return;
    }
  }

  if (req.method === 'POST') {
    const body = await leerJSON(req);
    switch (ruta) {
      case '/api/abrir': sorteo.abrir(); break;
      case '/api/cerrar': sorteo.cerrar(); break;
      case '/api/reiniciar': sorteo.reiniciar(); break;
      case '/api/excluir':
        if (!sorteo.excluir(body.login, body.excluido !== false)) return json(res, 404, { error: 'No existe ese participante' });
        break;
      case '/api/manual': {
        const usuario = String(body.usuario || '').trim().replace(/^@/, '');
        const euros = Number(body.euros);
        if (!usuario || !Number.isFinite(euros) || euros === 0) return json(res, 400, { error: 'Usuario y euros (distinto de 0) obligatorios' });
        sorteo.registrar({ login: usuario, nombre: usuario, tipo: 'manual', cantidad: euros, euros, texto: `Ajuste manual ${euros > 0 ? '+' : ''}${euros} €${body.nota ? ` (${body.nota})` : ''}` });
        break;
      }
      case '/api/simular': {
        const crear = SIMULACIONES[body.tipo];
        if (!crear) return json(res, 400, { error: 'Tipo de simulación no válido' });
        const u = String(body.usuario || `prueba${Math.floor(Math.random() * 90 + 10)}`).toLowerCase();
        sorteo.registrar(crear(u));
        break;
      }
      case '/api/sortear': {
        const r = sorteo.sortear({ quitarGanador: body.quitarGanador !== false });
        if (!r) return json(res, 409, { error: 'No hay nadie con papeletas' });
        emitir('ganador', r);
        console.log(`🏆 Ganador: ${r.ganador.nombre} (${r.ganador.papeletas}/${r.ganador.totalPapeletas} papeletas)`);
        emitirEstado();
        return json(res, 200, r);
      }
      default: return json(res, 404, { error: 'Ruta desconocida' });
    }
    emitirEstado();
    return json(res, 200, { ok: true });
  }

  res.writeHead(404); res.end('No encontrado');
});

// Solo escucha en tu propio PC: el panel no tiene contraseña.
servidor.listen(config.puerto, '127.0.0.1', () => {
  console.log(`\n  Panel del sorteo:  http://localhost:${config.puerto}`);
  console.log(`  Overlay para OBS:  http://localhost:${config.puerto}/overlay\n`);
  chat.conectar();
});

function salir() {
  sorteo.guardarYa();
  chat.parar();
  process.exit(0);
}
process.on('SIGINT', salir);
process.on('SIGTERM', salir);
