'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const N = require('../js/nucleo.js');

globalThis.window = globalThis;
require('../js/rueda.js');
const { trozos, anguloFinal, indiceBajoPuntero } = window.Rueda._interno;

const aj = N.mezclarAjustes({ canal: 'prueba', conversionMonedas: { USD: 0.9 } });
const acc = (linea, a = aj) => N.accionesDesdeMensaje(N.parseLine(linea), a);
const priv = (tags, usuario, texto) => `@${tags} :${usuario}!${usuario}@${usuario}.tmi.twitch.tv PRIVMSG #prueba :${texto}`;

test('ajustes guardados se mezclan con los de serie', () => {
  const a = N.mezclarAjustes({ valores: { bit: 0.02 }, maximo: 5, inventado: 1 });
  assert.equal(a.valores.bit, 0.02);
  assert.equal(a.valores.subTier1, 3.99);
  assert.equal(a.maximo, 5);
  assert.equal(a.inventado, undefined);
});

test('bits', () => {
  const [r] = acc(priv('bits=250;display-name=Abeja_Reina;id=m1', 'abeja_reina', 'Cheer250 vamos'));
  assert.deepEqual([r.tipo, r.login, r.nombre, r.cantidad], ['bits', 'abeja_reina', 'Abeja_Reina', 250]);
  assert.ok(Math.abs(r.euros - 2.5) < 1e-9);
});

test('palabra clave: solo como primera palabra y sin distinguir mayúsculas', () => {
  assert.equal(acc(priv('display-name=Pepe;id=a', 'pepe', '!SORTEO por favor'))[0].tipo, 'entrada');
  assert.equal(acc(priv('display-name=Pepe;id=b', 'pepe', 'quiero !sorteo')).length, 0);
  assert.equal(acc(priv('display-name=Pepe;id=c', 'pepe', 'hola')).length, 0);
  assert.equal(acc(priv('id=d', 'pepe', '!sorteo'), { ...aj, palabraClave: '' }).length, 0);
});

test('palabra clave solo para suscriptores', () => {
  const soloSubs = { ...aj, soloSuscriptores: true };
  assert.equal(acc(priv('subscriber=0;id=a', 'pepe', '!sorteo'), soloSubs)[0].rechazo, 'solo suscriptores');
  assert.equal(acc(priv('subscriber=1;id=b', 'pepe', '!sorteo'), soloSubs)[0].rechazo, undefined);
  assert.equal(acc(priv('badges=founder/0;id=c', 'pepe', '!sorteo'), soloSubs)[0].rechazo, undefined);
});

test('cheer que además escribe la palabra da las dos cosas', () => {
  const r = acc(priv('bits=100;id=x', 'ana', '!sorteo Cheer100'));
  assert.deepEqual(r.map((a) => a.tipo), ['bits', 'entrada']);
});

test('subs, regalos, upgrades y prime', () => {
  const un = (t) => acc(`@${t} :tmi.twitch.tv USERNOTICE #prueba`)[0];
  assert.equal(un('login=z;id=1;msg-id=sub;msg-param-sub-plan=1000').euros, 3.99);
  assert.equal(un('login=z;id=2;msg-id=resub;msg-param-sub-plan=3000').euros, 19.99);
  assert.equal(un('login=z;id=3;msg-id=sub;msg-param-sub-plan=Prime').euros, 0);
  const g = un('login=gen;display-name=Gen;id=4;msg-id=subgift;msg-param-sub-plan=1000;msg-param-recipient-display-name=Suertudo');
  assert.equal(g.tipo, 'regalo'); assert.equal(g.login, 'gen'); assert.match(g.texto, /Suertudo/);
  assert.equal(acc('@login=gen;id=5;msg-id=submysterygift;msg-param-sub-plan=1000 :tmi.twitch.tv USERNOTICE #prueba').length, 0);
  assert.equal(un('login=z;id=6;msg-id=giftpaidupgrade').euros, 3.99);
});

test('Hype Chat con conversión de moneda', () => {
  const [r] = acc(priv('id=h;pinned-chat-paid-amount=1000;pinned-chat-paid-currency=USD;pinned-chat-paid-exponent=2', 'rica', 'hola'));
  assert.equal(r.tipo, 'hypechat');
  assert.ok(Math.abs(r.euros - 9) < 1e-9);
});

test('etiquetas escapadas', () => {
  const m = N.parseLine('@display-name=a\\sb;system-msg=x\\:y :tmi.twitch.tv USERNOTICE #c');
  assert.equal(m.tags['display-name'], 'a b');
  assert.equal(m.tags['system-msg'], 'x;y');
});

