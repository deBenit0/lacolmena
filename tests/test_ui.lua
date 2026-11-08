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
H.itemClass = { [12360] = { 7, 7 } } -- la arcanita es un material (metal); la poción no

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
guildFrame.ChatTab = env.CreateFrame("Button", nil, guildFrame)
guildFrame.GuildInfoTab = env.CreateFrame("Button", nil, guildFrame)
ns.UI.AttachHost(guildFrame) -- ya enganchada: no se duplica
local tab = env.HDFProfGuildTabGuildFrame
H.ok(tab ~= nil, "pestaña lateral creada")
tab:Click()
local panel = env.HDFProfPanel
H.ok(panel and panel:IsShown(), "la pestaña abre la ventana")
H.ok(panel.host == guildFrame, "pegada a la ventana de hermandad")
H.ok(panel.pageFrames.home:IsShown(), "al abrir se ve primero el inicio")
H.ok(panel.pageFrames.home.help:GetText():find("Tablón", 1, true), "el inicio explica cómo funciona")
H.ok(not panel.tabs.board:IsShown(), "en el inicio no salen las pestañas de Pedidos")
local home = panel.pageFrames.home
H.ok(home.logoPath:find("norrisplay", 1, true), "logo de NorrisPlay en el inicio")
H.eq(home.twitchLink, nil, "sin enlace: solo el logo")
panel.sections.orders:Click()
H.ok(panel.pageFrames.board:IsShown(), "al entrar en Pedidos se ve el tablón")
H.ok(panel.tabs.board:IsShown() and panel.tabs.materials:IsShown(), "pestañas de Pedidos visibles")
H.eq(panel.tabs.requests, nil, "Peticiones va dentro del tablón (sin pestaña propia)")
panel.sections.home:Click()
H.ok(panel.pageFrames.home:IsShown(), "botón Inicio")
guildFrame:Hide()
H.ok(not panel:IsShown(), "al cerrar la hermandad se cierra")
guildFrame:Show()
tab:Click()

local function countItems(page)
  local n, headers = 0, 0
  for _, item in ipairs(page.list.items) do
    if item.header then headers = headers + 1 else n = n + 1 end
  end
  return n, headers
end
H.ok(panel.motto:GetText():find("Mi vida por el fundillo", 1, true), "el lema se ve al abrir")
H.ok(panel.sections.orders:IsEnabled(), "sección Pedidos activa")
H.ok(panel.sections.dungeons:IsEnabled() and not panel.sections.events:IsEnabled(), "Mazmorras activa; Eventos se ve pero no se puede pulsar")
H.ok(panel.pageFrames.equipment == nil, "sin pestaña de equipo (por ahora)")

-- Página "Pedir materiales": Bea no tiene recetas, así que hay que ver todo.
ns.UI.ShowPage("materials")
local recipes = panel.pageFrames.materials
H.ok(recipes:IsShown(), "página de materiales visible")
H.ok(not ns.db.settings.onlyMyReagents, "por defecto se ve todo")
ns.db.settings.onlyMyReagents = true
recipes:Refresh()
recipes:SetAllCollapsed(false)
H.ok((countItems(recipes)) > 0, "sin datos de mis recetas no se queda vacía: se ve todo")
H.ok(recipes.list.items[1] and true, "hay filas")
ns.db.settings.onlyMyReagents = false
recipes:SetAllCollapsed(false)
local n, headers = countItems(recipes)
H.eq(headers, 1, "un grupo de tipo de material")
H.eq(recipes.list.items[1].label, "Metales y piedras", "agrupado por tipo: Metales y piedras")
H.eq(n, 1, "solo materiales de verdad: la arcanita (ni la poción ni la coraza)")

-- Plegar y desplegar la profesión.
recipes.list.rows[1]:Click()
H.eq((countItems(recipes)), 0, "grupo plegado")
recipes.list.rows[1]:Click()
H.eq((countItems(recipes)), 1, "grupo desplegado")

-- Búsqueda.
recipes.search:SetText("12360")
recipes.search:GetScript("OnTextChanged")(recipes.search, true)
H.eq((countItems(recipes)), 1, "búsqueda por nombre")
recipes.search:SetText("")
recipes.search:GetScript("OnTextChanged")(recipes.search, true)

-- Filtro de profesión: Alquimia y vuelta a todas.
recipes.profButton:Click()
local menu = recipes.profMenu
H.ok(menu:IsShown(), "se abre el menú de profesiones")
H.ok(menu.buttons[1].text:GetText():find("Todas", 1, true) and menu.buttons[2].text:GetText():find("Alquimia", 1, true),
  "opciones: Todas y Alquimia")
