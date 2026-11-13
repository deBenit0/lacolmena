-- Quedadas de mazmorra: alguien propone una mazmorra (ahora o a una hora), los demás se
-- apuntan con los roles que pueden hacer y quien la propuso pulsa "Hacer grupo": el addon
-- elige 1 tanque, 1 sanador y 3 DPS, deja al resto de suplentes y puede invitarlos.
--
-- Quedada:
--   { id, a = quien la propone, t = creada, d = mazmorra (su id en la lista), at = hora,
--     av = versión del bloque del autor, x = cancelada, gp = grupo hecho
--       { t = tanque, h = sanador, d = { dps... }, b = { suplentes... } },
--     s = { [apuntado] = { r = roles (1 tanque, 2 sanador, 4 DPS), l = nivel, c = clase,
--                          st = cuándo se apuntó, o = se ha desapuntado, sv = versión } } }
-- Como las peticiones: cada parte tiene un solo dueño y su versión, así que dos copias se
-- fusionan siempre igual.
local _, ns = ...
local Codec = ns.Codec
local Dungeons = {}
ns.Dungeons = Dungeons

local floor, max, min = math.floor, math.max, math.min

Dungeons.TANK, Dungeons.HEAL, Dungeons.DPS = 1, 2, 4
Dungeons.ROLES = {
  { bit = 1, label = "Tanque", plural = "Tanques" },
  { bit = 2, label = "Sanador", plural = "Sanadores" },
  { bit = 4, label = "DPS", plural = "DPS" },
}
-- Roles que puede hacer cada clase en Classic.
Dungeons.CLASS_ROLES = {
  WARRIOR = 5, PALADIN = 7, DRUID = 7, PRIEST = 6, SHAMAN = 6,
  HUNTER = 4, ROGUE = 4, MAGE = 4, WARLOCK = 4,
}

-- Rol de cada personaje, para el recuento de la Hermandad. Sale de la rama de talentos con más
-- puntos (ramas en el orden del juego); las clases que solo pueden ser DPS lo son siempre.
Dungeons.TALENT_ROLES = {
  WARRIOR = { 4, 4, 1 }, PALADIN = { 2, 1, 4 }, PRIEST = { 2, 2, 4 },
  SHAMAN = { 4, 4, 2 }, DRUID = { 4, 4, 2 },
}
function Dungeons.RoleFromTalents(class, points)
  if Dungeons.CLASS_ROLES[class] == Dungeons.DPS then return Dungeons.DPS end
  local map = Dungeons.TALENT_ROLES[class]
  if not map or type(points) ~= "table" then return nil end
  local best, bestPoints = nil, 0
  for i, role in ipairs(map) do
    local p = tonumber(points[i]) or 0
    if p > bestPoints then best, bestPoints = role, p end
  end
  return best
end

-- Rol válido (1 tanque, 2 sanador, 4 DPS) o nil.
-- Rol de un personaje: uno o varios a la vez (suma de 1 tanque, 2 sanador y 4 DPS: de 1 a 7).
function Dungeons.CleanRole(role)
  role = tonumber(role)
  if role and role >= 1 and role <= 7 and role % 1 == 0 then return role end
  return nil
end

function Dungeons.HasRole(mask, bit)
  mask = tonumber(mask)
  return mask ~= nil and math.floor(mask / bit) % 2 == 1
end

