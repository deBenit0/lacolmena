# Los hijos del Fundillo: profesiones

Addon de WoW Forever para **Los hijos del Fundillo** (*«Mi vida por el fundillo»*): un addon
para todo lo que necesita la hermandad. Al abrirlo sale el **Inicio**, que explica cómo
funciona, con el lema y un resumen (pedidos abiertos, nuevos, los que puedes hacer y tus encargos
por enviar), y el **logo de NorrisPlay**. Desde ahí vas a cada sección:

- **Pedidos** (la que está hecha): cada miembro pide lo que necesita a quien sabe fabricarlo o
  recolectarlo, pagando si quiere.
- **Mazmorras**: proponer una mazmorra y que la gente se apunte por rol; el addon hace el grupo.
- **Eventos**: se ve pero aún no se puede abrir (próximamente).

Esta es la **fase 1** (versión 0.17.0). El diseño completo está en [`DISEÑO.md`](DISEÑO.md).

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

### Tablón (al entrar en Pedidos)
Los pedidos de la gente en este momento, en este orden:
1. **[Tu encargo]**: lo que aceptaste y aún no has enviado, con **Preparar correo** (con el
   buzón abierto) o **Enviar (ejemplo)** si es de demostración.
2. **Puedes hacerlo** (en verde): debajo dice si **tienes los materiales** o qué te falta
   (contando bolsas y banco); si lo recolectas, cuántos tienes.
3. **¡Nuevo!**: lo que ha llegado desde la última vez que miraste el tablón.
4. El resto y al final los tuyos (*[Tuyo]*, con quién lo hace y su plazo). Dentro de cada grupo,
   primero los que **corren prisa** y luego por karma.

Cada pedido dice quién lo pide, su **prisa**, la **propina** y si pone los materiales, con
**Ver pedido** (todos los detalles) y **Aceptar encargo**. Con **Solo lo que puedo hacer** filtras, y los
botones **Mis pedidos** e **Historial** abren la lista completa (con **< Tablón** para volver).
La antigua pestaña "Peticiones" está ahora dentro del tablón.

### Pedir materiales
**Solo materiales de verdad** (cueros, telas, barras, piezas, elementales, esencias...; sin pociones,
comida ni vendas) de todo lo que se puede fabricar en Classic, **agrupados por tipo**: Cueros, Telas,
Metales y piedras, Hierbas, Elementales, Piezas de ingeniería... Salen aunque nadie de la hermandad
los haya publicado aún. Puedes buscar, filtrar por profesión que lo fabrica (menú desplegable) o
marcar "Solo lo que usan mis recetas". Al entrar al juego, el addon carga en segundo plano los
nombres de todos los objetos para que el buscador los encuentre.

Los grupos salen **plegados**, salvo los que tienen materiales que usan tus recetas, y el addon
recuerda cuáles dejas abiertos. Con **+ Favorito** marcas lo que pides a menudo: sale arriba del
todo. Al elegir un material ves para qué recetas tuyas sirve, quién lo da, la cantidad con − y +,
y los botones **Pedir a la hermandad** y **Susurrar**.

*(La pestaña "Pedir equipo" está retirada de momento: se rehará más adelante.)*

### Al pedir: prisa y propina
- **¿Qué prisa tienes?**: *Sin prisa*, *Ya*, *Antes de 2 horas* u *Hoy*. Se ve en el tablón y
  en el aviso; los que corren prisa salen antes.
- **Ofrecer propina (opcional)**: botones *Nada*, *50 plata*, *1 oro*, *2 oro*, *5 oro*, o la que
  escribas.
- Si hay propina, al **Preparar correo** el envío va **contra reembolso**: el juego le cobra la
  propina al que pidió cuando recoge el objeto.
- El pedido va **siempre a toda la hermandad**: no se puede pedir a una persona concreta.
- Ya no se usan precios de subasta (ni Auctionator).

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
  hermandad") o desde la pestaña **Pedir materiales**. Se aceptan desde el **Tablón**.
- Quien pueda fabricarlo **o conseguirlo recolectando** (cuero → Desuello, hierbas →
  Herboristería, mineral y piedra → Minería) recibe un **aviso con sonido** (salvo en combate, mazmorras y bandas:
  se guarda para después).
- El aviso trae el botón **Lo hago yo** para aceptar sin abrir nada. Al entrar, un resumen en
  el chat te dice cuántas puedes hacer, y la pestaña del addon muestra ese número.
- **Aceptar encargo:** el pedido **se lo queda entero el primero que lo acepta** (no se reparte).
  Al aceptar eliges cuándo lo tendrás: **Lo hago ya** (1 hora), **Antes de 2 horas** o
  **Lo hago hoy** (hasta medianoche, mínimo 3 horas).
- **Plazo:** 15 minutos antes de que se acabe, al encargado le salta un **aviso**. Si no lo envía
  a tiempo (con 15 minutos de margen), el pedido **vuelve al tablón** para que lo coja otro, y a
  los dos les llega un aviso.
