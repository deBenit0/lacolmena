# Los hijos del Fundillo: profesiones

Addon de WoW Forever para **Los hijos del Fundillo** (*«Mi vida por el fundillo»*): un addon
para todo lo que necesita la hermandad. Arriba tiene tres secciones:

- **Pedidos** (la que está hecha): cada miembro pide lo que necesita a quien sabe fabricarlo o
  recolectarlo, pagando si quiere.
- **Mazmorras** y **Eventos**: se ven pero aún no se pueden abrir (próximamente).

Esta es la **fase 1** (versión 0.11.0). El diseño completo está en [`DISEÑO.md`](DISEÑO.md).

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
**Solo materiales de verdad** (cueros, telas, barras, piezas, elementales, esencias...; sin pociones,
comida ni vendas) de todo lo que se puede fabricar en Classic, **agrupados por tipo**: Cueros, Telas,
Metales y piedras, Hierbas, Elementales, Piezas de ingeniería... Salen aunque nadie de la hermandad
los haya publicado aún. Puedes buscar, filtrar por profesión que lo fabrica (menú desplegable) o
marcar "Solo lo que usan mis recetas". Al entrar al juego, el addon carga en segundo plano los
nombres de todos los objetos para que el buscador los encuentre.

Los grupos salen **plegados**, salvo los que tienen materiales que usan tus recetas, y el addon
recuerda cuáles dejas abiertos. Con **+ Favorito** marcas lo que pides a menudo: sale arriba del
todo. Al elegir un material ves para qué recetas tuyas sirve, el **precio en la subasta**, quién lo
da, la cantidad con − y +, y los botones **Pedir a todos**, **Pedir a [nombre]** y **Susurrar**.

*(La pestaña "Pedir equipo" está retirada de momento: se rehará más adelante.)*

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
  hermandad") o desde la pestaña **Pedir materiales**.
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

### Karma
- **Sube** cuando entregas lo que aceptaste y **baja** cuando recibes lo que pediste, según su
  valor en subasta: **1 punto por cada oro**. El precio se fija al crear la petición (con
  Auctionator si lo tiene quien pide; si no, 1 oro por unidad).
- Si una petición caduca o se cierra sin recibir nada, no se pierde karma.
- Se ve junto a cada nombre, hay una clasificación en Mis cosas y las peticiones de quien tiene
  **más karma salen antes** en las listas.

### Modo demostración (para probar)
En **Mis cosas**, marca **Modo demostración**: aparecen jugadores de ejemplo con sus recetas y
peticiones. Solo los ves tú; nunca se envían a la hermandad. Algunas peticiones están hechas a tu
medida: piden cosas que tú sabes fabricar o recolectar, y una va **dirigida a ti** (te salta el
aviso con **Lo hago yo**). Para probar todo el proceso:
1. Pulsa **Lo hago yo** en el aviso o en Peticiones y di cuántos haces. El de ejemplo te
   contesta en el chat.
2. Pulsa **Enviar (ejemplo)**: hace como si mandaras el correo (no se envía nada) y la petición
   se completa.
3. A los pocos segundos el de ejemplo lo "recibe", te da las gracias y **sube tu karma**.

Al desmarcarlo desaparece todo lo de ejemplo.

### Mis cosas
Tus profesiones publicadas, el **modo demostración**, el modo **No disponible** (sin avisos y apareces el último),
los avisos y el sonido, un **diagnóstico** (dónde puso la pestaña, si lee tus profesiones, si
encuentra Auctionator y el correo, versión del juego) y el estado del addon (versión, si hay una más nueva, mensajes por enviar).

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
