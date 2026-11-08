local H = ...
-- Pedidos de fabricación de Blizzard (hermandad), avisos tranquilos y ventana redimensionable.
H.AddMember("Ana")
H.AddMember("Bea")
local BLACKSMITHING = {
  name = "Herrería", rank = 300, max = 300,
  rows = { { name = "Coraza de torio", item = 12405, reagents = { { 12359, 16 } } } },
}
local ana = H.Login("Ana")
local bea = H.Login("Bea")
H.Advance(15)
H.OpenTradeSkill(bea, BLACKSMITHING) -- Bea sabe hacer la coraza
H.Advance(30)

-- 1) Ana publica un pedido de fabricación de hermandad en la mesa de Blizzard.
local pushes = {}
local push = bea.ns.Alerts.Push
bea.ns.Alerts.Push = function(a) pushes[#pushes + 1] = a.text; return push(a) end
ana.ns.Orders.Record(1001, ana.ns.Now()) -- (sin API moderna, el objeto no se conoce: se usa la receta)
ana.ns.MyChar().guildOrders[1].i = 12405  -- como lo daría C_TradeSkillUI en Forever
ana.ns.Sync.PublishMine()
H.Advance(20)
bea.ns.Alerts.Push = push
local found = false
for _, t in ipairs(pushes) do if t:find("pedidos de fabricación", 1, true) then found = true end end
H.ok(found, "aviso a Bea (sabe hacerlo): pedido de fabricación de hermandad")
local list = bea.ns.Orders.List(bea.ns.Now())
H.ok(list[1] and list[1].key == "i12405" and list[1].owner == "Ana-Reino", "Bea ve el pedido")
local env = bea.env
local gf = env.CreateFrame("Frame", "GuildFrame", env.UIParent)
bea.ns.UI.AttachHost(gf)
env.HDFProfGuildTabGuildFrame:Click()
bea.ns.UI.ShowPage("board")
local board = env.HDFProfPanel.pageFrames.board
board:Refresh()
local row
for _, r in ipairs(board.list.rows) do if r.item and r.item.kind == "co" then row = r end end
H.ok(row and row.title:GetText():find("[Pedido de Blizzard]", 1, true), "en el Tablón como [Pedido de Blizzard]")
H.ok(row.title:GetText():find("puedes hacerlo", 1, true), "marcado: puedes hacerlo")
row.accept:Click()
H.eq(#bea.ns.Orders.List(bea.ns.Now()), 0, "Ocultar lo quita del Tablón")
-- Al día siguiente ya no sale.
H.eq(#ana.ns.Orders.List(ana.ns.Now() + 25 * 3600), 0, "caduca a las 24 h")

-- 2) Avisos tranquilos: no se repite el mismo aviso; "No molestar" los guarda.
local A = bea.ns.Alerts
local alert = env.HDFProfAlert
A.HideCurrent()
H.Advance(1)
A.Push({ text = "Aviso de prueba" })
H.ok(alert:IsShown() and alert.text:GetText() == "Aviso de prueba", "sale el aviso")
A.HideCurrent()
H.Advance(1)
A.Push({ text = "Aviso de prueba" })
H.ok(not alert:IsShown(), "el mismo aviso no se repite en 10 minutos")
A.SetQuiet(2, bea.ns.Now()) -- 1 hora
H.ok(A.IsQuiet(), "No molestar activado")
A.Push({ text = "Durante no molestar" })
H.ok(not alert:IsShown(), "con No molestar no sale")
A.SetQuiet(1, bea.ns.Now()) -- quitarlo
H.Advance(2)
H.ok(alert:IsShown() and alert.text:GetText() == "Durante no molestar", "al quitarlo, sale lo guardado")

-- 3) Ventana: tamaño y posición recordados; clic derecho en el asa, por defecto.
local panel = env.HDFProfPanel
H.ok(panel.grip ~= nil, "asa para cambiar el tamaño")
bea.ns.UI.SetScale(1.3)
H.eq(panel:GetScale(), 1.3, "más grande")
bea.ns.UI.SetScale(5)
H.eq(panel:GetScale(), 1.6, "con un máximo")
panel:ClearAllPoints()
panel:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 100, -50)
bea.ns.UI.SavePosition()
local pos = bea.ns.db.settings.panelPos
H.ok(pos and pos[1] == "TOPLEFT" and pos[3] == 100, "recuerda dónde la dejaste")
panel:Hide()
bea.ns.UI.Open("board")
local point, _, _, x = panel:GetPoint(1)
H.ok(point == "TOPLEFT" and x == 100, "al volver a abrirla, en el mismo sitio")
panel.grip:GetScript("OnMouseUp")(panel.grip, "RightButton")
H.ok(bea.ns.db.settings.panelPos == nil and panel:GetScale() == 1, "clic derecho: tamaño y posición por defecto")

H.eq(#H.errors, 0, "sin errores de Lua")
