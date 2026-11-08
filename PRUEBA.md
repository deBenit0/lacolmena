# Guía de prueba en el juego

Para probar el addon con **2 personas** de la hermandad (A y B), las dos con la misma versión
instalada. Cada paso dice qué hacer y **qué debería pasar**. Si algo no pasa como dice, apunta el
número del paso y sigue con el siguiente.

**Antes de empezar (los dos):**
- Escribid `/console scriptErrors 1` en el chat para ver los errores de Lua.
- Abrid la ventana de hermandad (**J**). Debe salir la **pestaña con el engranaje** en el borde
  derecho.

## 0. Autocomprobación (los dos, 2 minutos)

1. Pulsa la pestaña del engranaje. → Se abre el **Inicio** con el lema y el logo.
2. Ve a **Pedidos → Mis cosas** y pulsa **Comprobar el addon**.
   → Sale una lista en verde, rojo o amarillo.
3. Abre una profesión, abre el buzón y vuelve a pulsar **Comprobar otra vez**.
   → Lo amarillo de *Ventana de profesión* y *Contra reembolso* pasa a verde o rojo.
4. Si hay algo en **rojo**: pulsa **Seleccionar informe**, Ctrl+C, y pégaselo a quien programa el
   addon.

## 1. Pedidos (A pide, B fabrica)

B debe tener una profesión que fabrique algo que A necesite (o que pueda recolectarlo).

1. **B** abre su ventana de profesión una vez.
   → En *Mis cosas* le salen sus recetas.
2. **A** abre su ventana de profesión, pasa el ratón por un material y pulsa **Pedir**
   (o usa *Pedidos → Pedir materiales*). Pulsa **Más opciones**, elige prisa (*Ya*) y una propina
   pequeña (*50 plata*) y pulsa **Pedir**.
   → A ve el pedido en su Tablón como *[Tuyo]*.
3. **B** → Le salta un **aviso con sonido** "A pide 5x ... (ya)".
4. **B** pulsa **Lo hago yo** en el aviso y elige **Antes de 2 horas**.
   → A recibe el aviso "B te hace 5x ...". En el Tablón de B sale como *[Tu encargo]* con el
   plazo.
5. **B** pulsa **Más tiempo** y elige *Lo hago hoy*.
   → A recibe "B necesita más tiempo...". El botón queda gris (solo una vez).
6. **B** abre el buzón y pulsa **Preparar correo** en su encargo.
   → Se ponen destinatario y asunto. La cantidad **todavía no** (el juego no deja contra
   reembolso sin objetos).
7. **B** pone los objetos en el correo. → Se marca solo **Contra reembolso** con 50 plata.
   **Comprueba que NO está en "Enviar dinero"** antes de enviar. Lo envía.
   → El pedido se **completa solo**. A recibe "B te ha enviado...". Karma: B +1, A −1
   (se ve junto a los nombres).
8. **A** recoge el correo. → El juego le cobra los 50 plata.

## 2. Ofertas (B ofrece, A lo quiere)

1. **B** abre su profesión, elige una receta que fabrique algo que tenga (una bolsa, una
   poción...) y pasa el ratón por el objeto. Pulsa **Ofrecer**, pone **2** y pulsa **Ofrecer**.
   → Sale en el Tablón como *[Oferta]* (gratis) para los dos.
2. **A** prueba los filtros: **Ver: ofertas**, **Categoría** y el buscador con el nombre del objeto.
   → La oferta aparece y desaparece según el filtro.
3. **A** pulsa **Lo quiero** y elige 1.
   → B recibe "A quiere 1x ... de tu oferta".
4. **B** abre el buzón, pulsa **Preparar correo** en su oferta, mete el objeto y envía.
   → A recibe el aviso y a B le queda 1 en la oferta.
5. **B** pulsa **Quitar oferta**. → Desaparece para los dos.

## 3. Mazmorras

1. **A** va a **Mazmorras → Proponer mazmorra**. Elige una de su nivel, la hora con **+**
   (dentro de unos 15 minutos) y su rol, y pulsa **Proponer**.
   → B recibe el aviso si tiene el nivel.
2. **B** marca sus roles y pulsa **Apuntarme**.
   → Los dos ven a B en su rol.
3. **A** pulsa **Hacer grupo**.
   → Salen los elegidos (con 2 personas faltarán huecos: es normal). B recibe "¡Vas a ... de ...!".
4. **A** pulsa **Invitar al grupo**. → A B le llega la invitación del juego.
5. Esperad a que falten menos de 10 minutos para la hora.
   → Los dos reciben el recordatorio "... empieza en ...".
6. **A** pulsa **Cancelar**. → Los dos la ven cancelada.

## 4. Hermandad (necesita un oficial: rango 0 o 1)

1. **El oficial** va a **Pedidos → Hermandad**, escribe un anuncio y pulsa **Publicar**.
   → El otro lo ve arriba en el **Inicio**.
2. **El oficial** va a *Pedir materiales* (o pasa el ratón por un material en su profesión),
   pulsa **Pedir**, pone 5 y marca **Para la hermandad (entre varios)**.
   → El otro lo ve arriba en su **Tablón** como *[Hermandad]*.
3. **El otro** pulsa **Aportar**, abre el buzón y manda 2 al oficial.
   → Sale "aportado 2 de 5" con su nombre. Sube en *Esta semana*. Si hay un tercero, que aporte
   también: se suman.
4. **El oficial** abre un pedido del otro en el Tablón (**Ver pedido**) y pulsa **Prioridad**.
   → En el Tablón del otro sale con *[Prioridad]*.
5. Si alguno tiene un **alt**: entra con él una vez. → Sale como "Alt (Principal)" y su karma es
   el mismo que el del principal.

## 5. Calidad de vida

1. Pasa el ratón por un objeto que fabrique el otro (en tus bolsas o en el chat).
   → En el tooltip sale "Los hijos del Fundillo: lo dan ..." con su nombre.
2. Repite un pedido del paso 1 pero entrégalo **comerciando en mano** en vez de por correo.
   → Al completarse el comercio, el pedido se marca como entregado solo.
3. Sal del juego, que el otro haga algo (aceptar un pedido tuyo, publicar un anuncio) y vuelve.
   → Al minuto de entrar sale la ventanita **"Mientras no estabas"**.

## 6. Al terminar (los dos)

1. Salid del juego y volved a entrar. → Siguen los pedidos, ofertas, quedadas y el karma.
2. Pulsa **Comprobar el addon** otra vez y, si hay errores guardados, **Copiar informe** y
   pásaselo a quien programa el addon junto con los números de los pasos que fallaron.

*Para probar solo, sin nadie más: activa el **modo demostración** en Mis cosas. Salen pedidos,
ofertas y quedadas de ejemplo que se completan solos.*