function Dungeons.RoleLabel(role, plural)
  for _, r in ipairs(Dungeons.ROLES) do
    if r.bit == role then return plural and r.plural or r.label end
  end
  -- varios a la vez: «Tanque/DPS»
  if Dungeons.CleanRole(role) then
    local parts = {}
    for _, r in ipairs(Dungeons.ROLES) do
      if Dungeons.HasRole(role, r.bit) then parts[#parts + 1] = r.label end
    end
    return table.concat(parts, "/")
  end
  return nil
end

-- Cuántos tanques, sanadores y DPS hay: cada personaje cuenta aparte (también los alts), desde
-- el nivel 10 (antes no hay talentos). Los que tienen el addon dicen su rol; del resto, las clases
-- que solo pueden ser DPS cuentan como DPS y las demás quedan «sin saber».
Dungeons.ROLE_MIN_LEVEL = 10
-- out.names[rol] = nombres de cada uno (para el tooltip de la Hermandad).
function Dungeons.RoleCounts(entries, roster)
  local out = { [1] = 0, [2] = 0, [4] = 0, unknown = 0 }
  out.names = { [1] = {}, [2] = {}, [4] = {}, unknown = {} }
  local seen = {}
  local function add(name, role, level, class)
    if seen[name] then return end
    seen[name] = true
    if (tonumber(level) or 0) < Dungeons.ROLE_MIN_LEVEL then return end
    role = Dungeons.CleanRole(role) or (Dungeons.CLASS_ROLES[class] == Dungeons.DPS and Dungeons.DPS) or nil
    if not role then
      out.unknown = out.unknown + 1
      table.insert(out.names.unknown, name)
      return
    end
    -- con varios roles, cuenta en cada uno
    for _, r in ipairs(Dungeons.ROLES) do
      if Dungeons.HasRole(role, r.bit) then
        out[r.bit] = out[r.bit] + 1
        table.insert(out.names[r.bit], name)
      end
    end
  end
  for name, e in pairs(entries or {}) do
    local r = roster and roster[name]
    add(name, e.ro, (r and r.level) or e.l, e.c or (r and r.class))
  end
  for name, r in pairs(roster or {}) do add(name, nil, r.level, r.class) end
  return out
end

-- Mazmorras con su rango de niveles recomendado, ordenadas por nivel. Cada una tiene un
-- número fijo (id) que es lo que se guarda y se envía: no cambiarlos nunca.
-- Las de WoW Forever (new = true) usan nombres en español provisionales.
Dungeons.LIST = {
  { id = 1, name = "Sima Ígnea", min = 13, max = 18 },
  { id = 101, name = "Salón de los Thanes", min = 13, max = 18, new = true },
  { id = 102, name = "Ruinas de Lordaeron", min = 15, max = 20, new = true },
  { id = 2, name = "Cuevas de los Lamentos", min = 17, max = 24 },
  { id = 3, name = "Minas de la Muerte", min = 17, max = 26 },
  { id = 4, name = "Castillo de Colmillo Oscuro", min = 22, max = 30 },
  { id = 5, name = "Cavernas de Brazanegra", min = 24, max = 32 },
  { id = 6, name = "Las Mazmorras", min = 24, max = 32 },
  { id = 103, name = "Zona de excavación", min = 24, max = 29, new = true },
  { id = 104, name = "Ciudad de Dalaran", min = 28, max = 33, new = true },
  { id = 9, name = "Monasterio Escarlata", min = 28, max = 44 },
  { id = 7, name = "Gnomeregan", min = 29, max = 38 },
  { id = 8, name = "Horado Rajacieno", min = 29, max = 38 },
  { id = 105, name = "La Ciudad Sumergida", min = 35, max = 40, new = true },
  { id = 10, name = "Zahúrda Rajacieno", min = 37, max = 46 },
  { id = 106, name = "Fortaleza Krol'dok", min = 40, max = 45, new = true },
  { id = 11, name = "Uldaman", min = 41, max = 51 },
  { id = 12, name = "Zul'Farrak", min = 42, max = 54 },
  { id = 13, name = "Maraudon", min = 46, max = 55 },
  { id = 107, name = "Prisión de Alcaz", min = 48, max = 53, new = true },
  { id = 14, name = "Templo de Atal'Hakkar", min = 50, max = 60 },
  { id = 15, name = "Profundidades de Roca Negra", min = 52, max = 60 },
  { id = 16, name = "Cumbre de Roca Negra", min = 55, max = 60 },
  { id = 17, name = "La Masacre", min = 55, max = 60 },
  { id = 108, name = "Bastión Fauce Negra", min = 55, max = 60, new = true },
  { id = 18, name = "Stratholme", min = 58, max = 60 },
  { id = 19, name = "Scholomance", min = 58, max = 60 },
  { id = 109, name = "Terraza del Modelador", min = 58, max = 60, new = true },
}
-- Grupos de leveo: hacer misiones juntos en una zona. Mismo sistema que las mazmorras, pero sin
-- reparto de roles: el grupo son los 5 primeros en apuntarse. Números desde 1001 (fijos).
Dungeons.ZONES = {
  { id = 1001, map = 1429, name = "Bosque de Elwynn", min = 1, max = 10, side = "Alliance" },
  { id = 1002, map = 1426, name = "Dun Morogh", min = 1, max = 10, side = "Alliance" },
  { id = 1003, map = 1438, name = "Teldrassil", min = 1, max = 10, side = "Alliance" },
  { id = 1004, map = 1411, name = "Durotar", min = 1, max = 10, side = "Horde" },
  { id = 1005, map = 1412, name = "Mulgore", min = 1, max = 10, side = "Horde" },
  { id = 1006, map = 1420, name = "Claros de Tirisfal", min = 1, max = 10, side = "Horde" },
  { id = 1007, map = 1436, name = "Páramos de Poniente", min = 10, max = 20, side = "Alliance" },
  { id = 1008, map = 1432, name = "Loch Modan", min = 10, max = 20, side = "Alliance" },
  { id = 1009, map = 1439, name = "Costa Oscura", min = 10, max = 20, side = "Alliance" },
  { id = 1010, map = 1413, name = "Los Baldíos", min = 10, max = 25, side = "Horde" },
  { id = 1011, map = 1421, name = "Bosque de Argénteos", min = 10, max = 20, side = "Horde" },
  { id = 1012, map = 1433, name = "Montañas Crestagrana", min = 15, max = 25, side = "Alliance" },
  { id = 1013, map = 1442, name = "Sierra Espolón", min = 15, max = 27 },
  { id = 1014, map = 1440, name = "Vallefresno", min = 18, max = 30 },
  { id = 1015, map = 1431, name = "Bosque del Ocaso", min = 18, max = 30 },
  { id = 1016, map = 1437, name = "Los Humedales", min = 20, max = 30 },
  { id = 1017, map = 1424, name = "Laderas de Trabalomas", min = 20, max = 30 },
  { id = 1018, map = 1441, name = "Las Mil Agujas", min = 25, max = 35 },
  { id = 1019, map = 1416, name = "Montañas de Alterac", min = 30, max = 40 },
  { id = 1020, map = 1417, name = "Tierras Altas de Arathi", min = 30, max = 40 },
  { id = 1021, map = 1443, name = "Desolace", min = 30, max = 40 },
  { id = 1022, map = 1434, name = "Vega de Tuercespina", min = 30, max = 45 },
  { id = 1023, map = 1445, name = "Marjal Revolcafango", min = 35, max = 45 },
  { id = 1024, map = 1418, name = "Tierras Inhóspitas", min = 35, max = 45 },
  { id = 1025, map = 1435, name = "Pantano de las Penas", min = 35, max = 45 },
  { id = 1026, map = 1444, name = "Feralas", min = 40, max = 50 },
  { id = 1027, map = 1425, name = "Tierras del Interior", min = 40, max = 50 },
  { id = 1028, map = 1446, name = "Tanaris", min = 40, max = 50 },
  { id = 1029, map = 1427, name = "La Garganta de Fuego", min = 43, max = 50 },
  { id = 1030, map = 1447, name = "Azshara", min = 45, max = 55 },
  { id = 1031, map = 1419, name = "Las Tierras Devastadas", min = 45, max = 55 },
  { id = 1032, map = 1449, name = "Cráter de Un'Goro", min = 48, max = 55 },
  { id = 1033, map = 1448, name = "Frondavil", min = 48, max = 55 },
  { id = 1034, map = 1428, name = "Las Estepas Ardientes", min = 50, max = 58 },
  { id = 1035, map = 1422, name = "Tierras de la Peste del Oeste", min = 51, max = 58 },
  { id = 1036, map = 1423, name = "Tierras de la Peste del Este", min = 53, max = 60 },
  { id = 1037, map = 1452, name = "Cuna del Invierno", min = 55, max = 60 },
  { id = 1038, map = 1451, name = "Silithus", min = 55, max = 60 },
}
for _, z in ipairs(Dungeons.ZONES) do z.zone = true end
Dungeons.LEVELING_SIZE = 5

Dungeons.BY_ID = {}
for _, dg in ipairs(Dungeons.LIST) do Dungeons.BY_ID[dg.id] = dg end
for _, z in ipairs(Dungeons.ZONES) do Dungeons.BY_ID[z.id] = z end

-- ¿Es un grupo de leveo (zona) y no una mazmorra?
function Dungeons.IsLeveling(r)
  local dg = r and Dungeons.BY_ID[r.d]
  return dg ~= nil and dg.zone == true
end

-- La zona que va mejor con mi nivel.
function Dungeons.RecommendedZone(level)
  level = level or 1
  local side = UnitFactionGroup and UnitFactionGroup("player")
  local best, bestScore
  for _, z in ipairs(Dungeons.ZONES) do
    -- las de inicio del otro bando, no
    if not (z.side and side and z.side ~= side) then
      local score = (level < z.min and (z.min - level) * 2) or (level > z.max and (level - z.max)) or 0
      if not best or score < bestScore then best, bestScore = z, score end
    end
  end
  return best.id
end

-- Un icono del juego distinto para cada mazmorra (la llave si no tiene).
Dungeons.KEY_ICON = "Interface\\Icons\\INV_Misc_Key_03"
local ICONS = {
  [1] = "Spell_Fire_FlameShock", [101] = "INV_Hammer_05", [102] = "Spell_Shadow_RaiseDead",
  [2] = "INV_Misc_MonsterFang_01", [3] = "Trade_Mining", [4] = "Ability_Mount_BlackDireWolf",
  [5] = "Spell_Frost_SummonWaterElemental", [6] = "INV_Misc_Key_04", [103] = "INV_Misc_Shovel_01",
  [104] = "Spell_Holy_MagicalSentry", [9] = "Spell_Holy_HolyBolt", [7] = "INV_Gizmo_02",
  [8] = "Spell_Nature_Thorns", [105] = "Spell_Frost_FrostWard", [10] = "Spell_Shadow_AnimateDead",
  [106] = "Ability_Warrior_BattleShout", [11] = "INV_Misc_Rune_01", [12] = "INV_Misc_Head_Troll_01",
  [13] = "Spell_Nature_ProtectionformNature", [107] = "Spell_Shadow_Teleport", [14] = "Spell_Shadow_LifeDrain",
  [15] = "Spell_Fire_LavaSpawn", [16] = "INV_Misc_Head_Dragon_Black", [17] = "Ability_Druid_Maul",
  [108] = "Ability_Warrior_WarCry", [18] = "INV_Misc_Bone_HumanSkull_01", [19] = "Spell_Shadow_DarkRitual",
  [109] = "Spell_Arcane_StarFire",
}
function Dungeons.Icon(d)
  if d and d >= 1001 then return "Interface\\Icons\\INV_Misc_Map_01" end
  local name = ICONS[d]
  return name and ("Interface\\Icons\\" .. name) or Dungeons.KEY_ICON
end

Dungeons.ACTIVE_FOR = 3 * 3600   -- una quedada se puede usar hasta 3 h después de su hora
Dungeons.KEEP_FOR = 12 * 3600    -- y se borra 12 h después
Dungeons.REMIND_BEFORE = 10 * 60 -- aviso a los apuntados 10 min antes
Dungeons.GROUP_SIZE = { tank = 1, heal = 1, dps = 3 }

local function bump(old, now)
  return max(now, (old or 0) + 1)
end

local function hasRole(mask, bit)
  return mask and floor(mask / bit) % 2 == 1
end
Dungeons.HasRole = hasRole

function Dungeons.Dungeon(d)
  return Dungeons.BY_ID[d] or { id = d, name = "Mazmorra", min = 1, max = 60 }
end

function Dungeons.LevelText(d)
  local dg = Dungeons.Dungeon(d)
  return dg.min .. "-" .. dg.max
end

-- La mazmorra que mejor encaja con un nivel (para proponerla por defecto).
function Dungeons.Recommended(level)
  level = level or 60
  local best, bestScore
  for _, dg in ipairs(Dungeons.LIST) do
    local score
    if level >= dg.min and level <= dg.max then
      score = math.abs((dg.min + dg.max) / 2 - level)
    else
      score = 100 + math.min(math.abs(level - dg.min), math.abs(level - dg.max))
    end
    if not bestScore or score < bestScore then best, bestScore = dg.id, score end
  end
  return best
end

function Dungeons.MyLevel()
  return (UnitLevel and UnitLevel("player")) or 60
end

function Dungeons.MyClass()
  if UnitClass then
    local _, class = UnitClass("player")
    if class then return class end
  end
  local c = ns.MyChar()
  return c and c.class or "WARRIOR"
end

function Dungeons.RolesFor(class)
  return Dungeons.CLASS_ROLES[class] or 4
end

-- Día de una quedada respecto a hoy: "hoy", "mañana" o "sáb 14" (reloj del ordenador).
Dungeons.WEEKDAYS = { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" }

-- Número de día (en hora local) de un momento del addon: sirve para comparar días.
function Dungeons.DayNumber(at)
  if not date then return 0 end
  local ok, t = pcall(date, "*t", at + ns.EPOCH)
  if not ok or type(t) ~= "table" then return 0 end
  local midnight = at + ns.EPOCH - (t.hour * 3600 + t.min * 60 + t.sec)
  return floor((midnight + 43200) / 86400)
end

function Dungeons.DayText(at, now)
  local diff = Dungeons.DayNumber(at) - Dungeons.DayNumber(now)
  if diff <= 0 then return "hoy" end
  if diff == 1 then return "mañana" end
  local ok, t = pcall(date, "*t", at + ns.EPOCH)
  if not ok or type(t) ~= "table" then return "" end
  return Dungeons.WEEKDAYS[t.wday] .. " " .. t.day
end

-- Hora de una quedada en el reloj del ordenador ("21:30").
function Dungeons.Clock(at)
  if date and ns.EPOCH then
    local ok, text = pcall(date, "%H:%M", at + ns.EPOCH)
    if ok and text then return text end
  end
  return "?"
end

local function runs()
  local g = ns.G()
  if not g then return nil end
  g.runs = g.runs or {}
  return g.runs, g
end
Dungeons.Runs = runs

---------------------------------------------------------------------------
-- Validación, fusión y huella
---------------------------------------------------------------------------
local function nameList(src, limit)
  if type(src) ~= "table" then return nil end
  local out = {}
  for i = 1, min(#src, limit) do
    if type(src[i]) == "string" then out[#out + 1] = src[i] end
  end
  return #out > 0 and out or nil
end

function Dungeons.Sanitize(r)
  if type(r) ~= "table" or type(r.id) ~= "string" or type(r.a) ~= "string" then return nil end
  local d = tonumber(r.d)
  if not d or not Dungeons.BY_ID[d] then return nil end
  local out = {
    id = r.id, a = r.a, t = tonumber(r.t) or 0, d = d,
    at = tonumber(r.at) or tonumber(r.t) or 0, av = tonumber(r.av) or 0,
  }
  if tonumber(r.x) then out.x = tonumber(r.x) end
  if type(r.gp) == "table" then
    local gp = {}
    if type(r.gp.t) == "string" then gp.t = r.gp.t end
    if type(r.gp.h) == "string" then gp.h = r.gp.h end
    gp.d = nameList(r.gp.d, 3)
    gp.b = nameList(r.gp.b, 40)
    out.gp = gp
  end
  if type(r.s) == "table" then
    local s, any = {}, false
    for name, su in pairs(r.s) do
      if type(name) == "string" and type(su) == "table" then
        local o = {}
        local mask = tonumber(su.r)
        if mask and mask >= 0 and mask <= 7 then o.r = floor(mask) end
        if tonumber(su.l) then o.l = floor(tonumber(su.l)) end
        if type(su.c) == "string" then o.c = su.c end
        if tonumber(su.st) then o.st = tonumber(su.st) end
        if su.o == true then o.o = true end
        if tonumber(su.sv) then o.sv = tonumber(su.sv) end
        if next(o) then
          s[name] = o
          any = true
        end
      end
    end
    if any then out.s = s end
  end
  return out
end

local function pick(a, b, verField)
  local va, vb = a[verField] or 0, b[verField] or 0
  if va ~= vb then return va > vb and a or b end
  return Codec.Serialize(a) >= Codec.Serialize(b) and a or b
end

function Dungeons.Merge(a, b)
  if not a then return b end
  if not b then return a end
  local base = pick({ a = a.a, t = a.t }, { a = b.a, t = b.t }, "_")
  local ab = pick({ d = a.d, at = a.at, av = a.av, x = a.x, gp = a.gp }, { d = b.d, at = b.at, av = b.av, x = b.x, gp = b.gp }, "av")
  local m = { id = a.id, a = base.a, t = base.t, d = ab.d, at = ab.at, av = ab.av, x = ab.x, gp = ab.gp }
  local names = {}
  for name in pairs(a.s or {}) do names[name] = true end
  for name in pairs(b.s or {}) do names[name] = true end
  for name in pairs(names) do
    local sa, sb = a.s and a.s[name], b.s and b.s[name]
    m.s = m.s or {}
    m.s[name] = (sa and sb) and pick(sa, sb, "sv") or sa or sb
  end
  return Dungeons.Sanitize(m)
end

function Dungeons.Hash(r)
  return Codec.Hash(Codec.Serialize(r))
end

-- Guarda una quedada recibida. Devuelve: cambió, la de antes, la nueva y si la nuestra tenía más.
function Dungeons.Apply(incoming, now)
  local list = runs()
  if not list then return false end
  local cur = list[incoming.id]
  local merged = Dungeons.Merge(cur, incoming)
  local behind = Codec.Serialize(merged) ~= Codec.Serialize(incoming)
  if cur and Codec.Serialize(cur) == Codec.Serialize(merged) then return false, cur, cur, behind end
  if not cur and Dungeons.IsGone(merged, now) then return false, nil, nil, false end
  list[incoming.id] = merged
  return true, cur, merged, behind
end

---------------------------------------------------------------------------
-- Estado
---------------------------------------------------------------------------
function Dungeons.IsGone(r, now)
  local ended = r.x or (r.at + Dungeons.ACTIVE_FOR)
  return now > ended + Dungeons.KEEP_FOR
end

-- "open" (se puede apuntar), "cancelled" o "past".
function Dungeons.State(r, now)
  if r.x then return "cancelled" end
  if now > r.at + Dungeons.ACTIVE_FOR then return "past" end
  return "open"
end

-- Apuntados activos, ordenados por prioridad: en línea, con nivel, y por orden de llegada.
function Dungeons.SignUps(r)
  local list = {}
  local dg = Dungeons.Dungeon(r.d)
  for name, su in pairs(r.s or {}) do
    if not su.o and su.r and su.r > 0 then
      list[#list + 1] = {
        name = name, roles = su.r, level = su.l, class = su.c, st = su.st or su.sv or 0,
        levelOk = not su.l or su.l >= dg.min,
        online = name == ns.Me() or (ns.Guild and ns.Guild.IsOnline(name)) or false,
      }
    end
  end
  table.sort(list, function(x, y)
    if x.online ~= y.online then return x.online end
    if x.levelOk ~= y.levelOk then return x.levelOk end
    if x.st ~= y.st then return x.st < y.st end
    return x.name < y.name
  end)
  return list
end

-- Elige el grupo: 1 tanque, 1 sanador y 3 DPS. Prueba todas las combinaciones de tanque y
-- sanador (alguien puede valer para varios roles) y se queda con la que llena más huecos;
-- si empatan, con la de los mejor colocados (en línea, con nivel, los primeros en apuntarse).
-- prefer = { [nombre] = 1 (delante de todos) o 3 (detrás de todos) } (para "Rehacer grupo").
function Dungeons.Pick(r, prefer)
  local list = Dungeons.SignUps(r)
  if Dungeons.IsLeveling(r) then
    -- Grupo de leveo: sin roles, los primeros en apuntarse (quien lo propone delante).
    table.sort(list, function(a, b)
      local pa, pb = prefer and prefer[a.name] or 2, prefer and prefer[b.name] or 2
      if pa ~= pb then return pa < pb end
      if (a.name == r.a) ~= (b.name == r.a) then return a.name == r.a end
      return (a.st or 0) < (b.st or 0)
    end)
    local gp = { d = {}, b = {} }
    for i, su in ipairs(list) do
      if i == 1 then gp.t = su.name
      elseif i == 2 then gp.h = su.name
      elseif i <= Dungeons.LEVELING_SIZE then gp.d[#gp.d + 1] = su.name
      else gp.b[#gp.b + 1] = su.name end
    end
    if #gp.d == 0 then gp.d = nil end
    if #gp.b == 0 then gp.b = nil end
    return gp
  end
  if prefer and next(prefer) then
    local groups = { {}, {}, {} }
    for _, su in ipairs(list) do
      local gi = prefer[su.name] or 2
      groups[gi][#groups[gi] + 1] = su
    end
    list = {}
    for _, grp in ipairs(groups) do
      for _, su in ipairs(grp) do list[#list + 1] = su end
    end
  end
  local tanks, heals = { false }, { false }
  for i, su in ipairs(list) do
    su.rank = i
    if hasRole(su.roles, Dungeons.TANK) then tanks[#tanks + 1] = su end
    if hasRole(su.roles, Dungeons.HEAL) then heals[#heals + 1] = su end
  end
  local best
  for _, tank in ipairs(tanks) do
    for _, heal in ipairs(heals) do
      if not tank or not heal or tank ~= heal then
        local dps, cost = {}, 0
        for _, su in ipairs(list) do
          if #dps < Dungeons.GROUP_SIZE.dps and su ~= tank and su ~= heal and hasRole(su.roles, Dungeons.DPS) then
            dps[#dps + 1] = su
            cost = cost + su.rank
          end
        end
        local filled = (tank and 1 or 0) + (heal and 1 or 0) + #dps
        cost = cost + (tank and tank.rank or 0) + (heal and heal.rank or 0)
        if not best or filled > best.filled or (filled == best.filled and cost < best.cost) then
          best = { tank = tank or nil, heal = heal or nil, dps = dps, filled = filled, cost = cost }
        end
      end
    end
  end
  local gp = { d = {} , b = {} }
  local chosen = {}
  if best and best.tank then gp.t = best.tank.name chosen[best.tank] = true end
  if best and best.heal then gp.h = best.heal.name chosen[best.heal] = true end
  for _, su in ipairs(best and best.dps or {}) do
    gp.d[#gp.d + 1] = su.name
    chosen[su] = true
  end
  for _, su in ipairs(list) do
    if not chosen[su] then gp.b[#gp.b + 1] = su.name end
  end
  if #gp.d == 0 then gp.d = nil end
  if #gp.b == 0 then gp.b = nil end
  return gp
end

-- Lo que falta en un grupo hecho: { "tanque", "sanador", "2 DPS" }.
function Dungeons.Missing(gp)
  local missing = {}
  if not gp then return missing end
  if not gp.t then missing[#missing + 1] = "tanque" end
  if not gp.h then missing[#missing + 1] = "sanador" end
  local dps = Dungeons.GROUP_SIZE.dps - #(gp.d or {})
  if dps > 0 then missing[#missing + 1] = dps .. " DPS" end
  return missing
end

-- ¿En qué rol voy en el grupo? ("tanque", "sanador", "DPS", "suplente" o nil)
function Dungeons.MyPlace(r, name)
  local gp = r and r.gp
  if not gp then return nil end
  name = name or ns.Me()
  if Dungeons.IsLeveling(r) then
    -- en los de leveo no hay papeles: o vas en el grupo o de suplente
    if gp.t == name or gp.h == name then return "en el grupo" end
    for _, n in ipairs(gp.d or {}) do if n == name then return "en el grupo" end end
    for _, n in ipairs(gp.b or {}) do if n == name then return "suplente" end end
    return nil
  end
  if gp.t == name then return "tanque" end
  if gp.h == name then return "sanador" end
  for _, n in ipairs(gp.d or {}) do if n == name then return "DPS" end end
  for _, n in ipairs(gp.b or {}) do if n == name then return "suplente" end end
  return nil
end

---------------------------------------------------------------------------
-- Acciones (devuelven la quedada cambiada o nil y un error)
---------------------------------------------------------------------------
local function signUpBlock(r, me, roles, now)
  r.s = r.s or {}
  local su = r.s[me] or {}
  if su.o or not su.st then su.st = now end
  su.r = roles
  su.l = Dungeons.MyLevel()
  su.c = Dungeons.MyClass()
  su.o = nil
  su.sv = bump(su.sv, now)
  r.s[me] = su
end

-- opts = { d = mazmorra, at = hora (nil = ahora), roles = mis roles (0 = no voy) }
function Dungeons.Create(opts, now)
  local list, g = runs()
  local me = ns.Me()
  if not list or not me then return nil, "No estás en una hermandad." end
  if not Dungeons.BY_ID[tonumber(opts.d) or 0] then return nil, "Elige una mazmorra." end
  g.runSeq = (g.runSeq or 0) + 1
  local id = me .. ":" .. Codec.EncodeUInt(now) .. Codec.EncodeUInt(g.runSeq % 1024)
  local r = { id = id, a = me, t = now, d = tonumber(opts.d), at = max(now, tonumber(opts.at) or now), av = now }
  local roles = tonumber(opts.roles) or 0
  if roles > 0 then signUpBlock(r, me, roles, now) end
  r = Dungeons.Sanitize(r)
  list[id] = r
  return r
end

local function getRun(id)
  local list = runs()
  return list and list[id]
end

function Dungeons.SignUp(id, roles, now)
  local r, me = getRun(id), ns.Me()
  if not r then return nil, "La quedada ya no existe." end
  if Dungeons.State(r, now) ~= "open" then return nil, "La quedada ya no está abierta." end
  roles = floor(tonumber(roles) or 0) % 8
  local allowed = Dungeons.RolesFor(Dungeons.MyClass())
  local ok = 0
  for _, role in ipairs(Dungeons.ROLES) do
    if hasRole(roles, role.bit) and hasRole(allowed, role.bit) then ok = ok + role.bit end
  end
  if ok == 0 then return nil, "Elige al menos un rol que pueda hacer tu clase." end
  signUpBlock(r, me, ok, now)
  return r
end

function Dungeons.Leave(id, now)
  local r, me = getRun(id), ns.Me()
  local su = r and r.s and r.s[me]
  if not su or su.o then return nil, "No estabas apuntado." end
  su.o = true
  su.sv = bump(su.sv, now)
  return r
end

-- Nombres cortos (en minúsculas) de los que ya están en mi grupo del juego.
local function partyNames()
  local set = {}
  for i = 1, 4 do
    local name = UnitName and UnitName("party" .. i)
    if name then set[ns.ShortName(name):lower()] = true end
  end
  return set
end

-- Los cinco del grupo hecho, en orden: tanque, sanador y los DPS.
function Dungeons.Members(gp)
  local names = {}
  if not gp then return names end
  if gp.t then names[#names + 1] = gp.t end
  if gp.h then names[#names + 1] = gp.h end
  for _, name in ipairs(gp.d or {}) do names[#names + 1] = name end
  return names
end

-- Hacer el grupo. Si ya estaba hecho ("Rehacer grupo"): los apuntados que ya están en tu grupo
-- del juego van primero (se quedan) y los elegidos que NO han entrado pasan detrás de todos:
-- así entran los suplentes en su sitio.
-- (Antes salía siempre el mismo grupo, porque la elección no cambia si no cambian los apuntados,
-- y parecía que el botón no hacía nada.)
function Dungeons.MakeGroup(id, now)
  local r, me = getRun(id), ns.Me()
  if not r then return nil, "La quedada ya no existe." end
  if r.a ~= me then return nil, "Solo quien la propuso puede hacer el grupo." end
  if Dungeons.State(r, now) ~= "open" then return nil, "La quedada ya no está abierta." end
  local prefer
  if r.gp then
    prefer = {}
    local party = partyNames()
    -- Si aún no has invitado a nadie, no se castiga a nadie por "no haber entrado".
    if next(party) then
      for _, name in ipairs(Dungeons.Members(r.gp)) do
        if name ~= me and not party[ns.ShortName(name):lower()] then prefer[name] = 3 end
      end
    end
    for name in pairs(r.s or {}) do
      if name == me or party[ns.ShortName(name):lower()] then prefer[name] = 1 end
    end
  end
  local gp = Dungeons.Pick(r, prefer)
  if not gp.t and not gp.h and not gp.d then return nil, "Aún no se ha apuntado nadie." end
  local function same(a, b)
    local function norm(x) -- mismo grupo aunque los DPS o suplentes salgan en otro orden
      local gp = Dungeons.Sanitize({ id = r.id, a = r.a, d = r.d, gp = x }).gp
      if gp.d then table.sort(gp.d) end
      if gp.b then table.sort(gp.b) end
      return Codec.Serialize(gp)
    end
    return norm(a) == norm(b)
  end
  if r.gp and same(gp, r.gp) then
    return nil, "No hay más gente apuntada con esos roles: el grupo sale igual."
  end
  r.gp = gp
  r.av = bump(r.av, now)
  return r
end

function Dungeons.Cancel(id, now)
  local r, me = getRun(id), ns.Me()
  if not r then return nil, "La quedada ya no existe." end
  if r.a ~= me then return nil, "Solo quien la propuso puede cancelarla." end
  r.x = now
  r.av = bump(r.av, now)
  return r
end

-- "HECHO": el grupo ya fue; la quedada se cierra para todos (como cancelada, que las versiones
-- anteriores del addon ya entienden: así no hace falta cambiar lo que se envía).
function Dungeons.Finish(id, now)
  local r, me = getRun(id), ns.Me()
  if not r then return nil, "La quedada ya no existe." end
  if r.a ~= me then return nil, "Solo quien la propuso puede cerrarla." end
  if not r.gp then return nil, "Primero haz el grupo." end
  return Dungeons.Cancel(id, now)
end

---------------------------------------------------------------------------
-- Invitar
---------------------------------------------------------------------------
-- El fallo de la 0.28 ("No se encuentra al jugador 'Xepe CAMWOWEU4Realm4PvP'"): en WoW Forever
-- cada uno guarda su nombre con el reino que le da su juego (GetNormalizedRealmName), que es un
-- reino interno distinto para cada uno ("CAMWOWEU4Realm4PvP", "CAMWOWEU5Realm2PvP"...). Como
-- no coincidía con el mío, se invitaba con "Nombre-ReinoInterno" y el servidor no lo encuentra.
-- Ahora se prueba primero solo con el nombre y, si el juego dice que no lo encuentra, con el
-- nombre tal como sale en la lista de la hermandad y por último con "Nombre-Reino".
local function inviteCandidates(full)
  local short = ns.ShortName(full)
  local list, seen = {}, {}
  local function add(n)
    if n and n ~= "" and not seen[n] then
      seen[n] = true
      list[#list + 1] = n
    end
  end
  -- Con apellido (WoW Forever) primero el nombre completo; si no, el corto.
  if ns.TellName then add(ns.TellName(full)) end
  add(short)
  local info = ns.Guild and ns.Guild.Find and ns.Guild.Find(full)
  if info and info.raw then add(info.raw) end
  local realm = full:match("%-(.+)$")
  if realm and realm ~= ns.Realm() then add(short .. "-" .. realm) end
  return list
end

local pending = {} -- ["nombre corto en minúsculas"] = { list, i, t }

local function sendInvite(name)
  local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if invite then pcall(invite, name) end
end

function Dungeons.Invite(r)
  if not r or not r.gp then return 0 end
  if not ((C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit) then return 0 end
  local me, n = ns.Me(), 0
  local party = partyNames()
  for _, name in ipairs(Dungeons.Members(r.gp)) do
    local short = ns.ShortName(name)
    if name ~= me and not party[short:lower()] and not (ns.Demo and ns.Demo.IsDemo(name)) then
      local list = inviteCandidates(name)
      pending[short:lower()] = { list = list, i = 1, t = GetTime and GetTime() or 0 }
      sendInvite(list[1])
      n = n + 1
    end
  end
  return n
end

-- "No se encuentra al jugador '%s'." del juego, convertido en patrón para leer el nombre.
local notFoundPattern
do
  local text = ERR_BAD_PLAYER_NAME_S
  if type(text) == "string" and text:find("%s", 1, true) then
    notFoundPattern = "^" .. text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
  end
end

ns.On("CHAT_MSG_SYSTEM", function(msg)
  if not next(pending) or type(msg) ~= "string" then return end
  if issecretvalue and issecretvalue(msg) then return end -- el juego a veces no deja leerlo
  local who = notFoundPattern and msg:match(notFoundPattern)
  if not who and (msg:find("encuentra", 1, true) or msg:lower():find("not found", 1, true)) then
    who = msg:match("'([^']+)'")
  end
  if not who then return end
  local short = (who:match("^([^%s%-]+)") or who):lower()
  local p = pending[short]
  if not p then return end
  local now = GetTime and GetTime() or 0
  if now - p.t > 20 or p.i >= #p.list then
    pending[short] = nil
    if p.i >= #p.list then
      ns.Print("no he podido invitar a %s. Invítalo a mano (clic derecho en su nombre).", p.list[1])
    end
    return
  end
  p.i, p.t = p.i + 1, now
  sendInvite(p.list[p.i])
end)

-- Borra las quedadas viejas.
function Dungeons.Purge(now)
  local list, g = runs()
  if not list then return end
  for id, r in pairs(list) do
    if Dungeons.IsGone(r, now) then
      list[id] = nil
      if g.runAlerted then g.runAlerted[id] = nil end
    end
  end
end

---------------------------------------------------------------------------
-- Grupos de leveo automáticos: si vas en grupo con alguien más de la hermandad por una zona de
-- leveo, el jefe del grupo lo publica solo en Grupos (para que se pueda unir quien ande cerca) y
-- los demás de la hermandad que van en ese grupo se apuntan solos. Si el grupo se deshace o
-- cambiáis de zona, se cancela (o se cambia de zona).
---------------------------------------------------------------------------
-- La zona de leveo en la que estoy (o nil).
function Dungeons.CurrentZone()
  if IsInInstance then
    local inside = IsInInstance()
    if inside then return nil end
  end
  local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local name = GetRealZoneText and GetRealZoneText()
  for _, z in ipairs(Dungeons.ZONES) do
    if (mapId and z.map == mapId) or (name and name == z.name) then return z.id end
  end
end

-- Los de la hermandad que van en mi grupo (sin contarme).
local function guildmatesInParty()
  local out = {}
  if not UnitName then return out end
  for i = 1, 4 do
    local name = UnitName("party" .. i)
    if name and name ~= UNKNOWNOBJECT then
      local _, full = ns.Guild.Find(ns.FullName(name))
      if full then out[full] = true end
    end
  end
  return out
end

local function amLeader()
  if UnitIsGroupLeader then return UnitIsGroupLeader("player") end
  return IsPartyLeader and IsPartyLeader() or false
end

function Dungeons.CheckAutoLeveling()
  local c, g = ns.MyChar(), ns.G()
  if not c or not g or not ns.Sync then return end
  local now, me = ns.Now(), ns.Me()
  local list = runs()
  local mates = guildmatesInParty()
  local zone = Dungeons.CurrentZone()
  local together = next(mates) ~= nil and zone ~= nil
  -- El mío (si soy el jefe): publicarlo, cambiarlo de zona o cancelarlo.
  local mine = c.autoRun and list and list[c.autoRun]
  if mine and (mine.x or Dungeons.State(mine, now) ~= "open") then mine, c.autoRun = nil, nil end
  if mine and (not together or not amLeader() or mine.d ~= zone) then
    ns.Sync.CancelRun(mine.id)
    mine, c.autoRun = nil, nil
  end
  if together and amLeader() and not mine then
    local allowed = Dungeons.RolesFor(Dungeons.MyClass())
    local r = ns.Sync.CreateRun({ d = zone, roles = allowed > 0 and allowed or Dungeons.DPS })
    if r then c.autoRun = r.id end
  end
  -- Los de los demás: si el jefe de mi grupo ha publicado uno en esta zona, me apunto.
  if together and list then
    for id, r in pairs(list) do
      local su = r.s and r.s[me]
      if mates[r.a] and r.d == zone and not r.x and Dungeons.State(r, now) == "open" and not (su and not su.o) then
        local allowed = Dungeons.RolesFor(Dungeons.MyClass())
        ns.Sync.SignUpRun(id, allowed > 0 and allowed or Dungeons.DPS)
      end
    end
  end
end

local function scheduleAuto() ns.Coalesce("autoLeveling", 3, Dungeons.CheckAutoLeveling) end
ns.On("GROUP_ROSTER_UPDATE", scheduleAuto)
ns.On("PARTY_MEMBERS_CHANGED", scheduleAuto)
ns.On("ZONE_CHANGED_NEW_AREA", scheduleAuto)
ns.Listen("LOGIN", function()
  if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(60, function() ns.SafeCall(Dungeons.CheckAutoLeveling) end) end
end)
