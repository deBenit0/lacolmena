# 🐝 Sorteo de La Colmena

Programa para hacer sorteos en directo en **Twitch**. Lee el chat de tu canal y mete
automáticamente en el sorteo a quien gasta dinero, dando **más papeletas a quien más ha gastado**.

Cuenta:

| Qué | Cómo se valora (editable en `config.json`) |
|---|---|
| Bits (cheers) | 0,01 € por bit |
| Sub / resub | Tier 1: 3,99 € · Tier 2: 7,99 € · Tier 3: 19,99 € · Prime: 0 € |
| Subs regaladas | Cada sub regalada suma su precio **a quien la regala** (las anónimas no cuentan) |
| Hype Chat | Su importe real, convertido a euros |
| Donaciones externas | A mano desde el panel (PayPal, Ko-fi, StreamElements…) |

Por defecto: **1 papeleta por cada euro**, y al menos 1 papeleta si alguien ha gastado algo
(p. ej. 100 bits = 1 papeleta; una sub Tier 1 = 3 papeletas; 12,98 € = 12 papeletas).
El ganador se elige al azar con `crypto.randomInt`, con probabilidad proporcional a sus papeletas.

No necesita contraseñas, tokens ni crear una app de Twitch: se conecta al chat como espectador
anónimo, porque Twitch ya envía a todo el chat la información de bits, subs y regalos.

## Requisitos

[Node.js](https://nodejs.org) 18 o superior. No hay que instalar nada más (`npm install` no hace falta).

## Uso

1. Abre `config.json` y cambia `"canal"` por el nombre de tu canal de Twitch.
2. En una terminal, dentro de esta carpeta:
   ```
   npm start
   ```
   (o, sin tocar el config: `npm start -- nombredetucanal`)
3. Abre **http://localhost:3000** en el navegador. Ese es el panel:
   - Lista de participantes con lo gastado, sus papeletas y su % de probabilidad.
   - **Abrir / Cerrar inscripción**: con el sorteo cerrado se sigue viendo la actividad pero no suma papeletas.
   - **🎲 Sortear**: saca un ganador con animación de ruleta. Si dejas marcado "Quitar al ganador",
     no puede volver a ganar en los siguientes sorteos (útil si sorteas varios premios).
   - **Excluir / Readmitir** a cualquiera (por ejemplo, a ti mismo o a un moderador).
   - **Añadir a mano** euros a alguien (o restar con un número negativo).
   - En "Pruebas y mantenimiento": botones para meter eventos falsos y probar, y **Reiniciar sorteo**.
4. En OBS, añade una **Fuente de navegador** con la URL `http://localhost:3000/overlay`
   (1920×1080). Es transparente y solo aparece cuando sacas un ganador.
   - `http://localhost:3000/overlay?ranking=5` muestra además el top 5 de papeletas en una esquina.
   - `?segundos=20` cambia cuánto tiempo se queda el ganador en pantalla (15 por defecto).

Todo se guarda en `datos/sorteo-<canal>.json`, así que si cierras el programa o se cae, al volver a
abrirlo sigue donde estaba. Para empezar un sorteo nuevo usa **Reiniciar sorteo**.

## Configuración (`config.json`)

- `valores`: cuántos euros vale cada cosa. Si quieres que las subs Prime den papeletas, pon por ejemplo `"subPrime": 3.99`.
- `papeletas.eurosPorPapeleta`: euros necesarios para 1 papeleta (pon `0.5` para dar el doble).
- `papeletas.minimaSiHaGastado`: papeletas mínimas para cualquiera que haya gastado algo (`0` para quitarlo).
- `papeletas.maximo`: tope de papeletas por persona (`0` = sin tope). Útil para que nadie "compre" el sorteo.
- `subsRegaladasCuentanParaQuienRegala`: `false` si no quieres contar los regalos.
- `conversionMonedas`: cambio a euros para Hype Chats en otras monedas.
- `ignorar`: cuentas que nunca entran (bots, etc.).
- `abrirAlArrancar`: si el sorteo empieza abierto al lanzar el programa.
- `puerto`: puerto del panel (3000).

## Cosas a tener en cuenta

- Solo cuenta lo que pasa **mientras el programa está abierto**: arráncalo antes de anunciar el sorteo.
- Las subs **regaladas anónimamente** no tienen a quién asignarse, así que no cuentan.
- Las donaciones de StreamElements/Streamlabs no pasan por el chat de Twitch: añádelas a mano.
- El panel solo es accesible desde tu propio PC (no tiene contraseña).
- Comprueba que tus sorteos cumplen las normas de Twitch y la ley de tu país sobre sorteos y promociones.

## Tests

```
npm test
```
