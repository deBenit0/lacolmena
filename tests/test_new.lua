local H = ...
-- Modo demostración, "Pedir" sobre un material y contra reembolso.
H.AddMember("Pepe")
H.AddMember("Ana")
local BLACKSMITHING = {
  name = "Herrería", rank = 300, max = 300, selected = 1,
  rows = { { name = "Coraza de torio", item = 12405, reagents = { { 4234, 4 }, { 2840, 2 } } } },
}
H.itemClass = { [4234] = { 7, 6 }, [2840] = { 7, 7 } }
local pepe = H.Login("Pepe", { bags = { [4234] = 1 } })
local ana = H.Login("Ana")
H.Advance(15)
local penv = pepe.env
penv.TradeSkillFrame = penv.CreateFrame("Frame", "TradeSkillFrame")
penv.TradeSkillInputBox = penv.CreateFrame("EditBox", "TradeSkillInputBox", penv.TradeSkillFrame)
penv.TradeSkillInputBox:SetText("2")
local slot = penv.CreateFrame("Button", "TradeSkillReagent1", penv.TradeSkillFrame)
slot:SetID(1)
H.OpenTradeSkill(pepe, BLACKSMITHING)
H.Advance(30)

-- 1) Modo demostración: solo para mí.
local ns = pepe.ns
ns.Demo.Set(true)
local demoEntries, demoRequests = 0, 0
for name, e in pairs(ns.G().entries) do
  if e.demo then demoEntries = demoEntries + 1 end
end
for _, r in pairs(ns.G().requests) do
  if r.demo then demoRequests = demoRequests + 1 end
end
H.ok(demoEntries >= 27, "jugadores de ejemplo: " .. demoEntries)
H.ok(demoRequests >= 10, "peticiones de ejemplo: " .. demoRequests)
local digest = ns.Sync.BuildDigest()
local leaked = false
for name in pairs(digest.e) do if name:find("Demo", 1, true) then leaked = true end end
H.ok(not leaked, "los de ejemplo no van en el resumen")
H.Advance(60)
local anaSees = false
for name in pairs(ana.ns.G().entries) do if name:find("-Demo", 1, true) then anaSees = true end end
H.ok(not anaSees, "Ana no recibe los datos de ejemplo")
-- La página de materiales muestra lo que usan mis recetas y dan los de ejemplo.
ns.UI.Open("materials")
local mats = penv.HDFProfPanel.pageFrames.materials
local keys = {}
for _, item in ipairs(mats.list.items) do if not item.header then keys[item.key] = true end end
H.ok(keys.i4234 and keys.i2840, "materiales de mi coraza: cuero (Peletería) y barra de cobre (Minería)")
H.ok(penv.HDFProfPanel.title:GetText():find("DEMOSTRACIÓN", 1, true), "el título avisa del modo demostración")
-- Peticiones de ejemplo para mí: aceptar, "enviar" y ver subir el karma.
local mineReq = ns.G().requests["Bruno-Demo:tuya1"]
H.ok(mineReq and mineReq.k == "i12405" and mineReq.pr == 1, "petición de ejemplo con algo que sé hacer (y prisa)")
H.ok(ns.Data.CanServe(mineReq, ns.Now()), "puedo atenderla")
ns.UI.Open("board")
local board = penv.HDFProfPanel.pageFrames.board
local firstReq
for _, it in ipairs(board.list.items) do if it.kind == "req" and not firstReq then firstReq = it end end
H.eq(firstReq.r.id, mineReq.id, "en el tablón, el primer pedido es el que corre prisa y puedo hacer")
H.eq(board.list.items[1].kind, "need", "y antes, los pedidos de la hermandad")
H.ok(#board.list.items >= 10, "el tablón muestra los pedidos de ejemplo: " .. #board.list.items)
local anyNew = false
for _, it in ipairs(board.list.items) do if it.new then anyNew = true end end
H.ok(anyNew, "la primera vez, los pedidos salen como nuevos")
ns.UI.ShowPage("materials")
H.ok(ns.G().boardSeen ~= nil, "al salir del tablón se apunta la visita")
H.Advance(1)
ns.UI.ShowPage("board")
anyNew = false
for _, it in ipairs(board.list.items) do if it.new then anyNew = true end end
H.ok(not anyNew, "al volver ya no son nuevos")
board.onlyMine:SetChecked(true)
board.onlyMine:GetScript("OnClick")(board.onlyMine)
for _, it in ipairs(board.list.items) do H.ok(it.canServe, "filtro: solo las que puedo hacer") end
H.ok(ns.db.settings.board.onlyMine, "el filtro Solo mis profesiones se recuerda")
board.onlyMine:SetChecked(false)
board.onlyMine:GetScript("OnClick")(board.onlyMine)
local alert = penv.HDFProfAlert -- ya salió (y se cerró solo) al activar el modo
H.ok(alert and alert.alert and alert.alert.id == mineReq.id and alert.text:GetText():find("(ya)", 1, true),
  "salta el aviso de la petición de ejemplo")
alert.commit:Click()
penv.HDFProfChoice.buttons[1]:Click()
H.ok(mineReq.c and mineReq.c[ns.Me()] and mineReq.c[ns.Me()].n == mineReq.q, "aceptada")
-- En el tablón sale arriba como "Tu encargo" con el botón de enviar y si tengo los materiales.
board:Refresh()
H.eq(board.list.items[1].r.id, mineReq.id, "mi encargo arriba del tablón")
H.ok(board.list.rows[1].title:GetText():find("[Tu encargo]", 1, true), "marcado como tu encargo")
H.eq(board.list.rows[1].accept:GetText(), "Enviar (ejemplo)", "botón de enviar en el tablón")
H.ok(board.list.rows[1].mats:GetText():find("Te faltan", 1, true), "dice qué materiales me faltan: " .. board.list.rows[1].mats:GetText())
ns.UI.Open("requests", mineReq.id)
local reqPage = penv.HDFProfPanel.pageFrames.requests
H.eq(reqPage.detail.b3:GetText(), "Enviar (ejemplo)", "botón para simular el envío")
local karmaBefore = ns.Data.KarmaFor(ns.Me())
reqPage.detail.b3:Click()
H.eq(ns.Data.RequestInfo(mineReq, ns.Now()).state, "done", "enviada: la petición se completa")
H.Advance(5)
H.ok(ns.Data.KarmaFor(ns.Me()) > karmaBefore, "sube mi karma al recibirlo el de ejemplo")
H.Advance(30)
local anaLeak = false
for id in pairs(ana.ns.G().requests) do if id:find("Demo", 1, true) then anaLeak = true end end
H.ok(not anaLeak, "las peticiones de ejemplo no salen de mi ordenador")
ns.Demo.Set(false)
local left = 0
for _, e in pairs(ns.G().entries) do if e.demo then left = left + 1 end end
H.eq(left, 0, "al quitarlo no queda nada de ejemplo")

-- 2) "Pedir" al pasar el ratón por un material.
slot:GetScript("OnEnter")(slot)
local hb = penv.HDFProfReagentAsk
H.ok(hb and hb:IsShown(), "aparece el botón Pedir sobre el material")
hb:Click()
local dialog = penv.HDFProfRequestDialog
H.ok(dialog:IsShown() and dialog.key == "i4234", "abre la petición de cuero")
H.eq(dialog.qty:GetText(), "7", "lo que falta: 4x2 - 1")
dialog:Hide()

