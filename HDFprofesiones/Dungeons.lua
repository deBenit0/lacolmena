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
Dungeons.BY_ID = {}
for _, dg in ipairs(Dungeons.LIST) do Dungeons.BY_ID[dg.id] = dg end

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
function Dungeons.Pick(r)
  local list = Dungeons.SignUps(r)
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

function Dungeons.MakeGroup(id, now)
  local r, me = getRun(id), ns.Me()
  if not r then return nil, "La quedada ya no existe." end
  if r.a ~= me then return nil, "Solo quien la propuso puede hacer el grupo." end
  if Dungeons.State(r, now) ~= "open" then return nil, "La quedada ya no está abierta." end
  local gp = Dungeons.Pick(r)
  if not gp.t and not gp.h and not gp.d then return nil, "Aún no se ha apuntado nadie." end
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

-- Invita a los elegidos (lo hace quien la propuso, al pulsar el botón).
local function inviteName(full)
  local realm = full:match("%-(.+)$")
  if realm and realm ~= ns.Realm() then return full end
  return ns.ShortName(full)
end

function Dungeons.Invite(r)
  if not r or not r.gp then return 0 end
  local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if not invite then return 0 end
  local me, n = ns.Me(), 0
  local names = { r.gp.t, r.gp.h }
  for _, name in ipairs(r.gp.d or {}) do names[#names + 1] = name end
  for i = 1, 5 do
    local name = names[i]
    if name and name ~= me and not (ns.Demo and ns.Demo.IsDemo(name)) then
      pcall(invite, inviteName(name))
      n = n + 1
    end
  end
  return n
end

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
