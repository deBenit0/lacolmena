# Los hijos del Fundillo: profesiones

Addon de WoW Forever para **Los hijos del Fundillo**: cada miembro ofrece lo que sabe
fabricar (a cambio de los materiales) y pide lo que necesita, pagando si quiere.

Esta es la **fase 1** (versión 0.1.0). El diseño completo está en [`DISEÑO.md`](DISEÑO.md).

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

### Recetas
Todo lo que se puede fabricar en la hermandad. Puedes buscar por nombre, filtrar por
profesión y ocultar el equipo de nivel bajo. Al elegir un objeto ves:
- los **materiales** y **cuántos tienes** (bolsas + banco);
- **quién lo fabrica**: primero los disponibles y conectados, después por última conexión;
  con el **cooldown** si la receta lo tiene y los **encargos completados** de cada uno;
- botones **Pedir a todos**, **Pedir a [nombre]** y **Susurrar**.

### Peticiones
- **Nueva petición:** mayús+clic en un objeto (o arrástralo al icono), cantidad, si aportas
  los materiales y el pago opcional en oro y/u objetos. Los encantamientos se piden desde
  la página de Recetas, porque no son objetos.
- Quien pueda fabricarlo recibe un **aviso con sonido** (salvo en combate, mazmorras y bandas:
  se guarda para después). Si la petición es para alguien concreto, solo le avisa a él.
- **Lo hago yo:** te comprometes a hacer una cantidad. Varios pueden repartirse una petición.
- **Soltar:** si al final no puedes. Un compromiso sin entregar caduca solo a las **48 h**.
- **Recibido** (solo el autor): confirma lo entregado. Esto suma al contador de encargos del
  fabricante.
- **Renovar** y **Cerrar** (solo el autor). Las peticiones caducan a los **7 días**; las
  terminadas se siguen viendo 2 días. Máximo **10 abiertas** por jugador.

### Mis cosas
Tus profesiones publicadas, el modo **No disponible** (sin avisos y apareces el último),
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
