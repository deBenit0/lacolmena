# Instrucciones para Claude

## Preguntas al usuario (OBLIGATORIO)
- SIEMPRE que haya que hacer preguntas al usuario, hacerlas **tipo test con botones** (herramienta AskUserQuestion), **de una en una**: una sola pregunta por llamada, esperar la respuesta y luego la siguiente.
- Nunca soltar listas de preguntas en texto plano.

## Proyecto
- Addon de WoW (WoW Forever oficial de Blizzard) para la hermandad **Los hijos del Fundillo**: coordinar profesiones (ofertas de fabricación a cambio de materiales y peticiones con pago opcional). Nombre provisional del addon: La Colmena.
- Todas las decisiones de diseño están en `DISEÑO.md`.
- Idioma de trabajo: español.

## Desarrollo
- El addon está en `LaColmena/` (cliente Classic moderno, interfaz 16001, Lua 5.1).
- Antes de subir cambios: `luacheck LaColmena` y `lua5.1 tests/run.lua` (deben pasar sin fallos).
  Si faltan: `apt-get install -y lua5.1 lua-check`.
- Las pruebas simulan WoW (`tests/harness.lua`) con varios jugadores conectados por una red falsa.
- Sin comando de barra ni botón de minimapa: el addon se abre desde la ventana de hermandad (decisión del usuario).
