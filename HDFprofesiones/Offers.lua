-- Ofertas: un miembro ofrece objetos concretos (bolsas, pociones...) que ya tiene. Los demás
-- pulsan "Lo quiero", el que ofrece se lo manda por correo y se apunta solo.
--
-- Todo viaja dentro de la ficha de cada jugador (cada uno solo escribe en la suya):
--   of = { [objeto] = { q = cuántos quedan, g = precio por unidad en cobre, t = publicada } }
--   cl = { ["Dueño-Reino:objeto"] = { q = cuántos quiero, t = cuándo, b = enviados antes } }
--   od = { [quien lo pidió] = { [objeto] = { n = enviados en total, t = último envío } } }
local _, ns = ...
local Data = ns.Data
local Offers = {}
ns.Offers = Offers

Offers.OFFER_TTL = 14 * 86400 -- una oferta dura 14 días
Offers.CLAIM_TTL = 48 * 3600  -- un "lo quiero" sin entregar caduca a las 48 h
Offers.KEEP_SENT = 7 * 86400  -- los envíos se recuerdan 7 días
Offers.MAX_OFFERS = 20

local floor, max, min = math.floor, math.max, math.min

-- Ofrecer fabricar: cada uno marca unas pocas recetas suyas y salen en «Se ofrece», una sola fila
-- por objeto con todos los que lo ofrecen (así no se llena de ofertas repetidas). En la ficha:
--   fb = { [receta "i123"/"e456"] = { g = precio en cobre, m = 1 si pone él los materiales, t = cuándo } }
Offers.CRAFT_TTL = 30 * 86400 -- se renuevan con un clic
Offers.MAX_CRAFTS = 15

local function cleanCrafts(fb)
  if type(fb) ~= "table" then return nil end
  local out, n = {}, 0
  for k, o in pairs(fb) do
    if n >= Offers.MAX_CRAFTS then break end
    if type(k) == "string" and k:match("^[ie]%d+$") and type(o) == "table" then
      local g = tonumber(o.g)
      out[k] = { g = (g and g > 0) and floor(g) or nil, m = (o.m == 1) and 1 or nil, t = tonumber(o.t) or 0,
        nt = ns.CleanNote(o.nt) }
      n = n + 1
    end
  end
  return n > 0 and out or nil
end

local function publish()
  ns.Sync.PublishMine()
  ns.Fire("DATA_CHANGED", "offer")
end

local function key(owner, id)
  return owner .. ":" .. id
end
Offers.Key = key

function Offers.ParseKey(k)
  local owner, id = tostring(k or ""):match("^(.+):(%d+)$")
  return owner, tonumber(id)
end

---------------------------------------------------------------------------
-- Validación (para la ficha)
---------------------------------------------------------------------------
function Offers.SanitizeInto(out, e)
  out.fb = cleanCrafts(e.fb)
  if type(e.of) == "table" then
    local of, any = {}, false
    for id, o in pairs(e.of) do
      id = tonumber(id)
      local q = type(o) == "table" and tonumber(o.q)
      if id and id > 0 and q and q >= 1 then
        of[floor(id)] = { q = floor(q), g = tonumber(o.g) and floor(tonumber(o.g)) or nil, t = tonumber(o.t) or 0,
          nt = ns.CleanNote(o.nt) }
        any = true
      end
    end
    out.of = any and of or nil
  end
  if type(e.cl) == "table" then
    local cl, any = {}, false
    for k, c in pairs(e.cl) do
      local q = type(c) == "table" and tonumber(c.q)
      if type(k) == "string" and Offers.ParseKey(k) and q and q >= 1 then
        cl[k] = { q = floor(q), t = tonumber(c.t) or 0, b = tonumber(c.b) or 0 }
        any = true
      end
    end
    out.cl = any and cl or nil
  end
  if type(e.od) == "table" then
    local od, any = {}, false
    for who, items in pairs(e.od) do
      if type(who) == "string" and type(items) == "table" then
        for id, d in pairs(items) do
          id = tonumber(id)
          local n = type(d) == "table" and tonumber(d.n)
          if id and n and n >= 1 then
            od[who] = od[who] or {}
            od[who][floor(id)] = { n = floor(n), t = tonumber(d.t) or 0 }
            any = true
          end
        end
      end
    end
    out.od = any and od or nil
  end
end

