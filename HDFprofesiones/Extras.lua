-- Extras:
--  1. Recetas que faltan: lo que la hermandad pide y nadie sabe hacer (ni recolectar), y aviso
--     a quien lo pidió cuando alguien aprende la receta.
--  2. Anunciar en el chat de hermandad un pedido u oferta (para los que no tienen el addon).
--  3. Mis estadísticas: entregas, recibidos, aportaciones y propinas, por semana.
local _, ns = ...
local Data = ns.Data
local Extras = {}
ns.Extras = Extras

---------------------------------------------------------------------------
-- 1. Recetas que faltan
---------------------------------------------------------------------------
-- ¿Hay alguien (que no sea "except") que lo fabrique o lo recolecte?
local function someoneMakes(key, except)
  local rec = Data.GetIndex()[key]
  for _, cr in ipairs(rec and rec.crafters or {}) do
    if cr.n ~= except then return true end
  end
  for _, name in ipairs((Data.GatherersOf(key))) do
    if name ~= except then return true end
  end
  return false
end
Extras.SomeoneMakes = someoneMakes

-- Lista de lo que se pide y nadie da: { key, askers = { nombres }, t = lo más reciente }.
function Extras.MissingRecipes(now)
  local g = ns.G()
  local byKey = {}
  local function add(key, who, t)
    if not key or someoneMakes(key, who) then return end
    local e = byKey[key] or { key = key, askers = {}, seen = {}, t = 0 }
    if not e.seen[who] then
      e.seen[who] = true
      e.askers[#e.askers + 1] = who
    end
    e.t = math.max(e.t, t or 0)
    byKey[key] = e
  end
  for _, r in pairs(g and g.requests or {}) do
    if Data.IsActiveState(Data.RequestInfo(r, now).state) then add(r.k, r.a, r.t) end
  end
  for _, n in ipairs(ns.Social.Needs(now)) do
    if n.left > 0 then add("i" .. n.id, n.owner, n.t) end
  end
  local list = {}
  for _, e in pairs(byKey) do
    e.seen = nil
    table.sort(e.askers)
    list[#list + 1] = e
  end
  table.sort(list, function(a, b) return a.t > b.t end)
  return list
end

-- Aviso a quien lo pidió cuando alguien aprende la receta que faltaba.
local lastMissing
function Extras.CheckLearned()
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  if not g or not me then return end
  local current = {}
  for _, e in ipairs(Extras.MissingRecipes(now)) do current[e.key] = e end
  if lastMissing then
    for key, e in pairs(lastMissing) do
      if not current[key] and someoneMakes(key, me) then
        local mine = false
        for _, who in ipairs(e.askers) do if who == me then mine = true end end
        if mine and ns.Alerts then
          local rec = Data.GetIndex()[key]
          local who = rec and rec.crafters[1] and ns.ShortName(rec.crafters[1].n) or "Alguien"
          local _, icon = ns.KeyInfo(key)
          ns.Alerts.Push({ page = "board", icon = icon,
            text = string.format("%s ya sabe hacer %s (lo pediste)", who, ns.KeyLabel(key)) })
        end
      end
    end
  end
  lastMissing = current
end
ns.Listen("DATA_CHANGED", function(kind)
  if kind == "entry" or kind == "request" or kind == "demo" then
    ns.Coalesce("missingRecipes", 2, function() ns.SafeCall(Extras.CheckLearned) end)
  end
end)

---------------------------------------------------------------------------
-- 2. Anunciar en el chat de hermandad
---------------------------------------------------------------------------
Extras.ANNOUNCE_GAP = 60 -- el mismo anuncio, como mucho una vez por minuto
local announced = {}

local function sendGuild(text)
  -- Forever: C_ChatInfo.SendChatMessage (la global solo queda como obsoleta).
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if not send or not (IsInGuild and IsInGuild()) then return false end
  return pcall(send, text:sub(1, 255), "GUILD")
end

local function itemText(key, q)
  local name, _, link = ns.KeyInfo(key)
  return string.format("%dx %s", q, link or ("[" .. (name or ns.KeyName(key)) .. "]"))
end

function Extras.AnnounceText(kind, obj)
  local tag = "[" .. ns.TITLE .. "] "
  if kind == "request" then
    local text = tag .. "Pido " .. itemText(obj.k, obj.q)
    if obj.g then text = text .. " (propina " .. math.floor(obj.g / 10000) .. " oro)" end
    return text .. ". ¿Quién puede hacerlo? Susurradme."
  elseif kind == "offer" then
    local text = tag .. "Ofrezco " .. itemText("i" .. obj.id, obj.free or obj.q)
    text = text .. ((obj.g and obj.g > 0) and (" a " .. math.floor(obj.g / 10000) .. " oro c/u") or " gratis")
    return text .. ". Susurradme si lo queréis."
  elseif kind == "need" then
    return tag .. "La hermandad necesita " .. itemText("i" .. obj.id, obj.left or obj.q)
      .. ". Si podéis aportar, mandádselo a " .. ns.ShortName(obj.owner) .. "."
  end
end

-- Devuelve true si se ha anunciado.
function Extras.Announce(kind, obj, id)
  local now = GetTime()
  id = kind .. ":" .. tostring(id)
  if announced[id] and now - announced[id] < Extras.ANNOUNCE_GAP then
    ns.Print("ya lo has anunciado hace poco: espera un minuto.")
    return false
  end
  local text = Extras.AnnounceText(kind, obj)
  if not text or not sendGuild(text) then return false end
  announced[id] = now
  return true
end

---------------------------------------------------------------------------
-- 3. Mis estadísticas (por personaje, por semana)
---------------------------------------------------------------------------
Extras.STAT_NAMES = {
  { id = "delivered", label = "Pedidos entregados" },
  { id = "offers", label = "Ofertas entregadas" },
  { id = "donated", label = "Aportaciones a la hermandad" },
  { id = "received", label = "Cosas recibidas" },
  { id = "tips", label = "Propinas ganadas", money = true },
}

local function stats()
  local c = ns.MyChar()
  if not c then return nil end
  c.stats = c.stats or { total = {}, weeks = {} }
  return c.stats
end

function Extras.AddStat(id, n)
  local s = stats()
  if not s or not n or n == 0 then return end
  local week = ns.Social.Week(ns.Now())
  s.total[id] = (s.total[id] or 0) + n
  s.weeks[week] = s.weeks[week] or {}
  s.weeks[week][id] = (s.weeks[week][id] or 0) + n
  -- solo se guardan las 8 últimas semanas
  for w in pairs(s.weeks) do
    if w < week - 8 then s.weeks[w] = nil end
  end
end

-- { this = { id = n }, last = {...}, total = {...} }
function Extras.Stats(now)
  local s = stats() or { total = {}, weeks = {} }
  local week = ns.Social.Week(now)
  return { this = s.weeks[week] or {}, last = s.weeks[week - 1] or {}, total = s.total }
end

-- Propina de un pedido que acabo de completar (la cobra el contra reembolso): una vez por pedido.
function Extras.CountTip(r)
  local c = ns.MyChar()
  local cm = r and r.c and r.c[ns.Me()]
  if not c or not cm or not r.g or Data.DeliveredOf(cm) < (cm.n or 1) then return end
  c.tipped = c.tipped or {}
  if c.tipped[r.id] then return end
  c.tipped[r.id] = ns.Now()
  Extras.AddStat("tips", math.floor(r.g * (cm.n or 0) / math.max(1, r.q)))
  for id, t in pairs(c.tipped) do
    if ns.Now() - t > 30 * 86400 then c.tipped[id] = nil end
  end
end
