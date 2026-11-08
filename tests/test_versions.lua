local H = ...
-- Versiones distintas y nombres con otro formato: que se note y que no se pierdan los pedidos.
H.AddMember("Ana")
H.AddMember("Bea")
local ana = H.Login("Ana")
local bea = H.Login("Bea")
H.Advance(20)
local ns = ana.ns

-- 1) Los dos con la misma versión: la comprobación lo dice.
H.eq(#ns.Sync.OtherVersions(), 0, "misma versión: nadie con otra")

-- 2) Alguien con una versión antigua: aviso en el chat (una sola vez) y sale en la comprobación.
local before = #ana.chat
ns.Sync.NotePeerVersion("Carla-Reino", "0.25.0")
ns.Sync.NotePeerVersion("Carla-Reino", "0.25.0")
local warned = 0
for i = before + 1, #ana.chat do
  if tostring(ana.chat[i]):find("Carla tiene una versión antigua", 1, true) then warned = warned + 1 end
end
H.eq(warned, 1, "aviso de versión antigua, una sola vez")
local other = ns.Sync.OtherVersions()
H.eq(#other, 1, "la comprobación ve una versión distinta")
H.ok(other[1]:find("Carla (0.25.0)", 1, true), "con el nombre y la versión")

-- 3) Alguien con una versión nueva: aviso para actualizar.
ns.Sync.NotePeerVersion("Dani-Reino", "9.0.0")
H.eq(ns.Sync.newest, "9.0.0", "se apunta la versión nueva")

-- 4) Nombres de la lista de la hermandad con el reino escrito distinto.
local Guild = ns.Guild
H.ok(Guild.full, "con la lista completa")
H.ok(Guild.Accepts("Bea-Reino"), "acepta a un miembro")
H.ok(not Guild.Accepts("Extraño-Reino"), "no acepta a quien no es de la hermandad")
local roster = Guild.roster
local saved = {}
for name, info in pairs(roster) do saved[name] = info end
for name in pairs(saved) do roster[name] = nil end
roster["Ana-Reino"] = saved["Ana-Reino"]
roster["Bea-Re ino"] = { online = true }
H.ok(Guild.Accepts("Bea-Reino"), "acepta aunque el reino venga con espacios")
roster["Ana-Reino"] = nil
roster["ana-otro"] = { online = true }
H.ok(Guild.Accepts("Extraño-Reino"), "si la lista ni me encuentra a mí, no descarta a nadie")
for name in pairs(roster) do roster[name] = nil end
for name, info in pairs(saved) do roster[name] = info end

-- 5) Un pedido de Bea llega a Ana.
bea.ns.UI.OpenRequestDialog({ k = "i2840", q = 3 })
bea.env.HDFProfRequestDialog:Publish()
H.Advance(10)
local got = false
for _, r in pairs(ns.G().requests) do if r.a == "Bea-Reino" and r.k == "i2840" then got = true end end
H.ok(got, "el pedido de Bea sale a Ana")

H.eq(#H.errors, 0, "sin errores de Lua")
