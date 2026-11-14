-- Hermandad: personajes alternativos, herramientas de oficiales, necesidades de la hermandad
-- (con donaciones) y reconocimientos (ayudas de la semana).
--
-- Todo viaja dentro de la ficha de cada jugador (cada uno solo escribe en la suya):
--   mn = mi personaje principal (si este es un alt)
--   wk = { w = semana, n = ayudas esta semana, pn = ayudas la semana anterior }
--   dn = { ["Oficial-Reino:objeto"] = { n = donados en total, t } }
-- Y solo cuentan si lo publica un oficial (rango 0 o 1 en la hermandad):
--   an = { x = anuncio, t }    mc = { [petición] = cerrada por moderación (hora) }
--   mp = { [petición] = prioridad (hora) }    nd = { [objeto] = { q = cuántos hacen falta, t } }
--   mo = { ["Dueño-Reino:objeto"] o ["Dueño-Reino:i<objeto>"] = oferta quitada por un oficial (hora) }
local _, ns = ...
local Social = {}
ns.Social = Social

Social.OFFICER_RANK = 1          -- rango 0 (líder) y 1 (oficiales)
Social.NEED_TTL = 30 * 86400     -- una necesidad dura 30 días
Social.ANNOUNCE_MAX = 200        -- letras de un anuncio
Social.INACTIVE_DAYS = 14

local floor, max, min = math.floor, math.max, math.min

---------------------------------------------------------------------------
-- Oficiales
---------------------------------------------------------------------------
function Social.IsOfficer(name)
  if not name then return false end
  if ns.Demo and ns.Demo.IsDemo(name) then return ns.Demo.IsOfficer(name) end
  local info = ns.Guild.Info(name)
  return info ~= nil and info.rank ~= nil and info.rank <= Social.OFFICER_RANK
end

function Social.AmOfficer()
  return Social.IsOfficer(ns.Me())
end

---------------------------------------------------------------------------
-- Validación y publicación en la ficha
---------------------------------------------------------------------------
local function cleanTimeMap(src)
  if type(src) ~= "table" then return nil end
  local out, any = {}, false
  for k, t in pairs(src) do
    if type(k) == "string" and tonumber(t) then
      out[k] = tonumber(t)
      any = true
    end
  end
  return any and out or nil
end

