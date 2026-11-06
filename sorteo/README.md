# Sorteo del Fundillo

Sorteos para directos de **Twitch** que funcionan **en el navegador**, sin instalar nada.

- La gente **entra escribiendo una palabra en el chat** (por defecto `!sorteo`).
- Quien **gasta dinero recibe papeletas extra** automáticamente: bits, subs, subs regaladas y Hype Chat.
  También entra aunque no haya escrito la palabra (se puede desactivar).
- El ganador sale con una animación sobre **fondo negro con los nombres cayendo de arriba abajo**, cada vez más
  despacio, hasta pararse en el ganador. Quien tiene más papeletas aparece más veces. Con sonido y confeti, lista para **OBS**.

![Panel](docs/panel.png)

![Nombres cayendo en OBS](docs/escena-nombres.png)

![Ganador en OBS](docs/escena-ganador.png)

## Cómo se reparten las papeletas

Por defecto (todo se cambia en **Ajustes**, dentro del panel):

| Qué hace la persona | Papeletas |
|---|---|
| Escribe `!sorteo` en el chat | 1 |
| Gasta dinero | +1 por cada euro (mínimo 1 si gasta algo) |

Cuánto vale cada cosa: bit 0,01 € · sub Tier 1 3,99 € · Tier 2 7,99 € · Tier 3 19,99 € · Prime 0 €.
Las subs regaladas cuentan para quien regala. Los Hype Chats cuentan su importe pasado a euros.

Ejemplos: escribe `!sorteo` y tira 500 bits → 1 + 5 = **6 papeletas**. No escribe pero se suscribe con Tier 1 → **3 papeletas**.

El ganador se elige con el generador aleatorio criptográfico del navegador, con probabilidad proporcional a las papeletas.

## Cómo usarlo

1. Abre `index.html` en Chrome, Edge o Firefox (doble clic vale), o la dirección donde lo tengas publicado (ver abajo).
2. En **Ajustes**, escribe el nombre de tu canal y pulsa **Guardar**. El punto de arriba se pone verde cuando ya lee el chat.
3. Durante el directo verás en vivo quién participa, sus papeletas y su probabilidad.
4. Pulsa **🎲 ¡SORTEAR!**. Los nombres empiezan a caer en el panel y en OBS a la vez.
5. En "Lo que escribe el último ganador" ves sus mensajes, para comprobar que está en el directo.

No hace falta cuenta, contraseña ni crear una app de Twitch: lee el chat como un espectador anónimo, y Twitch ya
anuncia en el chat los bits, subs y regalos.

Lo demás:
- **Abierto / Cerrado**: con el sorteo cerrado no entra nadie nuevo (para cerrar la inscripción antes de sortear).
- **Excluir / Readmitir** a cualquiera. Por defecto el ganador queda fuera de los siguientes sorteos (para varios premios).
- **Añadir a mano** euros a alguien (PayPal, Ko-fi, StreamElements…) o restarlos con un número negativo.
- **Pruebas**: botones para meter participantes falsos y ensayar. Pulsa **Reiniciar sorteo** antes del de verdad.
- **Exportar / Importar**: copia de seguridad del sorteo y los ajustes en un archivo.

Todo se guarda solo en tu navegador: si cierras la pestaña, al volver sigue donde estaba.

## En OBS

La escena (`escena.html`) es transparente y solo aparece (en negro) cuando sorteas. Para recibir la orden de sortear tiene que estar
**en el mismo navegador que el panel**:

**A · Todo dentro de OBS (recomendado)**
1. *Ver → Paneles → Paneles de navegador personalizados* → añade `index.html` (la dirección exacta aparece en el panel, en "Usar en OBS").
   Así manejas el sorteo desde OBS.
2. Añade una *Fuente de navegador* de 1920×1080 con `escena.html`, y marca *Controlar audio vía OBS* para el sonido.

**B · Captura de ventana**
Pulsa **🎬 Abrir escena** en el panel y captura esa ventana en OBS con *Captura de ventana* + filtro *Clave cromática*
(usa `escena.html?fondo=verde`).

Opciones de la escena, añadiéndolas a la dirección (y combinándolas con `&`):

| Opción | Qué hace |
|---|---|
| `?anuncio=1` | Barra "Escribe !sorteo para participar" mientras el sorteo está abierto |
| `?siempre=1` | El fondo negro con los nombres se ve siempre, no solo al sortear |
| `?segundos=20` | Segundos que se queda el ganador en pantalla (15 por defecto) |
| `?sonido=0` | Sin sonido |
| `?fondo=verde` | Fondo verde para clave cromática |

Ejemplo: `escena.html?anuncio=1&segundos=20`

En la escena no se muestra cuánta gente participa ni las papeletas de nadie; eso solo lo ves tú en el panel.

## Publicarlo con una dirección web (opcional)

Para tener una dirección fija (cómoda para OBS), se puede publicar gratis con GitHub Pages:
en el repositorio, *Settings → Pages → Deploy from a branch*, rama `main`, carpeta `/ (root)`.
Quedaría en `https://debenit0.github.io/lacolmena/sorteo/`.

## Cosas a tener en cuenta

- Solo cuenta lo que pasa **mientras el panel está abierto**: ábrelo antes de anunciar el sorteo.
- Las subs **regaladas de forma anónima** no cuentan (no se sabe quién las regala).
- Las donaciones de StreamElements/Streamlabs no pasan por el chat: añádelas a mano.
- Comprueba que tus sorteos cumplen las normas de Twitch y la ley de tu país sobre sorteos.

## Archivos

- `index.html`: panel · `escena.html`: escena para OBS
- `js/nucleo.js`: reglas del sorteo y lectura de mensajes de Twitch
- `js/chat.js`: conexión al chat · `js/rodillo.js`: animación de nombres, sonido y confeti · `js/enlace.js`: comunicación panel ↔ escena
- `test/`: tests (`npm test`, necesita Node.js; solo para desarrollo)
