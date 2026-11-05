local H = ...
-- Modo demostración, "Pedir" sobre un material, contra reembolso y precios de subasta.
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

-- 3) Precios: los apunta al mirar la subasta y Auctionator manda si está.
penv.GetNumAuctionItems = function() return 2 end
penv.GetAuctionItemInfo = function(_, i)
  if i == 1 then return "Cuero", "", 5, 1, true, 1, nil, 0, 0, 5000, 0, nil, nil, "X", nil, 0, 4234 end
  return "Cuero", "", 2, 1, true, 1, nil, 0, 0, 1800, 0, nil, nil, "Y", nil, 0, 4234
end
H.FireEvent(pepe, "AUCTION_ITEM_LIST_UPDATE")
H.Advance(1)
local unit, source = ns.Prices.Get(4234)
H.eq(unit, 900, "la venta más barata por unidad: 1800/2")
H.eq(source, "subasta", "fuente: subasta")
H.eq((ns.Prices.Suggest(4234, 10)), 8100, "oferta por 10: 9000 menos un 10%")
penv.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function() return 1200 end } } }
unit, source = ns.Prices.Get(4234)
H.ok(unit == 1200 and source == "Auctionator", "con Auctionator usa su precio")

-- 4) Contra reembolso al preparar el correo.
local req = ns.Sync.CreateRequest({ k = "i4234", q = 10, g = 9000 })
H.Advance(10)
ana.ns.Sync.Commit(req.id, 10)
H.Advance(10)
local aenv, cod = ana.env, nil
aenv.MailFrame = aenv.CreateFrame("Frame", "MailFrame")
aenv.SendMailNameEditBox = aenv.CreateFrame("EditBox", "SendMailNameEditBox")
aenv.SendMailCODButton = aenv.CreateFrame("CheckButton", "SendMailCODButton")
aenv.SendMailMoney = aenv.CreateFrame("Frame", "SendMailMoney")
aenv.MoneyInputFrame_SetCopper = function(_, c) cod = c end
local areq = ana.ns.G().requests[req.id]
ana.ns.Mail.Prepare(areq, 4)
H.eq(aenv.SendMailNameEditBox:GetText(), "Pepe", "destinatario")
H.eq(cod, 3600, "contra reembolso proporcional: 9000 x 4/10")
H.eq(#H.errors, 0, "sin errores de Lua")
