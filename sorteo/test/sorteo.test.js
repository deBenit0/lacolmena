'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { parseLine, aportacionDesdeMensaje } = require('../src/twitch');
const { Sorteo, calcularPapeletas, elegirPonderado } = require('../src/sorteo');

const config = {
  canal: 'prueba',
  abrirAlArrancar: true,
  valores: { bit: 0.01, subPrime: 0, subTier1: 3.99, subTier2: 7.99, subTier3: 19.99 },
  papeletas: { eurosPorPapeleta: 1, minimaSiHaGastado: 1, maximo: 0 },
  subsRegaladasCuentanParaQuienRegala: true,
  conversionMonedas: { EUR: 1, USD: 0.9 },
  ignorar: ['nightbot'],
};

const ap = (linea) => aportacionDesdeMensaje(parseLine(linea), config);

test('bits en PRIVMSG', () => {
  const r = ap('@badge-info=;bits=250;display-name=Abeja_Reina;id=m1;user-id=1 :abeja_reina!abeja_reina@abeja_reina.tmi.twitch.tv PRIVMSG #prueba :Cheer250 vamos');
  assert.equal(r.length, 1);
  assert.equal(r[0].login, 'abeja_reina');
  assert.equal(r[0].nombre, 'Abeja_Reina');
  assert.equal(r[0].tipo, 'bits');
  assert.equal(r[0].cantidad, 250);
  assert.ok(Math.abs(r[0].euros - 2.5) < 1e-9);
});

test('mensaje normal no cuenta', () => {
  assert.equal(ap('@display-name=Pepe;id=m2 :pepe!pepe@pepe.tmi.twitch.tv PRIVMSG #prueba :hola'), null);
});

test('sub, resub y prime', () => {
  const sub = ap('@display-name=Zángano;id=u1;login=zangano;msg-id=sub;msg-param-sub-plan=1000 :tmi.twitch.tv USERNOTICE #prueba');
  assert.equal(sub[0].euros, 3.99);
  assert.equal(sub[0].nombre, 'Zángano');
  const t3 = ap('@display-name=X;id=u2;login=x;msg-id=resub;msg-param-sub-plan=3000 :tmi.twitch.tv USERNOTICE #prueba :mensaje');
  assert.equal(t3[0].euros, 19.99);
  const prime = ap('@display-name=P;id=u3;login=p;msg-id=sub;msg-param-sub-plan=Prime :tmi.twitch.tv USERNOTICE #prueba');
  assert.equal(prime[0].euros, 0);
});

test('subgift cuenta para quien regala; submysterygift no se duplica', () => {
  const g = ap('@display-name=Gen;id=g1;login=gen;msg-id=subgift;msg-param-sub-plan=1000;msg-param-recipient-display-name=Suertudo :tmi.twitch.tv USERNOTICE #prueba');
  assert.equal(g[0].login, 'gen');
  assert.equal(g[0].tipo, 'regalo');
  assert.match(g[0].texto, /Suertudo/);
  const mystery = ap('@display-name=Gen;id=g0;login=gen;msg-id=submysterygift;msg-param-mass-gift-count=5;msg-param-sub-plan=1000 :tmi.twitch.tv USERNOTICE #prueba');
  assert.equal(mystery, null);
});

test('Hype Chat con conversión de moneda', () => {
  const r = ap('@display-name=Rica;id=h1;pinned-chat-paid-amount=1000;pinned-chat-paid-currency=USD;pinned-chat-paid-exponent=2 :rica!rica@rica.tmi.twitch.tv PRIVMSG #prueba :hola');
  assert.equal(r[0].tipo, 'hypechat');
  assert.ok(Math.abs(r[0].euros - 9) < 1e-9);
});

test('etiquetas escapadas', () => {
  const m = parseLine('@display-name=a\\sb;system-msg=x\\:y :tmi.twitch.tv USERNOTICE #c');
  assert.equal(m.tags['display-name'], 'a b');
  assert.equal(m.tags['system-msg'], 'x;y');
});