-- 3) Contra reembolso al preparar el correo.
local req = ns.Sync.CreateRequest({ k = "i4234", q = 10, g = 9000 })
H.Advance(10)
ana.ns.Sync.Commit(req.id, 1)
H.Advance(10)
-- Buzón como el de Classic: sin objetos, "Contra reembolso" está desactivado y se
-- envía dinero; al adjuntar objetos se puede marcar el reembolso.
local aenv = ana.env
local mail = { money = 0, items = 0, mode = 1 }
aenv.MailFrame = aenv.CreateFrame("Frame", "MailFrame")
aenv.SendMailNameEditBox = aenv.CreateFrame("EditBox", "SendMailNameEditBox")
aenv.SendMailMoney = aenv.CreateFrame("Frame", "SendMailMoney")
local codButton = aenv.CreateFrame("CheckButton", "SendMailCODButton")
aenv.SendMailCODButton = codButton
codButton.GetChecked = function() return mail.mode == 2 end
codButton.IsEnabled = function() return mail.items > 0 end
codButton.Click = function() if mail.items > 0 then mail.mode = 2 end end
aenv.SendMailRadioButton_OnClick = function(i) mail.mode = i end
aenv.HasSendMailItem = function(i) return i <= mail.items end
aenv.MoneyInputFrame_SetCopper = function(_, c) mail.money = c end
aenv.MoneyInputFrame_GetCopper = function() return mail.money end
local function attach(n)
  mail.items = n
  if n == 0 then mail.mode = 1 end -- el juego vuelve a "Enviar dinero"
  H.FireEvent(ana, "MAIL_SEND_INFO_UPDATE")
  H.Advance(0.1)
end
local areq = ana.ns.G().requests[req.id]
ana.ns.Mail.Prepare(areq, 4)
H.eq(aenv.SendMailNameEditBox:GetText(), "Pepe", "destinatario")
H.eq(mail.money, 0, "sin objetos no se pone dinero (se regalaría)")
H.eq(mail.mode, 1, "sigue en Enviar dinero mientras no hay objetos")
attach(1)
H.eq(mail.mode, 2, "al adjuntar objetos: Contra reembolso")
H.eq(mail.money, 3600, "contra reembolso proporcional: 9000 x 4/10")
attach(0)
H.eq(mail.money, 0, "si se quitan los objetos, se quita la cantidad (nunca se regala)")
attach(2)
H.ok(mail.mode == 2 and mail.money == 3600, "al volver a adjuntar, otra vez reembolso")
-- Si cambia el destinatario, el addon deja de tocar el correo.
aenv.SendMailNameEditBox:SetText("Otro")
mail.money, mail.mode = 0, 1
attach(1)
H.ok(mail.money == 0 and mail.mode == 1, "otro destinatario: no toca nada")
H.eq(#H.errors, 0, "sin errores de Lua")
