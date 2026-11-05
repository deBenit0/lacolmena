# Los hijos del Fundillo: profesiones

Addon de WoW Forever para **Los hijos del Fundillo**: cada miembro ofrece lo que sabe
fabricar (a cambio de los materiales) y pide lo que necesita, pagando si quiere.

Esta es la **fase 1** (versión 0.6.1). El diseño completo está en [`DISEÑO.md`](DISEÑO.md).

## Instalación

1. Descarga el repositorio (botón **Code → Download ZIP** en GitHub) o el ZIP del addon.
2. Copia la carpeta **`HDFprofesiones`** dentro de `World of Warcraft\_forever_\Interface\AddOns`.
   Debe quedar `AddOns\HDFprofesiones\HDFprofesiones.toc` (sin carpetas de más en medio).
3. En la pantalla de personajes, pulsa **AddOns** y comprueba que *Los hijos del Fundillo* está activado.

Todos los miembros deben tenerlo: la información viaja entre los que están conectados.

## Cómo se usa

- **Abrir el addon:** abre la ventana de hermandad y pulsa la **pestaña con el engranaje**
  que aparece en su borde derecho. Si no la ves ahí, abre la ventana Social (tecla `O`).
- **Publicar tus recetas:** abre **una vez la ventana de cada profesión** (también
  Encantamiento), sin filtros puestos. Cada vez que la abras se actualizan tus recetas y
  cooldowns. Para que se cuente lo que tienes en el banco, ábrelo una vez.

### Pedir materiales
Lo que **usan tus recetas** y alguien de la hermandad fabrica o consigue recolectando, agrupado
por profesión ([+]/[-] para plegar). Puedes buscar, filtrar por profesión (menú desplegable) o
desmarcar "Solo lo que usan mis recetas" para ver todo. Al elegir uno ves para qué recetas tuyas
sirve, el **precio en la subasta**, quién lo da, la cantidad con − y +, y los botones **Pedir a
todos**, **Pedir a [nombre]** y **Susurrar**.

### Pedir equipo
Armas, armaduras, bolsas y encantamientos que fabrica la hermandad, con sus **materiales en
casillas** (tienes/necesitas), quién lo fabrica y los mismos botones para pedir.

### Precio y pago
- El precio de la subasta sale de **Auctionator** (recomendado); si no lo tienes, de TSM o de lo
  que el addon apunta al mirar la subasta. La petición propone pagar **un 10% menos**.
- Si la petición ofrece oro, al **Preparar correo** el envío va **contra reembolso**: el juego
  le cobra al que pidió cuando recoge el objeto.

### Pedir en la hermandad (desde tu ventana de profesión)
Al pasar el ratón por un material de la receta aparece un botón **Pedir** para pedir solo ese.
Para pedir varios a la vez, pulsa **Pedir en la hermandad**. Se abre una ventana con
los materiales que te faltan (contando bolsas y banco):
- **Veces a fabricar** con − y +: las cantidades se recalculan solas.
- Cada material con su **casilla** y **cantidad editable**, y una nota: quién lo da en la
  hermandad, si puedes conseguirlo tú, si nadie lo da (probablemente de vendedor) o si ya lo
  tenías pedido (entonces **se amplía** esa petición en vez de crear otra).
- Vienen marcados solo los que da la hermandad y tú no puedes conseguir.

### Peticiones
- Solo se pide desde **tu ventana de profesión** (botón "Pedir" en cada material o "Pedir en la
  hermandad") o desde las pestañas **Pedir materiales** y **Pedir equipo**.
- Quien pueda fabricarlo **o conseguirlo recolectando** (cuero → Desuello, hierbas →
  Herboristería, mineral y piedra → Minería) recibe un **aviso con sonido** (salvo en combate, mazmorras y bandas:
  se guarda para después). Si la petición es para alguien concreto, solo le avisa a él.
- El aviso trae el botón **Lo hago yo** para aceptar sin abrir nada. Al entrar, un resumen en
  el chat te dice cuántas puedes hacer, y la pestaña del addon muestra ese número.
- **Lo hago yo:** te comprometes a hacer una cantidad. Varios pueden repartirse una petición.
- **Soltar:** si al final no puedes. Un compromiso sin entregar caduca solo a las **48 h**.
- **Entrega por correo:** quien ha aceptado envía los objetos por correo al autor y la
  petición **se completa sola** al enviarse el correo (solo cuentan los objetos pedidos y hasta
  lo prometido). Con el buzón abierto, el botón **Preparar correo** pone el destinatario y el asunto.
- **Recibido** (solo el autor): para entregas en mano. Las entregas suman al contador de
  encargos del fabricante.
- **Renovar** y **Cerrar** (solo el autor). Las peticiones caducan a los **7 días**; las
  terminadas se siguen viendo 2 días. Máximo **10 abiertas** por jugador.

### Mis cosas
Tus profesiones publicadas, el **modo demostración** (jugadores y peticiones de ejemplo que solo
ves tú, para probar cómo queda), el modo **No disponible** (sin avisos y apareces el último),
los avisos y el sonido, y el estado del addon (versión, si hay una más nueva, mensajes por enviar).

## Primera prueba en la hermandad: qué mirar

Activa los errores de Lua para verlos si salen: escribe `/console scriptErrors 1` en el chat.

1. ¿Aparece la pestaña del engranaje en la ventana de hermandad? ¿Está bien colocada?
2. Abre tus profesiones: ¿salen en **Mis cosas** con su número de recetas?
3. Con dos o más conectados: ¿veis las recetas de los demás en **Recetas**?
4. Haz una petición: ¿le llega el aviso a quien sabe hacerlo? ¿Funcionan *Lo hago yo* y *Recibido*?
5. Sal y vuelve a entrar: ¿se mantiene todo? ¿Le llegan los datos a quien entra más tarde?

Si algo falla, haz una captura del error (o de la ventana) y dile qué estabas haciendo.

## Pendiente (fase 2)

Personajes alternativos vinculados al principal, permisos de oficiales (moderar y marcar
prioridad), quién fabrica cada objeto en su ventana de información, aviso al comerciar el
objeto pedido y lista de objetos que nadie sabe hacer.

## Desarrollo

- Pruebas (fuera del juego, con un WoW simulado y varios jugadores conectados entre sí):
  `lua5.1 tests/run.lua`
- Análisis estático: `luacheck HDFprofesiones`
