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

function Demo.IsDemo(name)
  return type(name) == "string" and name:sub(-#REALM - 1) == "-" .. REALM
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
  return {
    n = full(name), v = now, c = CLASSES[(index % #CLASSES) + 1], l = 60, demo = true,
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
  for i, req in ipairs(REQUESTS) do
    local r = Data.SanitizeRequest({
      id = full(req[1]) .. ":demo" .. i, a = full(req[1]), t = now - i * 1800, k = "i" .. req[2],
      q = req[3], av = now, g = req[4], m = (i % 2 == 0) or nil,
    })
    -- algunas ya tienen a alguien encargado
    if i % 4 == 0 then
      r.c = { [full("Roca")] = { n = math.ceil(req[3] / 2), cv = now - 600 } }
    end
    r.demo = true
    g.requests[r.id] = r
  end
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
  wipe(Demo.online)
  wipe(Demo.seen)
  wipe(Demo.info)
  Data.indexDirty = true
  if not silent then ns.Fire("DATA_CHANGED", "demo") end
end

function Demo.Set(on)
  ns.db.settings.demo = on and true or nil
  if on then Demo.Enable() else Demo.Disable() end
end

-- Al entrar: quitar los restos de una sesión anterior y volver a crearlos si sigue activo.
ns.Listen("GUILD_CHANGED", function(key)
  if not key then return end
  Demo.Disable(true)
  if ns.db.settings.demo then Demo.Enable() end
end)
