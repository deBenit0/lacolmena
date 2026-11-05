local H = ...
-- Hermandad de 14 personas que entran y salen, con muchas recetas y peticiones.
local NAMES = { "Ana", "Bea", "Cris", "Dani", "Eva", "Fran", "Gema", "Hugo", "Ines", "Juan", "Kike", "Luz", "Mario", "Nora" }
for _, name in ipairs(NAMES) do H.AddMember(name) end

local PROFS = { "Alquimia", "Herrería", "Sastrería", "Peletería", "Ingeniería", "Cocina" }
local function randomTradeskill(seed)
  local rows = {}
  for i = 1, 90 do
    local id = 2000 + ((seed * 7919 + i * 104729) % 20000)
    rows[#rows + 1] = { name = "Receta " .. id, item = id, reagents = { { 2447 + (i % 7), 1 + i % 3 } } }
  end
  return { name = PROFS[(seed % #PROFS) + 1], rank = 300, max = 300, rows = rows }
end

local online, saved = {}, {}
local function login(name, i)
  local c = H.Login(name, { savedDB = saved[name] })
  online[name] = c
  H.Advance(2)
  if not saved[name] then H.OpenTradeSkill(c, randomTradeskill(i)) end
  return c
end
local function logout(name)
  saved[name] = H.Logout(online[name])
  online[name] = nil
end

-- Entran de uno en uno.
for i, name in ipairs(NAMES) do
  login(name, i)
  H.Advance(math.random(5, 20))
end
H.Advance(120)

-- Peticiones y compromisos al azar, con gente entrando y saliendo.
local ids = {}
for round = 1, 40 do
  local names = {}
  for name in pairs(online) do names[#names + 1] = name end
  table.sort(names)
  local who = names[math.random(1, #names)]
  local c = online[who]
  local action = math.random()
  if action < 0.35 then
    local r = c.ns.Sync.CreateRequest({ k = "i" .. (2000 + math.random(0, 20000)), q = math.random(1, 20) })
    if r then ids[#ids + 1] = r.id end
  elseif action < 0.7 and #ids > 0 then
    c.ns.Sync.Commit(ids[math.random(1, #ids)], math.random(1, 5))
  elseif action < 0.85 and #names > 4 then
    logout(who)
  else
    for _, name in ipairs(NAMES) do
      if not online[name] then login(name, 0) break end
    end
  end
  H.Advance(math.random(1, 15))
end
H.Advance(600)

-- Todos los conectados deben tener los mismos datos.
local ref, refName, same = nil, nil, true
for name, c in pairs(online) do
  local g = c.ns.G()
  local snap = { e = {}, r = {} }
  for n, e in pairs(g.entries) do snap.e[n] = e.v end
  for id, r in pairs(g.requests) do snap.r[id] = c.ns.Codec.Serialize(r) end
  if not ref then
    ref, refName = snap, name
  elseif not H.deepEqual(ref, snap) then
    same = false
    H.ok(false, "datos distintos entre " .. refName .. " y " .. name)
    break
  end
end
H.ok(same, "los conectados convergen")
local entries = 0
for _ in pairs(ref.e) do entries = entries + 1 end
H.eq(entries, #NAMES, "una ficha por miembro, también de los desconectados")

local types = {}
for k, v in pairs(H.traffic.byType) do types[#types + 1] = k .. "=" .. v end
table.sort(types)
print(string.format("  tráfico total: %d mensajes, %d KB (%s)", H.traffic.messages, math.floor(H.traffic.bytes / 1024), table.concat(types, " ")))
H.eq(#H.errors, 0, "sin errores de Lua")
