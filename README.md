# Los hijos del Fundillo: profesiones

Addon de WoW Forever para **Los hijos del Fundillo** (*«Mi vida por el fundillo»*): un addon
para todo lo que necesita la hermandad. Al abrirlo sale el **Inicio**, que explica cómo
funciona, con el lema y un resumen (pedidos abiertos, nuevos, los que puedes hacer y tus encargos
por enviar), y el **logo de NorrisPlay**. Desde ahí vas a cada sección:

- **Pedidos** (la que está hecha): cada miembro pide lo que necesita a quien sabe fabricarlo o
  recolectarlo, pagando si quiere.
- **Mazmorras**: proponer una mazmorra y que la gente se apunte por rol; el addon hace el grupo.
- **Eventos** y **Raids**: se ven pero aún no se pueden abrir (próximamente).

Esta es la **fase 1** (versión 0.26.0). El diseño completo está en [`DISEÑO.md`](DISEÑO.md).

## Instalación

1. Descarga el repositorio (botón **Code → Download ZIP** en GitHub) o el ZIP del addon.
2. Copia la carpeta **`HDFprofesiones`** dentro de `World of Warcraft\_forever_\Interface\AddOns`.
   Debe quedar `AddOns\HDFprofesiones\HDFprofesiones.toc` (sin carpetas de más en medio).
3. En la pantalla de personajes, pulsa **AddOns** y comprueba que *Los hijos del Fundillo* está activado.

Todos los miembros deben tenerlo: la información viaja entre los que están conectados.

> **WoW Forever** usa la ventana de profesiones moderna (no la de Classic). El addon funciona con las
> dos: en Forever pone botones propios **Pedir** junto a cada material, **Ofrecer** junto al objeto y
> **Pedir en la hermandad** junto a la casilla de cantidad.

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

**Solo mis profesiones** (casilla, se recuerda): deja solo lo que tú puedes hacer o recolectar
y lo que tienes que enviar.

**Buscar y filtrar:** caja **Buscar...** (por nombre del objeto o de quien lo pide u ofrece),
**Ver: todo / pedidos / ofertas** y **Categoría**: materiales, pociones y comida, bolsas, armas
y armaduras u otros. El tablón recuerda los filtros.

Cada pedido dice quién lo pide, su **prisa**, la **propina** y si pone los materiales, con
**Ver pedido** (todos los detalles) y **Aceptar encargo**. Con **Solo lo que puedo hacer** filtras, y los
botones **Mis pedidos** e **Historial** abren la lista completa (con **< Tablón** para volver).
La antigua pestaña "Peticiones" está ahora dentro del tablón.

### Ofertas (ofrecer objetos)
- **Desde tu ventana de profesión** (lo más directo): elige una receta y pasa el ratón por el
  objeto que fabrica (o púlsalo). Sale el botón **Ofrecer**: se abre una ventanita con el objeto
  ya puesto y la cantidad que llevas. Pulsa **Ofrecer** y listo: **gratis** por defecto.
- El precio por unidad (*50 plata*, *1 oro*, *5 oro* u otro) está en **Más opciones**.
- Se ofrece **solo desde la ventana de profesión** (lo que fabricas: bolsas, equipo, pociones...).
  Máximo 20 ofertas; duran 14 días.
- En el tablón salen como **[Oferta]**. Los demás pulsan **Lo quiero** y dicen cuántos (no se
  puede pedir más de lo que queda libre). Pueden echarse atrás con **Ya no lo quiero**.
- Al que ofrece le llega un aviso ("Bea quiere 3x Bolsa de lana"). En su oferta ve quién la
  quiere y, con el buzón abierto, **Preparar correo** pone destinatario, asunto y, si tiene
  precio, el **contra reembolso**.
- Al **enviar el correo se apunta solo**: baja lo que queda en la oferta y al que lo pidió le
  llega un aviso. Karma: +1 al que da y −1 al que recibe.
- Un "lo quiero" que no se manda en 48 horas caduca.

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

