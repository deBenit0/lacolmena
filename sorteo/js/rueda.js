/* Ruleta del sorteo: cada persona ocupa un trozo proporcional a sus papeletas.
 * También sonido (generado, sin archivos) y confeti. */
(function () {
  'use strict';

  const COLORES = [
    ['#f5b301', '#1a1405'], ['#3b2a12', '#ffe9a8'], ['#ffd24a', '#1a1405'],
    ['#6b4510', '#fff4d6'], ['#e58e00', '#1a1405'], ['#24190b', '#ffd24a'],
  ];
  const TAU = Math.PI * 2;
  const PUNTERO = -Math.PI / 2; // arriba

  // --- Sonido -------------------------------------------------------------
  let ctxAudio = null;
  function audio() {
    if (!ctxAudio) {
      const C = window.AudioContext || window.webkitAudioContext;
      if (!C) return null;
      ctxAudio = new C();
    }
    if (ctxAudio.state === 'suspended') ctxAudio.resume();
    return ctxAudio;
  }
  function nota(frec, ini, dur, tipo, vol) {
    const a = audio(); if (!a) return;
    const o = a.createOscillator(), g = a.createGain();
    o.type = tipo; o.frequency.value = frec;
    const t = a.currentTime + ini;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(a.destination);
    o.start(t); o.stop(t + dur + 0.02);
  }
  const Sonido = {
    activo: true,
    preparar() { audio(); },
    tic() { if (this.activo) nota(1500 + Math.random() * 300, 0, 0.04, 'square', 0.05); },
    fanfarria() {
      if (!this.activo) return;
      [[523, 0], [659, 0.12], [784, 0.24], [1047, 0.38]].forEach(([f, t]) => nota(f, t, 0.35, 'triangle', 0.18));
      [523, 659, 784, 1047].forEach((f) => nota(f, 0.6, 0.9, 'triangle', 0.1));
    },
  };

  // --- Geometría ------------------------------------------------------------
  function trozos(segmentos) {
    const total = segmentos.reduce((a, s) => a + s.papeletas, 0) || 1;
    let ini = 0;
    return segmentos.map((s, i) => {
      const ancho = (s.papeletas / total) * TAU;
      const t = { ...s, ini, ancho, color: COLORES[i % COLORES.length] };
      ini += ancho;
      return t;
    });
  }

  const mod = (a, n) => ((a % n) + n) % n;

  function anguloFinal(tirada) {
    const ts = trozos(tirada.segmentos);
    const g = ts[tirada.indiceGanador];
    const local = g.ini + tirada.posicion * g.ancho;
    return tirada.vueltas * TAU + mod(PUNTERO - local, TAU);
  }

  function indiceBajoPuntero(ts, angulo) {
    const local = mod(PUNTERO - angulo, TAU);
    for (let i = 0; i < ts.length; i++) if (local >= ts[i].ini && local < ts[i].ini + ts[i].ancho) return i;
    return ts.length - 1;
  }

  // Frenada suave al final, como una ruleta de verdad.
  const frenada = (t) => 1 - Math.pow(1 - t, 4);

  // --- Dibujo -------------------------------------------------------------
  class Ruleta {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.segmentos = [];
      this.angulo = 0;
      this.resaltado = -1;
      this.anim = null;
      this._ajustar();
      new ResizeObserver(() => { this._ajustar(); this.dibujar(); }).observe(canvas);
    }

    _ajustar() {
      const r = this.canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      this.canvas.width = Math.max(1, Math.round(r.width * dpr));
      this.canvas.height = Math.max(1, Math.round(r.height * dpr));
    }

    mostrar(segmentos) {
      if (this.anim) return;
      this.segmentos = segmentos;
      this.resaltado = -1;
      this.dibujar();
    }

    dibujar() {
      const { ctx, canvas } = this;
      const W = canvas.width, H = canvas.height;
      ctx.clearRect(0, 0, W, H);
      const R = Math.min(W, H) / 2 - Math.min(W, H) * 0.06;
      if (R <= 0) return;
      const cx = W / 2, cy = H / 2 + Math.min(W, H) * 0.02;
      const ts = trozos(this.segmentos.length ? this.segmentos : [{ nombre: '¿Quién será?', papeletas: 1 }]);

      // Sombra y aro exterior
      ctx.save();
      ctx.shadowColor = 'rgba(0,0,0,.45)'; ctx.shadowBlur = R * 0.08; ctx.shadowOffsetY = R * 0.03;
      ctx.beginPath(); ctx.arc(cx, cy, R * 1.06, 0, TAU); ctx.fillStyle = '#2a1d0c'; ctx.fill();
      ctx.restore();
      ctx.beginPath(); ctx.arc(cx, cy, R * 1.06, 0, TAU); ctx.lineWidth = R * 0.02; ctx.strokeStyle = '#f5b301'; ctx.stroke();

      // Trozos
      ts.forEach((t, i) => {
        const a0 = t.ini + this.angulo, a1 = a0 + t.ancho;
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.arc(cx, cy, R, a0, a1); ctx.closePath();
        ctx.fillStyle = i === this.resaltado ? '#fff3c4' : t.color[0];
        ctx.fill();
        if (ts.length > 1 && ts.length < 150) { ctx.lineWidth = Math.max(1, R * 0.004); ctx.strokeStyle = 'rgba(0,0,0,.35)'; ctx.stroke(); }

        // Nombre a lo largo del radio, si cabe
        const arco = t.ancho * R * 0.8;
        if (arco < R * 0.035) return;
        const tam = Math.min(R * 0.075, arco * 0.55);
        const medio = a0 + t.ancho / 2;
        const izquierda = Math.cos(medio) < 0; // en el lado izquierdo, girar 180° para que no salga del revés
        ctx.save();
        ctx.translate(cx, cy); ctx.rotate(izquierda ? medio + Math.PI : medio);
        ctx.font = `800 ${tam}px system-ui, "Segoe UI", sans-serif`;
        ctx.fillStyle = i === this.resaltado ? '#1a1405' : t.color[1];
        ctx.textAlign = izquierda ? 'left' : 'right'; ctx.textBaseline = 'middle';
        let nombre = t.nombre;
        const maxAncho = R * 0.66;
        while (nombre.length > 3 && ctx.measureText(nombre).width > maxAncho) nombre = nombre.slice(0, -2) + '…';
        ctx.fillText(nombre, izquierda ? -R * 0.93 : R * 0.93, 0);
        ctx.restore();
      });

      // Luces del aro
      const luces = 24;
      for (let k = 0; k < luces; k++) {
        const a = (k / luces) * TAU + this.angulo * 0.25;
        ctx.beginPath(); ctx.arc(cx + Math.cos(a) * R * 1.03, cy + Math.sin(a) * R * 1.03, R * 0.014, 0, TAU);
        ctx.fillStyle = k % 2 ? '#fff3c4' : '#f5b301'; ctx.fill();
      }

      // Centro: celda de panal con abeja
      ctx.beginPath();
      for (let k = 0; k < 6; k++) {
        const a = (k / 6) * TAU + Math.PI / 6;
        const x = cx + Math.cos(a) * R * 0.17, y = cy + Math.sin(a) * R * 0.17;
        k ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
      }
      ctx.closePath(); ctx.fillStyle = '#1a1405'; ctx.fill();
      ctx.lineWidth = R * 0.025; ctx.strokeStyle = '#f5b301'; ctx.stroke();
      ctx.font = `${R * 0.16}px system-ui, "Apple Color Emoji", "Segoe UI Emoji", sans-serif`;
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText('🐝', cx, cy + R * 0.01);

      // Puntero
      const py = cy - R * 1.02;
      ctx.save();
      ctx.translate(cx, py); ctx.rotate(this._balanceo || 0);
      ctx.beginPath(); ctx.moveTo(-R * 0.07, -R * 0.09); ctx.lineTo(R * 0.07, -R * 0.09); ctx.lineTo(0, R * 0.09); ctx.closePath();
      ctx.shadowColor = 'rgba(0,0,0,.5)'; ctx.shadowBlur = R * 0.03;
      ctx.fillStyle = '#e5534b'; ctx.fill();
      ctx.shadowBlur = 0; ctx.lineWidth = R * 0.012; ctx.strokeStyle = '#fff'; ctx.stroke();
      ctx.restore();
    }

    // Gira hasta el ganador. `inicio` es Date.now() del momento en que se lanzó,
    // para que panel y escena vayan sincronizados aunque una reciba el aviso tarde.
    girar(tirada, inicio) {
      return new Promise((resolver) => {
        if (this.anim) cancelAnimationFrame(this.anim);
        this.segmentos = tirada.segmentos;
        this.resaltado = -1;
        const ts = trozos(tirada.segmentos);
        const fin = anguloFinal(tirada);
        let ultimo = -1, ultimoTic = 0;
        const paso = () => {
          const t = Math.min(1, (Date.now() - inicio) / tirada.duracionMs);
          this.angulo = fin * frenada(t);
          const idx = indiceBajoPuntero(ts, this.angulo);
          if (idx !== ultimo) {
            ultimo = idx;
            const ahora = performance.now();
            if (ts.length > 1 && ahora - ultimoTic > 35) { Sonido.tic(); ultimoTic = ahora; this._balanceo = -0.35; }
          }
          this._balanceo = (this._balanceo || 0) * 0.82;
          this.dibujar();
          if (t < 1) this.anim = requestAnimationFrame(paso);
          else {
            this.anim = null;
            this._balanceo = 0;
            this.resaltado = tirada.indiceGanador;
            this.dibujar();
            Sonido.fanfarria();
            resolver();
          }
        };
        this.anim = requestAnimationFrame(paso);
      });
    }
  }

  // --- Confeti ------------------------------------------------------------
  function confeti(canvas, duracion = 4500) {
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const r = canvas.getBoundingClientRect();
    canvas.width = r.width * dpr; canvas.height = r.height * dpr;
    const W = canvas.width, H = canvas.height;
    const colores = ['#f5b301', '#ffd24a', '#fff3c4', '#e5534b', '#4fc36b', '#5aa9ff', '#ffffff'];
    const piezas = Array.from({ length: 220 }, (_, i) => ({
      x: W / 2 + (Math.random() - 0.5) * W * 0.2, y: H * 0.45,
      vx: (Math.random() - 0.5) * W * 0.03, vy: -Math.random() * H * 0.035 - H * 0.01,
      w: (6 + Math.random() * 8) * dpr, h: (8 + Math.random() * 10) * dpr,
      giro: Math.random() * TAU, vgiro: (Math.random() - 0.5) * 0.3,
      color: colores[i % colores.length],
    }));
    const t0 = performance.now();
    const paso = (ahora) => {
      const t = ahora - t0;
      ctx.clearRect(0, 0, W, H);
      for (const p of piezas) {
        p.vy += H * 0.0009; p.vx *= 0.99; p.x += p.vx; p.y += p.vy; p.giro += p.vgiro;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.giro);
        ctx.globalAlpha = Math.max(0, 1 - t / duracion);
        ctx.fillStyle = p.color; ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h * Math.abs(Math.cos(p.giro)));
        ctx.restore();
      }
      if (t < duracion) requestAnimationFrame(paso); else ctx.clearRect(0, 0, W, H);
    };
    requestAnimationFrame(paso);
  }

  window.Rueda = { Ruleta, Sonido, confeti, _interno: { trozos, anguloFinal, indiceBajoPuntero } };
})();
