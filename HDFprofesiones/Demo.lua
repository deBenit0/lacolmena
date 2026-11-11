-- Modo demostración: jugadores de mentira (3 o 4 por profesión) que ofrecen recetas y hacen
-- peticiones, para ver cómo queda el addon. Solo se ven en tu ordenador: nunca se envían.
local _, ns = ...
local Codec, Data = ns.Codec, ns.Data
local Demo = { online = {}, seen = {}, info = {} }
ns.Demo = Demo

local REALM = "Demo"
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- Recetas de ejemplo por profesión (objetos e identificadores reales de Classic).
-- Cada receta: { id, { {material, cantidad}, ... }, sale = cantidad por vez }
local RECIPES = {
  [164] = { -- Herrería
    { 2862, { { 2835, 1 } } }, { 2863, { { 2836, 1 } } }, { 2871, { { 2838, 1 } } },
    { 7964, { { 7912, 1 } } }, { 12404, { { 12365, 1 } } }, { 12405, { { 12359, 16 }, { 8170, 4 } } },
  },
  [165] = { -- Peletería
    { 2318, { { 2934, 3 } } }, { 2319, { { 2318, 4 } } }, { 4234, { { 2319, 5 } } },
    { 4304, { { 4234, 6 } } }, { 8170, { { 4304, 5 } } }, { 4265, { { 4234, 5 }, { 4291, 1 } } },
    { 8173, { { 4304, 5 }, { 8343, 1 } } },
  },
  [171] = { -- Alquimia
    { 118, { { 2447, 1 }, { 765, 1 }, { 3371, 1 } } }, { 929, { { 2453, 1 }, { 2450, 1 }, { 3372, 1 } } },
    { 3928, { { 8838, 1 }, { 3358, 1 }, { 8925, 1 } } }, { 13446, { { 13464, 2 }, { 13465, 1 }, { 18256, 1 } } },
    { 13443, { { 8838, 3 }, { 8839, 2 }, { 8925, 1 } } }, { 13452, { { 13465, 2 }, { 13466, 2 }, { 8925, 1 } } },
  },
  [197] = { -- Sastrería
    { 2996, { { 2589, 2 } } }, { 2997, { { 2592, 3 } } }, { 4305, { { 4306, 4 } } },
    { 4339, { { 4338, 5 } } }, { 14048, { { 14047, 5 } } }, { 14046, { { 14048, 5 }, { 14341, 1 } } },
  },
  [202] = { -- Ingeniería
    { 4357, { { 2835, 1 } } }, { 4364, { { 2836, 1 } } }, { 4377, { { 2838, 1 } } },
    { 10505, { { 7912, 2 } } }, { 15992, { { 12365, 2 } } }, { 15993, { { 12359, 3 }, { 15992, 3 }, { 14047, 3 } } },
  },
  [185] = { -- Cocina
    { 2680, { { 2672, 1 }, { 2678, 1 } } }, { 12210, { { 12184, 1 }, { 2692, 1 } } },
    { 13928, { { 13754, 1 }, { 2692, 1 } } }, { 13931, { { 13759, 1 }, { 159, 1 } } },
  },
  [129] = { -- Primeros auxilios
    { 1251, { { 2589, 1 } } }, { 3530, { { 2592, 1 } } }, { 6450, { { 4306, 1 } } },
    { 8544, { { 4338, 1 } } }, { 14529, { { 14047, 1 } } }, { 14530, { { 14047, 2 } } },
  },
  [186] = { -- Minería (fundición)
    { 2840, { { 2770, 1 } } }, { 3576, { { 2771, 1 } } }, { 3575, { { 2772, 1 } } },
    { 3860, { { 3858, 1 } } }, { 12359, { { 10620, 1 } } },
  },
}
-- Encantamientos (hechizos) y varitas.
local ENCHANTS = { 20034, 20026, 13890, 20012, 20015 }
local ENCHANT_ITEMS = { { 11287, { { 10940, 1 }, { 10938, 1 } } }, { 11288, { { 10940, 3 }, { 10939, 1 } } } }

