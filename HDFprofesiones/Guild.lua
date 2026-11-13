-- Lista de la hermandad: quién está conectado, cuándo se le vio y quién se ha ido.
local _, ns = ...
local Guild = {}
ns.Guild = Guild

local roster = {}
Guild.roster = roster
Guild.full = false -- true si vemos a todos los miembros (incluidos los desconectados)

function Guild.IsMember(name)
  return roster[name] ~= nil
end

function Guild.IsOnline(name)
  local r = roster[name] or (type(name) == "string" and Guild.Find(name)) or nil
  if r then return r.online end
  return ns.Demo and ns.Demo.IsOnline(name) or false
end

-- Ficha de la lista. Se busca también con otro reino interno o con apellido: si no, a un
-- oficial con otro reino nadie lo reconocía como oficial y se ignoraban sus cierres.
function Guild.Info(name)
  if type(name) ~= "string" then return nil end
  return roster[name] or (Guild.Find(name))
end

function Guild.MarkSeen(name)
  local g = ns.G()
  if g and name then g.seen[name] = ns.Now() end
end

-- Última vez que se vio al personaje (segundos relativos), o nil si no se sabe.
function Guild.LastSeen(name)
  local r = Guild.Info(name)
  if r and r.online then return ns.Now() end
  if ns.Demo and ns.Demo.IsDemo(name) then return ns.Demo.LastSeen(name) end
  local g = ns.G()
  local seen = g and g.seen[name]
  local fromRoster = r and r.seen
  if seen and fromRoster then return math.max(seen, fromRoster) end
  return seen or fromRoster
end

-- ¿Aceptamos datos de este personaje? Si vemos la lista completa, solo de miembros.
-- Nombre comparable: sin mayúsculas, espacios, guiones ni apóstrofos en el reino.
local function loose(name)
  local who, realm = tostring(name or ""):match("^([^%-]+)%-?(.*)$")
  if not who then return "" end
  return (who .. "-" .. realm:gsub("[%s%-']", "")):lower()
end
Guild.Loose = loose

function Guild.Accepts(name)
  if type(name) ~= "string" then return false end
  if name == ns.Me() then return true end
  if ns.Demo and ns.Demo.IsDemo(name) then return false end -- nadie puede hacerse pasar por uno de ejemplo
  if not Guild.full then return true end
  if roster[name] ~= nil then return true end
  -- Si la lista escribe los nombres de otra forma (ni siquiera me encuentra a mí), no me fío de
  -- ella para descartar: mejor aceptar que perder los pedidos de todos.
  if not roster[ns.Me()] then return true end
  -- Con otro reino interno o con apellido: se busca igual que para invitar.
  return Guild.Find(name) ~= nil
end

-- Busca a alguien en la lista aunque su nombre lleve otro reino: primero el nombre exacto, luego
-- el comparable y por último el nombre corto (si solo hay uno así).
function Guild.Find(name)
  if type(name) ~= "string" then return nil end
  if roster[name] then return roster[name], name end
  local want = loose(name)
  for n, r in pairs(roster) do
    if loose(n) == want then return r, n end
  end
  local short = ns.ShortName(name):lower()
  short = short:match("^(%S+)") or short -- «Nombre Apellido» de copias antiguas: el nombre de pila
  local found, foundName
  for n, r in pairs(roster) do
    if ns.ShortName(n):lower() == short then
      if found then return nil end -- hay dos con ese nombre: no adivinar
      found, foundName = r, n
    end
  end
  return found, foundName
end

function Guild.RequestRoster()
  if not (IsInGuild and IsInGuild()) then return end
  if C_GuildInfo and C_GuildInfo.GuildRoster then
    C_GuildInfo.GuildRoster()
  elseif GuildRoster then
    GuildRoster()
  end
end

