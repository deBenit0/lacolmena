'use strict';
// Lectura del chat de Twitch por IRC en modo anónimo (justinfan).
// No hace falta token: Twitch envía a todos los espectadores las etiquetas
// de bits, subs, subs regaladas y Hype Chat.

const tls = require('node:tls');
const { EventEmitter } = require('node:events');

const HOST = 'irc.chat.twitch.tv';
const PORT = 6697;

// --- Parseo de líneas IRC ---------------------------------------------------

function unescapeTag(v) {
  return v.replace(/\\(.)/g, (_, c) => ({ s: ' ', ':': ';', '\\': '\\', r: '\r', n: '\n' }[c] ?? c));
}

function parseLine(line) {
  const msg = { tags: {}, prefix: null, command: null, params: [] };
  let rest = line;

  if (rest.startsWith('@')) {
    const sp = rest.indexOf(' ');
    for (const part of rest.slice(1, sp).split(';')) {
      const eq = part.indexOf('=');
      if (eq === -1) msg.tags[part] = '';
      else msg.tags[part.slice(0, eq)] = unescapeTag(part.slice(eq + 1));
    }
    rest = rest.slice(sp + 1);
  }
  if (rest.startsWith(':')) {
    const sp = rest.indexOf(' ');
    msg.prefix = rest.slice(1, sp);
    rest = rest.slice(sp + 1);
  }
  const trailingIdx = rest.indexOf(' :');
  let trailing = null;
  if (trailingIdx !== -1) {
    trailing = rest.slice(trailingIdx + 2);
    rest = rest.slice(0, trailingIdx);
  }
  const parts = rest.split(' ').filter(Boolean);
  msg.command = parts.shift() || null;
  msg.params = parts;
  if (trailing !== null) msg.params.push(trailing);
  return msg;
}

// --- De mensaje IRC a "aportación" -----------------------------------------
// Devuelve null si el mensaje no implica gasto, o un objeto:
// { id, login, nombre, tipo, cantidad, euros, texto }

const PLANES = { Prime: 'subPrime', 1000: 'subTier1', 2000: 'subTier2', 3000: 'subTier3' };
const NOMBRE_PLAN = { Prime: 'Prime', 1000: 'Tier 1', 2000: 'Tier 2', 3000: 'Tier 3' };

function valorSub(plan, config) {
  const clave = PLANES[plan] || 'subTier1';
  return Number(config.valores[clave]) || 0;
}

function quien(tags, prefix) {
  const login = (tags.login || (prefix ? prefix.split('!')[0] : '') || '').toLowerCase();
  return { login, nombre: tags['display-name'] || login };
}

function aportacionDesdeMensaje(msg, config) {
  const t = msg.tags;
  const id = t.id || null;

  if (msg.command === 'PRIVMSG') {
    const { login, nombre } = quien(t, msg.prefix);
    const res = [];

    const bits = parseInt(t.bits, 10);
    if (bits > 0) {
      res.push({
        id: id && `${id}:bits`, login, nombre, tipo: 'bits', cantidad: bits,
        euros: bits * Number(config.valores.bit || 0),
        texto: `${bits} bits`,
      });
    }

    // Hype Chat (mensaje fijado de pago)
    const pagado = parseInt(t['pinned-chat-paid-amount'], 10);
    if (pagado > 0) {
      const exp = parseInt(t['pinned-chat-paid-exponent'] || '2', 10);
      const moneda = (t['pinned-chat-paid-currency'] || 'EUR').toUpperCase();
      const importe = pagado / 10 ** exp;
      const tasa = config.conversionMonedas?.[moneda];
      res.push({
        id: id && `${id}:hype`, login, nombre, tipo: 'hypechat', cantidad: importe,
        euros: importe * (tasa ?? 1),
        texto: `Hype Chat ${importe} ${moneda}${tasa === undefined ? ' (moneda sin tasa, contada 1:1)' : ''}`,
      });
    }
    return res.length ? res : null;
  }

  if (msg.command === 'USERNOTICE') {
    const tipoAviso = t['msg-id'];
    const { login, nombre } = quien(t, msg.prefix);
    const plan = t['msg-param-sub-plan'];

    if (tipoAviso === 'sub' || tipoAviso === 'resub') {
      return [{
        id, login, nombre, tipo: 'sub', cantidad: 1,
        euros: valorSub(plan, config),
        texto: `${tipoAviso === 'resub' ? 'Resub' : 'Sub'} ${NOMBRE_PLAN[plan] || plan || ''}`.trim(),
      }];
    }

    // Cada sub regalada llega como un "subgift" individual (también las de un
    // regalo masivo "submysterygift"), así que contamos solo los subgift para
    // no duplicar.
    if (tipoAviso === 'subgift') {
      if (!config.subsRegaladasCuentanParaQuienRegala) return null;
      const para = t['msg-param-recipient-display-name'] || t['msg-param-recipient-user-name'] || '?';
      return [{
        id, login, nombre, tipo: 'regalo', cantidad: 1,
        euros: valorSub(plan, config),
        texto: `Regala sub ${NOMBRE_PLAN[plan] || ''} a ${para}`.replace(/\s+/g, ' '),
      }];
    }

    // Cuando alguien que recibió una sub regalada (o Prime) sigue pagando,
    // Twitch envía "giftpaidupgrade"/"primepaidupgrade": es una sub de pago.
    if (tipoAviso === 'giftpaidupgrade' || tipoAviso === 'primepaidupgrade') {
      return [{
        id, login, nombre, tipo: 'sub', cantidad: 1,
        euros: valorSub(plan || '1000', config),
        texto: 'Continúa su sub pagando',
      }];
    }
  }
  return null;
}

