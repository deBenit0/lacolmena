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

test('bonus para el top 3 de regaladores de subs y de bits', () => {
  const e = N.estadoVacio();
  const meter = (login, tipo, cantidad, veces = 1) => {
    for (let i = 0; i < veces; i++) N.registrar(e, { id: `${login}${tipo}${i}`, login, nombre: login, tipo, cantidad, euros: tipo === 'bits' ? cantidad / 100 : 3.99, texto: '' }, aj);
  };
  meter('reina', 'regalo', 1, 10);   // top 1 regalos
  meter('rey', 'regalo', 1, 5);      // top 2 regalos (empata con duque)
  meter('duque', 'regalo', 1, 5);    // top 2 regalos
  meter('conde', 'regalo', 1, 1);    // puesto 4 -> nada
  meter('bitero', 'bits', 1000);     // top 1 bits
  meter('reina', 'bits', 500);       // top 2 bits
  meter('poco', 'bits', 100);        // top 3 bits
  N.registrar(e, { id: 'n', login: 'normal', tipo: 'entrada', texto: '' }, aj);

  const papeletas = (extra) => Object.fromEntries(N.lista(e, { ...aj, modo: 'igual', ...extra }).participantes.map((p) => [p.login, p.papeletas]));
  assert.deepEqual(papeletas({ bonusTop: false }), { reina: 1, rey: 1, duque: 1, conde: 1, bitero: 1, poco: 1, normal: 1 });
  // reina: 1 + 3 (top1 regalos) + 2 (top2 bits); rey/duque: 1 + 2; bitero: 1 + 3; poco: 1 + 1
  assert.deepEqual(papeletas({ bonusTop: true }), { reina: 6, rey: 3, duque: 3, conde: 1, bitero: 4, poco: 2, normal: 1 });
  assert.deepEqual(papeletas({ bonusTop: true, bonusTop1: 10, bonusTop2: 0, bonusTop3: 0 }).reina, 11 + 0);

  // En "Solo subs" el bonus no mete a quien no es sub
  N.registrar(e, { tipo: 'tier', login: 'rey', tier: 1 }, aj);
  const soloSubs = papeletas({ bonusTop: true, modo: 'soloSubs' });
  assert.equal(soloSubs.reina, 0);
  assert.equal(soloSubs.rey, 3);

  const { tops } = N.lista(e, { ...aj, bonusTop: true });
  assert.deepEqual(tops.regalos.map((t) => [t.login, t.puesto]), [['reina', 1], ['duque', 2], ['rey', 2]]);
  assert.deepEqual(tops.bits.map((t) => [t.login, t.cantidad, t.puesto]), [['bitero', 1000, 1], ['reina', 500, 2], ['poco', 100, 3]]);
});