### Pedir equipo
El mismo sistema que *Pedir materiales*, para armas, armaduras, bolsas y encantamientos que
fabrica la hermandad: cada objeto una vez, **agrupado por tipo** (Armas, Cabeza, Pecho, Manos,
Bolsas, Encantamientos...), grupos plegados, buscador, favoritos y desplegable de profesión.
Se oculta el equipo de mucho menos nivel que el tuyo.

### Al pedir: directo
La ventana de pedir tiene el objeto, la **cantidad** (con − y +), a su derecha la **propina**
(cada clic: sin propina, 50 plata, 1, 2 o 5 oro; escribir otra cantidad está desactivado por
ahora) y el botón **Pedir**. La prisa y "Aporto los materiales" están en **Más opciones**:

### Más opciones al pedir: prisa y propina
- **¿Qué prisa tienes?**: *Sin prisa*, *Ya*, *Antes de 2 horas* u *Hoy*. Se ve en el tablón y
  en el aviso; los que corren prisa salen antes.
- **Ofrecer propina (opcional)**: botones *Nada*, *50 plata*, *1 oro*, *2 oro*, *5 oro*, o la que
  escribas.
- Si hay propina, al **Preparar correo** el envío va **contra reembolso**: el juego le cobra la
  propina al que pidió cuando recoge el objeto. El buzón solo deja marcarlo cuando ya hay objetos
  adjuntos, así que el addon lo marca y pone la cantidad **en cuanto metes los objetos** (y la
  quita si los sacas: nunca la deja como "Enviar dinero").
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

### Hermandad (pestaña dentro de Pedidos)
- **Pedidos de la hermandad**: un oficial pide algo para la hermandad (frascos para la banda,
  materiales...) con la ventana normal de **Pedir** (en su profesión o en *Pedir materiales*)
  marcando **Para la hermandad (entre varios)**. Sale en el **Tablón** de todos como
  *[Hermandad]* (arriba del todo) y en esta pestaña. **Lo abastecen entre varios**: cada uno
  pulsa **Aportar**, dice cuántos y se lo manda por correo al oficial; se **apunta solo** al
  enviarlo. Se ve cuánto falta y quién ha aportado más.
- **Miembro de la semana**: quien más ha ayudado la semana pasada (pedidos enviados, ofertas y
  donaciones), y la clasificación de esta semana. También sale en el Inicio.
- **Para oficiales** (rango 0 y 1 de la hermandad): el **anuncio** que sale arriba en el Inicio
  de todos, y la lista de **inactivos** (más de 14 días sin entrar) y de **quién no tiene el
  addon**. En cada pedido pueden marcarlo como **Prioridad** (sale arriba en el Tablón de todos)
  o **cerrarlo** si es abusivo. Lo de oficial solo cuenta si de verdad tiene ese rango.

### Calidad de vida
- **Quién lo fabrica**: al pasar el ratón por cualquier objeto del juego (bolsas, subasta, chat,
  enlaces...), el tooltip dice quién de la hermandad lo da (en verde los conectados).
- **Comercio en mano**: si le das en mano a alguien lo de un pedido suyo que aceptaste (o de tu
  oferta, o una aportación a un pedido de la hermandad), al completarse el comercio se apunta
  solo, igual que por correo. Un comercio cancelado no cuenta.
- **Bienvenida a nuevos**: cuando alguien entra en la hermandad, a los oficiales les salta un
  aviso y uno de ellos (solo uno) le susurra una bienvenida con el recordatorio de instalar el
  addon. Se puede desactivar en *Hermandad* (casilla para oficiales).
- **Pedidos de fabricación de Blizzard** (Forever): si publicas en la mesa de pedidos un pedido
  para la **hermandad**, el addon avisa a quien sabe fabricarlo y lo pone en su Tablón como
  *[Pedido de Blizzard]* (se coge en la profesión → Pedidos → Hermandad). Se puede ocultar.
