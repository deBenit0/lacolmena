local H = ...
-- Con la base de datos de recetas de Classic, las páginas de pedir muestran todo lo de
-- cada profesión aunque nadie lo haya publicado todavía.
H.AddMember("Pepe")
H.equipIDs = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/equip_ids.lua")
-- Categorías de algunos materiales reales (en el juego las da GetItemInfoInstant).
H.itemClass = {}
for _, id in ipairs({ 2318, 2319, 4234, 4304, 8170 }) do H.itemClass[id] = { 7, 6, "Cuero" } end
for _, id in ipairs({ 2840, 3576, 3575, 3860, 12359, 2841, 3859, 6037, 12360 }) do H.itemClass[id] = { 7, 7 } end
for _, id in ipairs({ 2996, 2997, 4305, 4339, 14048, 14342 }) do H.itemClass[id] = { 7, 5 } end
for _, id in ipairs({ 4357, 4364, 4377, 10505, 15992, 4359, 4361, 4371 }) do H.itemClass[id] = { 7, 1 } end
local pepe = H.Login("Pepe", { recipeDB = true })
H.Advance(20)
local ns = pepe.ns
ns.UI.Open("materials")
local panel = pepe.env.HDFProfPanel
local function count(page)
  local n, headers, keys = 0, {}, {}
  for _, item in ipairs(page.list.items) do
    if item.header then headers[#headers + 1] = item.label else n = n + 1; keys[item.key] = true end
  end
  return n, headers, keys
end
local mats = panel.pageFrames.materials
local n0 = count(mats)
H.eq(n0, 0, "al abrir, todo plegado (Pepe no tiene recetas)")
mats:SetAllCollapsed(false)
local n, headers, keys = count(mats)
H.ok(n >= 25 and n < 60, "solo materiales de verdad: " .. n)
local labels = table.concat(headers, ", ")
H.ok(labels:find("Cueros", 1, true) and labels:find("Telas", 1, true) and labels:find("Metales y piedras", 1, true)
  and labels:find("Piezas de ingeniería", 1, true), "agrupados por tipo: " .. labels)
H.ok(keys.i2318 and keys.i4234, "están el cuero ligero y el cuero pesado")
H.ok(not keys.i13443, "las pociones no salen en materiales")
-- Elegir uno sin fabricantes conocidos: se puede pedir igual.
ns.UI.ShowPage("materials")
local row
for _, r in ipairs(mats.list.rows) do
  if r.item and not r.item.header then row = r break end
end
row:Click()
H.ok(mats.detail.craftersLabel:GetText():find("puedes pedirlo", 1, true), "sin fabricantes: se puede pedir igual")
H.ok(mats.detail.askAll:IsEnabled(), "botón Pedir a todos activo")
H.eq(#H.errors, 0, "sin errores de Lua")

-- Carga en segundo plano de los nombres: en tandas, y termina sola.
local requested = 0
pepe.env.C_Item = { RequestLoadItemDataByID = function() requested = requested + 1 end,
  GetItemInfo = function() return nil end }
ns.Preload.Start()
H.Advance(1)
H.ok(requested <= 60, "va en tandas pequeñas: " .. requested .. " en 1 s")
H.Advance(120)
local done, total = ns.Preload.Progress()
H.ok(total > 1000 and done == total, "termina de cargar: " .. done .. "/" .. total)
H.ok(requested >= total, "pide todos los objetos (la ventana abierta también pide los suyos)")
H.eq(#H.errors, 0, "sin errores de Lua (carga)")

-- Ajuste guardado de la 0.6 ("solo lo de mis recetas" marcado): se desmarca al actualizar.
H.AddMember("Viejo")
local viejo = H.Login("Viejo", { recipeDB = true, savedDB = { settings = { onlyMyReagents = true, alerts = true, sound = true } } })
H.Advance(5)
H.ok(viejo.ns.db.settings.onlyMyReagents == false, "se desmarca el filtro antiguo")
viejo.ns.UI.Open("materials")
local vm = viejo.env.HDFProfPanel.pageFrames.materials
local headersOnly = 0
for _, item in ipairs(vm.list.items) do if item.header then headersOnly = headersOnly + 1 end end
H.ok(headersOnly >= 4, "la lista de materiales muestra los grupos: " .. headersOnly)
H.eq(#H.errors, 0, "sin errores de Lua (actualización)")
