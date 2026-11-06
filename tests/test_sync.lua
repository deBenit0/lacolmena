local H = ...
H.AddMember("Ana", "MAGE")
H.AddMember("Bea", "WARRIOR")
H.AddMember("Cris", "WARRIOR")
H.AddMember("Dani", "WARRIOR") -- nunca se conecta

local ALCHEMY = {
  name = "Alquimia", rank = 300, max = 300,
  rows = {
    { name = "Pociones", kind = "header" },
    { name = "Poción de maná superior", item = 13443, reagents = { { 8838, 3 }, { 8839, 2 }, { 8925, 1 } } },
    { name = "Transmutar: arcanita", item = 12360, reagents = { { 12359, 1 }, { 12363, 1 } }, cooldown = 30000 },
    { name = "Frasco de titanes", item = 13510, reagents = { { 8846, 30 }, { 13423, 10 }, { 13468, 1 } } },
  },
}
-- Muchas recetas para que la ficha ocupe varios mensajes.
for i = 1, 250 do
  ALCHEMY.rows[#ALCHEMY.rows + 1] = { name = "Receta " .. i, item = 3000 + i * 41, reagents = { { 2447, 1 } } }
end

local ENCHANTING = {
  name = "Encantamiento", rank = 300, max = 300,
  rows = {
    { name = "Encantar arma: cruzado", enchant = 20034, reagents = { { 12811, 4 }, { 14344, 4 } } },
    { name = "Varita mística mayor", item = 11288, reagents = { { 11291, 1 }, { 11134, 3 } } },
  },
}

-- Comprueba que todos los conectados tienen exactamente los mismos datos.
local function converged(clients, what)
  local ref
  for _, c in ipairs(clients) do
    local g = c.ns.G()
    local versions, requests = {}, {}
    for name, e in pairs(g.entries) do versions[name] = e.v end
    for id, r in pairs(g.requests) do requests[id] = c.ns.Codec.Serialize(r) end
    local snapshot = { versions = versions, requests = requests }
    if not ref then
      ref = snapshot
    elseif not H.deepEqual(ref, snapshot) then
      H.ok(false, "datos distintos entre jugadores (" .. what .. "): " .. H.dump(ref) .. " / " .. H.dump(snapshot))
      return false
    end
  end
  H.ok(true, "todos tienen los mismos datos (" .. what .. ")")
  return true
end

-- 1) Ana entra sola y abre Alquimia.
local ana = H.Login("Ana", { class = "MAGE", skills = { { name = "Profesiones", header = true }, { name = "Alquimia", rank = 300, max = 300 } } })
H.Advance(15)
H.OpenTradeSkill(ana, ALCHEMY)
H.Advance(10)
local anaEntry = ana.ns.G().entries["Ana-Reino"]
H.ok(anaEntry ~= nil, "Ana publica su ficha")
H.ok(anaEntry.p and anaEntry.p[171], "con Alquimia (171)")
H.eq(#ana.ns.Codec.DecodeIDs(anaEntry.p[171].i), 253, "253 recetas de objeto (sin la cabecera)")
H.ok(anaEntry.p[171].cd and anaEntry.p[171].cd.i12360, "cooldown de arcanita")
H.ok(ana.ns.Data.GetInfo("171:i13443").v[1].r[8838] == 3, "materiales guardados")

-- 2) Bea entra: recibe la ficha de Ana (troceada en varios mensajes) y publica la suya.
local bea = H.Login("Bea")
H.Advance(15)
H.OpenCraft(bea, ENCHANTING)
H.Advance(60)
H.ok(bea.ns.G().entries["Ana-Reino"] ~= nil, "Bea recibe la ficha de Ana")
H.eq(bea.ns.G().entries["Ana-Reino"].v, anaEntry.v, "misma versión")
H.ok(ana.ns.G().entries["Bea-Reino"] ~= nil, "Ana recibe la ficha de Bea")
local beaProf = ana.ns.G().entries["Bea-Reino"].p[333]
H.ok(beaProf and beaProf.e, "Bea tiene encantamientos (no objetos)")
H.ok(ana.ns.Data.GetIndex().e20034 ~= nil, "índice: cruzado (encantamiento)")
H.ok(ana.ns.Data.GetIndex().i11288 ~= nil, "índice: varita (objeto de encantamiento)")
converged({ ana, bea }, "Ana y Bea")

-- 3) Ana se va. Cris entra y recibe la ficha de Ana a través de Bea.
local anaDB = H.Logout(ana)
H.Advance(5)
local cris = H.Login("Cris")
H.Advance(90)
H.ok(cris.ns.G().entries["Ana-Reino"] ~= nil, "Cris recibe la ficha de Ana (desconectada) a través de Bea")
H.ok(cris.ns.G().entries["Bea-Reino"] ~= nil, "Cris recibe la ficha de Bea")
converged({ bea, cris }, "Bea y Cris")

