local H = ...
-- Recorre la interfaz como lo haría un jugador (con marcos simulados) para cazar errores de Lua.
H.AddMember("Ana", "MAGE")
H.AddMember("Bea", "WARRIOR")

local ALCHEMY = {
  name = "Alquimia", rank = 300, max = 300,
  rows = {
    { name = "Poción de maná superior", item = 13443, reagents = { { 8838, 3 }, { 8839, 2 } } },
    { name = "Transmutar: arcanita", item = 12360, reagents = { { 12359, 1 }, { 12363, 1 } }, cooldown = 3600 },
    { name = "Coraza vieja", item = 2000, reagents = { { 2840, 4 } } },
  },
}
H.gear = { [2000] = { equipLoc = "INVTYPE_CHEST", minLevel = 10 } }

local ana = H.Login("Ana", { class = "MAGE", bags = { [8838] = 10 } })
local bea = H.Login("Bea", { bags = { [8838] = 1, [8839] = 5 } })
H.Advance(15)
H.OpenTradeSkill(ana, ALCHEMY)
H.Advance(60)

local ns = bea.ns
local env = bea.env

-- Pestaña lateral en la ventana de hermandad.
local guildFrame = env.CreateFrame("Frame", "GuildFrame", env.UIParent)
ns.UI.AttachHost(guildFrame)
local tab = env.HDFProfGuildTabGuildFrame
H.ok(tab ~= nil, "pestaña lateral creada")
tab:Click()
local panel = env.HDFProfPanel
H.ok(panel and panel:IsShown(), "la pestaña abre la ventana")
H.ok(panel.host == guildFrame, "pegada a la ventana de hermandad")
guildFrame:Hide()
H.ok(not panel:IsShown(), "al cerrar la hermandad se cierra")
guildFrame:Show()

-- Página de recetas.
ns.UI.Open("recipes")
H.Advance(1)
local recipes = panel.pageFrames.recipes
H.ok(recipes:IsShown(), "página de recetas visible")
local items = recipes.list.items
H.ok(#items == 2, "2 objetos visibles (la coraza de nivel bajo está oculta): " .. #items)
ns.db.settings.hideLowGear = false
recipes:Refresh()
H.eq(#recipes.list.items, 3, "3 objetos al desactivar el filtro")

-- Búsqueda.
recipes.search:SetText("13443")
recipes.search:GetScript("OnTextChanged")(recipes.search, true)
H.eq(#recipes.list.items, 1, "búsqueda por nombre")
recipes.search:SetText("")
recipes.search:GetScript("OnTextChanged")(recipes.search, true)

-- Filtro de profesión: Alquimia y vuelta a todas.
recipes.profButton:Click()
H.eq(recipes.state.prof, 171, "filtro: Alquimia")
recipes.profButton:Click()
H.eq(recipes.state.prof, nil, "filtro: todas")

-- Elegir la poción: pide los materiales (Bea no los conoce) y los recibe de Ana.
local potionRow
for _, row in ipairs(recipes.list.rows) do
  if row.item and row.item.key == "i13443" then potionRow = row end
end
H.ok(potionRow ~= nil, "fila de la poción")
potionRow:Click()
H.Advance(10)
recipes:RefreshDetail()
local mats = recipes.detail.mats:GetText()
H.ok(mats:find("3x Objeto 8838", 1, true) ~= nil, "materiales de la poción: " .. mats)
H.ok(mats:find("tienes 1", 1, true) ~= nil, "cuántos tengo")
local crafters = recipes.detail.crafters
H.eq(crafters.items[1].name, "Ana-Reino", "Ana la fabrica")
H.ok(crafters.items[1].online, "Ana en línea")

-- Pedírselo a Ana desde la receta.
crafters.rows[1]:Click()
H.ok(recipes.detail.askOne:IsEnabled(), "botón Pedir a Ana activo")
recipes.detail.askOne:Click()
local dialog = env.HDFProfRequestDialog
H.ok(dialog and dialog:IsShown(), "se abre la ventana de petición")
H.eq(dialog.key, "i13443", "con el objeto elegido")
H.eq(dialog.to, "Ana-Reino", "para Ana")
dialog.qty:SetText("4")
dialog.gold:SetText("2")
dialog.payRows[1].link:SetText(H.itemLink(12360))
dialog.payRows[1].count:SetText("1")
dialog:Publish()
H.ok(not dialog:IsShown(), "petición publicada")
local requests = panel.pageFrames.requests
H.ok(requests:IsShown(), "pasa a la página de peticiones")
local id = requests.state.id
local req = ns.G().requests[id]
H.ok(req and req.q == 4 and req.g == 20000 and req.pi[12360] == 1 and req.to == "Ana-Reino", "datos de la petición")
H.ok(requests.detail.info:GetText():find("Paga:", 1, true) ~= nil, "detalle con el pago")
H.ok(not requests.detail.b1:IsEnabled(), "Recibido desactivado sin compromisos")

-- Ana la ve, le salta el aviso, hace clic y acepta.
H.Advance(10)
local alert = ana.env.HDFProfAlert
H.ok(alert and alert:IsShown(), "aviso visible para Ana")
H.ok(alert.text:GetText():find("(a ti)", 1, true) ~= nil, "aviso: la petición es para ella")
alert:Click()
local anaPanel = ana.env.HDFProfPanel
local anaRequests = anaPanel.pageFrames.requests
H.ok(anaPanel:IsShown() and anaRequests:IsShown(), "el aviso abre sus peticiones")
H.eq(anaRequests.state.id, id, "con la petición elegida")
H.ok(anaRequests.detail.b1:IsEnabled(), "Lo hago yo activo")
anaRequests.detail.b1:Click()
local popup = ana.popups[#ana.popups]
H.eq(popup.which, "HDFPROF_AMOUNT", "pregunta cuántos")
popup.data.callback(4)
H.Advance(10)

-- Bea confirma lo recibido.
requests:Refresh()
H.ok(requests.detail.b1:IsEnabled(), "Recibido activo")
requests.detail.b1:Click()
popup = bea.popups[#bea.popups]
popup.data.callback(4)
H.Advance(10)
H.eq(ns.Data.RequestInfo(ns.G().requests[id], ns.Now()).state, "done", "petición hecha")
H.eq(ana.ns.Data.ThanksFor("Ana-Reino"), 1, "Ana ve su encargo completado")

-- Filtros de peticiones.
for _ = 1, 5 do
  requests.filterButton:Click()
end
H.eq(requests.state.filter, 1, "los filtros dan la vuelta")

-- Página "Mis cosas" y ajustes.
ns.UI.ShowPage("mine")
local mine = panel.pageFrames.mine
H.ok(mine:IsShown(), "página Mis cosas")
H.ok(mine.stats:GetText():find("Tu versión: 0.1.0", 1, true) ~= nil, "muestra la versión")
local anaMine
ana.ns.UI.ShowPage("mine")
anaMine = anaPanel.pageFrames.mine
H.ok(anaMine.profText:GetText():find("Alquimia", 1, true) ~= nil, "Ana ve su Alquimia publicada")
anaMine.unavailable:SetChecked(true)
anaMine.unavailable:GetScript("OnClick")(anaMine.unavailable)
H.Advance(10)
H.ok(ns.G().entries["Ana-Reino"].u == true, "Bea ve a Ana como no disponible")

-- Nueva petición sin objeto: no se publica.
ns.UI.OpenRequestDialog({})
dialog:Publish()
H.ok(dialog:IsShown(), "sin objeto no se publica")
dialog:Hide()

H.eq(#H.errors, 0, "sin errores de Lua en la interfaz")
