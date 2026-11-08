# Addon de profesiones — Los hijos del Fundillo

Nombre del addon: carpeta **HDFprofesiones**, título en el juego **Los hijos del Fundillo**.

## Objetivo
Coordinar las profesiones de la hermandad **Los hijos del Fundillo**:
- cada miembro **ofrece** lo que sabe fabricar (a cambio de los materiales);
- cada miembro **pide** lo que necesita y, opcionalmente, qué paga por ello.

## Plataforma
- **WoW Forever oficial** de Blizzard (Classic+, lanzado el 4-nov-2026, vía Battle.net).
  Cliente Classic moderno → API de Lua actual.
  Versión de interfaz para el `.toc`: **16001** (obtenida con `/dump select(4, GetBuildInfo())`).
- **Todos los miembros tendrán el addon**: la comunicación va solo por mensajes ocultos
  de addon en el canal de hermandad.
- **Solo en español.**
- **Sin Discord** (descartado).

## Recetas (ofertas)
- Escaneo **automático** al abrir la ventana de cada profesión; se publican **todas** las recetas.
  Se reescanea al aprender recetas nuevas.
- **Sin condiciones** por oferta: el modelo es "tráeme los materiales".
- Cada receta muestra sus **materiales y cuántos tienes** (bolsas, banco y todos tus personajes).
- **Cooldowns** visibles (transmutaciones, tela lunar…): disponible o tiempo restante.
- Fabricantes **desconectados visibles**, con "visto por última vez".
- Orden: **conectados primero**, luego por última conexión.
- Búsqueda por **texto + filtro por profesión** + filtro para ocultar recetas triviales.
- En el **tooltip** de cualquier objeto: quién de la hermandad lo fabrica.

## Peticiones
- Se pide un **objeto enlazado** o un **encantamiento** (los encantamientos no son objetos).
- **Cantidad** con entregas parciales (p. ej. 12/20 pociones). **Un solo encargado**: se lo queda
  entero el primero que lo acepta (si dos a la vez, gana el que lo hizo antes).
- Al aceptar, el encargado dice **cuándo**: ya (1 h), antes de 2 horas u hoy (medianoche, mín. 3 h).
  Pasado ese plazo (+15 min) el pedido vuelve al tablón. Aviso al encargado 15 min antes y a
  los dos si se pasa. El encargado puede pedir **más tiempo una vez** (opción más larga; aviso al
  que pidió). Quién lo tiene se decide por la hora en que aceptó, así que ampliar no lo cambia.
- El que pide indica su **prisa** con los mismos botones (o sin prisa).
- Indicador de **si el autor aporta los materiales**.
- **Propina opcional** con botones sugeridos (50 plata, 1, 2 y 5 oro) o la que se escriba; se
  cobra contra reembolso. Sin precios de subasta (se quitó Auctionator: consume y solo se
  actualiza al abrir la subasta).
- Los pedidos van **siempre a toda la hermandad** (no se puede pedir a una persona concreta).
- **Karma por pedido**: +1 al que entrega, −1 al que recibe.
- **Caducan a los 7 días** (renovables).
- Estados: **Abierta → Aceptada → Hecha**.
  - **Entrega por correo:** cuando quien aceptó envía el correo con los objetos al autor, se
    apunta sola y la petición se completa al llegar a la cantidad (caso principal: un herrero
    pide cuero y la peletera se lo manda). Solo cuentan los objetos pedidos y hasta lo prometido.
  - El autor también puede confirmar a mano las entregas en persona ("Recibido").
  - Al **comerciar** el objeto pedido con el autor, el addon propone cerrarla.
  - El fabricante puede **soltarla**.
- **Máximo 10** peticiones abiertas por jugador.
- **Aviso emergente + sonido** solo a quien conoce la receta; clic en el aviso abre la petición.
- Objetos pedidos que **nadie sabe hacer**: se listan aparte y se avisa cuando alguien aprende la receta.
- **Contador** de encargos completados por fabricante.

## Ofertas
- Un miembro ofrece objetos concretos que tiene (cantidad y precio por unidad, gratis por defecto).
- Viajan dentro de la ficha de cada jugador: ofertas (of), "lo quiero" (cl) y envíos (od). Cada
  uno escribe solo en la suya, así no hay conflictos.
- "Lo quiero" con cantidad (hasta lo libre); caduca a las 48 h. El que ofrece lo manda por correo
  y se apunta solo; contra reembolso si tiene precio. Karma +1 al que da, −1 al que recibe.
- Tablón: pedidos y ofertas juntos; buscador, Ver (todo/pedidos/ofertas) y categoría
  (materiales, pociones y comida, bolsas, armas y armaduras, otros).

## Hermandad
- Alts: cada personaje publica su principal (mn); por defecto el de más nivel de los míos en
  esta hermandad, se cambia en Mis cosas. Karma y ayudas se suman por persona.
- Oficiales = rango 0 y 1. Publican en su ficha anuncio (an), pedidos cerrados por moderación
  (mc), prioridad (mp) y necesidades (nd). Solo cuenta si quien lo publica es oficial en la lista
  de la hermandad.
- Necesidades: se dona por correo al oficial y se apunta solo (dn en la ficha del que dona).
- Miembro de la semana: ayudas (envíos de pedidos, ofertas y donaciones) por semana (wk).
- Pestañas Eventos y Raids visibles pero desactivadas.

## Confianza y límites
- Cada dato lo publica su dueño y viaja reenviado entre miembros; WoW no permite firmarlos.
  Un miembro con un addon modificado podría mentir (p. ej. decir que ha enviado algo). Lo más
  dañino está limitado: nadie se da karma a sí mismo, cada persona da como mucho 100 puntos a
  otra, se rechazan versiones del futuro (no se puede bloquear para siempre un dato ajeno) y un
  alt solo cuenta si su principal lo confirma (misma cuenta).