local NAMES = {
  [164] = { "Bruno", "Gerda", "Tarsis", "Olaf" }, [165] = { "Nimra", "Kael", "Sonia" },
  [171] = { "Ivette", "Mortis", "Alba", "Quino" }, [197] = { "Tula", "Faro", "Lys" },
  [202] = { "Chispa", "Bolt", "Ramiro" }, [333] = { "Selene", "Arcan", "Mirto", "Vela" },
  [185] = { "Pepa", "Gordo", "Lucio" }, [129] = { "Clara", "Venda", "Ruth" },
  [186] = { "Pico", "Roca", "Ferro" },
}

-- Peticiones de ejemplo: { autor, objeto, cantidad, pago en cobre }.
local REQUESTS = {
  { "Bruno", 4234, 20, 30000 }, { "Bruno", 2836, 40 }, { "Gerda", 8170, 12, 60000 },
  { "Nimra", 2840, 20 }, { "Nimra", 14047, 30, 20000 }, { "Kael", 12404, 10, 15000 },
  { "Ivette", 2453, 20 }, { "Ivette", 4339, 8 }, { "Tula", 4291, 10, 5000 },
  { "Chispa", 12359, 20, 80000 }, { "Chispa", 2863, 15 }, { "Selene", 13446, 5, 25000 },
  { "Pepa", 2318, 15 }, { "Clara", 8170, 5 }, { "Pico", 2871, 10, 10000 },
}

local function full(name) return name .. "-" .. REALM end

-- Peticiones de ejemplo hechas a tu medida: piden cosas que tú sabes fabricar o recolectar,
-- para que puedas probar todo el proceso (aceptar, enviar y ver cómo sube tu karma).
local ASKERS = { "Bruno", "Nimra", "Chispa", "Ivette", "Tula", "Pepa" }
local GATHER_ITEMS = { [393] = 4234, [182] = 3820, [186] = 2772 } -- cuero pesado, hierba, mineral de hierro
local FALLBACK_ITEM = 2318 -- cuero ligero: si aún no sabes hacer nada, para que puedas probar igual

