-- Datos compartidos de la hermandad: fichas de fabricantes, materiales y peticiones.
--
-- Ficha de fabricante (una por personaje, la publica su dueño):
--   { n = "Nombre-Reino", v = versión, c = clase, l = nivel, u = no disponible,
--     av = versión del addon, th = { [fabricante] = encargos confirmados por este autor },
--     of / cl / od = ofertas, "lo quiero" y envíos de ofertas (ver Offers.lua),
--     p = { [profesión] = { r = nivel, m = máximo, i = objetos, e = encantamientos,
--                           cd = { [receta] = fin del cooldown } } } }
--
-- Petición:
--   { id, a = autor, t = creada, k = "i<objeto>"/"e<encantamiento>", pk = profesión,
--     q = cantidad, av = versión del bloque del autor, m = aporta materiales,
--     g = propina en cobre, pr = prisa (1 ya, 2 antes de 2 h, 3 hoy),
--     x = cerrada, rn = renovada,
--     (pi, to y vu son de versiones anteriores: se conservan pero ya no se usan)
--     c = { [fabricante] = { n = prometidas, cv = versión, rl = soltada,
--                            by = plazo para entregarlo, w = cuándo dijo (1/2/3),
--                            at = cuándo lo aceptó, ex = ya pidió más tiempo,
--                            d = entregadas (lo confirma el autor), dv = versión,
--                            s = enviadas por correo (lo apunta el fabricante), sv = versión } } }
-- Cada parte tiene un único dueño y su propia versión, así que dos copias se
-- fusionan siempre igual, en cualquier orden (no hay conflictos).
local _, ns = ...
local Codec = ns.Codec
local Data = {}
ns.Data = Data

Data.REQUEST_TTL = 7 * 86400 -- las peticiones caducan a los 7 días
Data.COMMIT_TTL = 48 * 3600  -- encargos de versiones antiguas (sin plazo): caducan a las 48 h
Data.COMMIT_GRACE = 15 * 60  -- margen tras el plazo antes de que el pedido vuelva al tablón

-- Cuándo lo hará el que acepta (y la prisa del que pide): mismos botones.
Data.WHEN = {
  { id = 1, label = "Lo hago ya", need = "Lo necesita ya", ask = "Ya", secs = 3600 },
  { id = 2, label = "Antes de 2 horas", need = "Lo necesita antes de 2 h", ask = "Antes de 2 horas", secs = 7200 },
  { id = 3, label = "Lo hago hoy", need = "Lo necesita hoy", ask = "Hoy", today = true },
  -- el correo entre jugadores tarda y a veces no coincides con quien lo pidió
  { id = 4, label = "Antes de 24 horas", need = "Lo necesita antes de 24 h", ask = "En 24 horas", secs = 24 * 3600 },
}

-- Plazo (en el reloj del addon) para la opción elegida.
function Data.Deadline(when, now)
  local w = Data.WHEN[when] or Data.WHEN[3]
  if not w.today then return now + w.secs end
  -- "Hoy": hasta la medianoche (hora del ordenador), y como mínimo 3 horas.
  local left = 12 * 3600
  local t = date and date("*t")
  if type(t) == "table" and t.hour then left = (24 - t.hour) * 3600 - (t.min or 0) * 60 - (t.sec or 0) end
  return now + math.max(3 * 3600, left)
end
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
    kc = cleanNumberMap(e.kc, "string"),
    kd = tonumber(e.kd),
    ro = (type(e.ro) == "number" and e.ro >= 1 and e.ro <= 7 and e.ro % 1 == 0) and e.ro or nil, -- 1+2+4: varios roles
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
  if ns.Offers then ns.Offers.SanitizeInto(out, e) end -- ofertas, "lo quiero" y envíos
  if ns.Social then ns.Social.SanitizeInto(out, e) end -- alts, oficiales, necesidades, ayudas
  if ns.Orders then ns.Orders.SanitizeInto(out, e) end -- pedidos de fabricación de hermandad
  if ns.History then ns.History.SanitizeInto(out, e) end -- historial público
  return out