test('cálculo de papeletas', () => {
  const reglas = { eurosPorPapeleta: 1, minimaSiHaGastado: 1, maximo: 0 };
  assert.equal(calcularPapeletas(0, reglas), 0);
  assert.equal(calcularPapeletas(0.3, reglas), 1);
  assert.equal(calcularPapeletas(3.99, reglas), 3);
  assert.equal(calcularPapeletas(5, reglas), 5);
  assert.equal(calcularPapeletas(100, { ...reglas, maximo: 20 }), 20);
  assert.equal(calcularPapeletas(4.99, { eurosPorPapeleta: 0.5, minimaSiHaGastado: 1 }), 9);
});

test('elección ponderada recorre bien los tramos', () => {
  const pesos = [1, 3, 6];
  const conteo = [0, 0, 0];
  for (let r = 0; r < 10; r++) conteo[elegirPonderado(pesos, () => r)]++;
  assert.deepEqual(conteo, [1, 3, 6]);
  assert.equal(elegirPonderado([0, 0]), -1);
});

test('sorteo acumula, ignora duplicados/bots/cerrado y saca ganador', () => {
  const s = new Sorteo(config);
  s.registrar({ id: 'a', login: 'ana', nombre: 'Ana', tipo: 'bits', cantidad: 500, euros: 5, texto: '500 bits' });
  s.registrar({ id: 'a', login: 'ana', nombre: 'Ana', tipo: 'bits', cantidad: 500, euros: 5, texto: '500 bits' });
  s.registrar({ id: 'b', login: 'ana', nombre: 'Ana', tipo: 'sub', cantidad: 1, euros: 3.99, texto: 'Sub' });
  s.registrar({ id: 'c', login: 'nightbot', nombre: 'Nightbot', tipo: 'bits', cantidad: 100, euros: 1, texto: '100 bits' });
  s.registrar({ id: 'd', login: 'luis', nombre: 'Luis', tipo: 'regalo', cantidad: 1, euros: 3.99, texto: 'Regala sub' });
  s.cerrar();
  s.registrar({ id: 'e', login: 'tarde', nombre: 'Tarde', tipo: 'bits', cantidad: 100, euros: 1, texto: '100 bits' });

  const { participantes, totalPapeletas } = s.lista();
  assert.deepEqual(participantes.map((p) => [p.login, p.euros, p.papeletas]), [['ana', 8.99, 8], ['luis', 3.99, 3]]);
  assert.equal(totalPapeletas, 11);

  const r = s.sortear({ quitarGanador: true });
  assert.ok(['ana', 'luis'].includes(r.ganador.login));
  assert.equal(s.lista().participantes.find((p) => p.login === r.ganador.login).papeletas, 0);
  const r2 = s.sortear();
  assert.notEqual(r2.ganador.login, r.ganador.login);
  assert.equal(s.sortear(), null);
});

test('ajuste manual negativo puede quitar a alguien', () => {
  const s = new Sorteo(config);
  s.registrar({ login: 'eva', tipo: 'manual', cantidad: 2, euros: 2, texto: '+2' });
  assert.equal(s.lista().totalPapeletas, 2);
  s.registrar({ login: 'eva', tipo: 'manual', cantidad: -2, euros: -2, texto: '-2' });
  assert.equal(s.lista().participantes.length, 0);
});

test('cliente IRC: PING, JOIN y mensajes', () => {
  const { TwitchChat } = require('../src/twitch');
  const chat = new TwitchChat('#Prueba');
  const escritos = [];
  chat.socket = { write: (t) => escritos.push(t), destroy() {} };
  const estados = [];
  const mensajes = [];
  chat.on('estado', (e) => estados.push(e));
  chat.on('mensaje', (m) => mensajes.push(m));
  chat._procesar('PING :tmi.twitch.tv');
  chat._procesar(':justinfan1!justinfan1@justinfan1.tmi.twitch.tv JOIN #prueba');
  chat._procesar('@bits=10;display-name=A;id=z :a!a@a.tmi.twitch.tv PRIVMSG #prueba :Cheer10');
  assert.equal(chat.canal, 'prueba');
  assert.deepEqual(escritos, ['PONG :tmi.twitch.tv\r\n']);
  assert.deepEqual(estados, [{ conectado: true }]);
  assert.equal(mensajes.length, 1);
  assert.equal(aportacionDesdeMensaje(mensajes[0], config)[0].cantidad, 10);
});