-- 4) Cris pide algo que solo sabe hacer Ana (desconectada).
local req = cris.ns.Sync.CreateRequest({ k = "i13510", pk = 171, q = 3, g = 50000, m = true, pi = { [12360] = 1 } })
H.ok(req ~= nil, "Cris crea una petición")
H.Advance(10)
H.ok(bea.ns.G().requests[req.id] ~= nil, "Bea recibe la petición")
H.eq(#bea.sounds, 0, "Bea no sabe hacerlo: sin aviso")

-- Cris pide los materiales de una receta que nadie conectado conoce: no hay respuesta.
cris.ns.Sync.AskInfo("171:i13510")
H.Advance(10)
H.ok(cris.ns.Data.GetInfo("171:i13510") == nil, "sin materiales mientras Ana no está")

-- 5) Ana vuelve: recibe la petición y le salta el aviso.
ana = H.Login("Ana", { class = "MAGE", savedDB = anaDB, skills = { { name = "Profesiones", header = true }, { name = "Alquimia", rank = 300, max = 300 } } })
H.Advance(60)
H.ok(ana.ns.G().requests[req.id] ~= nil, "Ana recibe la petición al volver")
H.ok(ana.ns.G().alerted[req.id], "Ana recibe un aviso (sabe hacerlo)")
H.ok(#ana.sounds >= 1, "con sonido")
-- Ahora Ana está conectada y tiene los materiales: si Cris los pide, se los mandan.
cris.ns.Sync.AskInfo("171:i13510")
H.Advance(70)
local crisInfo = cris.ns.Data.GetInfo("171:i13510")
H.ok(crisInfo and crisInfo.v[1].r[8846] == 30, "Cris recibe los materiales del frasco")

-- 6) Ana acepta, Cris recibe el aviso, confirma la entrega y el contador llega a todos.
ana.ns.Sync.Commit(req.id, 3)
H.Advance(10)
local crisReq = cris.ns.G().requests[req.id]
H.eq(cris.ns.Data.RequestInfo(crisReq, cris.ns.Now()).state, "accepted", "Cris ve la petición aceptada")
H.ok(#cris.sounds >= 1, "aviso para Cris: Ana lo hará")
cris.ns.Sync.ConfirmDelivery(req.id, "Ana-Reino", 3)
H.Advance(20)
H.eq(bea.ns.Data.RequestInfo(bea.ns.G().requests[req.id], bea.ns.Now()).state, "done", "Bea la ve hecha")
H.eq(bea.ns.Data.ThanksFor("Ana-Reino"), 1, "Bea ve 1 encargo completado de Ana")
converged({ ana, bea, cris }, "tras la entrega")

-- 7) Dos personas aceptan a la vez la misma petición: todos acaban viendo lo mismo.
local req2 = cris.ns.Sync.CreateRequest({ k = "i13443", q = 10 })
H.Advance(10)
ana.ns.Sync.Commit(req2.id, 1)
bea.ns.Sync.Commit(req2.id, 1)
H.Advance(30)
converged({ ana, bea, cris }, "dos compromisos simultáneos")
local info2 = cris.ns.Data.RequestInfo(cris.ns.G().requests[req2.id], cris.ns.Now())
H.eq(info2.pending, 10, "solo cuenta uno: el pedido entero")
H.ok(info2.owner == "Ana-Reino" or info2.owner == "Bea-Reino", "se lo queda uno de los dos")
H.eq(ana.ns.Data.RequestInfo(ana.ns.G().requests[req2.id], ana.ns.Now()).owner, info2.owner, "todos ven al mismo")

-- 8) Bea sale; mientras, Cris confirma y cierra. Bea vuelve y se pone al día.
local beaDB = H.Logout(bea)
cris.ns.Sync.ConfirmDelivery(req2.id, "Ana-Reino", 6)
H.Advance(5)
cris.ns.Sync.Close(req2.id)
H.Advance(10)
bea = H.Login("Bea", { savedDB = beaDB })
H.Advance(60)
converged({ ana, bea, cris }, "Bea se pone al día al volver")
H.eq(bea.ns.Data.RequestInfo(bea.ns.G().requests[req2.id], bea.ns.Now()).state, "closed", "Bea la ve cerrada")

-- 9) Una nueva receta de Ana llega a todos en directo.
H.OpenTradeSkill(ana, ALCHEMY) -- Ana (reconectada) abre su ventana
H.Advance(5)
ALCHEMY.rows[#ALCHEMY.rows + 1] = { name = "Elixir nuevo", item = 99999, reagents = { { 2447, 2 } } }
H.FireEvent(ana, "TRADE_SKILL_UPDATE")
H.Advance(20)
H.ok(cris.ns.Data.GetIndex().i99999 ~= nil, "receta nueva de Ana llega a Cris")
converged({ ana, bea, cris }, "receta nueva")

-- 10) Nadie ha recibido mensajes de más de 255 bytes ni ha habido errores.
H.eq(#H.errors, 0, "sin errores de Lua")
print(string.format("  tráfico: %d mensajes, %d bytes", H.traffic.messages, H.traffic.bytes))