end

-- ¿Trae alguna versión (v, av, cv, dv, sv) muy por delante del reloj? Se mira a fondo
-- (bloques de cada fabricante o apuntado). Esas versiones son horas: el futuro no es legítimo.
local VERSION_FIELDS = { v = true, av = true, cv = true, dv = true, sv = true }
function Data.FromFuture(obj, now, depth)
  if type(obj) ~= "table" then return false end
  depth = depth or 0
  local limit = now + Data.FUTURE_MARGIN
  for k, v in pairs(obj) do
    if VERSION_FIELDS[k] and type(v) == "number" and v > limit then return true end
    if type(v) == "table" and depth < 3 and Data.FromFuture(v, now, depth + 1) then return true end
  end
  return false
end

-- Si nos llega nuestra propia ficha más nueva (p. ej. tras reinstalar), recuperamos sus recetas.
-- También recupera lo demás de la ficha (karma dado, encargos, ofertas, aportaciones, ayudas,
-- anuncio y necesidades), pero solo si en este ordenador no estaba: así, al jugar desde otro
-- PC o tras reinstalar, no se pierde y no se pisa lo que ya hubiera aquí.
local function restoreRest(e, c)
  local g, me = ns.G(), ns.Me()
  if not g or not me then return end
  g.karma = g.karma or {}
  local karma = g.karma[me]
  if (not karma or (not next(karma.kc or {}) and (karma.kd or 0) == 0)) and (e.kc or e.kd) then
    g.karma[me] = { kc = deepCopy(e.kc or {}), kd = e.kd or 0 }
  end
  if e.th and not next(g.thanks[me] or {}) then g.thanks[me] = deepCopy(e.th) end
  local function fill(field, value)
    if value ~= nil and (c[field] == nil or (type(c[field]) == "table" and next(c[field]) == nil)) then
      c[field] = deepCopy(value)
    end
  end
  fill("offers", e.of)
  fill("donated", e.dn)
  fill("needs", e.nd)
  fill("mc", e.mc)
  fill("mp", e.mp)
  fill("mo", e.mo)
  fill("guildOrders", e.go)
  fill("hist", e.hi)
  if e.an and not c.announce then c.announce = deepCopy(e.an) end
  if e.wk and not c.week then c.week = deepCopy(e.wk) end
  if e.od and not next(c.sent or {}) then c.sent = deepCopy(e.od) end
end

function Data.RestoreMine(e)
  local c = ns.MyChar()
  if not c then return end
  restoreRest(e, c)
  if not e.p then return end
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
  local e = { n = me, c = c.class, l = c.level, u = c.u or nil, av = ns.VERSION, ro = c.roleSet or c.roleAuto }
  local th = g.thanks[me]
  if th and next(th) then e.th = deepCopy(th) end
  if c.gather and next(c.gather) then e.ga = deepCopy(c.gather) end
  local karma = g.karma and g.karma[me]
  if karma then
    if karma.kc and next(karma.kc) then e.kc = deepCopy(karma.kc) end
    if karma.kd and karma.kd > 0 then e.kd = karma.kd end
  end
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
  if ns.Offers then ns.Offers.BuildInto(e, now) end
  if ns.Social then ns.Social.BuildInto(e, now) end
  if ns.Orders then ns.Orders.BuildInto(e, now) end
  if ns.History then ns.History.BuildInto(e) end
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

-- Recetas de la base de datos de Classic: aparecen aunque nadie las haya publicado.
local function addKnownRecipes()
  for pk, d in pairs(ns.RECIPE_DB or {}) do
    for prefix, list in pairs({ i = d.i, e = d.e }) do
      for _, id in ipairs(Codec.DecodeIDs(list) or {}) do
        local key = prefix .. id
        local rec = index[key]
        if not rec then
          rec = { crafters = {}, profs = {} }
          index[key] = rec
        end
        rec.profs[pk] = true
      end
    end
  end
end

