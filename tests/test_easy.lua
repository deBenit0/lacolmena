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
local picker = pepe.env.HDFProfMissingDialog
H.ok(picker and picker:IsShown(), "se abre la ventana para elegir qué pedir")
H.eq(picker.times, 3, "toma las veces de la ventana de profesión")
local rowLeather, rowBars = picker.rows[1], picker.rows[2]
H.eq(rowLeather.data.id, 4234, "fila 1: cuero")
H.eq(rowLeather.qty:GetText(), "11", "faltan 11 cueros (4x3 - 1)")
H.ok(rowLeather.check:GetChecked(), "cuero marcado: lo da la hermandad")
H.ok(rowLeather.note:GetText():find("Peletería", 1, true), "nota: lo da Peletería: " .. rowLeather.note:GetText())
H.eq(rowBars.qty:GetText(), "6", "faltan 6 barras")
H.ok(not rowBars.check:GetChecked(), "barras sin marcar: nadie las da")
H.ok(rowBars.note:GetText():find("vendedor", 1, true), "nota: ¿vendedor?")
picker:Submit()
H.ok(not picker:IsShown(), "se cierra al pedir")
H.Advance(10)
local leatherReq, oreReq
for _, r in pairs(pepe.ns.G().requests) do
  if r.k == "i4234" then leatherReq = r elseif r.k == "i2840" then oreReq = r end
end
H.ok(leatherReq and leatherReq.q == 11, "petición de 11 cueros")
H.ok(oreReq == nil, "las barras de vendedor no se piden")
local alert = ana.env.HDFProfAlert
H.ok(alert and alert:IsShown(), "aviso a Ana")
H.ok(alert.commit:IsShown(), "el aviso tiene el botón Lo hago yo")

-- Ahora quiere hacer 4: se amplía la petición de cuero en vez de crear otra.
pepe.ns.Missing.OnClick()
picker:SetTimes(4)
H.eq(rowLeather.qty:GetText(), "15", "con 4 veces faltan 15")
H.ok(rowLeather.note:GetText():find("se amplía a 15", 1, true), "nota: se amplía")
picker:Submit()
H.Advance(10)
local count = 0
for _ in pairs(pepe.ns.G().requests) do count = count + 1 end
H.eq(count, 1, "sigue habiendo una sola petición")
H.eq(pepe.ns.G().requests[leatherReq.id].q, 15, "ampliada a 15")
H.Advance(10)
H.eq(ana.ns.G().requests[leatherReq.id].q, 15, "Ana ve la petición ampliada")

-- Ana recibe el aviso con "Lo hago yo" y acepta desde ahí.
-- número en la pestaña: 1 (la de cuero; las barras no las sabe hacer)
H.Advance(2)
local tab = ana.env.HDFProfGuildTabGuildFrame
H.ok(tab.badge:IsShown() and tab.badge.text:GetText() == "1", "pestaña con 1 pendiente: " .. tostring(tab.badge.text:GetText()))
alert.commit:Click()
local choice = ana.env.HDFProfChoice
H.ok(choice and choice:IsShown(), "pregunta cuándo lo tendrá")
H.eq(choice.buttons[1]:GetText(), "Lo hago ya", "botón Lo hago ya")
H.eq(choice.buttons[2]:GetText(), "Antes de 2 horas", "botón Antes de 2 horas")
H.eq(choice.buttons[3]:GetText(), "Lo hago hoy", "botón Lo hago hoy")
choice.buttons[2]:Click()
H.Advance(10)
H.eq(pepe.ns.Data.RequestInfo(pepe.ns.G().requests[leatherReq.id], pepe.ns.Now()).state, "accepted", "aceptada desde el aviso")
H.Advance(2)
H.ok(not tab.badge:IsShown(), "ya no hay pendientes para Ana")

-- Resumen al entrar: Bea, que sabe peletería, entra y lo ve en el chat.
H.AddMember("Bea")
local bea = H.Login("Bea")
H.Advance(15)
H.OpenTradeSkill(bea, LEATHERWORKING)
local req3 = pepe.ns.Sync.CreateRequest({ k = "i4234", q = 2 })
H.Advance(60)
local summary = false
for _, line in ipairs(bea.chat) do
  if line:find("que puedes hacer", 1, true) then summary = true end
end
H.ok(summary, "resumen en el chat al entrar")
H.ok(req3 ~= nil, "petición para Bea")

-- Formulario: prisa y propina con botones; sin precio de subasta ni destinatario.
pepe.ns.UI.OpenRequestDialog({ k = "i4234" })
local dialog = pepe.env.HDFProfRequestDialog
H.eq(dialog.rush[2]:GetText(), "Ya", "prisa: Ya")
H.eq(dialog.rush[3]:GetText(), "Antes de 2 horas", "prisa: Antes de 2 horas")
H.eq(dialog.rush[4]:GetText(), "Hoy", "prisa: Hoy")
dialog.rush[4]:Click()
H.eq(dialog.pr, 3, "prisa elegida: hoy")
dialog.tips[3]:Click()
H.eq(dialog.gold:GetText(), "1", "propina sugerida: 1 oro")
dialog.tips[2]:Click()
H.eq(dialog.gold:GetText() .. "/" .. dialog.silver:GetText(), "/50", "propina sugerida: 50 plata")
dialog.gold:SetText("3")
dialog.silver:SetText("")
dialog:Publish()
local last
for _, r in pairs(pepe.ns.G().requests) do
  if not last or r.t > last.t or (r.t == last.t and r.id > last.id) then last = r end
end
H.ok(last and last.g == 30000 and last.pr == 3 and last.to == nil, "pedido con propina 3 oro y prisa hoy, para toda la hermandad")
H.eq(#H.errors, 0, "sin errores de Lua")
