/* Lee el chat de Twitch desde el navegador por WebSocket, como espectador
 * anónimo: no hace falta cuenta, token ni app. */
(function () {
  'use strict';

  class ChatTwitch {
    constructor({ alMensaje, alEstado }) {
      this.alMensaje = alMensaje || (() => {});
      this.alEstado = alEstado || (() => {});
      this.ws = null;
      this.canal = '';
      this.reintentos = 0;
      this.temporizador = null;
    }

    conectar(canal) {
      this.desconectar();
      this.canal = String(canal || '').trim().toLowerCase().replace(/^#/, '').replace(/^https?:\/\/(www\.)?twitch\.tv\//, '').split(/[/?]/)[0];
      if (!this.canal) return this.alEstado({ conectado: false, texto: 'Escribe tu canal en Ajustes' });
      this._abrir();
    }

    desconectar() {
      clearTimeout(this.temporizador);
      if (this.ws) { this.ws.onclose = null; this.ws.close(); this.ws = null; }
    }

    _abrir() {
      this.alEstado({ conectado: false, texto: `Conectando a #${this.canal}…` });
      const ws = new WebSocket('wss://irc-ws.chat.twitch.tv:443');
      this.ws = ws;
      ws.onopen = () => {
        ws.send('CAP REQ :twitch.tv/tags twitch.tv/commands');
        ws.send('PASS SCHMOOPIIE');
        ws.send('NICK justinfan' + Math.floor(10000 + Math.random() * 89999));
        ws.send('JOIN #' + this.canal);
      };
      ws.onmessage = (e) => {
        for (const linea of String(e.data).split('\r\n')) {
          if (!linea) continue;
          const msg = Nucleo.parseLine(linea);
          if (msg.command === 'PING') ws.send('PONG :' + (msg.params[0] || 'tmi.twitch.tv'));
          else if (msg.command === 'RECONNECT') ws.close();
          else if (msg.command === 'JOIN') { this.reintentos = 0; this.alEstado({ conectado: true, texto: `Leyendo el chat de #${this.canal}` }); }
          else if (msg.command === 'NOTICE') this.alEstado({ conectado: false, texto: 'Twitch: ' + msg.params[msg.params.length - 1] });
          else this.alMensaje(msg);
        }
      };
      ws.onclose = () => {
        if (this.ws !== ws) return;
        this.ws = null;
        const espera = Math.min(30000, 1000 * Math.pow(2, this.reintentos++));
        this.alEstado({ conectado: false, texto: `Sin conexión con el chat. Reintento en ${Math.round(espera / 1000)} s…` });
        this.temporizador = setTimeout(() => this._abrir(), espera);
      };
    }
  }

  window.ChatTwitch = ChatTwitch;
})();
