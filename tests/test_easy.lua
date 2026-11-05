local H = ...
-- Facilidad de uso: pedir lo que falta, "Lo hago yo" en el aviso, número en la pestaña,
-- resumen al entrar y formulario corto.
H.AddMember("Pepe")
H.AddMember("Ana")
local BLACKSMITHING = {
  name = "Herrería", rank = 300, max = 300, selected = 1,
  rows = { { name = "Coraza de torio", item = 12405, reagents = { { 4234, 4 }, { 2840, 2 } } } },
}
local LEATHERWORKING = {
  name = "Peletería", rank = 300, max = 300,
  rows = { { name = "Cuero pesado curtido", item = 4234, reagents = { { 4232, 3 } } } },
}
local ana = H.Login("Ana")
local guildFrame = ana.env.CreateFrame("Frame", "GuildFrame", ana.env.UIParent)
ana.ns.UI.AttachHost(guildFrame)
H.Advance(15)
H.OpenTradeSkill(ana, LEATHERWORKING)
H.Advance(30)
local pepe = H.Login("Pepe", { bags = { [4234] = 1 } })
H.Advance(30)

-- Pepe abre Herrería, quiere hacer 3 corazas y pide lo que le falta.
pepe.env.TradeSkillFrame = pepe.env.CreateFrame("Frame", "TradeSkillFrame")
pepe.env.TradeSkillCreateButton = pepe.env.CreateFrame("Button", "TradeSkillCreateButton", pepe.env.TradeSkillFrame)
pepe.env.TradeSkillInputBox = pepe.env.CreateFrame("EditBox", "TradeSkillInputBox", pepe.env.TradeSkillFrame)
pepe.env.TradeSkillInputBox:SetText("3")
H.OpenTradeSkill(pepe, BLACKSMITHING)
H.Advance(2)
pepe.ns.Missing.OnClick()
local popup = pepe.popups[#pepe.popups]
H.eq(popup.which, "HDFPROF_CONFIRM", "pregunta antes de pedir")
H.ok(popup.text:find("11x Objeto 4234", 1, true) and popup.text:find("6x Objeto 2840", 1, true), "cantidades exactas: " .. popup.text)
popup.data.callback()
H.Advance(10)
local leatherReq, oreReq
for _, r in pairs(pepe.ns.G().requests) do
  if r.k == "i4234" then leatherReq = r elseif r.k == "i2840" then oreReq = r end
end
H.ok(leatherReq and leatherReq.q == 11, "petición de 11 cueros")
H.ok(oreReq and oreReq.q == 6, "petición de 6 barras")
pepe.ns.Missing.OnClick()
pepe.popups[#pepe.popups].data.callback()
local count = 0
for _ in pairs(pepe.ns.G().requests) do count = count + 1 end
H.eq(count, 2, "no se piden dos veces")

-- Ana recibe el aviso con "Lo hago yo" y acepta desde ahí.
local alert = ana.env.HDFProfAlert
H.ok(alert and alert:IsShown(), "aviso a Ana")
H.ok(alert.commit:IsShown(), "el aviso tiene el botón Lo hago yo")
-- número en la pestaña: 1 (la de cuero; las barras no las sabe hacer)
H.Advance(2)
local tab = ana.env.HDFProfGuildTabGuildFrame
H.ok(tab.badge:IsShown() and tab.badge.text:GetText() == "1", "pestaña con 1 pendiente: " .. tostring(tab.badge.text:GetText()))
alert.commit:Click()
ana.popups[#ana.popups].data.callback(11)
H.Advance(10)
H.eq(pepe.ns.Data.RequestInfo(pepe.ns.G().requests[leatherReq.id], pepe.ns.Now()).state, "accepted", "aceptada desde el aviso")
H.Advance(2)
H.ok(not tab.badge:IsShown(), "ya no hay pendientes para Ana")

-- Resumen al entrar: Bea, que sabe peletería, entra y lo ve en el chat.
H.AddMember("Bea")
local bea = H.Login("Bea")
H.Advance(15)
H.OpenTradeSkill(bea, LEATHERWORKING)
local req3 = pepe.ns.Sync.CreateRequest({ k = "i4234", q = 2, to = "Bea-Reino" })
H.Advance(60)
local summary = false
for _, line in ipairs(bea.chat) do
  if line:find("que puedes hacer", 1, true) then summary = true end
end
H.ok(summary, "resumen en el chat al entrar")
H.ok(req3 ~= nil, "petición para Bea")

-- Formulario corto: sin destinatario, las opciones extra están ocultas.
pepe.ns.UI.OpenRequestDialog({ k = "i4234" })
local dialog = pepe.env.HDFProfRequestDialog
H.ok(not dialog.more:IsShown(), "formulario corto por defecto")
dialog.moreButton:Click()
H.ok(dialog.more:IsShown(), "Más opciones las muestra")
pepe.ns.UI.OpenRequestDialog({ k = "i4234", to = "Ana-Reino" })
H.ok(dialog.more:IsShown(), "con destinatario se abren solas")
dialog:Hide()
H.eq(#H.errors, 0, "sin errores de Lua")
