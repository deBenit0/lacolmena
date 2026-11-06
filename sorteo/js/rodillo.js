/* Animación del sorteo: fondo negro con los nombres cayendo de arriba abajo,
 * cada vez más despacio, hasta pararse en el ganador en la línea central.
 * Incluye sonido (generado, sin archivos) y confeti. */
(function () {
  'use strict';

  const ACENTO = '#facc15';

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
    tic() { if (this.activo) nota(1200 + Math.random() * 200, 0, 0.035, 'square', 0.04); },
    fanfarria() {
      if (!this.activo) return;
      [[523, 0], [659, 0.12], [784, 0.24], [1047, 0.38]].forEach(([f, t]) => nota(f, t, 0.35, 'triangle', 0.18));
      [523, 659, 784, 1047].forEach((f) => nota(f, 0.6, 0.9, 'triangle', 0.1));
    },
  };

  // Frenada suave al final.
  const frenada = (t) => 1 - Math.pow(1 - t, 4);

  // Posición final del rodillo (en filas) para una tirada.
  const desplazamientoFinal = (tirada) => tirada.indiceGanador;

  // Índice de la tira que queda en la línea central para un desplazamiento dado.
  const indiceEnCentro = (desplazamiento) => Math.round(desplazamiento);

  class Rodillo {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.nombres = [];       // participantes en reposo
      this.tira = null;        // nombres de la tirada en curso
      this.desplazamiento = 0; // en filas
      this.ganador = -1;
      this.anim = null;
      this.reposo = null;
      this.mantenerHasta = 0;
      this._ajustar();
      new ResizeObserver(() => { this._ajustar(); this.dibujar(); }).observe(canvas);
    }

    _ajustar() {
      const r = this.canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      this.canvas.width = Math.max(1, Math.round(r.width * dpr));
      this.canvas.height = Math.max(1, Math.round(r.height * dpr));
    }

    // En reposo, los participantes bajan despacito.
    mostrar(nombres) {
      this.nombres = nombres;
      if (this.anim || Date.now() < this.mantenerHasta) return; // dejar al ganador a la vista un rato
      this.tira = null; this.ganador = -1;
      if (!this.reposo) {
        const t0 = performance.now();
        const paso = (ahora) => {
          if (this.anim) { this.reposo = null; return; }
          this.desplazamiento = (ahora - t0) / 1000 * 0.6;
          this.dibujar();
          this.reposo = requestAnimationFrame(paso);
        };
        this.reposo = requestAnimationFrame(paso);
      }
    }

    _alto() { return Math.max(24, this.canvas.height / 7); }

    dibujar() {
      const { ctx, canvas } = this;
      const W = canvas.width, H = canvas.height;
      ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
      const h = this._alto();
      const cy = H / 2;

      // Franja central
      ctx.fillStyle = 'rgba(250, 204, 21, .12)';
      ctx.fillRect(0, cy - h / 2, W, h);
      ctx.fillStyle = ACENTO;
      ctx.fillRect(0, cy - h / 2, W, Math.max(2, h * 0.03));
      ctx.fillRect(0, cy + h / 2 - Math.max(2, h * 0.03), W, Math.max(2, h * 0.03));
      // Flechas a los lados
      const fl = h * 0.28;
      ctx.beginPath(); ctx.moveTo(fl * 0.4, cy - fl / 2); ctx.lineTo(fl * 1.2, cy); ctx.lineTo(fl * 0.4, cy + fl / 2); ctx.fill();
      ctx.beginPath(); ctx.moveTo(W - fl * 0.4, cy - fl / 2); ctx.lineTo(W - fl * 1.2, cy); ctx.lineTo(W - fl * 0.4, cy + fl / 2); ctx.fill();

      const lista = this.tira || this.nombres;
      if (!lista.length) {
        ctx.fillStyle = '#666'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.font = `600 ${h * 0.4}px system-ui, "Segoe UI", sans-serif`;
        ctx.fillText('Esperando participantes…', W / 2, cy);
        return;
      }

      // La fila k está en y = cy - (k - desplazamiento) * h: las siguientes
      // entran por arriba y bajan.
      const d = this.desplazamiento;
      const visibles = Math.ceil(H / h / 2) + 1;
      const centro = Math.floor(d);
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      for (let k = centro - visibles; k <= centro + visibles + 1; k++) {
        let nombre;
        if (this.tira) { if (k < 0 || k >= lista.length) continue; nombre = lista[k]; }
        else nombre = lista[((k % lista.length) + lista.length) % lista.length];
        const y = cy - (k - d) * h;
        const cerca = Math.max(0, 1 - Math.abs(y - cy) / (H / 2)); // 1 en el centro, 0 en los bordes
        const esGanador = !!this.tira && k === this.ganador;
        const tam = h * (0.42 + 0.22 * cerca) * (esGanador ? 1.15 : 1);
        ctx.font = `${esGanador ? 900 : 700} ${tam}px system-ui, "Segoe UI", sans-serif`;
        let texto = nombre;
        while (texto.length > 3 && ctx.measureText(texto).width > W * 0.84) texto = texto.slice(0, -2) + '…';
        if (esGanador) { ctx.shadowColor = ACENTO; ctx.shadowBlur = h * 0.5; ctx.fillStyle = '#fff'; }
        else { ctx.shadowBlur = 0; ctx.fillStyle = `rgba(255,255,255,${0.12 + 0.88 * Math.pow(cerca, 1.6)})`; }
        ctx.fillText(texto, W / 2, y);
      }
      ctx.shadowBlur = 0;

      // Difuminado arriba y abajo
      for (const [y0, y1] of [[0, H * 0.25], [H, H * 0.75]]) {
        const g = ctx.createLinearGradient(0, y0, 0, y1);
        g.addColorStop(0, 'rgba(0,0,0,1)'); g.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = g;
        ctx.fillRect(0, Math.min(y0, y1), W, Math.abs(y1 - y0));
      }
    }

    // `inicio` es Date.now() del momento del sorteo, para que panel y escena
    // vayan a la vez aunque una reciba el aviso un poco tarde.
    girar(tirada, inicio) {
      return new Promise((resolver) => {
        if (this.reposo) { cancelAnimationFrame(this.reposo); this.reposo = null; }
        if (this.anim) cancelAnimationFrame(this.anim);
        this.tira = tirada.tira;
        this.ganador = -1;
        const fin = desplazamientoFinal(tirada);
        let ultimo = -1;
        const paso = () => {
          const t = Math.min(1, (Date.now() - inicio) / tirada.duracionMs);
          this.desplazamiento = fin * frenada(t);
          const idx = indiceEnCentro(this.desplazamiento);
          if (idx !== ultimo) { ultimo = idx; Sonido.tic(); }
          this.dibujar();
          if (t < 1) this.anim = requestAnimationFrame(paso);
          else {
            this.anim = null;
            this.desplazamiento = fin;
            this.ganador = tirada.indiceGanador;
            this.mantenerHasta = Date.now() + 15000;
            setTimeout(() => this.mostrar(this.nombres), 15050);
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
    const colores = [ACENTO, '#ffffff', '#ffd23f', '#ff4d6d', '#3ddc97', '#4cc9f0'];
    const piezas = Array.from({ length: 220 }, (_, i) => ({
      x: W / 2 + (Math.random() - 0.5) * W * 0.3, y: H * 0.5,
      vx: (Math.random() - 0.5) * W * 0.03, vy: -Math.random() * H * 0.035 - H * 0.01,
      w: (6 + Math.random() * 8) * dpr, h: (8 + Math.random() * 10) * dpr,
      giro: Math.random() * Math.PI * 2, vgiro: (Math.random() - 0.5) * 0.3,
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

  window.Animacion = { Rodillo, Sonido, confeti, _interno: { desplazamientoFinal, indiceEnCentro } };
})();