test('papeletas: escribir + gastar, mínimo, máximo y quien gasta sin escribir', () => {
  const p = (escribio, euros, extra = {}) => N.papeletasDe({ escribio, euros, excluido: false }, { ...aj, ...extra });
  assert.equal(p(true, 0), 1);
  assert.equal(p(false, 0.3), 1);
  assert.equal(p(true, 3.99), 4);
  assert.equal(p(true, 12.98), 13);
  assert.equal(p(false, 100, { maximo: 20 }), 20);
  assert.equal(p(false, 5, { gastanEntranSinEscribir: false }), 0);
  assert.equal(p(true, 5, { gastanEntranSinEscribir: false }), 6);
  assert.equal(p(true, 0, { papeletasPorEscribir: 3 }), 3);
  assert.equal(N.papeletasDe({ escribio: true, euros: 50, excluido: true }, aj), 0);
});

test('elección ponderada recorre bien los tramos', () => {
  const conteo = [0, 0, 0];
  for (let r = 0; r < 10; r++) conteo[N.elegirPonderado([1, 3, 6], () => r)]++;
  assert.deepEqual(conteo, [1, 3, 6]);
  assert.equal(N.elegirPonderado([0, 0]), -1);
  for (let i = 0; i < 200; i++) { const k = N.elegirPonderado([5, 0, 5]); assert.ok(k === 0 || k === 2); }
});

test('registro: duplicados, bots, cerrado, palabra repetida', () => {
  const e = N.estadoVacio();
  const r = (a) => N.registrar(e, a, aj);
  r({ id: 'a', login: 'ana', nombre: 'Ana', tipo: 'bits', cantidad: 500, euros: 5, texto: '500 bits' });
  assert.equal(r({ id: 'a', login: 'ana', nombre: 'Ana', tipo: 'bits', cantidad: 500, euros: 5, texto: '500 bits' }), null);
  r({ id: 'b', login: 'ana', tipo: 'entrada', texto: 'escribe' });
  assert.equal(r({ id: 'b2', login: 'ana', tipo: 'entrada', texto: 'escribe' }), null);
  assert.equal(r({ id: 'c', login: 'nightbot', tipo: 'entrada', texto: 'x' }).motivo, 'usuario ignorado');
  r({ id: 'd', login: 'luis', nombre: 'Luis', tipo: 'entrada', texto: 'escribe' });
  e.abierto = false;
  assert.equal(r({ id: 'e', login: 'tarde', tipo: 'entrada', texto: 'x' }).motivo, 'sorteo cerrado');
  const l = N.lista(e, aj);
  assert.deepEqual(l.participantes.map((p) => [p.login, p.papeletas]), [['ana', 6], ['luis', 1]]);
  assert.equal(l.totalPapeletas, 7);
});

test('ajuste manual negativo puede quitar a alguien', () => {
  const e = N.estadoVacio();
  N.registrar(e, { login: 'eva', tipo: 'manual', cantidad: 2, euros: 2, texto: '+2' }, aj);
  assert.equal(N.lista(e, aj).totalPapeletas, 2);
  N.registrar(e, { login: 'eva', tipo: 'manual', cantidad: -5, euros: -5, texto: '-5' }, aj);
  assert.equal(N.lista(e, aj).participantes.length, 0);
});

test('sortear excluye al ganador y se agota', () => {
  const e = N.estadoVacio();
  for (const login of ['a', 'b', 'c']) N.registrar(e, { login, tipo: 'entrada', texto: 'x' }, aj);
  const vistos = new Set();
  for (let i = 0; i < 3; i++) vistos.add(N.sortear(e, aj).ganador.login);
  assert.equal(vistos.size, 3);
  assert.equal(N.sortear(e, aj), null);
});

test('la ruleta siempre se para en el trozo del ganador', () => {
  for (let k = 0; k < 500; k++) {
    const e = N.estadoVacio();
    const n = 1 + Math.floor(Math.random() * 40);
    for (let i = 0; i < n; i++) N.registrar(e, { login: 'u' + i, tipo: 'manual', euros: 1 + Math.random() * 30, texto: '' }, aj);
    const t = N.sortear(e, aj);
    assert.equal(indiceBajoPuntero(trozos(t.segmentos), anguloFinal(t)), t.indiceGanador);
    assert.equal(t.segmentos[t.indiceGanador].login, t.ganador.login);
  }
});