function Social.SanitizeInto(out, e)
  if type(e.mn) == "string" and e.mn ~= e.n then out.mn = e.mn end
  -- personajes de la misma cuenta (para confirmar que un alt es de verdad de ese principal)
  if type(e.al) == "table" then
    local al = {}
    for i = 1, math.min(#e.al, 12) do
      if type(e.al[i]) == "string" then al[#al + 1] = e.al[i] end
    end
    if #al > 0 then out.al = al end
  end
  if type(e.wk) == "table" and tonumber(e.wk.w) then
    out.wk = { w = floor(tonumber(e.wk.w)), n = floor(tonumber(e.wk.n) or 0), pn = floor(tonumber(e.wk.pn) or 0) }
  end
  if type(e.dn) == "table" then
    local dn, any = {}, false
    for k, d in pairs(e.dn) do
      local n = type(d) == "table" and tonumber(d.n)
      if type(k) == "string" and ns.Offers.ParseKey(k) and n and n >= 1 then
        dn[k] = { n = floor(n), t = tonumber(d.t) or 0, nt = tonumber(d.nt) }
        any = true
      end
    end
    out.dn = any and dn or nil
  end
  if type(e.an) == "table" and type(e.an.x) == "string" and e.an.x ~= "" then
    out.an = { x = e.an.x:sub(1, Social.ANNOUNCE_MAX), t = tonumber(e.an.t) or 0 }
  end
  out.mc = cleanTimeMap(e.mc)
  out.mp = cleanTimeMap(e.mp)
  out.mo = cleanTimeMap(e.mo)
  if type(e.nd) == "table" then
    local nd, any = {}, false
    for id, need in pairs(e.nd) do
      id = tonumber(id)
      local q = type(need) == "table" and tonumber(need.q)
      if id and id > 0 and q and q >= 1 then
        nd[floor(id)] = { q = floor(q), t = tonumber(need.t) or 0 }
        any = true
      end
    end
    out.nd = any and nd or nil
  end
end

local function mine()
  local c = ns.MyChar()
  if not c then return nil end
  c.donated = c.donated or {}
  c.mc = c.mc or {}
  c.mp = c.mp or {}
  c.mo = c.mo or {}
  c.needs = c.needs or {}
  return c
end

function Social.Week(now)
  return floor((now + ns.EPOCH - 4 * 86400) / (7 * 86400)) -- semanas que empiezan en lunes
end

local function myWeek(now)
  local c = mine()
  local w = Social.Week(now)
  c.week = c.week or { w = w, n = 0, pn = 0 }
  if c.week.w ~= w then
    c.week.pn = (c.week.w == w - 1) and c.week.n or 0
    c.week.n = 0
    c.week.w = w
  end
  return c.week
end

function Social.BuildInto(e, now)
  local c = mine()
  if not c then return end
  local main = Social.MyMain()
  if main and main ~= e.n then e.mn = main end
  local chars = Social.MyChars()
  if #chars > 1 then
    e.al = {}
    for i = 1, math.min(#chars, 12) do e.al[i] = chars[i].name end
  end
  local wk = myWeek(now)
  if wk.n > 0 or wk.pn > 0 then e.wk = { w = wk.w, n = wk.n, pn = wk.pn } end
  local dn = {}
  for k, d in pairs(c.donated) do
    if now - (d.t or 0) <= Social.NEED_TTL * 2 then dn[k] = { n = d.n, t = d.t, nt = d.nt } else c.donated[k] = nil end
  end
  if next(dn) then e.dn = dn end
  -- Lo de oficial se publica siempre; los demás solo lo tienen en cuenta si lo soy.
  if c.announce and c.announce.x ~= "" then e.an = { x = c.announce.x, t = c.announce.t } end
  local function times(src, ttl)
    local out
    for id, t in pairs(src) do
      if now - t <= ttl then
        out = out or {}
        out[id] = t
      else
        src[id] = nil
      end
    end
    return out
  end
  e.mc = times(c.mc, ns.Data.REQUEST_TTL * 2)
  e.mp = times(c.mp, ns.Data.REQUEST_TTL * 2)
  e.mo = times(c.mo, ns.Offers.CRAFT_TTL * 2)
  local nd
  for id, need in pairs(c.needs) do
    if now - need.t <= Social.NEED_TTL then
      nd = nd or {}
      nd[id] = { q = need.q, t = need.t }
    else
      c.needs[id] = nil
    end
  end
  e.nd = nd
end

---------------------------------------------------------------------------
-- Personajes alternativos
---------------------------------------------------------------------------
-- Mis personajes de esta hermandad (los que han entrado con el addon), el de más nivel primero.
function Social.MyChars()
  local list = {}
  local key = ns.guildKey
  for name, c in pairs(ns.db and ns.db.chars or {}) do
    if c.guild == key or name == ns.Me() then
      list[#list + 1] = { name = name, level = c.level or 0 }
    end
  end
  table.sort(list, function(a, b)
    if a.level ~= b.level then return a.level > b.level end
    return a.name < b.name
  end)
  return list
end

-- Mi principal: el que elegí en Mis cosas o, si no, el de más nivel.
function Social.MyMain()
  local chosen = ns.db and ns.db.settings.main and ns.db.settings.main[ns.guildKey or ""]
  local chars = Social.MyChars()
  for _, ch in ipairs(chars) do
    if ch.name == chosen then return chosen end
  end
  return chars[1] and chars[1].name or ns.Me()
end

function Social.SetMyMain(name)
  ns.db.settings.main = ns.db.settings.main or {}
  ns.db.settings.main[ns.guildKey or ""] = name
  ns.Sync.PublishMine()
  ns.Fire("DATA_CHANGED", "main")
end

-- La persona detrás de un personaje (su principal, o él mismo).
function Social.MainOf(name)
  if not name then return name end
  if name == ns.Me() then return Social.MyMain() end
  local g = ns.G()
  local e = g and g.entries[name]
  local main = e and e.mn
  if not main or main == name then return name end
  -- Solo vale si el principal también lo dice (los dos son de la misma cuenta): así nadie
  -- puede declararse alt de otro para cambiarle el karma.
  local mainEntry = g.entries[main]
  for _, other in ipairs(mainEntry and mainEntry.al or {}) do
    if other == name then return main end
  end
  return name
end

-- "Bea (Ana)" si Bea es un alt de Ana; si no, "Bea".
function Social.Who(name)
  local main = Social.MainOf(name)
  if main and main ~= name then return ns.DisplayName(name) .. " (" .. ns.DisplayName(main) .. ")" end
  return ns.DisplayName(name)
end

---------------------------------------------------------------------------
-- Datos de oficiales (con caché: se recalcula al cambiar algo)
---------------------------------------------------------------------------
local cache
local function officerData()
  if cache then return cache end
  cache = { mc = {}, mp = {}, mo = {}, announcements = {} }
  local g = ns.G()
  if not g then return cache end
  for name, e in pairs(g.entries) do
    local src = e
    if name == ns.Me() then
      local c = mine()
      src = { mc = c and c.mc, mp = c and c.mp, mo = c and c.mo, an = c and c.announce }
    end
    if Social.IsOfficer(name) then
      for id, t in pairs(src.mc or {}) do cache.mc[id] = t end
      for id, t in pairs(src.mp or {}) do cache.mp[id] = t end
      for k, t in pairs(src.mo or {}) do cache.mo[k] = math.max(cache.mo[k] or 0, t) end
      if src.an and src.an.x and src.an.x ~= "" then
        cache.announcements[#cache.announcements + 1] = { name = name, x = src.an.x, t = src.an.t or 0 }
      end
    end
  end
  table.sort(cache.announcements, function(a, b) return a.t > b.t end)
  return cache
end
function Social.Invalidate() cache = nil end
ns.Listen("DATA_CHANGED", Social.Invalidate)
ns.Listen("ROSTER_UPDATED", Social.Invalidate)

function Social.IsModClosed(id) return officerData().mc[id] end
function Social.IsPriority(id) return officerData().mp[id] ~= nil end
-- ¿Un oficial ha quitado esta oferta? Solo si la quitó después de ponerla: si el dueño la vuelve
-- a poner, sale otra vez.
function Social.IsOfferRemoved(k, t)
  local at = officerData().mo[k]
  return at ~= nil and at >= (t or 0)
end
function Social.Announcement() return officerData().announcements[1] end

-- Acciones de oficial.
local function publish()
  Social.Invalidate()
  ns.Sync.PublishMine()
  ns.Fire("DATA_CHANGED", "social")
end

function Social.SetAnnouncement(text, now)
  if not Social.AmOfficer() then return nil, "Solo los oficiales pueden publicar anuncios." end
  local c = mine()
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  c.announce = text ~= "" and { x = text:sub(1, Social.ANNOUNCE_MAX), t = now } or nil
  publish()
  return true
end

function Social.ModClose(id, now)
  if not Social.AmOfficer() then return nil, "Solo los oficiales pueden cerrar pedidos de otros." end
  mine().mc[id] = now
  publish()
  return true
end

-- Quitar una oferta de otro: k = Offers.Key(dueño, objeto) para «de sus bolsas» o
-- "Dueño-Reino:i123" para «ofrece fabricarlo».
function Social.ModRemoveOffer(k, now)
  if not Social.AmOfficer() then return nil, "Solo los oficiales pueden quitar ofertas de otros." end
  mine().mo[k] = now
  publish()
  return true
end

function Social.SetPriority(id, on, now)
  if not Social.AmOfficer() then return nil, "Solo los oficiales pueden marcar prioridad." end
  mine().mp[id] = on and now or nil
  publish()
  return true
end

---------------------------------------------------------------------------
-- Necesidades de la hermandad y donaciones
---------------------------------------------------------------------------
-- Lista: { owner, id, key, q, t, given, left, donors = { {name, n} } }
function Social.Needs(now)
  local g, list = ns.G(), {}
  if not g then return list end
  -- donaciones de todos, por necesidad
  local given = {}
  for name, e in pairs(g.entries) do
    local dn = e.dn
    if name == ns.Me() then dn = mine() and mine().donated end
    for k, d in pairs(dn or {}) do
      given[k] = given[k] or {}
      given[k][#given[k] + 1] = { name = name, n = d.n, t = d.t, nt = d.nt }
    end
  end
  for owner, e in pairs(g.entries) do
    local nd = e.nd
    if owner == ns.Me() then nd = mine() and mine().needs end
    if Social.IsOfficer(owner) then
      for id, need in pairs(nd or {}) do
        if now - (need.t or 0) <= Social.NEED_TTL then
          local key = owner .. ":" .. id
          local item = { owner = owner, id = id, key = key, q = need.q, t = need.t, given = 0, donors = {} }
          for _, d in ipairs(given[key] or {}) do
            -- solo cuenta lo aportado a ESTA necesidad (si se vuelve a crear, empieza de cero)
            if (d.nt and d.nt == need.t) or (not d.nt and (d.t or 0) >= (need.t or 0)) then
              item.given = item.given + d.n
              item.donors[#item.donors + 1] = { name = d.name, n = d.n }
            end
          end
          table.sort(item.donors, function(a, b) return a.n > b.n end)
          item.left = max(0, item.q - item.given)
          list[#list + 1] = item
        end
      end
    end
  end
  table.sort(list, function(a, b)
    if (a.left > 0) ~= (b.left > 0) then return a.left > 0 end
    return a.t > b.t
  end)
  return list
end

function Social.AddNeed(id, q, now)
  if not Social.AmOfficer() then return nil, "Solo los oficiales pueden añadir necesidades." end
  id, q = tonumber(id), floor(tonumber(q) or 0)
  if not id or q < 1 then return nil, "Elige un objeto y cuántos hacen falta." end
  local c = mine()
  c.needs[id] = { q = min(q, ns.Data.MAX_QTY), t = now }
  -- lo donado antes no cuenta para la nueva
  publish()
  return true
end

function Social.RemoveNeed(id)
  local c = mine()
  if not c or not c.needs[id] then return nil, "No tienes esa necesidad." end
  c.needs[id] = nil
  publish()
  return true
end

-- He enviado un correo: si es a un oficial que necesita algo de lo que mando, lo apunto
-- como donación. Descuenta de "items" lo usado. Devuelve { {id, n, owner} }.
function Social.RegisterMail(recipient, items, now)
  local c = mine()
  local done = {}
  if not c or not recipient then return done end
  for _, need in ipairs(Social.Needs(now)) do
    if need.owner:lower() == recipient:lower() and need.owner ~= ns.Me() then
      local credit = min(items[need.id] or 0, need.left)
      if credit > 0 then
        local d = c.donated[need.key] or { n = 0 }
        if d.nt ~= need.t then d = { n = 0 } end -- otra necesidad con el mismo objeto: de cero
        d.n, d.t, d.nt = d.n + credit, now, need.t
        c.donated[need.key] = d
        items[need.id] = items[need.id] - credit
        done[#done + 1] = { id = need.id, n = credit, owner = need.owner }
        if ns.History then ns.History.Add("a", "i" .. need.id, credit, need.owner, now) end
      end
    end
  end
  if #done > 0 then publish() end
  return done
end

---------------------------------------------------------------------------
-- Ayudas de la semana (pedidos enviados, ofertas y donaciones) y miembro de la semana
---------------------------------------------------------------------------
-- Una ayuda por cada cosa (pedido, oferta a alguien, necesidad) y semana, aunque se mande
-- en varios correos: así no se inflan troceando los envíos.
function Social.AddHelps(ids)
  local c = mine()
  if not c or type(ids) ~= "table" then return end
  local wk = myWeek(ns.Now())
  c.helped = c.helped or {}
  local added = 0
  for _, id in ipairs(ids) do
    if c.helped[id] ~= wk.w then
      c.helped[id] = wk.w
      added = added + 1
    end
  end
  for id, w in pairs(c.helped) do
    if w < wk.w - 1 then c.helped[id] = nil end
  end
  if added > 0 then
    wk.n = wk.n + added
    ns.Sync.PublishMine()
  end
end

function Social.AddHelp(n)
  local ids = {}
  for i = 1, n or 0 do ids[i] = "anon:" .. ns.Now() .. ":" .. i end
  Social.AddHelps(ids)
end

-- Ayudas por persona (sumando sus alts): { {name = principal, n} }, de más a menos.
-- which = "this" (esta semana) o "last" (la anterior).
function Social.Ranking(which, now)
  local g = ns.G()
  local week = Social.Week(now)
  local byPerson = {}
  for name, e in pairs(g and g.entries or {}) do
    local wk = e.wk
    if name == ns.Me() then wk = myWeek(now) end
    local n = 0
    if wk then
      if which == "this" then
        n = (wk.w == week) and wk.n or 0
      else
        n = (wk.w == week) and wk.pn or ((wk.w == week - 1) and wk.n or 0)
      end
    end
    if n > 0 then
      local person = Social.MainOf(name)
      byPerson[person] = (byPerson[person] or 0) + n
    end
  end
  local list = {}
  for person, n in pairs(byPerson) do list[#list + 1] = { name = person, n = n } end
  table.sort(list, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.name < b.name
  end)
  return list
end

function Social.MemberOfTheWeek(now)
  return Social.Ranking("last", now)[1]
end

---------------------------------------------------------------------------
-- Inactivos y quién no tiene el addon (para oficiales)
---------------------------------------------------------------------------
function Social.Inactive(now)
  local list, noAddon = {}, {}
  local g = ns.G()
  for name, info in pairs(ns.Guild.roster) do
    local seen = ns.Guild.LastSeen(name)
    if not info.online and seen and now - seen > Social.INACTIVE_DAYS * 86400 then
      list[#list + 1] = { name = name, days = floor((now - seen) / 86400) }
    end
    if g and not g.entries[name] then noAddon[#noAddon + 1] = name end
  end
  table.sort(list, function(a, b) return a.days > b.days end)
  table.sort(noAddon)
  return list, noAddon
end

-- Guardar en qué hermandad está cada personaje mío (para saber cuáles son míos aquí).
ns.Listen("GUILD_CHANGED", function(key)
  local c = ns.MyChar()
  if c then c.guild = key end
end)