---------------------------------------------------------------------------
-- Mis datos (en mi personaje) y lo que se publica en la ficha
---------------------------------------------------------------------------
local function mine()
  local c = ns.MyChar()
  if not c then return nil end
  c.offers = c.offers or {}
  c.claims = c.claims or {}
  c.sent = c.sent or {}
  c.crafts = c.crafts or {}
  return c
end

-- ¿Sé todavía hacer esta receta?
local function knows(c, k)
  for _, prof in pairs(c.profs or {}) do
    if prof.recipes and prof.recipes[k] then return true end
  end
  return false
end

-- Enviado por "owner" a "who" de un objeto (lo que dice la ficha del dueño).
function Offers.SentTo(owner, who, id)
  local g = ns.G()
  local e = g and g.entries[owner]
  local d = e and e.od and e.od[who] and e.od[who][id]
  if owner == ns.Me() then
    local c = mine()
    d = c and c.sent[who] and c.sent[who][id] or d
  end
  return d and d.n or 0
end

-- ¿Sigue pendiente un "lo quiero"? Devuelve lo que falta por enviar.
function Offers.ClaimLeft(owner, who, id, claim, now)
  if not claim or now > (claim.t or 0) + Offers.CLAIM_TTL then return 0 end
  return max(0, claim.q - Offers.ClaimGot(owner, who, id, claim))
end

-- Lo que ya me ha llegado de un "lo quiero": lo enviado menos lo que ya había antes de pedirlo
-- (b). Si el registro de envíos se borró (caduca a los días) y queda por debajo de b, se cuenta
-- desde cero: antes salía negativo y el "lo quiero" se quedaba colgado pidiendo de más.
function Offers.ClaimGot(owner, who, id, claim)
  local sent = Offers.SentTo(owner, who, id)
  local base = claim and claim.b or 0
  if sent < base then base = 0 end
  return sent - base
end

-- Lo que entra en mi ficha: ofertas vivas, "lo quiero" pendientes y envíos recientes.
function Offers.BuildInto(e, now)
  local c = mine()
  if not c then return end
  local of = {}
  for id, o in pairs(c.offers) do
    if o.q > 0 and now <= o.t + Offers.OFFER_TTL then
      of[id] = { q = o.q, g = o.g, t = o.t, nt = o.nt }
    else
      c.offers[id] = nil
    end
  end
  if next(of) then e.of = of end
  local cl = {}
  for k, claim in pairs(c.claims) do
    local owner, id = Offers.ParseKey(k)
    if owner and Offers.ClaimLeft(owner, ns.Me(), id, claim, now) > 0 then
      cl[k] = { q = claim.q, t = claim.t, b = claim.b }
    else
      c.claims[k] = nil
    end
  end
  if next(cl) then e.cl = cl end
  local od = {}
  for who, items in pairs(c.sent) do
    for id, d in pairs(items) do
      if now <= d.t + Offers.KEEP_SENT then
        od[who] = od[who] or {}
        od[who][id] = { n = d.n, t = d.t }
      else
        items[id] = nil
      end
    end
    if not next(items) then c.sent[who] = nil end
  end
  if next(od) then e.od = od end
  local fb, n = {}, 0
  for k, o in pairs(c.crafts) do
    -- (lo que se liga al recogerlo se quita: no se le puede dar a nadie)
    if now <= (o.t or 0) + Offers.CRAFT_TTL and knows(c, k) and n < Offers.MAX_CRAFTS and not ns.IsSoulbound(k) then
      fb[k] = { g = o.g, m = o.m, t = o.t, nt = o.nt }
      n = n + 1
    else
      c.crafts[k] = nil
    end
  end
  if n > 0 then e.fb = fb end
end

