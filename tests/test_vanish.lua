local H = ...
-- "Los pedidos desaparecen solos": que un pedido propio no se esconda ni se borre.
H.AddMember("Ana")
H.AddMember("Bea")
local ana = H.Login("Ana")
H.Login("Bea")
H.Advance(20)
local ns, env = ana.ns, ana.env
local gf = env.CreateFrame("Frame", "GuildFrame", env.UIParent)
ns.UI.AttachHost(gf)
env.HDFProfGuildTabGuildFrame:Click()
ns.UI.ShowPage("board")
local board = env.HDFProfPanel.pageFrames.board

-- 1) Con "Solo mis profesiones" y un filtro de categoría puestos, publico un pedido: se ve.
board.onlyMine:SetChecked(true)
board.onlyMine:GetScript("OnClick")(board.onlyMine)
ns.db.settings.board.cat = 3 -- "Pociones y comida": el pedido es de un material
ns.UI.OpenRequestDialog({ k = "i2840", q = 5 })
env.HDFProfRequestDialog:Publish()
board:Refresh()
local found = false
for _, it in ipairs(board.list.items) do if it.kind == "req" and it.r.k == "i2840" then found = true end end
H.ok(found, "mi pedido nuevo se ve aunque esté marcado Solo mis profesiones")
H.eq(ns.db.settings.board.cat, 1, "al publicar se quita el filtro de categoría")

-- 2) Si la lista de la hermandad trae los nombres en otro formato (no me encuentra a mí),
--    la limpieza no borra nada.
local myReq
for id, r in pairs(ns.G().requests) do if r.a == ns.Me() then myReq = id end end
local roster = ns.Guild.roster
local saved = {}
for name, info in pairs(roster) do saved[name] = info end
for name in pairs(saved) do roster[name] = nil end
roster["Ana-Otro Reino"] = { online = true } -- yo, pero con el reino escrito distinto
roster["Bea-Otro Reino"] = { online = true }
ns.Guild.full = true
H.FireEvent(ana, "GUILD_ROSTER_UPDATE")
ns.Guild.Refresh = ns.Guild.Refresh -- (la limpieza se llama al refrescar; aquí la forzamos)
for k in pairs(roster) do roster[k] = nil end
for name, info in pairs(saved) do roster[name] = info end
roster["Ana-Reino"] = nil -- la lista no me tiene a mí
ns.Guild.full = true
H.Advance(2)
H.ok(ns.G().requests[myReq] ~= nil, "mi pedido sigue aunque la lista de la hermandad no me encuentre")

H.eq(#H.errors, 0, "sin errores de Lua")