local function cleanup()
  -- Solo borramos si vemos la lista entera; si no, podríamos borrar a los desconectados.
  local g = ns.G()
  if not g or not Guild.full then return end
  -- Si en la lista no estoy yo, los nombres vienen en otro formato (reino escrito distinto...):
  -- no limpiar nada, o se borrarían datos buenos.
  local me = ns.Me()
  if not me or not roster[me] then return end
  local removed = false
  for name, e in pairs(g.entries) do
    if not Guild.Find(name) and not e.demo and name ~= me then
      g.entries[name] = nil
      removed = true
    end
  end
  for id, r in pairs(g.requests) do
    if not Guild.Find(r.a) and not r.demo and r.a ~= me then
      g.requests[id] = nil
      g.alerted[id], g.thanked[id] = nil, nil
      if g.karmaSeen then g.karmaSeen[id] = nil end
      removed = true
    end
  end
  for name in pairs(g.seen) do
    if not Guild.Find(name) then g.seen[name] = nil end
  end
  if removed then
    ns.Data.indexDirty = true
    ns.Fire("DATA_CHANGED", "cleanup")
  end
end

-- Texto de los nombres repetidos («Exagono Exagonal y Exagono Pérez»), o nil si no hay.
function Guild.DupesText()
  local parts = {}
  for _, raws in pairs(Guild.dupes or {}) do
    local names = {}
    for _, r in ipairs(raws) do names[#names + 1] = (r:match("^([^%-]+)") or r) end
    parts[#parts + 1] = table.concat(names, " y ")
  end
  if #parts == 0 then return nil end
  table.sort(parts)
  return table.concat(parts, "; ")
end

-- Avisa una vez por sesión de cada nombre de pila repetido.
local dupesWarned = {}
function Guild.WarnDupes()
  for name, raws in pairs(Guild.dupes or {}) do
    if not dupesWarned[name] then
      dupesWarned[name] = true
      local names = {}
      for _, r in ipairs(raws) do names[#names + 1] = (r:match("^([^%-]+)") or r) end
      local text = string.format("Hay %d en la hermandad que se llaman %s (%s): el addon aún no los distingue "
        .. "y sus pedidos, ofertas y correos pueden liarse. Díselo a quien lleva el addon.", #raws, ns.ShortName(name),
        table.concat(names, ", "))
      if ns.Alerts and ns.Alerts.Push then ns.Alerts.Push({ type = "other", page = "guild", text = text }) else ns.Print(text) end
    end
  end
end

function Guild.Refresh()
  if not (IsInGuild and IsInGuild()) then
    wipe(roster)
    Guild.full = false
    return
  end
  local total = GetNumGuildMembers() or 0
  local now = ns.Now()
  local fresh, count, dupes = {}, 0, {}
  for i = 1, total do
    local name, rankName, rankIndex, level, className, zone, note, officerNote, online, _, classFile = GetGuildRosterInfo(i)
    if name then
      local raw = name -- tal como lo da el juego (para invitar)
      name = ns.FullName(name)
      count = count + 1
      local seen
      if online then
        seen = now
      elseif GetGuildRosterLastOnline then
        local years, months, days, hours = GetGuildRosterLastOnline(i)
        if years then
          seen = now - ((((years or 0) * 365 + (months or 0) * 30 + (days or 0)) * 24 + (hours or 0)) * 3600)
        end
      end
      -- Dos con el mismo nombre de pila («Exagono Exagonal» y «Exagono Pérez»): el addon los
      -- guarda igual y se pisan. Se apunta para avisar.
      if fresh[name] and fresh[name].raw ~= raw then
        dupes[name] = dupes[name] or { fresh[name].raw }
        table.insert(dupes[name], raw)
      end
      fresh[name] = { online = online and true or false, rank = rankIndex, level = level, class = classFile, seen = seen,
        raw = raw, rankName = rankName, className = className, zone = zone, index = i,
        note = note, officerNote = officerNote }
    end
  end
  wipe(roster)
  for name, r in pairs(fresh) do roster[name] = r end
  Guild.dupes = dupes
  Guild.full = count > 0 and count == total
  Guild.count = count
  cleanup()
  ns.Fire("ROSTER_UPDATED")
end

ns.On("GUILD_ROSTER_UPDATE", function()
  ns.Coalesce("roster", 1, Guild.Refresh)
end)
ns.Listen("LOGIN", function()
  Guild.RequestRoster()
  C_Timer.NewTicker(60, function() ns.SafeCall(Guild.RequestRoster) end)
end)