test('modo subathon: solo regalos y donaciones, más papeletas a quien más dona', () => {
  const sub = { ...aj, modo: 'subathon', subathonNeto: false };
  const e = N.estadoVacio();
  const meter = (linea) => acc(linea, sub).forEach((a) => N.registrar(e, a, sub));
  meter(priv('id=a1', 'mirona', '!sorteo'));                                                         // escribir no mete
  meter('@login=propia;id=a2;msg-id=sub;msg-param-sub-plan=1000 :tmi.twitch.tv USERNOTICE #prueba');  // sub propia no cuenta
  meter('@login=regalona;display-name=Regalona;id=a3;msg-id=subgift;msg-param-sub-plan=1000;msg-param-recipient-user-name=x :tmi.twitch.tv USERNOTICE #prueba');
  meter('@login=regalona;display-name=Regalona;id=a4;msg-id=subgift;msg-param-sub-plan=1000;msg-param-recipient-user-name=y :tmi.twitch.tv USERNOTICE #prueba');
  meter(priv('bits=500;id=a5', 'bitera', 'Cheer500'));
  meter(priv('bits=50;id=a6', 'tacana', 'Cheer50'));                                                 // 0,50 €: no llega al mínimo de 1 €
  meter(priv('id=a7', 'streamelements', 'Donante just tipped €12.50 PogChamp'));
  meter(priv('id=a8', 'streamelements', 'Donante ha donado 2,50 €'));
  meter(priv('id=a9', 'streamelements', '¡Gracias por seguir el canal!'));                           // no es donación
  const l = N.lista(e, sub);
  const pap = Object.fromEntries(l.participantes.map((p) => [p.login, p.papeletas]));
  assert.deepEqual(pap, { donante: 15, regalona: 7, bitera: 5, tacana: 0, propia: 0 });
  assert.equal(e.participantes.mirona, undefined);
  assert.equal(e.participantes.donante.detalle.donaciones, 15);
  // con mínimo 0 entra cualquiera que haya donado algo
  assert.equal(N.lista(e, { ...sub, subathonMinimo: 0 }).participantes.find((p) => p.login === 'tacana').papeletas, 1);
  // regalos cuentan en el subathon aunque esté desactivado para el modo gasto
  const e2 = N.estadoVacio();
  acc('@login=r;id=b1;msg-id=subgift;msg-param-sub-plan=1000;msg-param-recipient-user-name=z :tmi.twitch.tv USERNOTICE #prueba', { ...sub, subsRegaladasCuentanParaQuienRegala: false })
    .forEach((a) => N.registrar(e2, a, sub));
  assert.equal(N.lista(e2, sub).participantes[0].papeletas, 3);
});

test('lectura de avisos de donación', () => {
  const d = (t) => N.leerDonacion(t, aj);
  assert.deepEqual(d('ElPepe just tipped €5.00 PogChamp'), { usuario: 'ElPepe', importe: 5, moneda: 'EUR' });
  assert.deepEqual(d('lucia_gg just tipped $10.50!'), { usuario: 'lucia_gg', importe: 10.5, moneda: 'USD' });
  assert.deepEqual(d('Rocio ha donado 7,50 € ❤'), { usuario: 'Rocio', importe: 7.5, moneda: 'EUR' });
  assert.deepEqual(d('gracias @Chusqui por donar 3€'), { usuario: 'Chusqui', importe: 3, moneda: 'EUR' });
  assert.deepEqual(d('Tomasito donó 1.000,00 EUR'), { usuario: 'Tomasito', importe: 1000, moneda: 'EUR' });
  assert.equal(d('hola a todos'), null);
  assert.deepEqual(N.leerDonacion('💸 Nuevo donativo de Pepa: 4 €', { ...aj, plantillasDonacion: 'Nuevo donativo de {usuario}: {cantidad}' }), { usuario: 'Pepa', importe: 4, moneda: 'EUR' });
});

test('top 3 con más de 3 personas y empates', () => {
  const ps = [['a', 9], ['b', 7], ['c', 7], ['d', 5], ['e', 5], ['f', 1]].map(([login, bits]) => ({ login, nombre: login, detalle: { bits } }));
  assert.deepEqual(N.top3(ps, 'bits').map((t) => [t.login, t.puesto]), [['a', 1], ['b', 2], ['c', 2]]);
  const ps2 = [['a', 9], ['b', 7], ['c', 5], ['d', 5], ['e', 1]].map(([login, bits]) => ({ login, nombre: login, detalle: { bits } }));
  assert.deepEqual(N.top3(ps2, 'bits').map((t) => [t.login, t.puesto]), [['a', 1], ['b', 2], ['c', 3], ['d', 3]]);
});