- Al entrar sin datos (otro PC, reinstalación) el addon recupera primero tu ficha de la
  hermandad antes de publicar la suya, para no perder karma, ofertas ni aportaciones.

## Mazmorras (quedadas)
- Proponer: mazmorra de la lista (Classic + 9 nuevas de WoW Forever, con id fijo), hora (ahora o
  en tramos de 15 min) y roles de quien propone.
- Apuntarse con varios roles, solo los que permite la clase. Se guarda nivel y clase.
- "Hacer grupo" (solo quien propone): 1 tanque, 1 sanador, 3 DPS; prueba todas las combinaciones
  tanque/sanador y llena el máximo de huecos; desempata por conectado > llega al nivel > primero
  en apuntarse. Resto: suplentes. Se puede rehacer.
- Avisos: quedada nueva (si tu nivel encaja), "vas de X" a los elegidos, recordatorio 10 min antes.
- Botón "Invitar al grupo". Se cancela; se borra 12 h después de terminar.
- Se sincroniza como las peticiones (mensaje M), por bloques con dueño: autor y cada apuntado.

## Avisos / ruido
- Modo **"no disponible"**: no recibes avisos y apareces detrás en las listas.
- **Silencio en combate, mazmorras y bandas**; los avisos se guardan y se muestran al salir.

## Personajes (alts)
- Alts **vinculados al main**, detección **automática** (personajes de la misma cuenta,
  vía datos guardados de cuenta; basta con entrar una vez con cada uno).
- Se publican las recetas de tus alts **aunque no estén en la hermandad** (las publica
  el personaje que sí está).
- El **main es el personaje de más nivel**; en empate, el de más tiempo jugado (y si no se sabe, por orden alfabético).

## Oficiales
- Se detectan por **permiso de rango** (poder editar la nota de oficial).
- **Moderan**: cerrar o borrar cualquier petición.
- **Prioridad**: marcan peticiones "de hermandad" que salen destacadas.

## Interfaz
- Al abrirlo, página de **Inicio** que explica cómo funciona; desde ahí a cada sección.
- Pedidos: **Tablón** (pestaña principal, incluye las antiguas "Peticiones"), Pedir materiales y Mis cosas.
- **Addon integral de la hermandad**: secciones arriba (**Inicio**, **Pedidos**, **Mazmorras**, **Eventos**).
  Solo Pedidos está hecha; las otras dos se ven desactivadas ("Próximamente").
- El lema **«Mi vida por el fundillo»** se ve siempre en la cabecera de la ventana.
- **Integrada en la ventana de hermandad** como pestaña lateral (sin tocar las pestañas de
  Blizzard, para que los parches no la rompan con facilidad).
- **Sin** comando de barra ni botón de minimapa.
  Riesgo asumido: si un parche cambia la ventana de hermandad, no habrá forma de abrir
  el addon hasta actualizarlo.

## Detalles internos
- **Sincronización por versiones**: solo viaja lo que cambia; los conectados se pasan los
  datos de los desconectados.
- **Sin base de datos de recetas cerrada**: las recetas nuevas de Forever se aprenden al escanear.
- **Control de versiones**: aviso de versión nueva; los oficiales ven quién no tiene el addon
  o lo tiene desactualizado.
- **Limpieza**: quien sale de la hermandad desaparece de las listas; solo se aceptan datos de miembros.

## Fases
Se programa por fases para poder probar en el juego cuanto antes.

**Fase 1 (versión 0.1.0):** recetas (escaneo, búsqueda, filtros, materiales con lo que tienes,
cooldowns, desconectados con última vez), peticiones completas (cantidad, encantamientos,
materiales, pago en oro/objetos, a alguien o a todos, estados, caducidades, límite de 10),
autor confirma entregas y contador de encargos, compromisos que caducan a las 48 h y se
pueden soltar, avisos con sonido y modo "no disponible", control de versiones, limpieza
de quien se va.

**Fase 2:** alts vinculados al main (con sus recetas y materiales), oficiales (moderar y
prioridad; ver quién no tiene el addon), tooltip con quién fabrica cada objeto, aviso al
comerciar el objeto pedido, lista de objetos que nadie sabe hacer con aviso al aprenderlos.

## Notas técnicas
- Mensajes ocultos por el canal de hermandad (prefijo `HDFprofesiones`), troceados a 250 bytes
  y enviados a 1 mensaje/s de media como mucho.
- Cada ficha de fabricante tiene un único dueño y una versión; cada parte de una petición
  (autor, cada fabricante, entregas) también, así que las copias se fusionan siempre igual,
  en cualquier orden.
- Al entrar, cada uno manda un resumen; los demás le envían lo que le falta. Los reenvíos
  se descartan justo antes de salir si otro ya ha empezado a enviar lo mismo.
- Pruebas: `lua5.1 tests/run.lua` (WoW simulado con varios jugadores conectados).

## Pedidos en el chat de hermandad (0.28.0)
- Al publicar un pedido, el addon escribe una línea en el chat de hermandad con una marca
  `(HDF1 <id> <datos>)`. Se puede desactivar en Mis cosas.
- Al entrar, lee el historial del chat de hermandad (C_Club, Comunidades) y recupera los pedidos que
  no conocía: llegan aunque quien pide ya no esté conectado. El autor lo pone el servidor.
- La copia del chat lleva la versión del autor un punto por debajo: gana siempre la de verdad.
- Los pedidos purgados se recuerdan (g.gone) para que no vuelvan desde el historial.