- **Más tiempo:** el encargado puede ampliar el plazo **una sola vez** (botón *Más tiempo* en el
  tablón o en el pedido) eligiendo una opción más larga. Al que pidió le llega un aviso.
- Si dos lo aceptan a la vez, se lo queda el que pulsó antes y al otro le avisa.
- **Soltar:** si al final no puedes, el pedido vuelve al tablón.
- **Entrega por correo:** quien ha aceptado envía los objetos por correo al autor y la
  petición **se completa sola** al enviarse el correo (solo cuentan los objetos pedidos). Con el buzón abierto, el botón **Preparar correo** pone el destinatario y el asunto.
- **Recibido** (solo el autor): para entregas en mano. Las entregas suman al contador de
  encargos del fabricante.
- **Renovar** y **Cerrar** (solo el autor). Las peticiones caducan a los **7 días**; las
  terminadas se siguen viendo 2 días. Máximo **10 abiertas** por jugador.

### Karma
- **+1** por cada pedido que entregas y **−1** por cada pedido que recibes.
- Si una petición caduca o se cierra sin recibir nada, no se pierde karma.
- Se ve junto a cada nombre, hay una clasificación en Mis cosas y las peticiones de quien tiene
  **más karma salen antes** en las listas.

### Mazmorras
- **Proponer mazmorra**: eliges la mazmorra de la lista (las de Classic y las **9 nuevas de WoW
  Forever**, marcadas como *nueva*, con su rango de niveles), la hora (**Ahora** o una hora
  concreta, en tramos de 15 minutos) y con qué roles vas tú (o ninguno si solo la organizas).
  Te propone la que mejor encaja con tu nivel.
- A los de la hermandad que tienen el nivel les llega un **aviso**.
- **Apuntarse**: marcas **todos los roles** que puedes hacer (Tanque, Sanador, DPS). Solo deja
  marcar los que puede tu clase (un mago no puede tanquear). Se puede cambiar o desapuntarse.
- Se ve quién se ha apuntado en cada rol, con su nivel (en rojo si no llega al mínimo) y si está
  conectado.
- **Hacer grupo** (solo quien la propuso): el addon elige **1 tanque, 1 sanador y 3 DPS**.
  Prueba todas las combinaciones (alguien que vale para varios roles va donde más falta) y da
  prioridad a los **conectados**, a los que **llegan al nivel** y a los **primeros en
  apuntarse**. El resto quedan de **suplentes**. Se puede rehacer si alguien se va.
- A los elegidos les llega un aviso ("¡Vas de tanque! Te invitará Ana"), y a todos los
  apuntados un **recordatorio 10 minutos antes**.
- **Invitar al grupo**: quien la propuso invita a los 4 elegidos con un botón.
- **Cancelar**: la quedada se ve como cancelada. Las quedadas se borran solas 12 horas después.

### Modo demostración (para probar)
En **Mis cosas**, marca **Modo demostración**: aparecen jugadores de ejemplo con sus recetas y
peticiones. Solo los ves tú; nunca se envían a la hermandad. Algunas peticiones están hechas a tu
medida: piden cosas que tú sabes fabricar o recolectar, y una **corre prisa** (te salta el
aviso con **Lo hago yo**). Para probar todo el proceso:
1. Pulsa **Lo hago yo** en el aviso o **Aceptar encargo** en el tablón y elige cuándo lo
   tendrás. El de ejemplo te contesta en el chat.
2. Pulsa **Enviar (ejemplo)**: hace como si mandaras el correo (no se envía nada) y la petición
   se completa.
3. A los pocos segundos el de ejemplo lo "recibe", te da las gracias y **sube tu karma**.

También salen dos quedadas de mazmorra: una **tuya** con 8 apuntados para probar **Hacer
grupo**, y otra de un jugador de ejemplo para probar a apuntarte.

Al desmarcarlo desaparece todo lo de ejemplo.

### Mis cosas
Tus profesiones publicadas, el **modo demostración**, el modo **No disponible** (sin avisos y apareces el último),
los avisos y el sonido, un **diagnóstico** (dónde puso la pestaña, si lee tus profesiones, si
encuentra el correo, versión del juego) y el estado del addon (versión, si hay una más nueva, mensajes por enviar).

## Primera prueba en la hermandad: qué mirar

Activa los errores de Lua para verlos si salen: escribe `/console scriptErrors 1` en el chat.

1. ¿Aparece la pestaña del engranaje en la ventana de hermandad? ¿Está bien colocada?
2. Abre tus profesiones: ¿salen en **Mis cosas** con su número de recetas?
3. Con dos o más conectados: ¿veis las recetas de los demás en **Recetas**?
4. Haz una petición: ¿le llega el aviso a quien sabe hacerlo? ¿Funcionan *Aceptar encargo* y *Recibido*?
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
