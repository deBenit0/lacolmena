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
  local r = roster[name]
  return r and r.online or false
end

function Guild.Info(name)
  return roster[name]
end

function Guild.MarkSeen(name)
  local g = ns.G()
  if g and name then g.seen[name] = ns.Now() end
end

-- Última vez que se vio al personaje (segundos relativos), o nil si no se sabe.
function Guild.LastSeen(name)
  local r = roster[name]
  if r and r.online then return ns.Now() end
  local g = ns.G()
  local seen = g and g.seen[name]
  local fromRoster = r and r.seen
  if seen and fromRoster then return math.max(seen, fromRoster) end
  return seen or fromRoster
end

-- ¿Aceptamos datos de este personaje? Si vemos la lista completa, solo de miembros.
function Guild.Accepts(name)
  if name == ns.Me() then return true end
  if not Guild.full then return true end
  return roster[name] ~= nil
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
  local removed = false
  for name in pairs(g.entries) do
    if not roster[name] then
      g.entries[name] = nil
      removed = true
    end
  end
  for id, r in pairs(g.requests) do
    if not roster[r.a] then
      g.requests[id] = nil
      removed = true
    end
  end
  for name in pairs(g.seen) do
    if not roster[name] then g.seen[name] = nil end
  end
  if removed then
    ns.Data.indexDirty = true
    ns.Fire("DATA_CHANGED", "cleanup")
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
  local fresh, count = {}, 0
  for i = 1, total do
    local name, _, rankIndex, level, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
    if name then
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
      fresh[name] = { online = online and true or false, rank = rankIndex, level = level, class = classFile, seen = seen }
    end
  end
  wipe(roster)
  for name, r in pairs(fresh) do roster[name] = r end
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