---------------------------------------------------------------------------
-- Consultas
---------------------------------------------------------------------------
-- Todas las ofertas vivas: { owner, id, key, q (en total), g, t, claims = { {name, left, t} },
--   pending (suma de lo pedido), free (lo que queda sin pedir), myClaim (lo que pido yo) }
function Offers.List(now)
  local g, me, list = ns.G(), ns.Me(), {}
  if not g then return list end
  -- "lo quiero" de todos, por oferta
  local claimsBy = {}
  for name, e in pairs(g.entries) do
    local cl = e.cl
    if name == me then
      local c = mine()
      cl = c and c.claims
    end
    for k, claim in pairs(cl or {}) do
      claimsBy[k] = claimsBy[k] or {}
      claimsBy[k][#claimsBy[k] + 1] = { name = name, claim = claim }
    end
  end
  for owner, e in pairs(g.entries) do
    local of = e.of
    if owner == me then
      local c = mine()
      of = c and c.offers
    end
    for id, o in pairs(of or {}) do
      local removed = ns.Social and ns.Social.IsOfferRemoved(key(owner, id), o.t)
      if o.q > 0 and now <= (o.t or 0) + Offers.OFFER_TTL and not removed then
        local k = key(owner, id)
        local item = { owner = owner, id = id, key = k, q = o.q, g = o.g, t = o.t, claims = {}, pending = 0, myClaim = 0,
          demo = e.demo, nt = o.nt }
        for _, cb in ipairs(claimsBy[k] or {}) do
          local left = Offers.ClaimLeft(owner, cb.name, id, cb.claim, now)
          if left > 0 then
            item.claims[#item.claims + 1] = { name = cb.name, left = left, t = cb.claim.t }
            item.pending = item.pending + left
            if cb.name == me then item.myClaim = left end
          end
        end
        table.sort(item.claims, function(a, b) return a.t < b.t end)
        item.free = max(0, item.q - item.pending)
        list[#list + 1] = item
      end
    end
  end
  return list
end

-- Recetas que se ofrecen fabricar, juntas por objeto:
--   { key, t (la más reciente), mine, crafters = { { name, g, m, t } } (en línea y baratos primero) }
function Offers.CraftList(now)
  local g, me, groups, list = ns.G(), ns.Me(), {}, {}
  if not g then return list end
  for owner, e in pairs(g.entries) do
    local fb = e.fb
    if owner == me then
      local c = mine()
      fb = c and c.crafts
    end
    for k, o in pairs(fb or {}) do
      local removed = ns.Social and ns.Social.IsOfferRemoved(owner .. ":" .. k, o.t)
      if now <= (o.t or 0) + Offers.CRAFT_TTL and not removed then
        local grp = groups[k]
        if not grp then
          grp = { key = k, crafters = {}, t = 0 }
          groups[k] = grp
          list[#list + 1] = grp
        end
        grp.crafters[#grp.crafters + 1] = { name = owner, g = o.g, m = o.m, t = o.t or 0, nt = o.nt }
        if (o.t or 0) > grp.t then grp.t = o.t or 0 end
        if owner == me then grp.mine, grp.myT = true, o.t or 0 end
      end
    end
  end
  for _, grp in ipairs(list) do
    table.sort(grp.crafters, function(a, b)
      local ao, bo = ns.Guild.IsOnline(a.name) and 1 or 0, ns.Guild.IsOnline(b.name) and 1 or 0
      if ao ~= bo then return ao > bo end
      if (a.g or 0) ~= (b.g or 0) then return (a.g or 0) < (b.g or 0) end
      return a.name < b.name
    end)
  end
  return list
end

function Offers.Knows(k)
  local c = mine()
  return c and knows(c, k) or false
end

function Offers.MyCrafts()
  local c = mine()
  return c and c.crafts or {}
end

function Offers.CountCrafts()
  local n = 0
  for _ in pairs(Offers.MyCrafts()) do n = n + 1 end
  return n
end

-- Ofrecer fabricar una receta mía (o cambiar su precio y quién pone los materiales).
-- note: nil = dejar la que tenía; "" = quitarla.
function Offers.SetCraft(k, price, mats, now, note)
  local c = mine()
  if not c or not ns.G() then return nil, "No estás en una hermandad." end
  if type(k) ~= "string" or not k:match("^[ie]%d+$") or not knows(c, k) then
    return nil, "No conozco esa receta tuya."
  end
  if ns.IsSoulbound(k) then return nil, "Lo que hace esa receta se liga al recogerlo: se quedaría en tu personaje." end
  if not c.crafts[k] and Offers.CountCrafts() >= Offers.MAX_CRAFTS then
    return nil, "Ya ofreces " .. Offers.MAX_CRAFTS .. " recetas: quita alguna antes."
  end
  price = tonumber(price)
  local old = c.crafts[k]
  if note == nil then note = old and old.nt end
  c.crafts[k] = { g = (price and price > 0) and floor(price) or nil, m = mats and 1 or nil, t = now, nt = ns.CleanNote(note) }
  publish()
  return true
end

function Offers.RemoveCraft(k)
  local c = mine()
  if not c or not c.crafts[k] then return nil, "No ofreces esa receta." end
  c.crafts[k] = nil
  publish()
  return true
end

-- Vuelve a contar los 30 días de todas mis recetas ofrecidas.
function Offers.RenewCrafts(now)
  local c = mine()
  if not c then return nil end
  local me = ns.Me()
  for k, o in pairs(c.crafts) do
    -- la que quitó un oficial no vuelve al renovar (sí si la ofreces otra vez a mano)
    if ns.Social and ns.Social.IsOfferRemoved(me .. ":" .. k, o.t) then
      c.crafts[k] = nil
    else
      o.t = now
    end
  end
  publish()
  return true
end

function Offers.CountMine()
  local c = mine()
  local n = 0
  for _, o in pairs(c and c.offers or {}) do if o.q > 0 then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------
-- Acciones (devuelven true o nil y un error)
---------------------------------------------------------------------------
-- Ofrecer "q" unidades de un objeto, con precio por unidad (0 o nil = gratis).
-- note: nil = dejar la que tenía; "" = quitarla.
function Offers.Create(id, q, price, now, note)
  local c = mine()
  if not c or not ns.G() then return nil, "No estás en una hermandad." end
  id, q = tonumber(id), floor(tonumber(q) or 0)
  if not id or id <= 0 then return nil, "Elige un objeto (arrástralo o mayús+clic en él)." end
  if q < 1 then return nil, "Indica cuántos ofreces." end
  if ns.IsSoulbound("i" .. id) then return nil, "Ese objeto se liga al recogerlo: no se puede dar a nadie." end
  if not c.offers[id] and Offers.CountMine() >= Offers.MAX_OFFERS then
    return nil, "Ya tienes " .. Offers.MAX_OFFERS .. " ofertas."
  end
  price = tonumber(price)
  if note == nil then note = c.offers[id] and c.offers[id].nt end
  c.offers[id] = { q = min(q, Data.MAX_QTY), g = (price and price > 0) and floor(price) or nil, t = now, nt = ns.CleanNote(note) }
  publish()
  return true
end

function Offers.Remove(id)
  local c = mine()
  if not c or not c.offers[id] then return nil, "No tienes esa oferta." end
  c.offers[id] = nil
  publish()
  return true
end

-- "Lo quiero": pido "q" unidades de la oferta.
function Offers.Claim(k, q, now)
  local c, me = mine(), ns.Me()
  local owner, id = Offers.ParseKey(k)
  if not c or not owner then return nil, "Esa oferta ya no existe." end
  if owner == me then return nil, "Es tu propia oferta." end
  local offer
  for _, it in ipairs(Offers.List(now)) do
    if it.key == k then offer = it end
  end
  if not offer then return nil, "Esa oferta ya no existe." end
  local available = offer.free + offer.myClaim
  q = min(available, floor(tonumber(q) or 1))
  if q < 1 then return nil, "Ya está todo pedido." end
  c.claims[k] = { q = q, t = now, b = Offers.SentTo(owner, me, id) }
  publish()
  if offer.demo and ns.Demo then ns.Demo.OnClaim(owner, id, q) end
  return true
end

function Offers.Unclaim(k)
  local c = mine()
  if not c or not c.claims[k] then return nil, "No lo habías pedido." end
  c.claims[k] = nil
  publish()
  return true
end

-- He enviado un correo: si es para alguien que quiere algo de mis ofertas, lo apunto.
-- Descuenta de "items" lo que use. Devuelve lo apuntado: { {id, n} }.
function Offers.RegisterMail(recipient, items, now)
  local c, g, me = mine(), ns.G(), ns.Me()
  local done = {}
  if not c or not g or not recipient then return done end
  local who
  for name in pairs(g.entries) do
    if name:lower() == recipient:lower() then who = name end
  end
  local e = who and g.entries[who]
  if not e or not e.cl then return done end
  for id, o in pairs(c.offers) do
    local claim = e.cl[key(me, id)]
    local left = Offers.ClaimLeft(me, who, id, claim, now)
    local credit = min(left, items[id] or 0, o.q)
    if credit > 0 then
      c.sent[who] = c.sent[who] or {}
      local d = c.sent[who][id] or { n = 0 }
      d.n = d.n + credit
      d.t = now
      c.sent[who][id] = d
      o.q = o.q - credit
      if o.q <= 0 then c.offers[id] = nil end
      items[id] = items[id] - credit
      done[#done + 1] = { id = id, n = credit, who = who }
    end
  end
  if #done > 0 then publish() end
  return done
end

-- «Ya lo he enviado» (a mano): por si no se detectó el correo o el comercio (lo mandó un alt,
-- se lo dio en mano...). Apunta lo que quedaba de su «lo quiero» como entregado.
function Offers.MarkSent(who, id, now)
  local c, g, me = mine(), ns.G(), ns.Me()
  if not c or not g or not who then return 0 end
  local o = c.offers[id]
  local e = g.entries[who]
  local claim = e and e.cl and e.cl[key(me, id)]
  if not o or not claim then return 0 end
  local credit = min(Offers.ClaimLeft(me, who, id, claim, now), o.q)
  if credit <= 0 then return 0 end
  c.sent[who] = c.sent[who] or {}
  local d = c.sent[who][id] or { n = 0 }
  d.n, d.t = d.n + credit, now
  c.sent[who][id] = d
  o.q = o.q - credit
  if o.q <= 0 then c.offers[id] = nil end
  ns.Extras.AddStat("offers", 1)
  publish()
  return credit
end

-- Recibido: cuando el que ofrece me ha enviado todo lo que pedí, quito mi "lo quiero",
-- le apunto el karma (+1 para él, -1 para mí) y aviso.
function Offers.CheckReceived(now)
  local c, g, me = mine(), ns.G(), ns.Me()
  if not c or not g then return end
  local changed = false
  for k, claim in pairs(c.claims) do
    local owner, id = Offers.ParseKey(k)
    local got = owner and Offers.ClaimGot(owner, me, id, claim) or 0
    if owner and got >= claim.q then
      c.claims[k] = nil
      ns.Extras.AddStat("received", 1)
      g.karma = g.karma or {}
      g.karma[me] = g.karma[me] or { kc = {}, kd = 0 }
      local karma = g.karma[me]
      karma.kc = karma.kc or {}
      karma.kc[owner] = (karma.kc[owner] or 0) + Data.KARMA_POINT
      karma.kd = (karma.kd or 0) + Data.KARMA_POINT
      if ns.History then ns.History.Add("o", "i" .. id, claim.q, owner, now) end
      changed = true
      if ns.Alerts then
        local _, icon = ns.KeyInfo("i" .. id)
        ns.Alerts.Push({ page = "board", icon = icon,
          text = string.format("%s te ha enviado %dx %s por correo", ns.DisplayName(owner), claim.q, ns.KeyLabel("i" .. id)) })
      end
    end
  end
  if changed then publish() end
end

-- Aviso al que ofrece cuando alguien quiere algo suyo.
function Offers.CheckClaims(name)
  local g, me = ns.G(), ns.Me()
  local e = g and g.entries[name]
  if not e or not e.cl or name == me then return end
  g.claimSeen = g.claimSeen or {}
  for k, claim in pairs(e.cl) do
    local owner, id = Offers.ParseKey(k)
    local seenKey = name .. "|" .. k .. "|" .. (claim.t or 0)
    if owner == me and not g.claimSeen[seenKey] and Offers.ClaimLeft(me, name, id, claim, ns.Now()) > 0 then
      g.claimSeen[seenKey] = ns.Now()
      if ns.Alerts then
        local _, icon = ns.KeyInfo("i" .. id)
        ns.Alerts.Push({ page = "board", icon = icon,
          text = string.format("%s quiere %dx %s de tu oferta", ns.DisplayName(name), claim.q, ns.KeyLabel("i" .. id)) })
      end
    end
  end
  for sk, t in pairs(g.claimSeen) do
    if ns.Now() - t > Offers.CLAIM_TTL * 2 then g.claimSeen[sk] = nil end
  end
end

ns.Listen("DATA_CHANGED", function(kind, name)
  if kind ~= "entry" or not name then return end
  ns.SafeCall(Offers.CheckClaims, name)
  ns.Coalesce("offersReceived", 1, function() ns.SafeCall(Offers.CheckReceived, ns.Now()) end)
end)
