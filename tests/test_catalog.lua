local H = ...
-- Con la base de datos de recetas de Classic, las páginas de pedir muestran todo lo de
-- cada profesión aunque nadie lo haya publicado todavía.
H.AddMember("Pepe")
H.equipIDs = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/equip_ids.lua")
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
H.ok(n > 300, "muchos materiales disponibles: " .. n)
H.ok(#headers >= 8, "agrupados por profesión: " .. table.concat(headers, ", "))
H.ok(keys.i2318 and keys.i4234, "están el cuero ligero y el cuero pesado")
ns.UI.ShowPage("equipment")
local equip = panel.pageFrames.equipment
ns.db.settings.hideLowGear = false
equip:SetAllCollapsed(false)
local ne, _, ekeys = count(equip)
H.ok(ne > 300, "mucho equipo disponible: " .. ne)
H.ok(ekeys.e20034, "encantamiento cruzado en equipo")
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
H.ok(headersOnly >= 8, "la lista de materiales muestra las profesiones: " .. headersOnly)
H.eq(#H.errors, 0, "sin errores de Lua (actualización)")