menu.buttons[2]:Click()
H.eq(recipes.state.prof, 171, "filtro: Alquimia")
H.ok(not menu:IsShown(), "el menú se cierra al elegir")
H.ok(recipes.profButton:GetText():find("Alquimia", 1, true), "el botón muestra la elegida")
recipes.profButton:Click()
menu.buttons[1]:Click()
H.eq(recipes.state.prof, nil, "filtro: todas")

-- Elegir la arcanita: quién la da.
local potionRow
for _, row in ipairs(recipes.list.rows) do
  if row.item and row.item.key == "i12360" then potionRow = row end
end
H.ok(potionRow ~= nil, "fila de la arcanita")
potionRow:Click()
-- Favoritos: la arcanita sube arriba del todo.
recipes.detail.fav:Click()
H.eq(recipes.list.items[1].label, "Favoritos", "grupo Favoritos arriba")
H.eq(recipes.list.items[2].key, "i12360", "la arcanita en favoritos")
H.eq(recipes.detail.fav:GetText(), "- Favorito", "el botón permite quitarla")
recipes.detail.fav:Click()
H.ok(recipes.list.items[1].label ~= "Favoritos", "quitada de favoritos")
recipes.state.key = "i12360"
recipes:RefreshDetail(true)
-- Cantidad con + y -.
H.eq(recipes.detail.qty:GetText(), "1", "cantidad inicial")
recipes.detail.plus:Click()
recipes.detail.plus:Click()
H.eq(recipes.detail.qty:GetText(), "3", "cantidad con +")
recipes.detail.minus:Click()
H.eq(recipes.detail.qty:GetText(), "2", "cantidad con -")
local crafters = recipes.detail.crafters
H.eq(crafters.items[1].name, "Ana-Reino", "Ana la fabrica")
H.ok(crafters.items[1].online, "Ana en línea")

-- Pedirlo a la hermandad (no se puede elegir a una persona).
H.eq(recipes.detail.askOne, nil, "sin botón Pedir a una persona")
recipes.detail.askAll:Click()
local dialog = env.HDFProfRequestDialog
H.ok(dialog and dialog:IsShown(), "se abre la ventana de petición")
H.eq(dialog.key, "i12360", "con el objeto elegido")
H.eq(dialog.qty:GetText(), "2", "la cantidad elegida pasa a la petición")
H.eq(dialog.priceText, nil, "sin precio de subasta")
H.eq(dialog.gold:GetText(), "", "sin propina por defecto")
dialog.qty:SetText("4")
dialog.tips[4]:Click() -- 2 oro
dialog.rush[3]:Click() -- antes de 2 horas
dialog:Publish()
H.ok(not dialog:IsShown(), "petición publicada")
H.ok(panel.pageFrames.board:IsShown(), "vuelve al tablón")
local id
for rid, r in pairs(ns.G().requests) do if r.a == "Bea-Reino" and r.k == "i12360" then id = rid end end
local req = ns.G().requests[id]
H.ok(req and req.q == 4 and req.g == 20000 and req.pr == 2 and req.to == nil, "datos de la petición")
ns.UI.Open("requests", id)
local requests = panel.pageFrames.requests
H.ok(requests.detail.info:GetText():find("Propina:", 1, true) ~= nil, "detalle con la propina")
H.ok(requests.detail.info:GetText():find("antes de 2 h", 1, true) ~= nil, "detalle con la prisa")
H.ok(not requests.detail.b1:IsEnabled(), "Recibido desactivado sin encargado")

-- Tablón de Ana: el pedido de Bea con Ver pedido y Aceptar encargo.
ana.ns.UI.Open("board")
local board = ana.env.HDFProfPanel.pageFrames.board
H.Advance(1)
board:Refresh()
H.eq(board.list.items[1] and board.list.items[1].r.id, id, "el pedido sale en el tablón de Ana")
H.ok(board.list.rows[1].accept:IsEnabled(), "Aceptar encargo activo")
H.ok(board.list.rows[1].sub:GetText():find("antes de 2 h", 1, true), "se ve la prisa")
H.ok(board.list.rows[1].sub:GetText():find("propina", 1, true), "se ve la propina")
board.list.rows[1].view:Click()
H.ok(ana.env.HDFProfPanel.pageFrames.requests:IsShown(), "Ver pedido abre el detalle")
board:Refresh()
ana.ns.UI.Open("board")
H.ok(not board.empty:IsShown(), "sin el texto de vacío")