local function myKeys()
  local c = ns.MyChar()
  local mats, others = {}, {}
  if c then
    for _, prof in pairs(c.profs or {}) do
      for key in pairs(prof.recipes or {}) do
        local kind, id = ns.ParseKey(key)
        if kind == "i" then
          local _, class = ns.ItemInstant(id)
          if class == 7 or class == 5 then mats[#mats + 1] = key else others[#others + 1] = key end
        end
      end
    end
  end
  table.sort(mats)
  table.sort(others)
  local keys = {}
  for i = 1, math.min(2, #mats) do keys[#keys + 1] = mats[i] end
  for i = 1, math.min(2 - #keys, #others) do keys[#keys + 1] = others[i] end
  for skill, id in pairs(GATHER_ITEMS) do
    if c and c.gather and c.gather[skill] then keys[#keys + 1] = "i" .. id end
  end
  return keys
end

local function addMyRequests(g, now)
  local keys = myKeys()
  local list = {}
  -- Siempre hay al menos una, así puedes probarlo aunque aún no tengas profesiones.
  table.insert(list, { k = keys[1] or ("i" .. FALLBACK_ITEM), pr = 1 })
  for i = 2, #keys do list[#list + 1] = { k = keys[i], pr = (i % 3 == 0) and 3 or nil } end
  local made = {}
  for i, item in ipairs(list) do
    local author = full(ASKERS[(i - 1) % #ASKERS + 1])
    local r = Data.SanitizeRequest({
      id = author .. ":tuya" .. i, a = author, t = now - i * 240, k = item.k,
      q = 5 * i, av = now, g = 10000 * i, m = (i % 2 == 0) or nil, pr = item.pr,
    })
    if r then
      r.demo = true
      g.requests[r.id] = r
      made[#made + 1] = r
    end
  end
  return made
end

-- Ofertas de ejemplo: { quien, objeto, cuántos, precio por unidad }.
local OFFERS = {
  { "Tula", 4240, 4, 0 },        -- Bolsa de lana, gratis
  { "Lys", 14046, 2, 50000 },    -- Bolsa de paño rúnico, 5 oro
  { "Ivette", 929, 10, 0 },      -- Poción de sanación
  { "Mortis", 13446, 5, 10000 }, -- Poción de sanación sublime, 1 oro
  { "Pepa", 13931, 20, 0 },      -- Comida
  { "Gerda", 12404, 10, 5000 },  -- Piedra de afilar densa
}

function Demo.AddOffers(g, now)
  for i, o in ipairs(OFFERS) do
    local e = g.entries[full(o[1])]
    if e then
      e.of = e.of or {}
      e.of[o[2]] = { q = o[3], g = o[4] > 0 and o[4] or nil, t = now - i * 1500 }
    end
  end
end

-- Quedadas de mazmorra de ejemplo: una tuya (para probar "Hacer grupo") y otra de Bruno.
function Demo.AddRuns(g, now)
  local D = ns.Dungeons
  if not D then return end
  local list = D.Runs()
  local mine = D.Recommended(D.MyLevel())
  local dg = D.Dungeon(mine)
  local function add(id, author, d, at, people, levelOf)
    local r = { id = id, a = author, t = now - 900, d = d, at = at, av = now, s = {} }
    for j, name in ipairs(people) do
      local e = g.entries[full(name)]
      local class = e and e.c or "WARRIOR"
      r.s[full(name)] = { r = D.RolesFor(class), l = levelOf(j), c = class, st = now - 800 + j * 40, sv = now }
    end
    r = D.Sanitize(r)
    r.demo = true
    list[r.id] = r
  end
  local base = math.max(dg.min, math.min(D.MyLevel(), dg.max))
  add(ns.Me() .. ":quedadademo", ns.Me(), mine, now + 25 * 60,
    { "Gerda", "Ivette", "Mortis", "Kael", "Tula", "Chispa", "Selene", "Pico" },
    function(j) return j == 5 and (dg.min - 3) or (base - (j % 3)) end)
  add(full("Bruno") .. ":quedadademo", full("Bruno"), 18, now - 5 * 60,
    { "Bruno", "Olaf", "Alba", "Faro" }, function() return 60 end)
end

-- Lo que dicen los jugadores de ejemplo (en tu chat; nadie más lo ve).
local function say(author, text)
  ns.Print("|cffff8040[ejemplo]|r " .. ns.ShortName(author) .. ": " .. text)
end

-- Hermandad de ejemplo: anuncio y necesidades de Gerda (oficial), donaciones, un alt
-- (Olaf es alt de Bruno) y ayudas de la semana.
function Demo.AddGuild(g, now)
  local S = ns.Social
  local gerda = g.entries[full("Gerda")]
  if gerda then
    gerda.an = { x = "Este sábado a las 21:00 vamos a Onyxia. ¡Traed frascos y resistencia al fuego!", t = now - 3600 }
    gerda.nd = { [13443] = { q = 40, t = now - 86400 }, [12360] = { q = 10, t = now - 86400 } }
  end
  local donors = { { "Ivette", 13443, 15 }, { "Mortis", 13443, 10 }, { "Chispa", 12360, 3 } }
  for _, d in ipairs(donors) do
    local e = g.entries[full(d[1])]
    if e then
      e.dn = e.dn or {}
      e.dn[full("Gerda") .. ":" .. d[2]] = { n = d[3], t = now - 3600 }
    end
  end
  local olaf = g.entries[full("Olaf")]
  if olaf then olaf.mn = full("Bruno") end
  local bruno = g.entries[full("Bruno")]
  if bruno then bruno.al = { full("Bruno"), full("Olaf") } end
  local week = S.Week(now)
  local helps = { Bruno = { 4, 9 }, Olaf = { 2, 3 }, Ivette = { 6, 5 }, Tula = { 3, 11 }, Kael = { 1, 2 } }
  for name, h in pairs(helps) do
    local e = g.entries[full(name)]
    if e then e.wk = { w = week, n = h[1], pn = h[2] } end
  end
  S.Invalidate()
end

-- Has pedido algo de una oferta de ejemplo: te lo "manda" a los pocos segundos.
function Demo.OnClaim(owner, id, q)
  local me = ns.Me()
  ns.After(2, function() say(owner, "¡Es tuyo! Te lo mando ahora por correo.") end)
  ns.After(4, function()
    local g = ns.G()
    local e = g and g.entries[owner]
    if not ns.db.settings.demo or not e then return end
    e.od = e.od or {}
    e.od[me] = e.od[me] or {}
    local d = e.od[me][id] or { n = 0 }
    d.n, d.t = d.n + q, ns.Now()
    e.od[me][id] = d
    if e.of and e.of[id] then
      e.of[id].q = e.of[id].q - q
      if e.of[id].q <= 0 then e.of[id] = nil end
    end
    ns.Fire("DATA_CHANGED", "entry", owner)
  end)
end

-- Has aceptado una petición de ejemplo.
function Demo.OnCommit(r)
  if not r or not r.demo then return end
  ns.After(2, function() say(r.a, "¡Genial, es tuyo! Mándamelo por correo cuando lo tengas.") end)
end

-- "Enviar (ejemplo)": hace como si mandaras el correo; el autor lo recibe a los pocos segundos.
function Demo.SimulateMail(r)
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  local cm = r and r.demo and r.c and r.c[me]
  if not cm or not Data.CommitActive(cm, now, r) then return false end
  local units = cm.n - Data.DeliveredOf(cm)
  if units <= 0 then return false end
  cm.s = Data.DeliveredOf(cm) + units
  cm.sv = now
  ns.Print(string.format("correo de ejemplo enviado a %s: %dx %s (de verdad no se envía nada).",
    ns.ShortName(r.a), units, ns.KeyLabel(r.k)))
  ns.Fire("DATA_CHANGED", "request", r.id)
  ns.After(3, function()
    local e = g.entries[r.a]
    if not ns.db.settings.demo or not e or g.requests[r.id] ~= r then return end
    -- El autor apunta el karma y el encargo, igual que haría un jugador de verdad.
    local value = Data.KARMA_POINT -- 1 punto por pedido
    e.kc = e.kc or {}
    e.kc[me] = (e.kc[me] or 0) + value
    e.kd = (e.kd or 0) + value
    e.th = e.th or {}
    e.th[me] = (e.th[me] or 0) + 1
    say(r.a, "¡Recibido! Gracias, crack. (+1 de karma para ti)")
    ns.Fire("DATA_CHANGED", "entry", r.a)
  end)
  return true
end

function Demo.IsDemo(name)
  return type(name) == "string" and name:sub(-#REALM - 1) == "-" .. REALM
end

-- En el modo demostración, Gerda hace de oficial (anuncio y necesidades de ejemplo).
function Demo.IsOfficer(name)
  return name == full("Gerda")
end

function Demo.IsOnline(name)
  return Demo.online[name] or false
end

function Demo.LastSeen(name)
  return Demo.seen[name]
end

function Demo.GetInfo(ik)
  if ns.db and ns.db.settings.demo then return Demo.info[ik] end
end

local function buildEntry(name, pk, recipes, now, index)
  local items, enchants = {}, {}
  for _, rec in ipairs(recipes) do
    items[#items + 1] = rec[1]
    Demo.info[Data.InfoKey(pk, "i" .. rec[1])] = { v = { { m = rec.sale or 1, r = (function()
      local r = {}
      for _, re in ipairs(rec[2]) do r[re[1]] = re[2] end
      return r
    end)() } } }
  end
  if pk == 333 then
    for _, id in ipairs(ENCHANTS) do enchants[#enchants + 1] = id end
  end
  local class = CLASSES[(index % #CLASSES) + 1]
  local tree = index % 3 + 1
  local role = (index % 5 ~= 4) and ns.Dungeons.RoleFromTalents(class, { tree == 1 and 31 or 0,
    tree == 2 and 31 or 0, tree == 3 and 31 or 0 }) or nil
  return {
    n = full(name), v = now, c = class, l = 60, demo = true, ro = role,
    -- Algunos ofrecen fabricar sus primeras recetas (varios la misma: salen juntos).
    fb = (index % 2 == 0 and items[1]) and {
      ["i" .. items[1]] = { g = (index % 4 == 0) and 10000 or nil, m = (index % 3 == 0) and 1 or nil, t = now - index * 3600 },
      [items[2] and ("i" .. items[2]) or ("i" .. items[1])] = { t = now - index * 7200 },
    } or nil,
    u = (index % 7 == 3) or nil,
    p = { [pk] = {
      r = 300 - (index % 3) * 15, m = 300,
      i = #items > 0 and Codec.EncodeIDs(items) or nil,
      e = #enchants > 0 and Codec.EncodeIDs(enchants) or nil,
    } },
  }
end

function Demo.Enable()
  local g = ns.G()
  if not g then return end
  Demo.Disable(true)
  local now = ns.Now()
  local index = 0
  for pk, names in pairs(NAMES) do
    local recipes = pk == 333 and ENCHANT_ITEMS or RECIPES[pk] or {}
    for i, name in ipairs(names) do
      index = index + 1
      -- cada uno sabe casi todo lo de su profesión (alguno sabe menos)
      local mine = {}
      for j, rec in ipairs(recipes) do
        if (j + i) % 4 ~= 0 then mine[#mine + 1] = rec end
      end
      g.entries[full(name)] = buildEntry(name, pk, mine, now, index)
      Demo.online[full(name)] = (index % 3 == 0)
      Demo.seen[full(name)] = now - (index * 5400)
    end
  end
  -- Karma de ejemplo: unos han ayudado más que otros.
  local all = {}
  for name in pairs(g.entries) do
    if g.entries[name].demo then all[#all + 1] = name end
  end
  table.sort(all)
  for i, name in ipairs(all) do
    local e = g.entries[name]
    local helped = all[(i % #all) + 1]
    e.kc = { [helped] = ((i * 7) % 9) * 40000 }
    e.kd = ((i * 5) % 6) * 30000
  end
  for i, req in ipairs(REQUESTS) do
    local r = Data.SanitizeRequest({
      id = full(req[1]) .. ":demo" .. i, a = full(req[1]), t = now - i * 1800, k = "i" .. req[2],
      q = req[3], av = now, g = req[4], m = (i % 2 == 0) or nil,
    })
    -- algunas ya tienen a alguien encargado
    if i % 4 == 0 then
      r.c = { [full("Roca")] = { n = req[3], cv = now - 600, w = 2, by = now + 5400 } }
    end
    if i % 5 == 0 then r.pr = 1 elseif i % 3 == 0 then r.pr = 3 end
    r.demo = true
    g.requests[r.id] = r
  end
  Demo.mine = addMyRequests(g, now)
  Demo.AddRuns(g, now)
  Demo.AddOffers(g, now)
  Demo.AddGuild(g, now)
  Data.indexDirty = true
  ns.Fire("DATA_CHANGED", "demo")
end

function Demo.Disable(silent)
  local g = ns.G()
  if not g then return end
  for name, e in pairs(g.entries) do
    if e.demo then g.entries[name] = nil end
  end
  for id, r in pairs(g.requests) do
    if r.demo then g.requests[id] = nil end
  end
  for id, r in pairs(g.runs or {}) do
    if r.demo then g.runs[id] = nil end
  end
  wipe(Demo.online)
  wipe(Demo.seen)
  wipe(Demo.info)
  Data.indexDirty = true
  if not silent then ns.Fire("DATA_CHANGED", "demo") end
end

function Demo.Set(on)
  ns.db.settings.demo = on and true or nil
  if on then
    Demo.Enable()
    -- Enseña el aviso que te saltaría con una petición para ti.
    local r = Demo.mine and Demo.mine[1]
    if r and ns.Alerts then
      ns.After(1.5, function()
        local _, icon = ns.KeyInfo(r.k)
        ns.Alerts.Push({ id = r.id, icon = icon, canCommit = true,
          text = string.format("%s pide %dx %s (ya)", ns.ShortName(r.a), r.q, ns.KeyLabel(r.k)) })
      end)
    end
  else
    Demo.Disable()
  end
end

-- Al entrar: quitar los restos de una sesión anterior y volver a crearlos si sigue activo.
ns.Listen("GUILD_CHANGED", function(key)
  if not key then return end
  Demo.Disable(true)
  if ns.db.settings.demo then Demo.Enable() end
end)
