local H = ...
-- Caso principal: un herrero pide cuero, un peletero lo acepta y se lo manda por correo.
H.AddMember("Pepe")  -- herrero
H.AddMember("Ana")   -- peletera
H.AddMember("Bea")   -- peletera

local LEATHERWORKING = {
  name = "Peletería", rank = 300, max = 300,
  rows = { { name = "Cuero pesado curtido", item = 4234, reagents = { { 4232, 3 } } } },
}
local pepe = H.Login("Pepe")
local ana = H.Login("Ana")
local bea = H.Login("Bea")
H.Advance(15)
H.OpenTradeSkill(ana, LEATHERWORKING)
H.OpenTradeSkill(bea, LEATHERWORKING)
H.Advance(60)

-- Pepe pide 20 cueros: les avisa a las dos peleteras.
local req = pepe.ns.Sync.CreateRequest({ k = "i4234", q = 20, g = 30000 })
H.Advance(10)
H.ok(ana.ns.G().alerted[req.id] and bea.ns.G().alerted[req.id], "avisa a las peleteras")

-- Un correo sin haber aceptado no cuenta.
H.SendMail(bea, "Pepe", { { 4234, 5 } })
H.Advance(10)
H.eq(pepe.ns.Data.RequestInfo(pepe.ns.G().requests[req.id], pepe.ns.Now()).delivered, 0, "sin aceptar, el correo no cuenta")

-- Ana acepta y manda 12 (y otra cosa que no tiene nada que ver), escribiendo el nombre en minúsculas.
ana.ns.Sync.Commit(req.id, 20)
H.Advance(10)
H.SendMail(ana, "pepe", { { 4234, 12 }, { 9999, 3 } })
H.Advance(10)
local info = pepe.ns.Data.RequestInfo(pepe.ns.G().requests[req.id], pepe.ns.Now())
H.eq(info.delivered, 12, "Pepe ve 12 enviadas por correo")
H.eq(info.state, "accepted", "sigue aceptada (faltan 8)")
H.ok(pepe.env.HDFProfAlert and pepe.env.HDFProfAlert.text:GetText():find("por correo", 1, true), "aviso a Pepe: te lo han enviado")

-- Un correo que falla no cuenta.
H.SendMail(ana, "Pepe", { { 4234, 8 } }, false)
H.Advance(10)
H.eq(pepe.ns.Data.RequestInfo(pepe.ns.G().requests[req.id], pepe.ns.Now()).delivered, 12, "correo fallido: no cuenta")

-- Pepe se desconecta; Ana manda los 8 que faltan. La petición se completa sola.
local pepeDB = H.Logout(pepe)
H.SendMail(ana, "Pepe", { { 4234, 10 } }) -- manda de más: solo cuenta lo que prometió
H.Advance(10)
local beaReq = bea.ns.G().requests[req.id]
H.eq(bea.ns.Data.RequestInfo(beaReq, bea.ns.Now()).state, "done", "hecha sin que Pepe confirme nada")
H.eq(ana.ns.G().requests[req.id].c["Ana-Reino"].s, 20, "cuenta 20, no 22")

-- Pepe vuelve: ve la petición hecha y suma el encargo de Ana, que llega a todos.
pepe = H.Login("Pepe", { savedDB = pepeDB })
H.Advance(60)
H.eq(pepe.ns.Data.RequestInfo(pepe.ns.G().requests[req.id], pepe.ns.Now()).state, "done", "Pepe la ve hecha al volver")
H.eq(pepe.ns.G().thanks["Pepe-Reino"]["Ana-Reino"], 1, "Pepe suma 1 encargo a Ana")
H.Advance(30)
H.eq(bea.ns.Data.ThanksFor("Ana-Reino"), 1, "Bea ve el encargo de Ana")

-- El autor también puede confirmar a mano (entrega en persona) sin contar dos veces.
local req2 = pepe.ns.Sync.CreateRequest({ k = "i4234", q = 5 })
H.Advance(10)
ana.ns.Sync.Commit(req2.id, 5)
H.Advance(10)
H.SendMail(ana, "Pepe", { { 4234, 3 } })
H.Advance(10)
pepe.ns.Sync.ConfirmDelivery(req2.id, "Ana-Reino", 2)
H.Advance(10)
H.eq(bea.ns.Data.RequestInfo(bea.ns.G().requests[req2.id], bea.ns.Now()).state, "done", "3 por correo + 2 en mano = hecha")
H.eq(pepe.ns.G().thanks["Pepe-Reino"]["Ana-Reino"], 2, "segundo encargo de Ana")
H.eq(#H.errors, 0, "sin errores de Lua")
