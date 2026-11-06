'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const N = require('../js/nucleo.js');

globalThis.window = globalThis;
require('../js/rodillo.js');
const { desplazamientoFinal, indiceEnCentro } = window.Animacion._interno;

const aj = N.mezclarAjustes({ canal: 'prueba', modo: 'gasto', conversionMonedas: { USD: 0.9 } });
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

test('tier de sub sacado de las insignias', () => {
  assert.equal(N.tierDeEtiquetas({ badges: 'moderator/1' }), 0);
  assert.equal(N.tierDeEtiquetas({ badges: 'subscriber/0' }), 1);
  assert.equal(N.tierDeEtiquetas({ badges: 'vip/1,subscriber/12' }), 1);
  assert.equal(N.tierDeEtiquetas({ badges: 'subscriber/2003,premium/1' }), 2);
  assert.equal(N.tierDeEtiquetas({ badges: 'subscriber/3024' }), 3);
  assert.equal(N.tierDeEtiquetas({ badges: 'founder/0' }), 1);
  assert.equal(N.tierDeEtiquetas({ subscriber: '1' }), 1);
});

test('los mensajes, subs y regalos anotan el tier', () => {
  const e = N.estadoVacio();
  const meter = (linea) => acc(linea).forEach((a) => N.registrar(e, a, aj));
  meter(priv('badges=subscriber/2006;id=t1', 'ana', 'hola'));
  meter('@login=luis;id=t2;msg-id=resub;msg-param-sub-plan=3000 :tmi.twitch.tv USERNOTICE #prueba');
  meter('@login=gen;id=t3;msg-id=subgift;msg-param-sub-plan=1000;msg-param-recipient-user-name=suertudo :tmi.twitch.tv USERNOTICE #prueba');
  meter(priv('badges=subscriber/0;id=t4', 'ana', 'otra vez')); // no baja el tier
  assert.deepEqual(e.tiers, { ana: 2, luis: 3, suertudo: 1 });
  assert.equal(e.eventos.length, 2, 'el tier no ensucia la actividad');
});

test('modos de sorteo', () => {
  const e = N.estadoVacio();
  const entra = (login, tier, euros) => {
    N.registrar(e, { id: login, login, nombre: login, tipo: 'entrada', texto: '' }, aj);
    if (tier) N.registrar(e, { tipo: 'tier', login, tier }, aj);
    if (euros) N.registrar(e, { id: login + 'b', login, tipo: 'bits', cantidad: euros * 100, euros, texto: '' }, aj);
  };
  entra('nosub', 0, 10); entra('t1', 1); entra('t2', 2); entra('t3', 3);
  const papeletas = (modo) => Object.fromEntries(N.lista(e, { ...aj, modo }).participantes.map((p) => [p.login, p.papeletas]));
  assert.deepEqual(papeletas('igual'), { nosub: 1, t1: 1, t2: 1, t3: 1 });
  assert.deepEqual(papeletas('subs'), { nosub: 1, t1: 2, t2: 3, t3: 4 });
  assert.deepEqual(papeletas('soloSubs'), { nosub: 0, t1: 1, t2: 1, t3: 1 });
  assert.deepEqual(papeletas('gasto'), { nosub: 11, t1: 1, t2: 1, t3: 1 });
  // En solo subs, el que no es sub nunca puede ganar
  for (let i = 0; i < 50; i++) {
    const copia = JSON.parse(JSON.stringify(e));
    assert.notEqual(N.sortear(copia, { ...aj, modo: 'soloSubs' }).ganador.login, 'nosub');
  }
});

test('el dueño del canal no participa', () => {
  const e = N.estadoVacio();
  assert.equal(N.registrar(e, { id: 'x', login: 'prueba', tipo: 'entrada', texto: '' }, aj).motivo, 'es el dueño del canal');
});

test('cheer que además escribe la palabra da las dos cosas', () => {
  const r = acc(priv('bits=100;id=x', 'ana', '!sorteo Cheer100'));
  assert.deepEqual(r.map((a) => a.tipo), ['bits', 'entrada']);
});

test('subs, regalos, upgrades y prime', () => {
  const un = (t) => acc(`@${t} :tmi.twitch.tv USERNOTICE #prueba`).find((x) => x.tipo !== 'tier');
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

test('los nombres siempre se paran en el ganador', () => {
  for (let k = 0; k < 500; k++) {
    const e = N.estadoVacio();
    const n = 1 + Math.floor(Math.random() * 40);
    for (let i = 0; i < n; i++) N.registrar(e, { login: 'u' + i, nombre: 'U' + i, tipo: 'manual', euros: 1 + Math.random() * 30, texto: '' }, aj);
    const t = N.sortear(e, aj);
    assert.equal(t.tira[indiceEnCentro(desplazamientoFinal(t))], t.ganador.nombre);
    assert.ok(t.tira.length > t.indiceGanador + 3, 'quedan nombres por encima del ganador');
    if (n > 1) {
      assert.notEqual(t.tira[t.indiceGanador - 1], t.ganador.nombre, 'el anterior no es el ganador');
      for (let j = 1; j < t.indiceGanador; j++) assert.notEqual(t.tira[j], t.tira[j - 1], 'sin repetidos seguidos');
    }
  }
});

test('en la tira sale más quien tiene más papeletas', () => {
  const segs = [{ nombre: 'Mucho', papeletas: 50 }, { nombre: 'Poco', papeletas: 1 }, { nombre: 'Medio', papeletas: 10 }];
  const { tira } = N.construirTira(segs, 1, 2000);
  const cuenta = (x) => tira.filter((n) => n === x).length;
  assert.ok(cuenta('Mucho') > cuenta('Medio') && cuenta('Medio') > cuenta('Poco'));
});