// --- Cliente --------------------------------------------------------------

class TwitchChat extends EventEmitter {
  constructor(canal) {
    super();
    this.canal = canal.toLowerCase().replace(/^#/, '');
    this.socket = null;
    this.buffer = '';
    this.reintentos = 0;
    this.parado = false;
    this.conectado = false;
  }

  conectar() {
    this.parado = false;
    const nick = `justinfan${Math.floor(10000 + Math.random() * 89999)}`;
    const sock = tls.connect({ host: HOST, port: PORT, servername: HOST });
    this.socket = sock;
    sock.setEncoding('utf8');

    sock.on('secureConnect', () => {
      sock.write('CAP REQ :twitch.tv/tags twitch.tv/commands\r\n');
      sock.write('PASS SCHMOOPIIE\r\n');
      sock.write(`NICK ${nick}\r\n`);
      sock.write(`JOIN #${this.canal}\r\n`);
    });

    sock.on('data', (chunk) => {
      this.buffer += chunk;
      let idx;
      while ((idx = this.buffer.indexOf('\r\n')) !== -1) {
        const linea = this.buffer.slice(0, idx);
        this.buffer = this.buffer.slice(idx + 2);
        if (linea) this._procesar(linea);
      }
    });

    const alCerrar = () => {
      if (this.socket !== sock) return;
      this.socket = null;
      this.buffer = '';
      if (this.conectado) this.emit('estado', { conectado: false });
      this.conectado = false;
      if (this.parado) return;
      const espera = Math.min(30000, 1000 * 2 ** this.reintentos++);
      this.emit('aviso', `Desconectado del chat. Reintentando en ${Math.round(espera / 1000)} s…`);
      setTimeout(() => this.conectar(), espera);
    };
    sock.on('error', (err) => this.emit('aviso', `Error de conexión: ${err.message}`));
    sock.on('close', alCerrar);
  }

  parar() {
    this.parado = true;
    this.socket?.destroy();
  }

  _procesar(linea) {
    const msg = parseLine(linea);
    switch (msg.command) {
      case 'PING':
        this.socket?.write(`PONG :${msg.params[0] || 'tmi.twitch.tv'}\r\n`);
        return;
      case 'RECONNECT':
        this.socket?.destroy();
        return;
      case 'JOIN':
        if (!this.conectado) {
          this.conectado = true;
          this.reintentos = 0;
          this.emit('estado', { conectado: true });
        }
        return;
      case 'NOTICE':
        this.emit('aviso', `Twitch: ${msg.params[msg.params.length - 1]}`);
        return;
      default:
        this.emit('mensaje', msg);
    }
  }
}

module.exports = { TwitchChat, parseLine, aportacionDesdeMensaje };
