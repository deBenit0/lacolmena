local H = ...
-- Recetas que faltan, anunciar en el chat, mis estadísticas, y que no vuelvan los fallos
-- encontrados en la revisión (karma propio, versiones del futuro, otro PC).
H.AddMember("Ana")
H.AddMember("Bea")
H.AddMember("Cris")
local MINING = {
  name = "Minería", rank = 300, max = 300,
  rows = { { name = "Barra de cobre", item = 2840, reagents = { { 2770, 1 } } } },
}
local ana = H.Login("Ana")
local bea = H.Login("Bea")
local cris = H.Login("Cris")
H.Advance(30)

-- 1) Recetas que faltan: Ana pide algo que nadie hace; cuando Bea aprende la receta, aviso a Ana.
local req = ana.ns.Sync.CreateRequest({ k = "i2840", q = 3 })
H.Advance(15)
local missing = cris.ns.Extras.MissingRecipes(cris.ns.Now())
H.ok(missing[1] and missing[1].key == "i2840" and missing[1].askers[1] == "Ana-Reino", "falta la barra (la pide Ana)")
ana.ns.Extras.CheckLearned() -- recuerda lo que falta ahora
local pushes = {}
local push = ana.ns.Alerts.Push
ana.ns.Alerts.Push = function(a) pushes[#pushes + 1] = a.text; return push(a) end
H.OpenTradeSkill(bea, MINING)
H.Advance(30)
ana.ns.Alerts.Push = push
local ok = false
for _, t in ipairs(pushes) do if t:find("ya sabe hacer", 1, true) then ok = true end end
H.ok(ok, "aviso a Ana: Bea ya sabe hacerlo")
H.eq(#cris.ns.Extras.MissingRecipes(cris.ns.Now()), 0, "ya no falta")

-- 2) Anunciar en el chat de hermandad, como mucho una vez por minuto.
local sent = {}
ana.env.C_ChatInfo.SendChatMessage = function(text, kind) sent[#sent + 1] = { text = text, kind = kind } end
H.ok(ana.ns.Extras.Announce("request", req, req.id), "anunciado")
H.eq(sent[1] and sent[1].kind, "GUILD", "en el canal de hermandad")
H.ok(sent[1].text:find("Pido 3x", 1, true), "con lo que pide: " .. sent[1].text)
H.ok(not ana.ns.Extras.Announce("request", req, req.id), "no se repite enseguida")
H.Advance(61)
H.ok(ana.ns.Extras.Announce("request", req, req.id), "al minuto, sí")

-- 3) Mis estadísticas: Bea entrega por correo y Ana lo recibe.
bea.ns.Sync.Commit(req.id, 1)
H.Advance(10)
H.SendMail(bea, "Ana", { { 2840, 3 } })
H.Advance(20)
local st = bea.ns.Extras.Stats(bea.ns.Now())
H.eq(st.this.delivered, 1, "Bea: 1 pedido entregado esta semana")
H.eq(st.total.delivered, 1, "y en total")
H.eq(ana.ns.Extras.Stats(ana.ns.Now()).this.received, 1, "Ana: 1 cosa recibida")

-- 4) Que no vuelvan los fallos de la revisión.
-- 4a) Nadie se da karma a sí mismo.
local ce = cris.ns.G().entries["Cris-Reino"]
ce.kc = { ["Cris-Reino"] = 5000000 }
H.eq(bea.ns.Data.KarmaFor("Cris-Reino") - 0, bea.ns.Data.KarmaFor("Cris-Reino"), "(sin errores)")
bea.ns.G().entries["Cris-Reino"].kc = { ["Cris-Reino"] = 5000000 }
H.eq(bea.ns.Data.KarmaFor("Cris-Reino"), 0, "darse karma a uno mismo no cuenta")
-- 4b) Una versión del futuro se rechaza (no se puede bloquear para siempre un dato ajeno).
local fake = ana.ns.Codec.Deserialize(ana.ns.Codec.Serialize(ana.ns.G().requests[req.id]))
fake.x, fake.av = ana.ns.Now(), ana.ns.Now() + 10 ^ 6
cris.ns.Comm.Send("Q", fake.id .. "~" .. cris.ns.Data.RequestHash(fake) .. "~" .. cris.ns.Codec.Serialize(fake), "GUILD")
H.Advance(10)
H.ok(not ana.ns.G().requests[req.id].x, "una versión del futuro no cierra el pedido de otro")
-- 4c) Entrar desde otro ordenador (sin datos) no borra el karma que diste.
local kBea = cris.ns.Data.KarmaFor("Bea-Reino")
H.ok(kBea >= 1, "Bea tiene karma por la entrega")
H.Advance(3 * 86400)
H.Logout(ana)
H.Advance(5)
H.Login("Ana") -- base de datos vacía: otro PC
H.Advance(60)
H.eq(cris.ns.Data.KarmaFor("Bea-Reino"), kBea, "tras entrar Ana desde otro PC, Bea conserva su karma")

H.eq(#H.errors, 0, "sin errores de Lua")
