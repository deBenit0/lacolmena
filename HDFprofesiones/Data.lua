-- Datos compartidos de la hermandad: fichas de fabricantes, materiales y peticiones.
--
-- Ficha de fabricante (una por personaje, la publica su dueño):
--   { n = "Nombre-Reino", v = versión, c = clase, l = nivel, u = no disponible,
--     av = versión del addon, th = { [fabricante] = encargos confirmados por este autor },
--     p = { [profesión] = { r = nivel, m = máximo, i = objetos, e = encantamientos,
--                           cd = { [receta] = fin del cooldown } } } }
--
-- Petición:
--   { id, a = autor, t = creada, k = "i<objeto>"/"e<encantamiento>", pk = profesión,
--     q = cantidad, av = versión del bloque del autor, m = aporta materiales,
--     g = pago en cobre, pi = { [objeto] = n } pago en objetos, to = para quién,
--     x = cerrada, rn = renovada,
--     c = { [fabricante] = { n = prometidas, cv = versión, rl = soltada,
--                            d = entregadas (lo confirma el autor), dv = versión,
--                            s = enviadas por correo (lo apunta el fabricante), sv = versión } } }
-- Cada parte tiene un único dueño y su propia versión, así que dos copias se
-- fusionan siempre igual, en cualquier orden (no hay conflictos).
local _, ns = ...
local Codec = ns.Codec
local Data = {}
ns.Data = Data

Data.REQUEST_TTL = 7 * 86400 -- las peticiones caducan a los 7 días
Data.COMMIT_TTL = 48 * 3600  -- un "lo hago yo" sin entregar caduca a las 48 h
Data.MAX_OPEN = 10           -- peticiones abiertas por jugador
Data.KEEP_AFTER = 2 * 86400  -- las terminadas se siguen viendo 2 días
Data.MAX_QTY = 1000

-- Recetas con cooldown conocidas; el resto se aprende al ver cooldowns reales.
Data.KNOWN_COOLDOWNS = {
  ["171:i12360"] = true, -- Transmutar: arcanita
  ["171:i6037"] = true,  -- Transmutar: mitril en veraplata
  ["171:i3577"] = true,  -- Transmutar: hierro en oro
  ["171:i7076"] = true,  -- Esencia de tierra
  ["171:i7078"] = true,  -- Esencia de fuego
  ["171:i7080"] = true,  -- Esencia de agua
  ["171:i7082"] = true,  -- Esencia de aire
  ["171:i12803"] = true, -- Esencia de vida
  ["171:i12808"] = true, -- Esencia de muerte
  ["197:i14342"] = true, -- Tela lunar
}

Data.STATE_LABEL = {
  open = "Abierta", accepted = "Aceptada", done = "Hecha", closed = "Cerrada", expired = "Caducada",
}

local floor, max, min = math.floor, math.max, math.min

local function deepCopy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = deepCopy(x) end
  return t
end
Data.Copy = deepCopy

-- Nueva versión: siempre mayor que la anterior, aunque sea en el mismo segundo.
local function bump(old, now)
  return max(now, (old or 0) + 1)
end

local function cleanNumberMap(src, keyType)
  if type(src) ~= "table" then return nil end
  local out, any = {}, false
  for k, v in pairs(src) do
    if type(k) == keyType and type(v) == "number" and v == v then
      out[k] = v
      any = true
    end
  end
  return any and out or nil
end

---------------------------------------------------------------------------
-- Fichas de fabricantes
---------------------------------------------------------------------------
function Data.SanitizeEntry(e)
  if type(e) ~= "table" or type(e.n) ~= "string" or type(e.v) ~= "number" then return nil end
  local out = {
    n = e.n,
    v = e.v,
    c = type(e.c) == "string" and e.c or nil,
    l = tonumber(e.l),
    u = (e.u == true) or nil,
    av = type(e.av) == "string" and e.av or nil,
    th = cleanNumberMap(e.th, "string"),
    ga = cleanNumberMap(e.ga, "number"),
  }
  if type(e.p) == "table" then
    local profs, any = {}, false
    for pk, p in pairs(e.p) do
      if (type(pk) == "number" or type(pk) == "string") and type(p) == "table" then
        profs[pk] = {
          r = tonumber(p.r),
          m = tonumber(p.m),
          i = (type(p.i) == "string" and p.i ~= "") and p.i or nil,
          e = (type(p.e) == "string" and p.e ~= "") and p.e or nil,
          cd = cleanNumberMap(p.cd, "string"),
        }
        any = true
      end
    end
    out.p = any and profs or nil
  end
  return out