function Data.GetIndex()
  if index and not Data.indexDirty then return index end
  index = {}
  addKnownRecipes()
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
  if not r or r.a == me then return false end
  if Data.RequestInfo(r, now).state ~= "open" then return false end
  return Data.ICanCraft(r.k) or Data.ICanGather(r.k) or false
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

-- Karma de un personaje, en puntos (1 punto por pedido): los pedidos que le reconocen los
-- demás por entregar, menos los que ha recibido él.
-- Se suma por persona: el principal y todos sus alts.
function Data.KarmaFor(name)
  local g = ns.G()
  if not g then return 0 end
  local mainOf = ns.Social and ns.Social.MainOf or function(n) return n end
  local person = mainOf(name)
  local copper = 0
  for ename, e in pairs(g.entries) do
    -- nadie se puede dar karma a sí mismo (ni a sus alts), y cada autor da como mucho
    -- Data.KARMA_CAP puntos a cada persona
    local giver = mainOf(ename)
    for who, v in pairs(e.kc or {}) do
      if giver ~= person and (who == person or mainOf(who) == person) then
        copper = copper + math.min(v, Data.KARMA_CAP * Data.KARMA_POINT)
      end
    end
    if e.kd and (ename == person or mainOf(ename) == person) then copper = copper - e.kd end
  end
  if copper >= 0 then return math.floor(copper / 10000) end
  return -math.floor(-copper / 10000)
end

-- "+12" en verde, "-5" en rojo, "0" en gris.
function Data.KarmaText(name)
  local k = Data.KarmaFor(name)
  if k > 0 then return "|cff40ff40+" .. k .. "|r" end
  if k < 0 then return "|cffff5050" .. k .. "|r" end
  return "|cff9999990|r"
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
  for ename, e in pairs(g.entries) do
    if ename ~= name and e.th and e.th[name] then total = total + math.min(e.th[name], Data.KARMA_CAP) end
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
  local real = ns.db and ns.db.info[ik]
  if real or not ns.Demo then return real end
  return ns.Demo.GetInfo(ik)
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
local AUTHOR_FIELDS = { "q", "m", "g", "pi", "to", "x", "rn", "vu", "pr", "rj", "nt" }

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
  local vu = tonumber(r.vu)
  if vu and vu >= 1 then out.vu = floor(vu) end
  local pr = tonumber(r.pr)
  if pr and Data.WHEN[pr] then out.pr = pr end
  out.nt = ns.CleanNote(r.nt) -- nota del que pide
  -- rj = { [fabricante] = hora }: el autor le quitó el encargo (vuelve al Mercado)
  if type(r.rj) == "table" then
    local rj, any = {}, false
    for name, t in pairs(r.rj) do
      if type(name) == "string" and tonumber(t) then
        rj[name] = tonumber(t)
        any = true
      end
    end
    if any then out.rj = rj end
  end
  if type(r.c) == "table" then
    local c, any = {}, false
    for name, cm in pairs(r.c) do
      if type(name) == "string" and type(cm) == "table" then
        local o = {}
        local n = tonumber(cm.n)
        if n and n >= 1 then o.n = floor(n) end
        if tonumber(cm.cv) then o.cv = tonumber(cm.cv) end
        if cm.rl == true then o.rl = true end
        if tonumber(cm.by) then o.by = tonumber(cm.by) end
        if tonumber(cm.at) then o.at = tonumber(cm.at) end
        if cm.ex == true then o.ex = true end
        local w = tonumber(cm.w)
        if w and Data.WHEN[w] then o.w = w end
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