test('subathon en € netos, como el overlay', () => {
  const sub = { ...aj, modo: 'subathon', subathonNeto: true };
  const e = N.estadoVacio();
  const meter = (linea) => acc(linea, sub).forEach((a) => N.registrar(e, a, sub));
  for (let i = 0; i < 5; i++) meter(`@login=t1;id=g1${i};msg-id=subgift;msg-param-sub-plan=1000;msg-param-recipient-user-name=r${i} :tmi.twitch.tv USERNOTICE #prueba`);
  meter('@login=t3;id=g3;msg-id=subgift;msg-param-sub-plan=3000;msg-param-recipient-user-name=z :tmi.twitch.tv USERNOTICE #prueba');
  meter(priv('bits=1000;id=b1', 'bitera', 'Cheer1000'));
  meter(priv('id=d1', 'streamelements', 'Donante just tipped €10.00'));
  const l = N.lista(e, sub);
  const v = Object.fromEntries(l.participantes.map((p) => [p.login, [p.valor, p.papeletas]]));
  assert.deepEqual(v, { t1: [9.9, 9], t3: [9.91, 9], bitera: [7, 7], donante: [9, 9] });
  // en bruto, los mismos datos dan otras cifras
  const b = Object.fromEntries(N.lista(e, { ...sub, subathonNeto: false }).participantes.map((p) => [p.login, p.papeletas]));
  assert.deepEqual(b, { t1: 19, t3: 19, bitera: 10, donante: 10 });
});

test('!donacion solo la pueden usar mods y el dueño del canal', () => {
  const sub = { ...aj, modo: 'subathon' };
  const e = N.estadoVacio();
  const meter = (linea) => acc(linea, sub).forEach((a) => N.registrar(e, a, sub));
  meter(priv('badges=moderator/1;mod=1;id=c1', 'unmod', '!donacion @Abuela 20'));
  meter(priv('badges=broadcaster/1;id=c2', 'prueba', '!donación Primo 5,50€'));
  meter(priv('id=c3', 'listillo', '!donacion listillo 1000'));
  assert.deepEqual(Object.keys(e.participantes).sort(), ['abuela', 'primo']);
  assert.equal(e.participantes.abuela.detalle.donaciones, 20);
  assert.equal(e.participantes.primo.detalle.donaciones, 5.5);
  assert.equal(N.lista(e, sub).participantes.find((p) => p.login === 'abuela').papeletas, 18); // 20 € al 90 %
});

test('sugerencias del chat y lista a mano para sortear opciones', () => {
  const e = N.estadoVacio();
  const meter = (linea) => acc(linea).forEach((a) => N.registrar(e, a, aj));
  meter(priv('id=s0', 'ana', '!sugerencia Gandalf'));                      // cerrado: no entra
  assert.equal(e.opciones.length, 0);
  e.recogiendo = true;
  meter(priv('display-name=Ana;id=s1', 'ana', '!sugerencia   Gandalf   el Gris  '));
  meter(priv('id=s2', 'luis', '!Sugerencia gandalf el gris'));             // repetida (sin importar mayúsculas)
  meter(priv('id=s3', 'luis', '!sugerencia Legolas'));
  meter(priv('id=s4', 'luis', '!sugerencia Aragorn'));                     // cambia la suya
  meter(priv('id=s5', 'pepe', '!sugerencia'));                             // vacía
  assert.deepEqual(e.opciones.map((o) => [o.texto, o.autor]), [['Gandalf el Gris', 'Ana'], ['Aragorn', 'luis']]);
  assert.equal(N.anadirOpciones(e, ['Póster Zelda', '  ', 'aragorn', 'Póster Elden Ring']), 2);
  assert.equal(e.opciones.length, 4);
  e.queSorteo = 'Nombre del alter';
  const vistos = new Set();
  for (let i = 0; i < 200; i++) {
    const copia = JSON.parse(JSON.stringify(e));
    const t = N.sortearOpcion(copia, aj);
    assert.equal(t.tira[t.indiceGanador], t.ganador.nombre);
    assert.equal(t.titulo, 'Nombre del alter');
    vistos.add(t.ganador.nombre);
  }
  assert.equal(vistos.size, 4, 'todas las opciones pueden salir');
  assert.equal(N.sortearOpcion(N.estadoVacio(), aj), null);
});