-- Ana la ve, le salta el aviso, hace clic y acepta "antes de 2 horas".
H.Advance(10)
local alert = ana.env.HDFProfAlert
H.ok(alert and alert:IsShown(), "aviso visible para Ana")
alert:Click()
local anaPanel = ana.env.HDFProfPanel
local anaRequests = anaPanel.pageFrames.requests
H.ok(anaPanel:IsShown() and anaRequests:IsShown(), "el aviso abre sus peticiones")
H.eq(anaRequests.state.id, id, "con la petición elegida")
H.ok(anaRequests.detail.b1:IsEnabled(), "Aceptar encargo activo")
anaRequests.detail.b1:Click()
ana.env.HDFProfChoice.buttons[2]:Click()
H.Advance(10)
H.eq(ns.Data.RequestInfo(ns.G().requests[id], ns.Now()).owner, "Ana-Reino", "Bea ve que lo hace Ana")
board:Refresh()
local stillThere = false
for _, it in ipairs(board.list.items) do if it.r.id == id and it.pending == 0 then stillThere = true end end
H.ok(not stillThere, "aceptado: ya no se puede aceptar desde el tablón (sale como tu encargo)")

-- Ana pide más tiempo (una vez): solo plazos más largos, y a Bea le llega el aviso.
local beaPushes = {}
local beaPush = ns.Alerts.Push
ns.Alerts.Push = function(a) beaPushes[#beaPushes + 1] = a.text; return beaPush(a) end
ana.ns.UI.Open("board")
board:Refresh()
local myRow = board.list.rows[1]
H.eq(myRow.view:GetText(), "Más tiempo", "en mi encargo: botón Más tiempo")
myRow.view:Click()
local opts = ana.env.HDFProfChoice
H.eq(opts.buttons[1]:GetText(), "Lo hago hoy", "solo ofrece plazos más largos")
H.ok(not opts.buttons[2]:IsShown(), "una sola opción")
opts.buttons[1]:Click()
H.Advance(10)
local extended = false
for _, t in ipairs(beaPushes) do if t:find("necesita más tiempo", 1, true) then extended = true end end
H.ok(extended, "a Bea le avisa: necesita más tiempo")
ns.Alerts.Push = beaPush
H.eq(ns.Data.RequestInfo(ns.G().requests[id], ns.Now()).owner, "Ana-Reino", "sigue siendo de Ana")
board:Refresh()
H.ok(not board.list.rows[1].view:IsEnabled(), "más tiempo solo una vez")

-- Aviso a Ana cuando le quedan menos de 15 minutos.
local anaPushes = {}
local anaPush = ana.ns.Alerts.Push
ana.ns.Alerts.Push = function(a) anaPushes[#anaPushes + 1] = a.text; return anaPush(a) end
local acm = ana.ns.G().requests[id].c["Ana-Reino"]
local savedBy = acm.by
acm.by = ana.ns.Now() + 600
ana.ns.Alerts.CheckDeadlines()
ana.ns.Alerts.CheckDeadlines()
H.eq(#anaPushes, 1, "un solo aviso de plazo")
H.ok(anaPushes[1] and anaPushes[1]:find("Te quedan", 1, true), "aviso: te quedan 10 minutos")
acm.by = savedBy
ana.ns.Alerts.Push = anaPush

-- Bea confirma lo recibido.
ns.UI.Open("requests", id)
H.ok(requests.detail.b1:IsEnabled(), "Recibido activo")
requests.detail.b1:Click()
bea.popups[#bea.popups].data.callback(4)
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
H.ok(mine.stats:GetText():find("Tu versión: 0.21.0", 1, true) ~= nil, "muestra la versión")
H.ok(mine.stats:GetText():find("Pestaña en: |cff40ff40GuildFrame", 1, true) ~= nil, "diagnóstico: pestaña en la ventana de hermandad")
H.ok(mine.stats:GetText():find("Correo: |cff40ff40compatible", 1, true) ~= nil, "diagnóstico: correo")
local anaMine
ana.ns.UI.ShowPage("mine")
anaMine = anaPanel.pageFrames.mine
H.ok(anaMine.profText:GetText():find("Alquimia", 1, true) ~= nil, "Ana ve su Alquimia publicada")
anaMine.unavailable:SetChecked(true)
anaMine.unavailable:GetScript("OnClick")(anaMine.unavailable)
H.Advance(10)
H.ok(ns.G().entries["Ana-Reino"].u == true, "Bea ve a Ana como no disponible")

-- Sin objeto elegido no se abre la ventana de petición (no se pide con mayús+clic).
dialog:Hide()
ns.UI.OpenRequestDialog({})
H.ok(not dialog:IsShown(), "sin objeto no se abre")

H.eq(#H.errors, 0, "sin errores de Lua en la interfaz")
