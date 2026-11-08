# Instrucciones para Claude

## Preguntas al usuario (OBLIGATORIO)
- SIEMPRE que haya que hacer preguntas al usuario, hacerlas **tipo test con botones** (herramienta AskUserQuestion), **de una en una**: una sola pregunta por llamada, esperar la respuesta y luego la siguiente.
- Nunca soltar listas de preguntas en texto plano.

## Proyecto
- Addon de WoW (WoW Forever oficial de Blizzard) para la hermandad **Los hijos del Fundillo**: coordinar profesiones (ofertas de fabricación a cambio de materiales y peticiones con pago opcional). Nombre del addon: **HDFprofesiones** (carpeta) y "Los hijos del Fundillo" (título en el juego).
- Todas las decisiones de diseño están en `DISEÑO.md`.
- Idioma de trabajo: español.

## Desarrollo
- **Ramas:** el proyecto completo (addon, pruebas, documentación, estas instrucciones) está en la rama
  **`desarrollo`**. La rama **`main`** es pública para la hermandad y solo lleva la carpeta
  `HDFprofesiones` y un README corto: al publicar, se copia ahí solo el addon (nada más).
- **Releases:** al subir una etiqueta `vX.Y.Z` (igual que `## Version` del .toc) sobre un commit de
  `desarrollo`, la Action `.github/workflows/publicar.yml` pasa las pruebas y publica en Releases un
  ZIP que solo contiene `HDFprofesiones`.
- El addon está en `HDFprofesiones/` (cliente Classic moderno, interfaz 16001, Lua 5.1).
- Antes de subir cambios: `luacheck HDFprofesiones` y `lua5.1 tests/run.lua` (deben pasar sin fallos).
  Si faltan: `apt-get install -y lua5.1 lua-check`.
- Las pruebas simulan WoW (`tests/harness.lua`) con varios jugadores conectados por una red falsa.
- Sin comando de barra ni botón de minimapa: el addon se abre desde la ventana de hermandad (decisión del usuario).
- **WoW Forever usa el cliente moderno** (tipo de juego interno "camelot", versión 1.60.x), NO la interfaz de
  Classic Era: profesiones con `ProfessionsFrame` + `C_TradeSkillUI` (no existen `GetNumTradeSkills`,
  `TradeSkillReagent1`...), hermandad con Comunidades, chat con `ChatFrameUtil`. Antes de usar cualquier
  función o ventana del juego, verificarla contra la rama **`forever`** de `Gethe/wow-ui-source`
  (`git clone --depth 1 --branch forever --filter=blob:none https://github.com/Gethe/wow-ui-source`).
  El addon mantiene también el camino clásico por compatibilidad.