end

-- Si nos llega nuestra propia ficha más nueva (p. ej. tras reinstalar), recuperamos sus recetas.
function Data.RestoreMine(e)
  local c = ns.MyChar()
  if not c or not e.p then return end
  for pk, p in pairs(e.p) do
    local prof = c.profs[pk]
    if not prof then
      prof = { recipes = {}, cd = {}, r = p.r, m = p.m }
      c.profs[pk] = prof
    end
    prof.recipes = prof.recipes or {}
    for _, id in ipairs(Codec.DecodeIDs(p.i) or {}) do prof.recipes["i" .. id] = true end
    for _, id in ipairs(Codec.DecodeIDs(p.e) or {}) do prof.recipes["e" .. id] = true end
  end
end

-- Guarda una ficha recibida si es más nueva. Devuelve cambiado, recibidaAntigua.
function Data.ApplyEntry(e)
  local g = ns.G()
  if not g then return false, false end
  local cur = g.entries[e.n]
  if cur and cur.v >= e.v then return false, cur.v > e.v end
  g.entries[e.n] = e
  Data.indexDirty = true
  if e.n == ns.Me() then Data.RestoreMine(e) end
  return true, false
end

function Data.BuildMyEntry(now)
  local me, c, g = ns.Me(), ns.MyChar(), ns.G()
  if not me or not c or not g then return nil end
  local e = { n = me, c = c.class, l = c.level, u = c.u or nil, av = ns.VERSION }
  local th = g.thanks[me]
  if th and next(th) then e.th = deepCopy(th) end
  if c.gather and next(c.gather) then e.ga = deepCopy(c.gather) end
  local profs, anyProf = {}, false
  for pk, prof in pairs(c.profs) do
    local items, enchants = {}, {}
    for key in pairs(prof.recipes or {}) do
      local kind, id = ns.ParseKey(key)
      if kind == "i" then
        items[#items + 1] = id
      elseif kind == "e" then
        enchants[#enchants + 1] = id
      end
    end
    local cd, anyCd = {}, false
    for key, t in pairs(prof.cd or {}) do
      if t > now then
        cd[key] = t
        anyCd = true
      end
    end
    profs[pk] = {
      r = prof.r,
      m = prof.m,
      i = #items > 0 and Codec.EncodeIDs(items) or nil,
      e = #enchants > 0 and Codec.EncodeIDs(enchants) or nil,
      cd = anyCd and cd or nil,
    }
    anyProf = true
  end
  e.p = anyProf and profs or nil
  return e
end

-- Recalcula mi ficha; si ha cambiado, sube la versión. Devuelve true si cambió.
function Data.UpdateMyEntry(now)
  local e = Data.BuildMyEntry(now)
  if not e then return false end
  local g = ns.G()
  local old = g.entries[e.n]
  if old then
    local oldV = old.v
    old.v = nil
    local same = Codec.Serialize(old) == Codec.Serialize(e)
    old.v = oldV
    if same then return false end
    e.v = bump(oldV, now)
  else
    e.v = now
  end
  g.entries[e.n] = e
  Data.indexDirty = true
  return true
end

-- Índice: para cada receta, quién la sabe hacer.
local index
local function addToIndex(prefix, ids, name, pk)
  for _, id in ipairs(ids or {}) do
    local key = prefix .. id
    local rec = index[key]
    if not rec then
      rec = { crafters = {}, profs = {} }
      index[key] = rec
    end
    rec.crafters[#rec.crafters + 1] = { n = name, p = pk }
    rec.profs[pk] = true
  end
end

function Data.GetIndex()
  if index and not Data.indexDirty then return index end
  index = {}
  local g = ns.G()
  if g then
    for name, e in pairs(g.entries) do
      for pk, p in pairs(e.p or {}) do
        addToIndex("i", Codec.DecodeIDs(p.i), name, pk)
        addToIndex("e", Codec.DecodeIDs(p.e), name, pk)
      end
    end
  end
  Data.indexDirty = false
  return index
end

-- Profesión que produce una receta, si solo hay una.
function Data.SingleProfession(key)
  local rec = Data.GetIndex()[key]
  if not rec then return nil end
  local only
  for pk in pairs(rec.profs) do
    if only ~= nil then return nil end
    only = pk
  end
  return only
end

-- ¿Puedo conseguirlo recolectando? true/false, o nil si aún no se sabe qué objeto es.
function Data.ICanGather(key)
  local skill = ns.GatherSkillFor(key)
  if skill == nil then return nil end
  local c = ns.MyChar()
  return skill and c and c.gather and c.gather[skill] ~= nil or false
end

-- Quién de la hermandad puede conseguirlo recolectando: lista de nombres y la habilidad.
function Data.GatherersOf(key)
  local skill = ns.GatherSkillFor(key)
  local g = ns.G()
  local names = {}
  if not skill or not g then return names, skill end
  for name, e in pairs(g.entries) do
    if e.ga and e.ga[skill] then names[#names + 1] = name end
  end
  table.sort(names)
  return names, skill
end

-- ¿Puedo atender esta petición? (sé fabricarlo o conseguirlo, no es mía y está abierta para mí)
function Data.CanServe(r, now)
  local me = ns.Me()
  if not r or r.a == me or (r.to and r.to ~= me) then return false end
  if Data.RequestInfo(r, now).state ~= "open" then return false end
  return r.to == me or Data.ICanCraft(r.k) or Data.ICanGather(r.k) or false
end

-- Peticiones que puedo atender ahora mismo.
function Data.ServableRequests(now)
  local g, list = ns.G(), {}
  if not g then return list end
  for _, r in pairs(g.requests) do
    if Data.CanServe(r, now) then list[#list + 1] = r end
  end
  table.sort(list, function(a, b) return (a.t or 0) > (b.t or 0) end)
  return list
end

-- Mis peticiones activas de un objeto (para no pedirlo dos veces).
function Data.MyActiveRequestFor(key, now)
  local g, me = ns.G(), ns.Me()
  if not g then return nil end
  for _, r in pairs(g.requests) do
    if r.a == me and r.k == key and Data.IsActiveState(Data.RequestInfo(r, now).state) then return r end
  end
end

function Data.ICanCraft(key)
  local c = ns.MyChar()
  if not c then return false end
  for _, prof in pairs(c.profs) do
    if prof.recipes and prof.recipes[key] then return true end
  end
  return false
end

-- Encargos confirmados a un fabricante, sumando lo que dice cada autor.
function Data.ThanksFor(name)
  local g = ns.G()
  if not g then return 0 end
  local total = 0
  for _, e in pairs(g.entries) do
    if e.th and e.th[name] then total = total + e.th[name] end
  end
  return total
end

---------------------------------------------------------------------------
-- Materiales de cada receta (datos fijos del juego, compartidos entre hermandades)
---------------------------------------------------------------------------
function Data.InfoKey(pk, key)
  return tostring(pk) .. ":" .. key
end

function Data.GetInfo(ik)
  return ns.db and ns.db.info[ik]
end

local function sanitizeReagents(r)
  if type(r) ~= "table" then return nil end
  local out, any = {}, false
  for id, n in pairs(r) do
    id, n = tonumber(id), tonumber(n)
    if id and n and id > 0 and n > 0 then
      out[floor(id)] = floor(n)
      any = true
    end
  end
  return any and out or nil
end

-- Añade una variante de materiales (puede haber dos recetas que den lo mismo).
function Data.AddInfoVariant(ik, made, reagents)
  reagents = sanitizeReagents(reagents)
  if not reagents or not ns.db then return false end
  local info = ns.db.info[ik]
  if not info then
    info = { v = {} }
    ns.db.info[ik] = info
  end
  info.v = info.v or {}
  made = tonumber(made) or 1
  local sig = Codec.Serialize(reagents)
  for _, var in ipairs(info.v) do
    if Codec.Serialize(var.r) == sig then
      if var.m ~= made then
        var.m = made
        return true
      end
      return false
    end
  end
  if #info.v >= 4 then return false end
  info.v[#info.v + 1] = { m = made, r = reagents }
  return true
end

function Data.MarkCooldown(ik)
  if not ns.db then return false end
  local info = ns.db.info[ik]
  if not info then
    info = { v = {} }
    ns.db.info[ik] = info
  end
  if info.cd then return false end
  info.cd = true
  return true
end

function Data.IsCooldownRecipe(ik)
  local info = Data.GetInfo(ik)
  return Data.KNOWN_COOLDOWNS[ik] or (info and info.cd) or false
end

function Data.MergeInfo(ik, d)
  if type(ik) ~= "string" or not ik:match("^[^:]+:[ie]%d+$") or type(d) ~= "table" then return false end
  local changed = false
  if type(d.v) == "table" then
    for _, var in ipairs(d.v) do
      if type(var) == "table" then
        changed = Data.AddInfoVariant(ik, var.m, var.r) or changed
      end
    end
  end
  if d.cd == true then changed = Data.MarkCooldown(ik) or changed end
  return changed
end

---------------------------------------------------------------------------
-- Peticiones
---------------------------------------------------------------------------
local AUTHOR_FIELDS = { "q", "m", "g", "pi", "to", "x", "rn" }

function Data.SanitizeRequest(r)
  if type(r) ~= "table" then return nil end
  if type(r.id) ~= "string" or type(r.a) ~= "string" then return nil end
  if type(r.k) ~= "string" or not r.k:match("^[ie]%d+$") then return nil end
  local q = tonumber(r.q)
  if not q or q ~= q then return nil end
  local out = {
    id = r.id,
    a = r.a,
    t = tonumber(r.t) or 0,
    k = r.k,
    q = min(Data.MAX_QTY, max(1, floor(q))),
    av = tonumber(r.av) or 0,
  }
  if type(r.pk) == "number" or type(r.pk) == "string" then out.pk = r.pk end
  if r.m == true then out.m = true end
  local gold = tonumber(r.g)
  if gold and gold >= 1 then out.g = floor(gold) end
  if type(r.pi) == "table" then
    local pi, any = {}, false
    for id, n in pairs(r.pi) do
      id, n = tonumber(id), tonumber(n)
      if id and n and id > 0 and n >= 1 then
        pi[floor(id)] = floor(n)
        any = true
      end
    end
    if any then out.pi = pi end
  end
  if type(r.to) == "string" and r.to ~= "" then out.to = r.to end
  if tonumber(r.x) then out.x = tonumber(r.x) end
  if tonumber(r.rn) then out.rn = tonumber(r.rn) end
  if type(r.c) == "table" then
    local c, any = {}, false
    for name, cm in pairs(r.c) do
      if type(name) == "string" and type(cm) == "table" then
        local o = {}
        local n = tonumber(cm.n)
        if n and n >= 1 then o.n = floor(n) end
        if tonumber(cm.cv) then o.cv = tonumber(cm.cv) end
        if cm.rl == true then o.rl = true end
        local d = tonumber(cm.d)
        if d and d >= 1 then o.d = floor(d) end
        if tonumber(cm.dv) then o.dv = tonumber(cm.dv) end
        local sent = tonumber(cm.s)
        if sent and sent >= 1 then o.s = floor(sent) end
        if tonumber(cm.sv) then o.sv = tonumber(cm.sv) end
        if next(o) then
          c[name] = o
          any = true
        end
      end
    end
    if any then out.c = c end
  end
  return out
end

-- Elige el bloque con mayor versión; si empatan, el mismo para todos (orden del texto).
local function pickBlock(a, b, verField)
  local va, vb = a[verField] or 0, b[verField] or 0
  if va ~= vb then return va > vb and a or b end
  return Codec.Serialize(a) >= Codec.Serialize(b) and a or b
end

local function authorBlock(r)
  local block = { av = r.av }
  for _, f in ipairs(AUTHOR_FIELDS) do block[f] = r[f] end
  return block
end

function Data.MergeRequests(a, b)
  if not a then return deepCopy(b) end
  if not b then return deepCopy(a) end
  -- Los datos fijos (autor, objeto, fecha) solo difieren si algo va mal: elegir siempre igual.
  local base = pickBlock({ a = a.a, t = a.t, k = a.k, pk = a.pk }, { a = b.a, t = b.t, k = b.k, pk = b.pk }, "_")
  local m = { id = a.id, a = base.a, t = base.t, k = base.k, pk = base.pk }
  local ab = pickBlock(authorBlock(a), authorBlock(b), "av")
  m.av = ab.av
  for _, f in ipairs(AUTHOR_FIELDS) do m[f] = deepCopy(ab[f]) end

  local names = {}
  for name in pairs(a.c or {}) do names[name] = true end
  for name in pairs(b.c or {}) do names[name] = true end
  local commits, any = {}, false
  for name in pairs(names) do
    local ca = (a.c and a.c[name]) or {}
    local cb = (b.c and b.c[name]) or {}
    local crafter = pickBlock({ n = ca.n, cv = ca.cv, rl = ca.rl }, { n = cb.n, cv = cb.cv, rl = cb.rl }, "cv")
    local delivered = pickBlock({ d = ca.d, dv = ca.dv }, { d = cb.d, dv = cb.dv }, "dv")
    local sent = pickBlock({ s = ca.s, sv = ca.sv }, { s = cb.s, sv = cb.sv }, "sv")
    local o = {
      n = crafter.n, cv = crafter.cv, rl = crafter.rl,
      d = delivered.d, dv = delivered.dv, s = sent.s, sv = sent.sv,
    }
    if next(o) then
      commits[name] = o
      any = true
    end
  end
  if any then m.c = commits end
  return m
end

function Data.RequestHash(r)
  return Codec.Hash(Codec.Serialize(r))
end

-- Entregado por un fabricante: lo que confirmó el autor o lo que envió por correo (lo mayor).
local function deliveredOf(cm)
  return max(cm.d or 0, cm.s or 0)
end
Data.DeliveredOf = deliveredOf

local function lastActivity(cm)
  return max(cm.cv or 0, cm.dv or 0, cm.sv or 0)
end

function Data.CommitActive(cm, now)
  if not cm or cm.rl or not cm.n then return false end
  if deliveredOf(cm) >= cm.n then return false end
  return now <= lastActivity(cm) + Data.COMMIT_TTL
end

-- Estado calculado de una petición (no se guarda: todos llegan al mismo resultado).
function Data.RequestInfo(r, now)
  local info = { delivered = 0, pending = 0, commits = {} }
  for name, cm in pairs(r.c or {}) do
    local d = deliveredOf(cm)
    info.delivered = info.delivered + d
    local active = Data.CommitActive(cm, now)
    local pending = active and (cm.n - d) or 0
    info.pending = info.pending + pending
    if active or d > 0 then
      info.commits[#info.commits + 1] = {
        name = name,
        promised = max(cm.n or 0, d),
        delivered = d,
        mailed = cm.s or 0,
        pending = pending,
        active = active,
        deadline = active and (lastActivity(cm) + Data.COMMIT_TTL) or nil,
      }
    end
  end
  table.sort(info.commits, function(x, y) return x.name < y.name end)
  info.expires = max(r.t or 0, r.rn or 0) + Data.REQUEST_TTL
  info.remaining = max(0, r.q - info.delivered - info.pending)
  if r.x then
    info.state, info.ended = "closed", r.x
  elseif info.delivered >= r.q then
    local last = 0
    for _, cm in pairs(r.c or {}) do last = max(last, cm.dv or 0, cm.sv or 0) end
    info.state, info.ended = "done", last
  elseif now > info.expires then
    info.state, info.ended = "expired", info.expires
  elseif info.remaining <= 0 then
    info.state = "accepted"
  else
    info.state = "open"
  end
  return info
end

function Data.IsActiveState(state)
  return state == "open" or state == "accepted"
end

local function isGone(r, now)
  local info = Data.RequestInfo(r, now)
  return not Data.IsActiveState(info.state) and now > (info.ended or 0) + Data.KEEP_AFTER
end

-- Fusiona una petición recibida. Devuelve: cambiado, anterior, fusionada, recibidaIncompleta.
function Data.ApplyRequest(incoming, now)
  local g = ns.G()
  if not g then return false end
  local cur = g.requests[incoming.id]
  local merged = cur and Data.MergeRequests(cur, incoming) or deepCopy(incoming)
  local mergedText = Codec.Serialize(merged)
  local behind = mergedText ~= Codec.Serialize(incoming)
  if cur and Codec.Serialize(cur) == mergedText then return false, cur, cur, behind end
  if not cur and isGone(merged, now) then return false, nil, nil, false end -- no resucitar
  g.requests[incoming.id] = merged
  return true, cur, merged, behind
end

-- Borra las peticiones terminadas hace tiempo.
function Data.Purge(now)
  local g = ns.G()
  if not g then return end
  for id, r in pairs(g.requests) do
    if isGone(r, now) then
      g.requests[id] = nil
      g.alerted[id] = nil
      g.thanked[id] = nil
    end
  end
end

function Data.CountOpenBy(author, now)
  local g = ns.G()
  if not g then return 0 end
  local n = 0
  for _, r in pairs(g.requests) do
    if r.a == author and Data.IsActiveState(Data.RequestInfo(r, now).state) then n = n + 1 end
  end
  return n
end

-- opts = { k, pk, q, m, g, pi, to }
function Data.CreateRequest(opts, now)
  local g, me = ns.G(), ns.Me()
  if not g or not me then return nil, "No estás en una hermandad." end
  if not ns.ParseKey(opts.k) then return nil, "Elige un objeto o encantamiento." end
  if Data.CountOpenBy(me, now) >= Data.MAX_OPEN then
    return nil, "Ya tienes " .. Data.MAX_OPEN .. " peticiones abiertas."
  end
  g.reqSeq = (g.reqSeq or 0) + 1
  local id = me .. ":" .. Codec.EncodeUInt(now) .. Codec.EncodeUInt(g.reqSeq % 1024)
  local r = Data.SanitizeRequest({
    id = id, a = me, t = now, k = opts.k, pk = opts.pk, q = opts.q or 1, av = now,
    m = opts.m and true or nil, g = opts.g, pi = opts.pi, to = opts.to,
  })
  g.requests[id] = r
  return r
end

local function getRequest(id)
  local g = ns.G()
  return g and g.requests[id]
end

-- "Lo hago yo": me comprometo a hacer "amount" más.
function Data.Commit(id, amount, now)
  local r, me = getRequest(id), ns.Me()
  if not r then return nil, "La petición ya no existe." end
  if r.a == me then return nil, "No puedes aceptar tu propia petición." end
  if r.to and r.to ~= me then return nil, "Esta petición es para otra persona." end
  local info = Data.RequestInfo(r, now)
  if info.state ~= "open" then return nil, "La petición ya no está abierta." end
  amount = min(info.remaining, max(1, floor(tonumber(amount) or 1)))
  r.c = r.c or {}
  local cm = r.c[me] or {}
  local delivered = deliveredOf(cm)
  local myPending = Data.CommitActive(cm, now) and (cm.n - delivered) or 0
  cm.n = delivered + myPending + amount
  cm.cv = bump(cm.cv, now)
  cm.rl = nil
  r.c[me] = cm
  return r
end

-- Soltar: ya no voy a hacer lo que prometí.
function Data.Release(id, now)
  local r, me = getRequest(id), ns.Me()
  if not r or not r.c or not r.c[me] then return nil, "No tenías nada aceptado." end
  local cm = r.c[me]
  cm.rl = true
  cm.cv = bump(cm.cv, now)
  return r
end

-- El autor confirma que ha recibido "amount" de un fabricante.
-- Devuelve la petición y si cambió el contador de encargos.
function Data.ConfirmDelivery(id, crafter, amount, now)
  local r, me = getRequest(id), ns.Me()
  if not r then return nil, "La petición ya no existe." end
  if r.a ~= me then return nil, "Solo el autor puede confirmar entregas." end
  local info = Data.RequestInfo(r, now)
  local left = r.q - info.delivered
  if left <= 0 then return nil, "Ya está todo entregado." end
  amount = min(left, max(1, floor(tonumber(amount) or 1)))
  r.c = r.c or {}
  local cm = r.c[crafter] or {}
  if not cm.n then
    cm.n = amount
    cm.cv = bump(cm.cv, now)
  end
  cm.d = deliveredOf(cm) + amount
  cm.dv = bump(cm.dv, now)
  r.c[crafter] = cm
  return r, Data.CheckThanks(r, now)
end

-- Contador de encargos: lo lleva el autor. Suma uno a cada fabricante que entrega todo
-- lo que prometió (o que completa la petición), confirmado a mano o enviado por correo.
function Data.CheckThanks(r, now)
  local g, me = ns.G(), ns.Me()
  if not g or not r or r.a ~= me or not r.c then return false end
  local info = Data.RequestInfo(r, now)
  local changed = false
  for crafter, cm in pairs(r.c) do
    local d = deliveredOf(cm)
    if d > 0 and (d >= (cm.n or 0) or info.delivered >= r.q) then
      g.thanked[r.id] = g.thanked[r.id] or {}
      if not g.thanked[r.id][crafter] then
        g.thanked[r.id][crafter] = true
        g.thanks[me] = g.thanks[me] or {}
        g.thanks[me][crafter] = (g.thanks[me][crafter] or 0) + 1
        changed = true
      end
    end
  end
  return changed
end

-- He enviado un correo con objetos a alguien: lo apunto en sus peticiones que yo había
-- aceptado (solo objetos de la petición y hasta lo que prometí). Devuelve las peticiones cambiadas.
function Data.RegisterMail(recipient, items, now)
  local g, me = ns.G(), ns.Me()
  local changed = {}
  if not g or not recipient or type(items) ~= "table" then return changed end
  -- las más antiguas primero
  local list = {}
  local to = recipient:lower()
  for _, r in pairs(g.requests) do
    if r.a:lower() == to and r.c and r.c[me] then list[#list + 1] = r end
  end
  table.sort(list, function(a, b) return (a.t or 0) < (b.t or 0) end)
  for _, r in ipairs(list) do
    local kind, id = ns.ParseKey(r.k)
    local cm = r.c[me]
    local left = items[id] or 0
    if kind == "i" and left > 0 and Data.CommitActive(cm, now) then
      local credit = min(left, cm.n - deliveredOf(cm))
      if credit > 0 then
        cm.s = deliveredOf(cm) + credit
        cm.sv = bump(cm.sv, now)
        items[id] = left - credit
        changed[#changed + 1] = r
      end
    end
  end
  return changed
end

function Data.CloseRequest(id, now)
  local r, me = getRequest(id), ns.Me()
  if not r then return nil, "La petición ya no existe." end
  if r.a ~= me then return nil, "Solo el autor puede cerrarla." end
  r.x = now
  r.av = bump(r.av, now)
  return r
end

function Data.RenewRequest(id, now)
  local r, me = getRequest(id), ns.Me()
  if not r then return nil, "La petición ya no existe." end
  if r.a ~= me then return nil, "Solo el autor puede renovarla." end
  local info = Data.RequestInfo(r, now)
  if info.state == "done" or info.state == "closed" then return nil, "La petición ya está terminada." end
  if Data.CountOpenBy(me, now) >= Data.MAX_OPEN and not Data.IsActiveState(info.state) then
    return nil, "Ya tienes " .. Data.MAX_OPEN .. " peticiones abiertas."
  end
  r.rn = now
  r.av = bump(r.av, now)
  return r
end
