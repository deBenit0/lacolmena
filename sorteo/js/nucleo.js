/* Lógica del sorteo (sin dependencias). Funciona en el navegador como script
 * normal (window.Nucleo) y en Node para los tests (module.exports). */
(function (raiz) {
  'use strict';

  const AJUSTES_DEFECTO = {
    canal: '',
    // Entrar escribiendo en el chat
    palabraClave: '!sorteo',
    // Modo del sorteo:
    //  'igual'    todos por igual (1 papeleta cada uno)
    //  'subs'     abierto a todos, los subs tienen más papeletas según su tier
    //  'soloSubs' solo participan los suscriptores (1 papeleta cada uno)
    //  'gasto'    más gasto (bits, subs, regalos, Hype Chat), más papeletas
    //  'subathon' solo quien regala subs o dona (bits, Hype Chat, StreamElements…);
    //             suscribirse uno mismo o escribir la palabra no cuenta
    modo: 'igual',
    // 'personas' (sortea gente del chat) u 'opciones' (lista a mano + sugerencias del chat)
    tipoSorteo: 'personas',
    papeletasNoSub: 1,
    papeletasTier1: 2,
    papeletasTier2: 3,
    papeletasTier3: 4,
    // Extra para el top 3 de quien más subs regala y quien más bits da
    bonusTop: false,
    bonusTop1: 3,
    bonusTop2: 2,
    bonusTop3: 1,
    papeletasPorEscribir: 1,
    // Gasto
    gastanEntranSinEscribir: true,
    eurosPorPapeleta: 1,
    minimaSiHaGastado: 1,
    maximo: 0,
    // Subathon: donado mínimo (en €) para entrar. 0 = cualquier cantidad.
    subathonMinimo: 1,
    // Contar en € netos, igual que la barra del overlay del subathon
    subathonNeto: true,
    netos: { subTier1: 1.98, subTier2: 3.96, subTier3: 9.91, porcentajeDonaciones: 90, porcentajeBits: 70, porcentajeHypeChat: 70 },
    // Comandos del chat
    comandoDonacion: '!donacion',     // solo mods y el dueño del canal: !donacion Nombre 5
    comandoSugerencia: '!sugerencia', // cualquiera, mientras se recogen sugerencias
    // Donaciones de StreamElements/Streamlabs leídas del aviso que pone su bot en el chat.
    // Plantillas separadas por ";" con {usuario} y {cantidad}.
    botsDonaciones: ['streamelements', 'streamlabs'],
    plantillasDonacion: '{usuario} just tipped {cantidad}; {usuario} tipped {cantidad}; {usuario} ha donado {cantidad}; {usuario} donó {cantidad}; {usuario} dono {cantidad}; gracias {usuario} por (?:la donación|donar) de {cantidad}; gracias {usuario} por donar {cantidad}',
    monedaPorDefecto: 'EUR',
    valores: { bit: 0.01, subPrime: 0, subTier1: 3.99, subTier2: 7.99, subTier3: 19.99 },
    subsRegaladasCuentanParaQuienRegala: true,
    conversionMonedas: { EUR: 1, USD: 0.92, GBP: 1.18, MXN: 0.05, ARS: 0.001, CLP: 0.001, COP: 0.00023 },
    ignorar: ['nightbot', 'streamelements', 'streamlabs', 'moobot', 'ananonymousgifter'],
    // Sorteo
    quitarGanador: true,
    duracionSorteo: 8,
    sonidoPanel: false,
  };

  function mezclarAjustes(guardados) {
    const a = JSON.parse(JSON.stringify(AJUSTES_DEFECTO));
    if (!guardados || typeof guardados !== 'object') return a;
    for (const k of Object.keys(a)) {
      if (!(k in guardados)) continue;
      if (a[k] && typeof a[k] === 'object' && !Array.isArray(a[k])) Object.assign(a[k], guardados[k]);
      else a[k] = guardados[k];
    }
    return a;
  }

  // --- IRC --------------------------------------------------------------------
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
    const ti = rest.indexOf(' :');
    let trailing = null;
    if (ti !== -1) { trailing = rest.slice(ti + 2); rest = rest.slice(0, ti); }
    const parts = rest.split(' ').filter(Boolean);
    msg.command = parts.shift() || null;
    msg.params = parts;
    if (trailing !== null) msg.params.push(trailing);
    return msg;
  }

  function autor(msg) {
    const t = msg.tags;
    const login = (t.login || (msg.prefix ? msg.prefix.split('!')[0] : '') || '').toLowerCase();
    return { login, nombre: t['display-name'] || login };
  }

  function texto(msg) {
    return msg.command === 'PRIVMSG' ? (msg.params[msg.params.length - 1] || '') : '';
  }

  // --- Mensaje -> acciones -----------------------------------------------------
  const PLANES = { Prime: 'subPrime', 1000: 'subTier1', 2000: 'subTier2', 3000: 'subTier3' };
  const NOMBRE_PLAN = { Prime: 'Prime', 1000: 'Tier 1', 2000: 'Tier 2', 3000: 'Tier 3' };
  const valorSub = (plan, aj) => Number(aj.valores[PLANES[plan] || 'subTier1']) || 0;

  const MODOS = {
    igual: 'Todos por igual',
    subs: 'Subs más papeletas',
    soloSubs: 'Solo subs',
    gasto: 'Más gasto, más papeletas',
    subathon: 'Subathon',
  };

  // --- Donaciones anunciadas por un bot (StreamElements, Streamlabs) -----------
  // Importe con símbolo o código de moneda delante o detrás: "€5.00", "5,00 €", "$10", "10.50 EUR", "5 euros".
  const MONEDAS = [
    [/^(€|eur|euros?)$/i, 'EUR'], [/^(\$|usd|d[oó]lar(?:es)?)$/i, 'USD'], [/^(£|gbp)$/i, 'GBP'],
    [/^mxn$/i, 'MXN'], [/^ars$/i, 'ARS'], [/^clp$/i, 'CLP'], [/^cop$/i, 'COP'],
  ];
  const RE_SIMBOLO = '(?:€|\\$|£|EUR|USD|GBP|MXN|ARS|CLP|COP|euros?|d[oó]lar(?:es)?)';
  const RE_CANTIDAD = `((?:${RE_SIMBOLO}\\s?)?\\d[\\d.,]*(?:\\s?${RE_SIMBOLO})?)`;
  const RE_USUARIO = '@?([\\p{L}\\p{N}_]{2,25})';

  function numeroDe(texto) {
    const t = texto.replace(/[^\d.,]/g, '');
    const ultimo = Math.max(t.lastIndexOf('.'), t.lastIndexOf(','));
    if (ultimo === -1) return parseFloat(t);
    const dec = t.slice(ultimo + 1);
    if (dec.length === 3 && (t.match(/[.,]/g) || []).length >= 1 && !/[.,]\d{1,2}$/.test(t)) {
      return parseFloat(t.replace(/[.,]/g, '')); // "1.000" o "1,000" = mil
    }
    return parseFloat(t.slice(0, ultimo).replace(/[.,]/g, '') + '.' + dec);
  }

  function monedaDe(texto, porDefecto) {
    const partes = texto.match(/€|\$|£|[A-Za-zóÓ]+/g) || [];
    for (const parte of partes) for (const [re, codigo] of MONEDAS) if (re.test(parte)) return codigo;
    return porDefecto || 'EUR';
  }

  const cacheRegex = new Map();
  function regexDePlantilla(plantilla) {
    if (!cacheRegex.has(plantilla)) {
      let fuente = plantilla.trim().split(/(\{usuario\}|\{cantidad\}|\(\?:[^)]*\))/).map((trozo) => {
        if (trozo === '{usuario}') return RE_USUARIO;
        if (trozo === '{cantidad}') return RE_CANTIDAD;
        if (/^\(\?:/.test(trozo)) return trozo; // grupos opcionales escritos a mano
        return trozo.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+');
      }).join('');
      let re = null;
      try { re = new RegExp(fuente, 'iu'); } catch (e) { re = null; }
      cacheRegex.set(plantilla, { re, usuarioPrimero: plantilla.indexOf('{usuario}') < plantilla.indexOf('{cantidad}') });
    }
    return cacheRegex.get(plantilla);
  }

  // Intenta leer una donación en el texto de un aviso. Devuelve { usuario, importe, moneda } o null.
  function leerDonacion(texto, aj) {
    const plantillas = String(aj.plantillasDonacion || '').split(';').map((x) => x.trim()).filter((x) => x.includes('{usuario}') && x.includes('{cantidad}'));
    for (const pl of plantillas) {
      const { re, usuarioPrimero } = regexDePlantilla(pl);
      const m = re && re.exec(texto);
      if (!m) continue;
      const usuario = usuarioPrimero ? m[1] : m[2];
      const cantidad = usuarioPrimero ? m[2] : m[1];
      const importe = numeroDe(cantidad);
      if (!(importe > 0)) continue;
      return { usuario, importe, moneda: monedaDe(cantidad, aj.monedaPorDefecto) };
    }
    return null;
  }

  // Tier de suscripción a partir de las insignias del mensaje (0 = no es sub).
  // Twitch numera la insignia de sub con los meses (0, 3, 6…) en Tier 1/Prime,
  // y con 2000+ y 3000+ en Tier 2 y Tier 3. La de fundador cuenta como Tier 1.
  function tierDeEtiquetas(tags) {
    const badges = tags.badges || '';
    const m = /(?:^|,)subscriber\/(\d+)/.exec(badges);
    if (m) { const v = parseInt(m[1], 10); return v >= 3000 ? 3 : v >= 2000 ? 2 : 1; }
    if (/(?:^|,)founder\//.test(badges)) return 1;
    return tags.subscriber === '1' ? 1 : 0;
  }
  const tierDePlan = (plan) => (plan === '3000' ? 3 : plan === '2000' ? 2 : 1);

  // Devuelve una lista (posiblemente vacía) de acciones:
  //  { tipo: 'bits'|'sub'|'regalo'|'hypechat', id, login, nombre, cantidad, euros, texto }
  //  { tipo: 'entrada', id, login, nombre, texto }
  function accionesDesdeMensaje(msg, aj) {
    const t = msg.tags;
    const id = t.id || null;
    const res = [];

    if (msg.command === 'PRIVMSG') {
      const { login, nombre } = autor(msg);
      if ((aj.botsDonaciones || []).some((b) => b.toLowerCase() === login)) {
        const d = leerDonacion(texto(msg), aj);
        if (d) {
          const tasa = aj.conversionMonedas && aj.conversionMonedas[d.moneda];
          res.push({ tipo: 'donacion', id: id && id + ':don', login: d.usuario.toLowerCase(), nombre: d.usuario, cantidad: d.importe,
            euros: d.importe * (tasa == null ? 1 : tasa), texto: `dona ${d.importe} ${d.moneda} (${nombre})` });
        }
        return res; // los mensajes del bot no cuentan para nada más
      }
      const txt = texto(msg).trim();
      const primera = (txt.split(/\s+/)[0] || '').toLowerCase();
      const sinTilde = (x) => String(x || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
      // !donacion Nombre 5 → donación por Bizum o en efectivo apuntada por un mod (como en el overlay)
      if (aj.comandoDonacion && sinTilde(primera) === sinTilde(aj.comandoDonacion)) {
        const esMod = t.mod === '1' || /(^|,)(broadcaster|moderator)\//.test(t.badges || '');
        const m = /^\S+\s+@?([\p{L}\p{N}_]{2,25})\s+(\d[\d.,]*)/u.exec(txt);
        if (esMod && m) {
          const importe = numeroDe(m[2]);
          if (importe > 0) res.push({ tipo: 'donacion', id: id && id + ':cmd', login: m[1].toLowerCase(), nombre: m[1], cantidad: importe,
            euros: importe, texto: `dona ${importe} € (Bizum/efectivo, lo apunta ${nombre})` });
        }
        return res;
      }
      // !sugerencia texto → opción para un sorteo de opciones
      if (aj.comandoSugerencia && sinTilde(primera) === sinTilde(aj.comandoSugerencia)) {
        const propuesta = txt.slice(primera.length).trim().replace(/\s+/g, ' ').slice(0, 60);
        if (propuesta) res.push({ tipo: 'sugerencia', login, nombre, texto: propuesta });
        return res;
      }
      const bits = parseInt(t.bits, 10);
      if (bits > 0) {
        res.push({ tipo: 'bits', id: id && id + ':bits', login, nombre, cantidad: bits,
          euros: bits * Number(aj.valores.bit || 0), texto: bits + ' bits' });
      }
      const pagado = parseInt(t['pinned-chat-paid-amount'], 10);
      if (pagado > 0) {
        const exp = parseInt(t['pinned-chat-paid-exponent'] || '2', 10);
        const moneda = (t['pinned-chat-paid-currency'] || 'EUR').toUpperCase();
        const importe = pagado / Math.pow(10, exp);
        const tasa = aj.conversionMonedas && aj.conversionMonedas[moneda];
        res.push({ tipo: 'hypechat', id: id && id + ':hype', login, nombre, cantidad: importe,
          euros: importe * (tasa == null ? 1 : tasa), texto: `Hype Chat ${importe} ${moneda}` });
      }
      const palabra = (aj.palabraClave || '').trim().toLowerCase();
      if (palabra) {
        const primera = texto(msg).trim().split(/\s+/)[0].toLowerCase();
        if (primera === palabra) res.push({ tipo: 'entrada', id, login, nombre, texto: `escribe ${palabra}` });
      }
      const tier = tierDeEtiquetas(t);
      if (tier > 0) res.unshift({ tipo: 'tier', login, nombre, tier });
      return res;
    }

    if (msg.command === 'USERNOTICE') {
      const aviso = t['msg-id'];
      const { login, nombre } = autor(msg);
      const plan = t['msg-param-sub-plan'];
      if (aviso === 'sub' || aviso === 'resub') {
        res.push({ tipo: 'tier', login, nombre, tier: tierDePlan(plan) });
        res.push({ tipo: 'sub', id, login, nombre, cantidad: 1, euros: valorSub(plan, aj),
          texto: `${aviso === 'resub' ? 'Resub' : 'Sub'} ${NOMBRE_PLAN[plan] || ''}`.trim() });
      } else if (aviso === 'subgift') {
        const receptor = (t['msg-param-recipient-user-name'] || '').toLowerCase();
        if (receptor) res.push({ tipo: 'tier', login: receptor, nombre: t['msg-param-recipient-display-name'] || receptor, tier: tierDePlan(plan) });
        // Un regalo masivo (submysterygift) llega además como N "subgift": solo
        // contamos estos para no duplicar.
        if (aj.subsRegaladasCuentanParaQuienRegala || aj.modo === 'subathon') {
          const para = t['msg-param-recipient-display-name'] || t['msg-param-recipient-user-name'] || '?';
          res.push({ tipo: 'regalo', id, login, nombre, cantidad: 1, tier: tierDePlan(plan), euros: valorSub(plan, aj),
            texto: `regala sub ${NOMBRE_PLAN[plan] || ''} a ${para}`.replace(/\s+/g, ' ') });
        }
      } else if (aviso === 'giftpaidupgrade' || aviso === 'primepaidupgrade') {
        res.push({ tipo: 'tier', login, nombre, tier: tierDePlan(plan || '1000') });
        res.push({ tipo: 'sub', id, login, nombre, cantidad: 1, euros: valorSub(plan || '1000', aj),
          texto: 'continúa su sub pagando' });
      }
    }
    return res;
  }

  // --- Papeletas --------------------------------------------------------------
  // ¿Está apuntado? Escribió la palabra, o gastó y quien gasta entra sin escribir.
  // Lo donado sin contar la sub propia: regalos, bits, Hype Chat, donaciones y ajustes a mano.
  function valorDonado(p, aj) {
    const d = p.detalle || {};
    if (!aj.subathonNeto) return Math.max(0, Number(p.donado) || 0);
    const N = aj.netos || {};
    const pct = (v) => (Number(v) || 0) / 100;
    const regT = d.regalosT || { 1: d.regalos || 0 }; // registros antiguos sin tier: Tier 1
    const v = (regT[1] || 0) * (Number(N.subTier1) || 0) + (regT[2] || 0) * (Number(N.subTier2) || 0) + (regT[3] || 0) * (Number(N.subTier3) || 0)
      + (d.bits || 0) * (Number(aj.valores.bit) || 0) * pct(N.porcentajeBits)
      + (d.hypechat || 0) * pct(N.porcentajeHypeChat)
      + (d.donaciones || 0) * pct(N.porcentajeDonaciones)
      + (d.manual || 0); // lo añadido a mano ya va en € tal cual
    return Math.max(0, Math.round(v * 100) / 100);
  }
  const donadoDe = (p, aj) => valorDonado(p, aj);

  function participa(p, aj) {
    if (!p || p.excluido) return false;
    if (aj.modo === 'subathon') {
      const minimo = Math.max(0, Number(aj.subathonMinimo) || 0);
      const v = donadoDe(p, aj);
      return v > 0 && v + 1e-9 >= minimo;
    }
    return p.escribio || (p.euros > 0 && !!aj.gastanEntranSinEscribir);
  }

  // `extra`: papeletas de bonus (top de regaladores). Solo se suman a quien ya
  // participa en el modo elegido (en "Solo subs", alguien que no es sub sigue fuera).
  function papeletasDe(p, aj, tier, extra) {
    if (!participa(p, aj)) return 0;
    tier = tier == null ? (p.tier || 0) : tier;
    const num = (v) => Math.max(0, Number(v) || 0);
    let n;
    switch (aj.modo) {
      case 'subs': n = num([aj.papeletasNoSub, aj.papeletasTier1, aj.papeletasTier2, aj.papeletasTier3][tier]); break;
      case 'soloSubs': n = tier > 0 ? 1 : 0; break;
      case 'subathon': {
        const epp = Number(aj.eurosPorPapeleta) || 1;
        n = Math.max(1, Math.floor(donadoDe(p, aj) / epp + 1e-9));
        break;
      }
      case 'gasto': {
        const base = p.escribio ? num(aj.papeletasPorEscribir) : 0;
        let extra = 0;
        if (p.euros > 0) {
          const epp = Number(aj.eurosPorPapeleta) || 1;
          extra = Math.max(Math.floor(p.euros / epp + 1e-9), num(aj.minimaSiHaGastado));
        }
        n = base + extra;
        break;
      }
      default: n = 1; // 'igual'
    }
    if (n > 0 && extra > 0) n += extra;
    const max = num(aj.maximo);
    if (max > 0) n = Math.min(n, max);
    return n;
  }

  function aleatorioSeguro(total) {
    const c = (typeof crypto !== 'undefined' && crypto.getRandomValues) ? crypto : (typeof require === 'function' ? require('node:crypto').webcrypto : null);
    // Rechazo para evitar sesgo de módulo.
    const limite = Math.floor(0x100000000 / total) * total;
    const buf = new Uint32Array(1);
    do { c.getRandomValues(buf); } while (buf[0] >= limite);
    return buf[0] % total;
  }

  function elegirPonderado(pesos, aleatorio) {
    const total = pesos.reduce((a, b) => a + b, 0);
    if (total <= 0) return -1;
    let r = (aleatorio || aleatorioSeguro)(total);
    for (let i = 0; i < pesos.length; i++) {
      if (r < pesos[i]) return i;
      r -= pesos[i];
    }
    return pesos.length - 1;
  }

  // --- Estado del sorteo ------------------------------------------------------
  function estadoVacio() {
    return { abierto: true, participantes: {}, eventos: [], ganadores: [], idsVistos: [], mensajesGanador: [], tiers: {},
      opciones: [], recogiendo: false, queSorteo: '' };
  }

  const redondear = (n) => Math.round(n * 100) / 100;

  // Aplica una acción al estado. Devuelve el evento registrado (o null si se descarta en silencio).
  function registrar(estado, ac, aj, ahora) {
    const login = (ac.login || '').toLowerCase();
    if (!login) return null;
    if (ac.tipo === 'tier') {
      // Solo se anota el tier (no es un evento visible). Se queda con el mayor visto.
      // En el subathon no hace falta, y así no crece con cada sub que escribe en un chat enorme.
      if (ac.tier > 0 && aj.modo !== 'subathon') {
        if (!estado.tiers) estado.tiers = {};
        estado.tiers[login] = Math.max(estado.tiers[login] || 0, ac.tier);
      }
      return null;
    }
    if (ac.tipo === 'sugerencia') return registrarSugerencia(estado, ac, aj, login, ahora);
    if (ac.id) {
      if (estado.idsVistos.includes(ac.id)) return null;
      estado.idsVistos.push(ac.id);
      if (estado.idsVistos.length > 3000) estado.idsVistos.splice(0, estado.idsVistos.length - 3000);
    }
    const ev = { hora: ahora || new Date().toISOString(), login, nombre: ac.nombre || login, tipo: ac.tipo,
      texto: ac.texto, euros: ac.euros != null ? redondear(ac.euros) : null, contado: false };
    const existente = estado.participantes[login];

    if ((aj.ignorar || []).some((s) => s.toLowerCase() === login)) ev.motivo = 'usuario ignorado';
    else if (aj.canal && login === String(aj.canal).toLowerCase()) ev.motivo = 'es el dueño del canal';
    else if (!estado.abierto) ev.motivo = 'sorteo cerrado';
    else if (ac.tipo === 'entrada' && existente && existente.escribio) return null; // repetir la palabra no hace nada
    else if (ac.tipo === 'entrada' && aj.modo === 'subathon') return null; // en el subathon escribir no mete a nadie
    else if (ac.tipo !== 'entrada' && ac.tipo !== 'manual' && !(ac.euros > 0)) ev.motivo = 'sin valor en euros';
    else {
      const p = existente || { login, nombre: ev.nombre, euros: 0, donado: 0, escribio: false, excluido: false,
        detalle: { bits: 0, subs: 0, regalos: 0, regalosT: { 1: 0, 2: 0, 3: 0 }, hypechat: 0, manual: 0, donaciones: 0 } };
      p.nombre = ev.nombre;
      if (p.donado == null) p.donado = 0;
      if (p.detalle.donaciones == null) p.detalle.donaciones = 0;
      if (ac.tipo === 'entrada') p.escribio = true;
      else {
        p.euros = redondear(p.euros + ac.euros);
        if (ac.tipo !== 'sub') p.donado = Math.max(0, redondear(p.donado + ac.euros));
        if (ac.tipo === 'bits') p.detalle.bits += ac.cantidad;
        else if (ac.tipo === 'sub') p.detalle.subs += 1;
        else if (ac.tipo === 'regalo') {
          p.detalle.regalos += 1;
          if (!p.detalle.regalosT) p.detalle.regalosT = { 1: p.detalle.regalos - 1, 2: 0, 3: 0 };
          const tr = ac.tier === 2 || ac.tier === 3 ? ac.tier : 1;
          p.detalle.regalosT[tr] = (p.detalle.regalosT[tr] || 0) + 1;
        }
        else if (ac.tipo === 'hypechat') p.detalle.hypechat = redondear(p.detalle.hypechat + ac.euros);
        else if (ac.tipo === 'manual') p.detalle.manual = redondear(p.detalle.manual + ac.euros);
        else if (ac.tipo === 'donacion') p.detalle.donaciones = redondear(p.detalle.donaciones + ac.euros);
        if (p.euros < 0) p.euros = 0;
      }
      if (p.euros <= 0 && !p.escribio) delete estado.participantes[login];
      else estado.participantes[login] = p;
      ev.contado = true;
    }
    estado.eventos.unshift(ev);
    if (estado.eventos.length > 300) estado.eventos.length = 300;
    return ev;
  }

  // --- Sorteo de opciones (lista a mano + sugerencias del chat) ----------------
  const MAX_OPCIONES = 300;
  const clave = (x) => String(x).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ').trim();

  function registrarSugerencia(estado, ac, aj, login, ahora) {
    if (!estado.recogiendo) return null;
    if ((aj.ignorar || []).some((s) => s.toLowerCase() === login)) return null;
    if (!estado.opciones) estado.opciones = [];
    const texto = String(ac.texto || '').trim();
    if (!texto) return null;
    // Una sugerencia por persona: si vuelve a escribir, cambia la suya.
    const previa = estado.opciones.findIndex((o) => o.origen === 'chat' && o.login === login);
    const repetida = estado.opciones.find((o) => clave(o.texto) === clave(texto));
    if (repetida) return null; // ya está en la lista
    if (previa === -1 && estado.opciones.length >= MAX_OPCIONES) return null;
    const opcion = { id: 'o' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6), texto, autor: ac.nombre || login, login, origen: 'chat' };
    if (previa !== -1) estado.opciones[previa] = opcion; else estado.opciones.push(opcion);
    const ev = { hora: ahora || new Date().toISOString(), login, nombre: ac.nombre || login, tipo: 'sugerencia',
      texto: `sugiere «${texto}»${previa !== -1 ? ' (cambia la suya)' : ''}`, euros: null, contado: true };
    estado.eventos.unshift(ev);
    if (estado.eventos.length > 300) estado.eventos.length = 300;
    return ev;
  }

  // Añade opciones escritas a mano (una por línea). Devuelve cuántas ha añadido.
  function anadirOpciones(estado, textos) {
    if (!estado.opciones) estado.opciones = [];
    let n = 0;
    for (const bruto of textos) {
      const texto = String(bruto || '').trim().replace(/\s+/g, ' ').slice(0, 80);
      if (!texto || estado.opciones.some((o) => clave(o.texto) === clave(texto)) || estado.opciones.length >= MAX_OPCIONES) continue;
      estado.opciones.push({ id: 'o' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6) + n, texto, autor: null, login: null, origen: 'manual' });
      n++;
    }
    return n;
  }

  function sortearOpcion(estado, aj, opciones) {
    opciones = opciones || {};
    const lista = (estado.opciones || []).filter((o) => !o.descartada);
    if (!lista.length) return null;
    const segmentos = lista.map((o) => ({ nombre: o.texto, papeletas: 1 }));
    const i = elegirPonderado(segmentos.map(() => 1), opciones.aleatorio);
    const o = lista[i];
    const ganador = { hora: new Date().toISOString(), tipo: 'opcion', nombre: o.texto, autor: o.autor, login: null,
      titulo: estado.queSorteo || '', participantes: lista.length, papeletas: 1, totalPapeletas: lista.length, probabilidad: 1 / lista.length };
    estado.ganadores.unshift(ganador);
    estado.mensajesGanador = [];
    const duracionMs = Math.max(3, Number(aj.duracionSorteo) || 8) * 1000;
    const largo = Math.round(30 + duracionMs / 1000 * 4);
    const t = construirTira(segmentos, i, largo);
    return { tira: t.tira, indiceGanador: t.indiceGanador, ganador, duracionMs, titulo: ganador.titulo };
  }

  // Top 3 por un campo del detalle (regalos o bits). Empates comparten puesto.
  // Devuelve [{ login, nombre, cantidad, puesto }] con puesto 1..3.
  function top3(participantes, campo) {
    const orden = participantes.filter((p) => p.detalle && p.detalle[campo] > 0)
      .sort((a, b) => b.detalle[campo] - a.detalle[campo] || a.nombre.localeCompare(b.nombre));
    const res = [];
    let puesto = 0;
    for (let i = 0; i < orden.length; i++) {
      const p = orden[i];
      if (i === 0 || p.detalle[campo] !== orden[i - 1].detalle[campo]) puesto = i + 1;
      if (puesto > 3) break;
      res.push({ login: p.login, nombre: p.nombre, cantidad: p.detalle[campo], puesto });
    }
    return res;
  }

  function lista(estado, aj) {
    const tiers = estado.tiers || {};
    const todos = Object.values(estado.participantes);
    const tops = { regalos: top3(todos, 'regalos'), bits: top3(todos, 'bits') };
    const premio = (puesto) => Math.max(0, Number(aj['bonusTop' + puesto]) || 0);
    const ps = todos.map((p) => {
      const tier = tiers[p.login] || 0;
      const top = {};
      let extra = 0;
      if (aj.bonusTop) {
        for (const campo of ['regalos', 'bits']) {
          const t = tops[campo].find((x) => x.login === p.login);
          if (t) { top[campo] = t.puesto; extra += premio(t.puesto); }
        }
      }
      return Object.assign({}, p, { tier, top, extra, valor: valorDonado(p, aj), papeletas: papeletasDe(p, aj, tier, extra) });
    });
    const total = ps.reduce((a, p) => a + p.papeletas, 0);
    ps.forEach((p) => { p.probabilidad = total ? p.papeletas / total : 0; });
    ps.sort((a, b) => b.papeletas - a.papeletas || b.euros - a.euros || a.nombre.localeCompare(b.nombre));
    return { participantes: ps, totalPapeletas: total, tops };
  }

  // Tira de nombres que pasa por pantalla: aparecen más veces quienes tienen
  // más papeletas, sin repetir el mismo nombre dos veces seguidas, y el
  // ganador queda en la posición `indiceGanador` (con unos nombres más detrás
  // para que la pantalla no se quede vacía por arriba al pararse).
  function construirTira(segmentos, indiceGanador, largo, aleatorio) {
    const rnd = aleatorio || ((n) => Math.floor(Math.random() * n));
    const pesos = segmentos.map((s) => s.papeletas);
    // Saca un nombre ponderado que no esté en `evitar`.
    const sacar = (evitar) => {
      for (let intento = 0; intento < 10; intento++) {
        const n = segmentos[elegirPonderado(pesos, rnd)].nombre;
        if (!evitar.includes(n)) return n;
      }
      const libre = segmentos.find((s) => !evitar.includes(s.nombre));
      return libre ? libre.nombre : segmentos[0].nombre;
    };
    const ganador = segmentos[indiceGanador].nombre;
    const uno = segmentos.length === 1;
    // Se construye hacia atrás desde el ganador y luego hacia delante, sin
    // repetir nunca el mismo nombre dos veces seguidas.
    const tira = new Array(largo + EXTRA_TIRA);
    tira[largo] = ganador;
    for (let k = largo - 1; k >= 0; k--) tira[k] = uno ? ganador : sacar([tira[k + 1]]);
    for (let k = largo + 1; k < tira.length; k++) tira[k] = uno ? ganador : sacar([tira[k - 1]]);
    return { tira, indiceGanador: largo };
  }
  const EXTRA_TIRA = 6;

  // Saca ganador y prepara la animación (la misma en panel y escena).
  function sortear(estado, aj, opciones) {
    opciones = opciones || {};
    const { participantes, totalPapeletas } = lista(estado, aj);
    const segmentos = participantes.filter((p) => p.papeletas > 0).map((p) => ({ login: p.login, nombre: p.nombre, papeletas: p.papeletas }));
    const i = elegirPonderado(segmentos.map((s) => s.papeletas), opciones.aleatorio);
    if (i < 0) return null;
    const g = segmentos[i];
    const ganador = { hora: new Date().toISOString(), tipo: 'persona', login: g.login, nombre: g.nombre, papeletas: g.papeletas,
      totalPapeletas, probabilidad: g.papeletas / totalPapeletas, participantes: segmentos.length, titulo: estado.queSorteo || '' };
    estado.ganadores.unshift(ganador);
    estado.mensajesGanador = [];
    if (aj.quitarGanador) estado.participantes[g.login].excluido = true;
    const duracionMs = Math.max(3, Number(aj.duracionSorteo) || 8) * 1000;
    const largo = Math.round(30 + duracionMs / 1000 * 4); // nombres que pasan antes del ganador
    const { tira, indiceGanador } = construirTira(segmentos, i, largo);
    return { tira, indiceGanador, ganador, duracionMs, titulo: ganador.titulo };
  }

  const Nucleo = { AJUSTES_DEFECTO, MODOS, tierDeEtiquetas, participa, top3, leerDonacion, numeroDe, valorDonado, anadirOpciones, sortearOpcion, mezclarAjustes, parseLine, autor, texto, accionesDesdeMensaje,
    papeletasDe, elegirPonderado, estadoVacio, registrar, lista, sortear, construirTira };

  if (typeof module !== 'undefined' && module.exports) module.exports = Nucleo;
  else raiz.Nucleo = Nucleo;
})(typeof window !== 'undefined' ? window : globalThis);
