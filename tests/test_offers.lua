local H = ...
-- Ofertas: alguien ofrece objetos concretos, otro pulsa "Lo quiero" y se le manda por correo.
-- Y el tablón: buscar y filtrar por tipo y categoría.
H.AddMember("Ana")
H.AddMember("Bea")
H.AddMember("Cris")
H.itemClass = { [4240] = { 1, 0 }, [929] = { 0, 1 }, [2318] = { 7, 6 } } -- bolsa, poción, cuero
local ana = H.Login("Ana", { bags = { [4240] = 4 } })
local bea = H.Login("Bea")
local cris = H.Login("Cris")
H.Advance(20)
local O = ana.ns.Offers

-- Ana ofrece 4 bolsas a 1 oro cada una.
local ok = O.Create(4240, 4, 10000, ana.ns.Now())
H.ok(ok, "oferta creada")
H.ok(O.Create(nil, 1, 0, ana.ns.Now()) == nil, "sin objeto no hay oferta")
H.Advance(15)
local list = bea.ns.Offers.List(bea.ns.Now())
H.eq(#list, 1, "Bea ve la oferta")
H.ok(list[1].owner == "Ana-Reino" and list[1].q == 4 and list[1].g == 10000 and list[1].free == 4, "datos de la oferta")

-- Bea quiere 3; Ana recibe el aviso.
local pushes = {}
local push = ana.ns.Alerts.Push
ana.ns.Alerts.Push = function(a) pushes[#pushes + 1] = a.text; return push(a) end
H.ok(bea.ns.Offers.Claim(list[1].key, 3, bea.ns.Now()), "Bea lo quiere")
H.Advance(15)
ana.ns.Alerts.Push = push
H.ok(pushes[1] and pushes[1]:find("Bea quiere 3x", 1, true), "aviso a Ana: Bea quiere 3")
local cl = cris.ns.Offers.List(cris.ns.Now())[1]
H.eq(cl.free, 1, "a Cris le queda 1 libre")
H.ok(cris.ns.Offers.Claim(cl.key, 5, cris.ns.Now()), "Cris pide 5...")
H.Advance(15)
H.eq(ana.ns.Offers.List(ana.ns.Now())[1].pending, 4, "...pero solo le cuenta 1: todo pedido")
H.ok(bea.ns.Offers.Claim(cl.key, 1, bea.ns.Now()) == true, "Bea puede cambiar lo que pide")
bea.ns.Offers.Claim(cl.key, 3, bea.ns.Now())

-- Ana se lo manda por correo a Bea: se apunta solo.
local kAna, kBea = cris.ns.Data.KarmaFor("Ana-Reino"), cris.ns.Data.KarmaFor("Bea-Reino")
local bpushes = {}
local bpush = bea.ns.Alerts.Push
bea.ns.Alerts.Push = function(a) bpushes[#bpushes + 1] = a.text; return bpush(a) end
H.SendMail(ana, "Bea", { { 4240, 3 } })
H.Advance(20)
bea.ns.Alerts.Push = bpush
local after = cris.ns.Offers.List(cris.ns.Now())[1]
H.eq(after.q, 1, "a Ana le queda 1 bolsa en la oferta")
H.eq(after.pending, 1, "solo queda pendiente lo de Cris")
local beaFound = false
for _, b in ipairs(bpushes) do if b:find("te ha enviado 3x", 1, true) then beaFound = true end end
H.ok(beaFound, "aviso a Bea: te lo ha enviado")
H.eq(bea.ns.MyChar().claims[after.key], nil, "a Bea se le quita el lo quiero")
H.Advance(20)
H.eq(cris.ns.Data.KarmaFor("Ana-Reino") - kAna, 1, "Ana gana 1 de karma")
H.eq(cris.ns.Data.KarmaFor("Bea-Reino") - kBea, -1, "Bea pierde 1")

-- Un correo a quien no ha pedido nada no cuenta.
H.SendMail(ana, "Bea", { { 4240, 1 } })
H.Advance(10)
H.eq(ana.ns.Offers.List(ana.ns.Now())[1].q, 1, "a Bea ya no le debía nada: no cuenta")
-- Cris recibe la última: la oferta se acaba.
H.SendMail(ana, "Cris", { { 4240, 1 } })
H.Advance(20)
H.eq(#bea.ns.Offers.List(bea.ns.Now()), 0, "oferta agotada: desaparece")

-- Quitar una oferta.
O.Create(929, 10, 0, ana.ns.Now())
H.Advance(10)
H.eq(#bea.ns.Offers.List(bea.ns.Now()), 1, "nueva oferta de pociones")
O.Remove(929)
H.Advance(10)
H.eq(#bea.ns.Offers.List(bea.ns.Now()), 0, "quitada")

-- Tablón de Bea: pedidos y ofertas juntos, con buscador y filtros.
O.Create(4240, 2, 0, ana.ns.Now())
O.Create(929, 5, 0, ana.ns.Now())
cris.ns.Sync.CreateRequest({ k = "i2318", q = 10 })
H.Advance(20)
local env = bea.env
local gf = env.CreateFrame("Frame", "GuildFrame", env.UIParent)
bea.ns.UI.AttachHost(gf)
env.HDFProfGuildTabGuildFrame:Click()
bea.ns.UI.ShowPage("board")
local board = env.HDFProfPanel.pageFrames.board
local function kinds()
  local o, r = 0, 0
  for _, it in ipairs(board.list.items) do
    if it.kind == "offer" then o = o + 1 else r = r + 1 end
  end
  return o, r
end
local o, r = kinds()
H.ok(o == 2 and r == 1, "2 ofertas y 1 pedido: " .. o .. "/" .. r)
H.ok(board.list.rows[1].title:GetText():find("[Oferta]", 1, true) or board.list.rows[2].title:GetText():find("[Oferta]", 1, true),
  "las ofertas van marcadas")
board.showButton:Click()
o, r = kinds()
H.ok(o == 0 and r == 1, "Ver: pedidos")
board.showButton:Click()
o, r = kinds()
H.ok(o == 2 and r == 0, "Ver: ofertas")
board.showButton:Click()
board.catButton:Click()
board.catButton:Click()
board.catButton:Click() -- Bolsas
H.eq(board.catButton:GetText(), "Bolsas", "categoría: bolsas")
o, r = kinds()
H.ok(o == 1 and r == 0, "solo la bolsa")
for _ = 1, 3 do board.catButton:Click() end -- vuelta a todas
H.eq(board.catButton:GetText(), "Categoría: todas", "todas las categorías")
board.search:SetText("929")
board.search:GetScript("OnTextChanged")(board.search, true)
H.eq(#board.list.items, 1, "buscador: por nombre del objeto")
board.search:SetText("cris")
board.search:GetScript("OnTextChanged")(board.search, true)
o, r = kinds()
H.ok(o == 0 and r == 1, "buscador: por nombre de quien lo pide")
board.search:SetText("")
board.search:GetScript("OnTextChanged")(board.search, true)

-- "Lo quiero" desde el tablón.
local potRow
for _, row in ipairs(board.list.rows) do
  if row.item and row.item.kind == "offer" and row.item.o.id == 929 then potRow = row end
end
H.eq(potRow.accept:GetText(), "Lo quiero", "botón Lo quiero")
potRow.accept:Click()
bea.popups[#bea.popups].data.callback(2)
board:Refresh()
for _, row in ipairs(board.list.rows) do
  if row.item and row.item.kind == "offer" and row.item.o.id == 929 then potRow = row end
end
H.eq(potRow.accept:GetText(), "Ya no lo quiero", "se puede echar atrás")
H.ok(potRow.mats:GetText():find("Has pedido 2", 1, true), "dice lo que has pedido")

-- Ventana de ofrecer: mayús+clic en el objeto y precio con botones.
bea.ns.UI.OpenOfferDialog()
local d = env.HDFProfOfferDialog
H.ok(d:IsShown(), "ventana de ofrecer")
d.link:SetText(H.itemLink(2318))
d.link:GetScript("OnTextChanged")(d.link, true)
H.eq(d.id, 2318, "objeto elegido con mayús+clic")
d.qty:SetText("3")
d.prices[3]:Click()
H.eq(d.gold:GetText(), "1", "precio: 1 oro")
d:Publish()
H.ok(not d:IsShown(), "publicada")
H.Advance(15)
local found
for _, it in ipairs(ana.ns.Offers.List(ana.ns.Now())) do if it.id == 2318 then found = it end end
H.ok(found and found.q == 3 and found.g == 10000 and found.owner == "Bea-Reino", "Ana ve la oferta de Bea")

-- Ofrecer desde la ventana de profesión: botón "Ofrecer" en el objeto que fabrica la receta.
local TAILORING = {
  name = "Sastrería", rank = 300, max = 300, selected = 1,
  rows = { { name = "Bolsa de lana", item = 4240, reagents = { { 2592, 3 } } } },
}
local aenv = ana.env
aenv.TradeSkillFrame = aenv.CreateFrame("Frame", "TradeSkillFrame")
aenv.TradeSkillSkillIcon = aenv.CreateFrame("Button", "TradeSkillSkillIcon", aenv.TradeSkillFrame)
H.OpenTradeSkill(ana, TAILORING)
H.Advance(2)
aenv.TradeSkillSkillIcon:GetScript("OnEnter")(aenv.TradeSkillSkillIcon)
local ob = aenv.HDFProfOfferButton
H.ok(ob and ob:IsShown(), "al pasar por el objeto sale Ofrecer")
ob:Click()
local od = aenv.HDFProfOfferDialog
H.ok(od:IsShown() and od.id == 4240, "ventana de ofrecer con la bolsa ya elegida")
H.ok(not od.link:IsShown(), "sin tener que elegir el objeto")
H.ok(not od.more:IsShown(), "precio oculto (gratis por defecto)")
H.ok(od.summary:GetText():find("Gratis", 1, true), "dice Gratis")
od.qty:SetText("2")
od.plus:Click()
H.eq(od.qty:GetText(), "3", "cantidad con +")
od:Publish()
H.ok(not od:IsShown(), "ofrecida en un clic")
local mineOffer
for _, it in ipairs(ana.ns.Offers.List(ana.ns.Now())) do if it.owner == "Ana-Reino" and it.id == 4240 then mineOffer = it end end
H.ok(mineOffer and mineOffer.q == 3 and not mineOffer.g, "3 bolsas gratis")

-- Modo demostración: ofertas de ejemplo; al pedir una, te la "mandan".
bea.ns.Demo.Set(true)
local demoOffer
for _, it in ipairs(bea.ns.Offers.List(bea.ns.Now())) do if it.owner == "Tula-Demo" then demoOffer = it end end
H.ok(demoOffer ~= nil, "oferta de ejemplo")
local kBefore = bea.ns.Data.KarmaFor("Bea-Reino")
bea.ns.Offers.Claim(demoOffer.key, 1, bea.ns.Now())
H.Advance(10)
H.eq(bea.ns.MyChar().claims[demoOffer.key], nil, "la de ejemplo llega sola")
H.eq(bea.ns.Data.KarmaFor("Bea-Reino") - kBefore, -1, "a Bea le baja 1 al recibirlo")
H.ok(bea.ns.G().karma["Bea-Reino"].kc["Tula-Demo"], "apunta el karma a Tula")
bea.ns.Demo.Set(false)

H.eq(#H.errors, 0, "sin errores de Lua")
