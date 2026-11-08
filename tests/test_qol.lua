local H = ...
-- Calidad de vida: tooltip "lo dan", comercio en mano, bienvenida a nuevos y resumen al entrar.
H.AddMember("Ana")
H.AddMember("Bea")
H.AddMember("Cris")
for _, m in ipairs(H.roster) do if m.name == "Ana" or m.name == "Bea" then m.rankIndex = 1 end end -- oficiales
H.itemClass = { [2840] = { 7, 7 } }
local ALCHEMY = {
  name = "Minería", rank = 300, max = 300,
  rows = { { name = "Barra de cobre", item = 2840, reagents = { { 2770, 1 } } } },
}
local ana = H.Login("Ana", { bags = { [2840] = 10 } })
local bea = H.Login("Bea")
local cris = H.Login("Cris")
H.Advance(15)
H.OpenTradeSkill(ana, ALCHEMY)
H.Advance(40)

-- 1) Tooltip: quién lo da.
local line = cris.ns.QoL.TooltipLines(2840)
H.ok(line and line:find("Ana", 1, true), "tooltip: la barra la da Ana")
H.eq(cris.ns.QoL.TooltipLines(99999), nil, "si nadie lo da, no añade nada")
local tip = cris.env.GameTooltip
local added
tip.AddLine = function(_, text) added = text end
tip.GetItem = function() return "Barra", H.itemLink(2840) end
local script = tip:GetScript("OnTooltipSetItem")
H.ok(script ~= nil, "enganchado al tooltip de objetos")
script(tip)
H.ok(added and added:find("Ana", 1, true), "la línea sale en el tooltip")

-- 2) Comercio en mano: Ana acepta un pedido de Cris y se lo da comerciando.
local req = cris.ns.Sync.CreateRequest({ k = "i2840", q = 5 })
H.Advance(10)
ana.ns.Sync.Commit(req.id, 1)
H.Advance(10)
local env = ana.env
env.ERR_TRADE_COMPLETE = "Comercio completado."
env.GetUnitName = function() return "Cris" end
env.GetTradePlayerItemInfo = function(i)
  if i == 1 then return "Barra", nil, 5, 1, nil, false, false, 2840 end
end
H.FireEvent(ana, "TRADE_SHOW")
H.FireEvent(ana, "TRADE_PLAYER_ITEM_CHANGED", 1)
H.FireEvent(ana, "TRADE_ACCEPT_UPDATE", 1, 1)
H.FireEvent(ana, "TRADE_CLOSED")
H.FireEvent(ana, "UI_INFO_MESSAGE", 0, "Comercio completado.") -- llega justo después de cerrarse
H.Advance(15)
H.eq(cris.ns.Data.RequestInfo(cris.ns.G().requests[req.id], cris.ns.Now()).state, "done",
  "el pedido se completa al comerciar en mano")
-- Un comercio cancelado no cuenta.
local req2 = cris.ns.Sync.CreateRequest({ k = "i2840", q = 5 })
H.Advance(10)
ana.ns.Sync.Commit(req2.id, 1)
H.Advance(10)
H.FireEvent(ana, "TRADE_SHOW")
H.FireEvent(ana, "TRADE_ACCEPT_UPDATE", 1, 0)
H.FireEvent(ana, "TRADE_CLOSED")
H.Advance(5)
H.FireEvent(ana, "UI_INFO_MESSAGE", 0, "Comercio completado.")
H.Advance(10)
H.eq(cris.ns.Data.RequestInfo(cris.ns.G().requests[req2.id], cris.ns.Now()).delivered, 0, "comercio cancelado: no cuenta")

-- 3) Bienvenida: se une Dani. Avisa a los oficiales; solo Ana (la primera por nombre) susurra.
local whispers = {}
for _, c in ipairs({ ana, bea, cris }) do
  c.env.ERR_GUILD_JOIN_S = "%s se ha unido a la hermandad."
  c.env.SendChatMessage = function(text, kind, _, to) whispers[#whispers + 1] = { from = c.name, text = text, kind = kind, to = to } end
end
local pushes = {}
local push = bea.ns.Alerts.Push
bea.ns.Alerts.Push = function(a) pushes[#pushes + 1] = a.text; return push(a) end
for _, c in ipairs({ ana, bea, cris }) do H.FireEvent(c, "CHAT_MSG_SYSTEM", "Dani se ha unido a la hermandad.") end
H.Advance(10)
bea.ns.Alerts.Push = push
H.ok(pushes[1] and pushes[1]:find("Dani se ha unido", 1, true), "aviso al oficial: Dani se ha unido")
H.eq(#whispers, 1, "un solo susurro de bienvenida")
H.ok(whispers[1] and whispers[1].from == "Ana" and whispers[1].to == "Dani" and whispers[1].kind == "WHISPER",
  "lo manda Ana a Dani")
H.ok(whispers[1].text:find("HDFprofesiones", 1, true), "le dice que instale el addon")

-- 4) Resumen al entrar: lo que ha pasado desde "since".
local since = cris.ns.Now()
H.Advance(5)
local req3 = cris.ns.Sync.CreateRequest({ k = "i2840", q = 2 })
H.Advance(10)
ana.ns.Sync.Commit(req3.id, 1)
ana.ns.Social.SetAnnouncement("Reunión el viernes", ana.ns.Now())
H.Advance(15)
local lines = cris.ns.QoL.Summary(since, cris.ns.Now())
local text = table.concat(lines, "\n")
H.ok(text:find("Ana aceptó tu pedido", 1, true), "resumen: Ana aceptó tu pedido")
H.ok(text:find("Reunión el viernes", 1, true), "resumen: el anuncio nuevo")
local f = cris.ns.QoL.ShowSummary(lines, since)
H.ok(f and f:IsShown() and f.title:GetText():find("mientras no estabas", 1, true), "ventanita del resumen")

H.eq(#H.errors, 0, "sin errores de Lua")
