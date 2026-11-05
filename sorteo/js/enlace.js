/* Comunica el panel con la escena de OBS cuando están en el mismo navegador
 * (por ejemplo, panel como "panel de navegador" de OBS y escena como fuente de
 * navegador, o escena abierta con el botón "Abrir escena"). */
(function () {
  'use strict';
  const NOMBRE = 'colmena-sorteo';
  const oyentes = [];
  let canal = null;
  try { canal = new BroadcastChannel(NOMBRE); canal.onmessage = (e) => oyentes.forEach((f) => f(e.data)); } catch (e) { canal = null; }

  // Respaldo por localStorage (el evento "storage" llega a las demás pestañas).
  window.addEventListener('storage', (e) => {
    if (e.key !== NOMBRE || !e.newValue || canal) return;
    try { const d = JSON.parse(e.newValue); oyentes.forEach((f) => f(d.msg)); } catch (err) { /* ignorar */ }
  });

  window.Enlace = {
    enviar(msg) {
      if (canal) canal.postMessage(msg);
      else { try { localStorage.setItem(NOMBRE, JSON.stringify({ msg, n: Math.random() })); } catch (e) { /* sin almacenamiento */ } }
    },
    escuchar(f) { oyentes.push(f); },
  };
})();