-- Elige el bloque con mayor versión. Si empatan: el que trae más datos (una versión vieja del addon
-- borra los campos que no conoce, como rj o nt, pero deja la misma versión) y, si no, el mismo para
-- todos (orden del texto).
local function fieldCount(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end
local function pickBlock(a, b, verField)
  local va, vb = a[verField] or 0, b[verField] or 0
  if va ~= vb then return va > vb and a or b end
  local na, nb = fieldCount(a), fieldCount(b)
  if na ~= nb then return na > nb and a or b end
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
    local crafter = pickBlock({ n = ca.n, cv = ca.cv, rl = ca.rl, by = ca.by, w = ca.w, at = ca.at, ex = ca.ex },
      { n = cb.n, cv = cb.cv, rl = cb.rl, by = cb.by, w = cb.w, at = cb.at, ex = cb.ex }, "cv")
    local delivered = pickBlock({ d = ca.d, dv = ca.dv }, { d = cb.d, dv = cb.dv }, "dv")
    local sent = pickBlock({ s = ca.s, sv = ca.sv }, { s = cb.s, sv = cb.sv }, "sv")
    local o = {
      n = crafter.n, cv = crafter.cv, rl = crafter.rl, by = crafter.by, w = crafter.w,
      at = crafter.at, ex = crafter.ex,
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

-- Plazo de un encargo: el que dijo al aceptar (o 48 h en versiones antiguas).
local function commitDeadline(cm)
  if cm.by then return cm.by + Data.COMMIT_GRACE end
  return lastActivity(cm) + Data.COMMIT_TTL
end

-- ¿Sigue en pie este encargo? (sin soltar, sin entregar del todo y dentro de plazo)
local function commitAlive(cm, now)
  if not cm or cm.rl or not cm.n then return false end
  if deliveredOf(cm) >= cm.n then return false end
  return now <= commitDeadline(cm)
end

-- ¿Le quitó el autor el encargo? (solo cuenta si se lo quitó después de aceptarlo)
local function rejected(r, name, cm)
  local t = r and r.rj and r.rj[name]
  return t ~= nil and t >= (cm.at or cm.cv or 0)
end
Data.Rejected = function(r, name) return r and r.c and r.c[name] and rejected(r, name, r.c[name]) or false end

-- El pedido es de uno solo: el primero que lo aceptó (si dos lo aceptan a la vez sin verse,
-- gana el que lo hizo antes; todos llegan a la misma conclusión).
function Data.OwnerOf(r, now)
  local owner, ocm
  for name, cm in pairs(r and r.c or {}) do
    if commitAlive(cm, now) and not rejected(r, name, cm) then
      -- la hora en que lo aceptó (ampliar el plazo no cambia quién lo tiene)
      local cv, ocv = cm.at or cm.cv or 0, ocm and (ocm.at or ocm.cv or 0)
      if not owner or cv < ocv or (cv == ocv and name < owner) then owner, ocm = name, cm end
    end
  end
  return owner, ocm
end

-- ¿Está activo este encargo? Con la petición, además tiene que ser el que se queda el pedido.
function Data.CommitActive(cm, now, r)
  if not commitAlive(cm, now) then return false end
  if r then
    local _, ocm = Data.OwnerOf(r, now)
    return ocm == cm
  end
  return true
end

-- Estado calculado de una petición (no se guarda: todos llegan al mismo resultado).
function Data.RequestInfo(r, now)
  local info = { delivered = 0, pending = 0, commits = {} }
  info.owner = Data.OwnerOf(r, now)
  for name, cm in pairs(r.c or {}) do
    local d = deliveredOf(cm)
    info.delivered = info.delivered + d
    local active = name == info.owner
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
        deadline = active and (cm.by or commitDeadline(cm)) or nil,
        when = cm.w,
      }
    end
  end
  table.sort(info.commits, function(x, y) return x.name < y.name end)
  -- Sin encargado, el último que lo aceptó y se le pasó el plazo (sin soltarlo ni que se lo
  -- quitaran): el autor aún puede darle a «Recibido» (el correo tarda y a veces no coincidís).
  if not info.owner then
    local best, bestAt
    for name, cm in pairs(r.c or {}) do
      if cm.n and not cm.rl and not rejected(r, name, cm) and deliveredOf(cm) < cm.n then
        local at = cm.at or cm.cv or 0
        if not bestAt or at > bestAt then best, bestAt = name, at end
      end
    end
    if best then info.late = { name = best, pending = 0, mailed = r.c[best].s or 0 } end
  end
  info.expires = max(r.t or 0, r.rn or 0) + Data.REQUEST_TTL
  info.remaining = max(0, r.q - info.delivered - info.pending)
  local modClosed = ns.Social and ns.Social.IsModClosed(r.id)
  if r.x then
    info.state, info.ended = "closed", r.x
  elseif modClosed and info.delivered < r.q then
    info.state, info.ended, info.moderated = "closed", modClosed, true
  elseif info.delivered >= r.q then
    local last = 0
    for _, cm in pairs(r.c or {}) do last = max(last, cm.dv or 0, cm.sv or 0) end
    info.state, info.ended = "done", last
  elseif now > info.expires then
    info.state, info.ended = "expired", info.expires
  elseif info.remaining <= 0 or info.owner then
    -- con encargado, aunque se haya ampliado la cantidad: nadie más puede cogerlo hasta que
    -- él entregue (o caduque su plazo) y entonces vuelve a estar abierto lo que falte
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

-- Nombre de verdad de alguien de la hermandad. En WoW Forever cada uno guarda su nombre con su
-- reino interno (Xepe-CAMWOWEU4Realm4PvP) y el chat de hermandad lo da con apellido y sin reino
-- («Xepe Barbabrote»): si no coincide con ninguna ficha, se busca la ficha con ese nombre corto
-- (o con su primera palabra), solo si hay una. Fuera del chat solo se tocan los nombres con
-- apellido (los que vienen del chat): un «Nombre-Reino» normal es de verdad aunque no tenga ficha.
function Data.CanonicalName(name, fromChat)
  local g = ns.G()
  if type(name) ~= "string" or not g or g.entries[name] then return name end
  local short = ns.ShortName(name):lower()
  if not fromChat and not short:find(" ", 1, true) then return name end
  local first = short:match("^(%S+)")
  local byShort, nShort, byFirst, nFirst = nil, 0, nil, 0
  for n, ent in pairs(g.entries) do
    if not ent.demo then
      local s = ns.ShortName(n):lower()
      if s == short then byShort, nShort = n, nShort + 1 end
      if s == first then byFirst, nFirst = n, nFirst + 1 end
    end
  end
  if nShort == 1 then return byShort end
  if nShort == 0 and nFirst == 1 then return byFirst end
  return name
end

-- Id de verdad de una petición (autor de verdad + su sufijo). Devuelve id, autor.
function Data.CanonicalRequestId(id)
  local a, suffix = tostring(id):match("^(.*):([^:]+)$")
  if not a then return id end
  local ca = Data.CanonicalName(a)
  return ca .. ":" .. suffix, ca
end

-- Si la petición es una copia con el nombre mal escrito, devuelve otra con el id y autor de
-- verdad; si no, la misma.
function Data.Canonicalize(r)
  if type(r) ~= "table" or type(r.id) ~= "string" then return r end
  local cid, ca = Data.CanonicalRequestId(r.id)
  if cid == r.id then return r end
  local c = deepCopy(r)
  c.id, c.a = cid, ca
  return c
end

-- Junta las copias repetidas (el mismo pedido con el nombre del autor escrito de otra forma)
-- con el pedido de verdad. Devuelve cuántas ha juntado.
function Data.MergeCopies(now)
  local g = ns.G()
  if not g then return 0 end
  local copies = {}
  for id, r in pairs(g.requests) do
    local c = Data.Canonicalize(r)
    if c ~= r then copies[#copies + 1] = { id = id, req = c } end
  end
  for _, p in ipairs(copies) do
    g.requests[p.id] = nil
    g.alerted[p.id] = nil
    g.thanked[p.id] = nil
    if g.karmaSeen then g.karmaSeen[p.id] = nil end
    -- si el de verdad ya terminó y se borró, la copia no lo resucita
    if not (g.gone and g.gone[p.req.id]) then Data.ApplyRequest(p.req, now) end
  end
  return #copies
end

-- Borra las peticiones terminadas hace tiempo.
function Data.Purge(now)
  local g = ns.G()
  if not g then return end
  Data.MergeCopies(now)
  -- Los borrados se recuerdan un tiempo: así no vuelven desde el historial del chat.
  g.gone = g.gone or {}
  for id, t in pairs(g.gone) do
    if now - t > Data.REQUEST_TTL + Data.KEEP_AFTER then g.gone[id] = nil end
  end
  for id, r in pairs(g.requests) do
    if isGone(r, now) then
      g.gone[id] = now
      g.requests[id] = nil
      g.alerted[id] = nil
      g.thanked[id] = nil
      if g.karmaSeen then g.karmaSeen[id] = nil end
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

-- opts = { k, pk, q, m, g = propina, pr = prisa }
function Data.CreateRequest(opts, now)
  local g, me = ns.G(), ns.Me()
  if not g or not me then return nil, "No estás en una hermandad." end
  if not ns.ParseKey(opts.k) then return nil, "Elige un objeto o encantamiento." end
  if ns.IsSoulbound(opts.k) then return nil, "Ese objeto se liga al recogerlo: quien lo fabrique no te lo puede dar." end
  if Data.CountOpenBy(me, now) >= Data.MAX_OPEN then
    return nil, "Ya tienes " .. Data.MAX_OPEN .. " peticiones abiertas."
  end
  g.reqSeq = (g.reqSeq or 0) + 1
  local id = me .. ":" .. Codec.EncodeUInt(now) .. Codec.EncodeUInt(g.reqSeq % 1024)
  local r = Data.SanitizeRequest({
    id = id, a = me, t = now, k = opts.k, pk = opts.pk, q = opts.q or 1, av = now,
    m = opts.m and true or nil, g = opts.g, pr = opts.pr, nt = opts.nt,
  })
  g.requests[id] = r
  return r
end

local function getRequest(id)
  local g = ns.G()
  return g and g.requests[id]
end

-- "Lo hago yo": me quedo el pedido entero y digo cuándo lo tendré (when = 1, 2 o 3).
-- Solo puede tenerlo uno: si ya lo ha aceptado otro, no se puede.
function Data.Commit(id, when, now)
  local r, me = getRequest(id), ns.Me()
  if not r then return nil, "La petición ya no existe." end
  if r.a == me then return nil, "No puedes aceptar tu propia petición." end
  local info = Data.RequestInfo(r, now)
  if info.owner and info.owner ~= me then
    return nil, "Ya lo ha aceptado " .. ns.ShortName(info.owner) .. "."
  end
  if info.state ~= "open" then return nil, "La petición ya no está abierta." end
  if r.rj and r.rj[me] then return nil, ns.ShortName(r.a) .. " te quitó este encargo: no puedes volver a cogerlo." end
  when = Data.WHEN[tonumber(when) or 0] and tonumber(when) or 3
  r.c = r.c or {}
  local cm = r.c[me] or {}
  if info.owner ~= me then cm.at, cm.ex = now, nil end -- lo acepto ahora (o de nuevo)
  cm.n = r.q - (info.delivered - deliveredOf(cm))
  cm.w = when
  cm.by = Data.Deadline(when, now)
  cm.cv = bump(cm.cv, now)
  cm.rl = nil
  r.c[me] = cm
  return r
end

Data.MIN_EXTEND = 30 * 60 -- "más tiempo" tiene que ampliar al menos media hora

-- Opciones para pedir más tiempo: las que dan un plazo más largo que el actual.
function Data.ExtendOptions(r, now)
  local cm = r and r.c and r.c[ns.Me()]
  local list = {}
  if not cm or cm.ex or not Data.CommitActive(cm, now, r) then return list end
  for _, w in ipairs(Data.WHEN) do
    if Data.Deadline(w.id, now) > (cm.by or 0) + Data.MIN_EXTEND then list[#list + 1] = w end
  end
  return list
end

-- Pedir más tiempo (una sola vez): nuevo plazo con la opción elegida.
function Data.Extend(id, when, now)
  local r, me = getRequest(id), ns.Me()
  local cm = r and r.c and r.c[me]
  if not cm or not Data.CommitActive(cm, now, r) then return nil, "Ese pedido no es tuyo." end
  if cm.ex then return nil, "Ya pediste más tiempo una vez." end
  local by = Data.Deadline(tonumber(when) or 3, now)
  if by <= (cm.by or 0) + Data.MIN_EXTEND then return nil, "Elige un plazo más largo que el que tenías." end
  cm.by, cm.w, cm.ex = by, tonumber(when) or 3, true
  cm.cv = bump(cm.cv, now)
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
  -- "Recibido" es lo entregado EN MANO, además de lo que ya contó el correo o el comercio.
  cm.d = deliveredOf(cm) + amount
  cm.dv = bump(cm.dv, now)
  r.c[crafter] = cm
  return r, Data.CheckThanks(r, now)
end

-- Contador de encargos: lo lleva el autor. Suma uno a cada fabricante que entrega todo
-- lo que prometió (o que completa la petición), confirmado a mano o enviado por correo.
Data.KARMA_POINT = 10000 -- el karma se guarda en "cobre" por compatibilidad: 1 punto = 10000
Data.KARMA_CAP = 100      -- como mucho 100 puntos de cada persona a otra
-- Versiones del futuro: los datos llevan la hora como versión. Si llega algo con una versión
-- muy por delante del reloj, se rechaza (si no, quien lo mandase bloquearía para siempre ese dato).
Data.FUTURE_MARGIN = 600

-- Karma por pedido: cuando el encargado entrega todo, él gana 1 punto y yo (autor) pierdo 1.
function Data.CheckThanks(r, now)
  local g, me = ns.G(), ns.Me()
  if not g or not r or r.a ~= me or not r.c then return false end
  local info = Data.RequestInfo(r, now)
  g.karma = g.karma or {}
  g.karma[me] = g.karma[me] or { kc = {}, kd = 0 }
  local karma = g.karma[me]
  karma.kc = karma.kc or {}
  local changed = false
  for crafter, cm in pairs(r.c) do
    local d = deliveredOf(cm)
    if d > 0 and (d >= (cm.n or 0) or info.delivered >= r.q) then
      g.thanked[r.id] = g.thanked[r.id] or {}
      if not g.thanked[r.id][crafter] then
        g.thanked[r.id][crafter] = true
        g.thanks[me] = g.thanks[me] or {}
        g.thanks[me][crafter] = (g.thanks[me][crafter] or 0) + 1
        karma.kc[crafter] = (karma.kc[crafter] or 0) + Data.KARMA_POINT
        karma.kd = (karma.kd or 0) + Data.KARMA_POINT
        if ns.History then ns.History.Add("p", r.k, d, crafter, now) end
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
    if kind == "i" and left > 0 and Data.CommitActive(cm, now, r) then
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

-- El autor amplía la cantidad de su petición (por ejemplo, porque ahora necesita más).
function Data.SetQuantity(id, q, now)
  local r, me = getRequest(id), ns.Me()
  if not r then return nil, "La petición ya no existe." end
  if r.a ~= me then return nil, "Solo el autor puede cambiarla." end
  q = min(Data.MAX_QTY, max(1, floor(tonumber(q) or 1)))
  if q == r.q then return r end
  r.q = q
  r.av = bump(r.av, now)
  return r
end

-- El autor le quita el encargo a quien lo aceptó (no lo envía): vuelve al Mercado para otro.
function Data.Reject(id, crafter, now)
  local r, me = getRequest(id), ns.Me()
  if not r then return nil, "La petición ya no existe." end
  if r.a ~= me then return nil, "Solo el autor puede quitar el encargo." end
  if not (r.c and r.c[crafter]) then return nil, "Esa persona no tiene el encargo." end
  r.rj = r.rj or {}
  r.rj[crafter] = now
  r.av = bump(r.av, now)
  return r
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
