'use strict';
// Lógica del sorteo: acumula lo gastado por cada persona, calcula papeletas
// y saca un ganador ponderado (más papeletas = más probabilidad).

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const MAX_EVENTOS = 300;

function calcularPapeletas(euros, reglas) {
  if (!(euros > 0)) return 0;
  const porPapeleta = Number(reglas.eurosPorPapeleta) || 1;
  let n = Math.floor(euros / porPapeleta + 1e-9);
  n = Math.max(n, Number(reglas.minimaSiHaGastado) || 0);
  const max = Number(reglas.maximo) || 0;
  if (max > 0) n = Math.min(n, max);
  return n;
}

// Elige un índice con probabilidad proporcional a su peso.
// `aleatorio(total)` debe devolver un entero en [0, total).
function elegirPonderado(pesos, aleatorio = (total) => crypto.randomInt(total)) {
  const total = pesos.reduce((a, b) => a + b, 0);
  if (total <= 0) return -1;
  let r = aleatorio(total);
  for (let i = 0; i < pesos.length; i++) {
    if (r < pesos[i]) return i;
    r -= pesos[i];
  }
  return pesos.length - 1;
}

function estadoVacio(abierto) {
  return { abierto, participantes: {}, eventos: [], ganadores: [], idsVistos: [] };
}

class Sorteo {
  constructor(config, { archivo } = {}) {
    this.config = config;
    this.archivo = archivo || null;
    this.estado = estadoVacio(!!config.abrirAlArrancar);
    this._cargar();
    this._vistos = new Set(this.estado.idsVistos);
    this._timerGuardado = null;
  }

  // --- Persistencia -------------------------------------------------------
  _cargar() {
    if (!this.archivo || !fs.existsSync(this.archivo)) return;
    try {
      const datos = JSON.parse(fs.readFileSync(this.archivo, 'utf8'));
      this.estado = { ...estadoVacio(!!this.config.abrirAlArrancar), ...datos };
    } catch (e) {
      console.warn(`No se pudo leer ${this.archivo}: ${e.message}. Empiezo de cero.`);
    }
  }

  _guardar() {
    if (!this.archivo) return;
    clearTimeout(this._timerGuardado);
    this._timerGuardado = setTimeout(() => this.guardarYa(), 300);
  }

  guardarYa() {
    if (!this.archivo) return;
    clearTimeout(this._timerGuardado);
    this.estado.idsVistos = [...this._vistos].slice(-2000);
    fs.mkdirSync(path.dirname(this.archivo), { recursive: true });
    const tmp = `${this.archivo}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.estado, null, 2));
    fs.renameSync(tmp, this.archivo);
  }

  // --- Registro de gasto --------------------------------------------------
  _ignorado(login) {
    return (this.config.ignorar || []).map((s) => s.toLowerCase()).includes(login);
  }

  // Devuelve { contado: bool, motivo?, evento }
  registrar(ap) {
    const login = (ap.login || '').toLowerCase();
    if (!login) return { contado: false, motivo: 'sin usuario' };
    if (ap.id) {
      if (this._vistos.has(ap.id)) return { contado: false, motivo: 'duplicado' };
      this._vistos.add(ap.id);
    }

    const evento = {
      hora: new Date().toISOString(),
      login,
      nombre: ap.nombre || login,
      tipo: ap.tipo,
      texto: ap.texto,
      euros: Math.round(ap.euros * 100) / 100,
      contado: false,
    };

    if (this._ignorado(login)) evento.motivo = 'usuario ignorado';
    else if (!this.estado.abierto) evento.motivo = 'sorteo cerrado';
    else if (!(ap.euros > 0) && ap.tipo !== 'manual') evento.motivo = 'sin valor en euros';
    else {
      const p = this.estado.participantes[login] || {
        login, nombre: evento.nombre, euros: 0, excluido: false,
        detalle: { bits: 0, subs: 0, regalos: 0, hypechat: 0, manual: 0 },
      };
      p.nombre = evento.nombre;
      p.euros = Math.round((p.euros + ap.euros) * 100) / 100;
      if (ap.tipo === 'bits') p.detalle.bits += ap.cantidad;
      else if (ap.tipo === 'sub') p.detalle.subs += 1;
      else if (ap.tipo === 'regalo') p.detalle.regalos += 1;
      else if (ap.tipo === 'hypechat') p.detalle.hypechat = Math.round((p.detalle.hypechat + ap.euros) * 100) / 100;
      else if (ap.tipo === 'manual') p.detalle.manual = Math.round((p.detalle.manual + ap.euros) * 100) / 100;
      if (p.euros <= 0) delete this.estado.participantes[login];
      else this.estado.participantes[login] = p;
      evento.contado = true;
    }

    this.estado.eventos.unshift(evento);
    this.estado.eventos.length = Math.min(this.estado.eventos.length, MAX_EVENTOS);
    this._guardar();
    return { contado: evento.contado, motivo: evento.motivo, evento };
  }

  // --- Consultas ----------------------------------------------------------
  lista() {
    const ps = Object.values(this.estado.participantes).map((p) => ({
      ...p,
      papeletas: p.excluido ? 0 : calcularPapeletas(p.euros, this.config.papeletas),
    }));
    const total = ps.reduce((a, p) => a + p.papeletas, 0);
    for (const p of ps) p.probabilidad = total ? p.papeletas / total : 0;
    ps.sort((a, b) => b.papeletas - a.papeletas || b.euros - a.euros || a.nombre.localeCompare(b.nombre));
    return { participantes: ps, totalPapeletas: total };
  }

  resumen() {
    const { participantes, totalPapeletas } = this.lista();
    return {
      canal: this.config.canal,
      abierto: this.estado.abierto,
      participantes,
      totalPapeletas,
      totalEuros: Math.round(participantes.reduce((a, p) => a + p.euros, 0) * 100) / 100,
      eventos: this.estado.eventos.slice(0, 100),
      ganadores: this.estado.ganadores,
      reglas: this.config.papeletas,
    };
  }

  // --- Acciones -----------------------------------------------------------
  abrir() { this.estado.abierto = true; this._guardar(); }
  cerrar() { this.estado.abierto = false; this._guardar(); }

  excluir(login, excluido = true) {
    const p = this.estado.participantes[(login || '').toLowerCase()];
    if (!p) return false;
    p.excluido = !!excluido;
    this._guardar();
    return true;
  }

  sortear({ quitarGanador = true } = {}) {
    const { participantes, totalPapeletas } = this.lista();
    const candidatos = participantes.filter((p) => p.papeletas > 0);
    const i = elegirPonderado(candidatos.map((p) => p.papeletas));
    if (i < 0) return null;
    const g = candidatos[i];
    const ganador = {
      hora: new Date().toISOString(),
      login: g.login,
      nombre: g.nombre,
      papeletas: g.papeletas,
      totalPapeletas,
      probabilidad: g.probabilidad,
      euros: g.euros,
    };
    this.estado.ganadores.unshift(ganador);
    if (quitarGanador) this.estado.participantes[g.login].excluido = true;
    this._guardar();
    return { ganador, candidatos: candidatos.map((p) => ({ nombre: p.nombre, papeletas: p.papeletas })) };
  }

  reiniciar() {
    this.estado = estadoVacio(this.estado.abierto);
    this._vistos = new Set();
    this._guardar();
  }
}

module.exports = { Sorteo, calcularPapeletas, elegirPonderado };
