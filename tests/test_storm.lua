local H = ...
-- Hermandad grande: 30 fichas grandes (varios mensajes cada una) y 10 conectados.
-- Alguien entra con la base de datos vacía: no deben llegarle 10 copias de cada ficha.
local seedDB
do
  H.AddMember("Semilla")
  local seed = H.Login("Semilla")
  H.Advance(15)
  local g = seed.ns.G()
  for i = 1, 30 do
    local name = "Viejo" .. i
    H.AddMember(name)
    local items = {}
    for j = 1, 220 do items[j] = 2000 + ((i * 7919 + j * 104729) % 30000) end
    g.entries[name .. "-Reino"] = { n = name .. "-Reino", v = 1000 + i, c = "WARRIOR", l = 60,
      p = { [171] = { r = 300, m = 300, i = seed.ns.Codec.EncodeIDs(items) } } }
  end
  seedDB = H.Logout(seed)
end
for i = 1, 10 do H.AddMember("Online" .. i) end
for i = 1, 10 do
  H.Login("Online" .. i, { savedDB = seedDB })
  H.Advance(1)
end
H.Advance(300)
local before = H.copy(H.traffic.byType)
local beforeMessages = H.traffic.messages
H.AddMember("Nuevo")
local nuevo = H.Login("Nuevo")
H.Advance(600)
local entries = 0
for _ in pairs(nuevo.ns.G().entries) do entries = entries + 1 end
H.ok(entries >= 41, "el nuevo recibe todas las fichas: " .. entries)
local needed = 0
for name in pairs(H.clients.Online1.ns.G().entries) do
  if name ~= "Nuevo-Reino" then needed = needed + 1 end
end
H.eq(needed, 41, "fichas que necesita el nuevo: 30 antiguas + 10 conectados + Semilla")
local pushes = (H.traffic.byType.P or 0) - (before.P or 0) - 1 -- menos la suya propia
print(string.format("  fichas enviadas al nuevo: %d (necesarias %d), %d mensajes en total",
  pushes, needed, H.traffic.messages - beforeMessages))
H.ok(pushes <= needed * 1.25, "pocos envíos repetidos: " .. pushes .. " fichas para " .. needed)
H.eq(#H.errors, 0, "sin errores de Lua")