- **Avisos tranquilos**: el mismo aviso no se repite en 10 minutos, varios seguidos se agrupan, y
  en *Mis cosas* hay **No molestar** (1 hora, 3 horas o hasta mañana): los avisos se guardan y
  salen después.
- **Ventana a tu gusto**: se puede arrastrar a cualquier sitio y agrandar o achicar con el asa de
  la esquina inferior derecha (clic derecho en el asa: como estaba). Se recuerda.
- **Al entrar, lo importante primero**: los pedidos y quedadas se envían antes que las fichas de
  recetas, para que lleguen antes cuando se conectan muchos a la vez.
- **Recetas que faltan**: en *Hermandad*, el botón **Faltan (N)** lista lo que se pide y nadie
  sabe hacer. Cuando alguien aprende esa receta, a quien lo pidió le llega un aviso.
- **Anunciar en el chat**: en tus pedidos (*Ver pedido* → **Anunciar en el chat**) y en tus
  ofertas sin peticiones (**Anunciar**), para los de la hermandad que no tienen el addon. Como
  mucho una vez por minuto.
- **Tus números**: en *Mis cosas*, pedidos y ofertas entregados, aportaciones, cosas recibidas y
  propinas ganadas, esta semana, la anterior y en total.
- **Resumen al entrar**: al conectarte, una ventanita con lo que ha pasado mientras no estabas
  (pedidos tuyos aceptados o entregados, pedidos nuevos que puedes hacer, ofertas tuyas pedidas,
  pedidos de hermandad, quedadas y el anuncio).

### Personajes alternativos
- Tus personajes se unen solos: el de **más nivel** es tu **principal** (lo puedes cambiar en
  *Mis cosas*). Los demás salen como "Beita (Bea)".
- El **karma** y las ayudas de la semana son **por persona**: lo que haga un alt suma al principal.
- Cada personaje tiene que entrar una vez con el addon para que se sepa que es tuyo.

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

Gerda hace de **oficial de ejemplo** (anuncio y necesidades), Olaf es un **alt** de Bruno y hay
ayudas de la semana. También salen **ofertas de ejemplo** (bolsas, pociones, comida): pide una con **Lo quiero** y a
los pocos segundos te la "mandan". Y dos quedadas de mazmorra: una **tuya** con 8 apuntados para probar **Hacer
grupo**, y otra de un jugador de ejemplo para probar a apuntarte.

Al desmarcarlo desaparece todo lo de ejemplo.

### Mis cosas
Tus profesiones publicadas, el **modo demostración**, el modo **No disponible** (sin avisos y apareces el último),
los avisos y el sonido, **Comprobar el addon** y **Copiar informe**, un **diagnóstico** (dónde puso la pestaña, si lee tus profesiones, si
encuentra el correo, versión del juego) y el estado del addon (versión, si hay una más nueva, mensajes por enviar).

## Primera prueba en la hermandad

Sigue la guía paso a paso de [`PRUEBA.md`](PRUEBA.md) (2 personas: pedidos, ofertas y mazmorras,
con lo que debería pasar en cada paso).

- **Comprobar el addon** (en *Mis cosas*): revisa todo lo que depende del juego (pestaña de
  hermandad, ventana de profesión, contra reembolso, invitar, arrastrar objetos, logo...) y lo
  marca en verde (bien), rojo (falla) o amarillo (abre esa ventana y vuelve a comprobar).
- **Copiar informe**: junta la versión, la comprobación y los **errores guardados** del addon
  (se guardan solos, hasta 20) en un texto para copiar con Ctrl+C y pasárselo a quien lo programa.

## Pendiente (fase 2)

Personajes alternativos vinculados al principal, permisos de oficiales (moderar y marcar
prioridad), quién fabrica cada objeto en su ventana de información, aviso al comerciar el
objeto pedido y lista de objetos que nadie sabe hacer.

## Desarrollo

- Pruebas (fuera del juego, con un WoW simulado y varios jugadores conectados entre sí):
  `lua5.1 tests/run.lua`
- Análisis estático: `luacheck HDFprofesiones`
