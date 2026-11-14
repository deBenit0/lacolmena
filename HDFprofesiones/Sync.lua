-- Sincronización entre los miembros conectados.
--
-- Mensajes (una letra + datos):
--   H  hola: resumen de lo que tengo (versión de cada ficha y huella de cada petición)
--   W  quiero: lista de fichas/peticiones que me faltan
--   P  ficha de un fabricante        Q  petición        M  quedada de mazmorra
--   R  pido los materiales de una receta      I  materiales de una receta
--
-- Al entrar, cada uno manda su resumen. Los demás le envían lo que le falta y
-- piden lo que él tenga más nuevo. Para no repetir envíos, cada reenvío espera
-- un momento al azar (el dueño responde primero) y, justo antes de salir de la
-- cola, se descarta si otro jugador ya ha empezado a enviar lo mismo.
local _, ns = ...
local Codec, Comm, Data, Guild = ns.Codec, ns.Comm, ns.Data, ns.Guild
local Sync = {}
ns.Sync = Sync

local rand = ns.Random
local started = false
local pending = {}            -- envíos programados: ["P:nombre"] = { token, ver }
local want = { e = {}, r = {}, m = {} } -- lo que pediremos con un W
local wantScheduled = false
local infoAsked = {}
Sync.peers = {}               -- [personaje] = versión del addon
Sync.RESYNC_EVERY = 300       -- segundos entre resúmenes periódicos
Sync.lastHello = nil          -- cuándo llegó el último resumen de otro jugador (para la comprobación)
Sync.oldWarned = {}           -- [personaje] = true si ya avisé de que tiene una versión antigua

---------------------------------------------------------------------------
-- Nombres compactos: "Nombre-Reino" se envía como "Nombre" si es del reino del remitente
---------------------------------------------------------------------------
local function compress(s, realm)
  local name, rest = s:match("^([^:]+)(.*)$")
  local suffix = "-" .. realm
  if name and #name > #suffix and name:sub(-#suffix) == suffix then
    return name:sub(1, -#suffix - 1) .. rest
  end
  return s
end

local function expand(s, realm)
  local name, rest = s:match("^([^:]+)(.*)$")
  if name and not name:find("-", 1, true) then return name .. "-" .. realm .. rest end
  return s
end

local function realmOf(full)
  return (type(full) == "string" and full:match("%-(.+)$")) or ns.Realm()
end

---------------------------------------------------------------------------
-- Envíos
---------------------------------------------------------------------------
-- Formato de P, Q e I: cabecera con qué es y qué versión, y después los datos:
--   P  nombre~versión~ficha     Q  id~huella~petición     I  receta~materiales
-- La cabecera va en el primer trozo, así los demás saben enseguida qué se está enviando.
local inflight = {} -- lo último que otros han enviado: ["P:nombre"] = { v, h, t }

local function markInflight(key, v, h)
  local cur = inflight[key]
  if cur and v and cur.v and cur.v > v then v = cur.v end
  inflight[key] = { v = v, h = h, t = GetTime() }
end

local function cancel(kind, id)
  pending[kind .. ":" .. id] = nil
end

-- Comprobaciones "¿lo ha enviado otro desde que se pidió (since)?" para los reenvíos.
-- Lo que publica el dueño o el autor no se comprueba: siempre sale.
local function entryAlreadySent(name, since)
  return function()
    local g = ns.G()
    local e = g and g.entries[name]
    local s = inflight["P:" .. name]
    return not e or (s ~= nil and s.t >= since and s.v ~= nil and s.v >= e.v)
  end
end

local function requestAlreadySent(id, since)
  return function()
    local g = ns.G()
    local r = g and g.requests[id]
    local s = inflight["Q:" .. id]
    return not r or (s ~= nil and s.t >= since and s.h == Data.RequestHash(r))
  end
end

local function runAlreadySent(id, since)
  return function()
    local list = ns.Dungeons.Runs()
    local r = list and list[id]
    local s = inflight["M:" .. id]
    return not r or (s ~= nil and s.t >= since and s.h == ns.Dungeons.Hash(r))
  end
end

local function infoAlreadySent(ik, since)
  return function()
    local s = inflight["I:" .. ik]
    return s ~= nil and s.t >= since
  end
end

-- since: momento en que alguien lo pidió; si se indica, es un reenvío que se
-- descarta en cuanto otro se adelante.
function Sync.PushEntry(name, priority, since)
  local g = ns.G()
  local e = g and g.entries[name]
  if not e or e.demo then return end
  cancel("P", name)
  Comm.Send("P", name .. "~" .. Codec.EncodeUInt(e.v) .. "~" .. Codec.Serialize(e), "GUILD", nil, priority,
    since and entryAlreadySent(name, since) or nil)
end

function Sync.PushRequest(id, priority, since)
  local g = ns.G()
  local r = g and g.requests[id]
  if not r or r.demo then return end
  cancel("Q", id)
  Comm.Send("Q", id .. "~" .. Data.RequestHash(r) .. "~" .. Codec.Serialize(r), "GUILD", nil, priority,
    since and requestAlreadySent(id, since) or nil)
end

function Sync.PushRun(id, priority, since)
  local list = ns.Dungeons.Runs()
  local r = list and list[id]
  if not r or r.demo then return end
  cancel("M", id)
  Comm.Send("M", id .. "~" .. ns.Dungeons.Hash(r) .. "~" .. Codec.Serialize(r), "GUILD", nil, priority,
    since and runAlreadySent(id, since) or nil)
end

function Sync.PushInfo(ik, since)
  local info = Data.GetInfo(ik)
  if not info or not info.v or #info.v == 0 then return end
  cancel("I", ik)
  Comm.Send("I", ik .. "~" .. Codec.Serialize({ k = ik, v = info.v, cd = info.cd or nil }), "GUILD", nil, nil,
    infoAlreadySent(ik, since or GetTime()))
end

-- Programa un reenvío; si otro lo manda antes, se cancela.
local function schedule(kind, id, delay, ver)
  local key = kind .. ":" .. id
  if pending[key] then return end
  local token, since = {}, GetTime()
  pending[key] = { token = token, ver = ver }
  ns.After(delay, function()
    local p = pending[key]
    if not p or p.token ~= token then return end
    pending[key] = nil
    -- Lo importante primero: pedidos y quedadas salen con prioridad alta; las fichas
    -- (recetas, ofertas...) con la normal, detrás.
    if kind == "P" then
      Sync.PushEntry(id, nil, since)
    elseif kind == "Q" then
      Sync.PushRequest(id, "high", since)
    elseif kind == "M" then
      Sync.PushRun(id, "high", since)
    elseif kind == "I" then
      Sync.PushInfo(id, since)
    end
  end)
end

-- Olvidar envíos antiguos para que la tabla no crezca sin fin.
C_Timer.NewTicker(300, function()
  local limit = GetTime() - 600
  for key, s in pairs(inflight) do
    if s.t < limit then inflight[key] = nil end
  end
end)

local function involvesMe(req)
  local me = ns.Me()
  return req.a == me or (req.c and req.c[me]) and true or false
end

---------------------------------------------------------------------------
-- Resumen ("hola") y peticiones de lo que falta
---------------------------------------------------------------------------
function Sync.BuildDigest()
  local g, realm = ns.G(), ns.Realm()
  local e, r = {}, {}
  for name, ent in pairs(g.entries) do
    if not ent.demo then e[compress(name, realm)] = ent.v end
  end
  for id, req in pairs(g.requests) do
    if not req.demo then r[compress(id, realm)] = Data.RequestHash(req) end
  end
  local m
  for id, run in pairs(ns.Dungeons.Runs() or {}) do
    if not run.demo then
      m = m or {}
      m[compress(id, realm)] = ns.Dungeons.Hash(run)
    end
  end
  return { pv = ns.PROTOCOL, av = ns.VERSION, e = e, r = r, m = m }
end

function Sync.SendHello()
  if not ns.G() then return end
  Comm.Send("H", Codec.Serialize(Sync.BuildDigest()), "GUILD", nil, "high")
end

local function flushWant()
  wantScheduled = false
  local realm = ns.Realm()
  local e, r, m, any = {}, {}, {}, false
  for name, v in pairs(want.e) do
    e[compress(name, realm)] = v
    any = true
  end
  for id in pairs(want.r) do
    r[#r + 1] = compress(id, realm)
    any = true
  end
  for id in pairs(want.m) do
    m[#m + 1] = compress(id, realm)
    any = true
  end
  wipe(want.e)
  wipe(want.r)
  wipe(want.m)
  if any then Comm.Send("W", Codec.Serialize({ e = e, r = r, m = #m > 0 and m or nil }), "GUILD", nil, "high") end
end

local function scheduleWant()
  if wantScheduled then return end
  wantScheduled = true
  ns.After(rand(1, 3), flushWant)
end

---------------------------------------------------------------------------
-- Versiones del addon
---------------------------------------------------------------------------
local function versionNumber(v)
  local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)")
  if not a then return 0 end
  return tonumber(a) * 1000000 + tonumber(b) * 1000 + tonumber(c)
end
Sync.VersionNumber = versionNumber

function Sync.NotePeerVersion(sender, av)
  if type(av) ~= "string" then return end
  Sync.peers[sender] = av
  if versionNumber(av) > versionNumber(ns.VERSION) and versionNumber(av) > versionNumber(Sync.newest) then
    local first = not Sync.newest
    Sync.newest = av
    if first then ns.Print("hay una versión nueva del addon (%s); tú tienes la %s.", av, ns.VERSION) end
    ns.Fire("NEW_VERSION", av)
    if first and ns.Alerts then
      ns.Alerts.Push({ page = "home", text = string.format(
        "Hay una versión nueva del addon (%s). Cierra el juego y actualízalo: con versiones distintas no se ven los pedidos.", av) })
    end
  elseif versionNumber(av) < versionNumber(ns.VERSION) and not Sync.oldWarned[sender] then
    Sync.oldWarned[sender] = true
    ns.Print("%s tiene una versión antigua del addon (%s; la tuya es la %s): puede que no vea tus pedidos. Dile que lo actualice.",
      ns.DisplayName(sender), av, ns.VERSION)
  end
end

-- Compañeros vistos con otra versión: { "Nombre (0.25.0)", ... }.
function Sync.OtherVersions()
  local out = {}
  for name, av in pairs(Sync.peers) do
    if av ~= ns.VERSION then out[#out + 1] = string.format("%s (%s)", ns.DisplayName(name), av) end
  end
  table.sort(out)
  return out
end

---------------------------------------------------------------------------
-- Recepción
---------------------------------------------------------------------------
Comm.Register("H", function(sender, payload)
  local d = Codec.Deserialize(payload)
  if type(d) ~= "table" then return end
  Sync.NotePeerVersion(sender, d.av)
  if d.pv ~= ns.PROTOCOL then return end
  Sync.lastHello = ns.Now()
  local g = ns.G()
  if not g then return end
  local realm, me = realmOf(sender), ns.Me()
  local theirE, theirR = {}, {}
  if type(d.e) == "table" then
    for k, v in pairs(d.e) do
      if type(k) == "string" and type(v) == "number" then theirE[expand(k, realm)] = v end
    end
  end
  if type(d.r) == "table" then
    for k, v in pairs(d.r) do
      if type(k) == "string" and type(v) == "string" then theirR[expand(k, realm)] = v end
    end
  end
  -- ¿Estaba esperando a recuperar mi ficha? Si alguien la tiene, la pido (y sigo esperando);
  -- si me contestan sin tenerla y nadie la ha mencionado, soy nuevo: publico ya.
  if Sync.waitingOwn then
    if theirE[me] then
      Sync.ownSeen = true
    elseif not Sync.ownSeen then
      Sync.ownMissing = (Sync.ownMissing or 0) + 1
      if Sync.ownMissing >= 3 then
        Sync.waitingOwn = nil
        ns.After(0.5, Sync.PublishMine)
      end
    end
  end
  -- Lo que tengo y le falta (o tiene más antiguo): se lo envío.
  for name, ent in pairs(g.entries) do
    local v = theirE[name]
    if (not v or v < ent.v) and Guild.Accepts(name) then
      -- Las fichas de otros, un poco después: así no tapan a los pedidos.
      schedule("P", name, name == me and rand(0.2, 1) or rand(4, 10), ent.v)
    end
  end
  for id, req in pairs(g.requests) do
    if theirR[id] ~= Data.RequestHash(req) then
      schedule("Q", id, involvesMe(req) and rand(0.2, 1) or rand(2, 8))
    end
  end
  -- Lo que tiene y me falta: lo pido.
  for name, v in pairs(theirE) do
    local ent = g.entries[name]
    if (not ent or ent.v < v) and Guild.Accepts(name) then
      if not want.e[name] or want.e[name] < v then want.e[name] = v end
    end
  end
  for id in pairs(theirR) do
    -- las copias con el nombre mal escrito no se piden si ya tengo el pedido de verdad
    local cid = Data.CanonicalRequestId(id)
    if not g.requests[id] and not g.requests[cid] and not (g.gone and (g.gone[id] or g.gone[cid])) then
      want.r[id] = true
    end
  end
  -- Quedadas de mazmorra.
  local theirM = {}
  if type(d.m) == "table" then
    for k, v in pairs(d.m) do
      if type(k) == "string" and type(v) == "string" then theirM[expand(k, realm)] = v end
    end
  end
  local knowsLeveling = versionNumber(d.av) >= versionNumber("0.34.0")
  for id, run in pairs(ns.Dungeons.Runs() or {}) do
    if not run.demo and theirM[id] ~= ns.Dungeons.Hash(run)
      and (knowsLeveling or not ns.Dungeons.IsLeveling(run)) then
      schedule("M", id, run.a == me and rand(0.2, 1) or rand(2, 8))
    end
  end
  for id in pairs(theirM) do
    if not (ns.Dungeons.Runs() or {})[id] then want.m[id] = true end
  end
  if next(want.e) or next(want.r) or next(want.m) then scheduleWant() end
end)

Comm.Register("W", function(sender, payload)
  local w = Codec.Deserialize(payload)
  local g = ns.G()
  if type(w) ~= "table" or not g then return end
  local realm, me = realmOf(sender), ns.Me()
  if type(w.e) == "table" then
    for k, v in pairs(w.e) do
      if type(k) == "string" and type(v) == "number" then
        local name = expand(k, realm)
        if want.e[name] and want.e[name] <= v then want.e[name] = nil end -- ya lo ha pedido otro
        local ent = g.entries[name]
        if ent and ent.v >= v then
          schedule("P", name, name == me and rand(0.1, 0.5) or rand(0.5, 4), ent.v)
        end
      end
    end
  end
  if type(w.r) == "table" then
    for _, k in ipairs(w.r) do
      if type(k) == "string" then
        local id = expand(k, realm)
        want.r[id] = nil
        local req = g.requests[id]
        if req then schedule("Q", id, involvesMe(req) and rand(0.1, 0.5) or rand(0.5, 4)) end
      end
    end
  end
  if type(w.m) == "table" then
    for _, k in ipairs(w.m) do
      if type(k) == "string" then
        local id = expand(k, realm)
        want.m[id] = nil
        local run = (ns.Dungeons.Runs() or {})[id]
        if run and not run.demo then schedule("M", id, run.a == me and rand(0.1, 0.5) or rand(0.5, 4)) end
      end
    end
  end
end)

-- Cabeceras: "a~b~resto" (P, Q y M) o "a~resto" (I).
local function header2(payload)
  return payload:match("^([^~]*)~([^~]*)~(.*)$")
end

local function header1(payload)
  return payload:match("^([^~]*)~(.*)$")
end

Comm.RegisterPeek("P", function(sender, payload)
  local name, v = header2(payload)
  v = v and Codec.DecodeUInt(v, 1)
  if name and v then markInflight("P:" .. name, v) end
end)

Comm.RegisterPeek("Q", function(sender, payload)
  local id, h = header2(payload)
  if id and h then markInflight("Q:" .. id, nil, h) end
end)

Comm.RegisterPeek("M", function(sender, payload)
  local id, h = header2(payload)
  if id and h then markInflight("M:" .. id, nil, h) end
end)

Comm.RegisterPeek("I", function(sender, payload)
  local ik = header1(payload)
  if ik then markInflight("I:" .. ik) end
end)

Comm.Register("P", function(sender, payload)
  local name, _, body = header2(payload)
  local e = body and Data.SanitizeEntry(Codec.Deserialize(body))
  if not e or e.n ~= name or not Guild.Accepts(e.n) or not ns.G() then return end
  if Data.FromFuture(e, ns.Now()) then return end -- versión del futuro: no es legítima
  markInflight("P:" .. e.n, e.v)
  local p = pending["P:" .. e.n]
  if p and (p.ver or 0) <= e.v then cancel("P", e.n) end
  if want.e[e.n] and want.e[e.n] <= e.v then want.e[e.n] = nil end
  if e.n == ns.Me() and Sync.waitingOwn then
    Sync.waitingOwn = nil -- ya tengo mi ficha: ahora sí se puede publicar (con lo recuperado)
    ns.Coalesce("publishMine", 1, function() Sync.PublishMine() end)
  end
  local changed, stale = Data.ApplyEntry(e)
  if changed then
    ns.Fire("DATA_CHANGED", "entry", e.n)
    if e.n == ns.Me() then ns.Coalesce("publishMine", 3, function() Sync.PublishMine() end) end
  elseif stale then
    -- nos han mandado una ficha antigua: compartimos la nuestra, más nueva
    local cur = ns.G().entries[e.n]
    schedule("P", e.n, e.n == ns.Me() and rand(0.2, 1) or rand(2, 6), cur.v)
  end
end)

Comm.Register("Q", function(sender, payload)
  local id, _, body = header2(payload)
  local r = body and Data.SanitizeRequest(Codec.Deserialize(body))
  if not r or r.id ~= id or not Guild.Accepts(r.a) or not ns.G() then return end
  if Data.FromFuture(r, ns.Now()) then return end
  markInflight("Q:" .. r.id, nil, Data.RequestHash(r))
  want.r[r.id] = nil
  -- Copia con el nombre del autor mal escrito (de quien tiene una versión vieja): se junta con
  -- el pedido de verdad.
  local copy = Data.Canonicalize(r)
  if copy ~= r then
    want.r[copy.id] = nil
    local gone = ns.G().gone
    if gone and gone[copy.id] then return end -- el de verdad ya terminó: la copia no lo resucita
    r = copy
  end
  -- Nadie tiene más de 10 pedidos abiertos: si llegan muchos más de alguien, se ignoran (así no
  -- se puede llenar el archivo de guardado de los demás con pedidos inventados).
  if not ns.G().requests[r.id] and Data.CountOpenBy(r.a, ns.Now()) >= Data.MAX_OPEN * 2 then return end
  local changed, old, merged, behind = Data.ApplyRequest(r, ns.Now())
  if behind then
    schedule("Q", r.id, rand(1.5, 5)) -- teníamos algo que la recibida no tenía
  else
    cancel("Q", r.id)
  end
  if changed then
    -- Si es mía y alguien ha entregado (por correo), sumo su encargo.
    if merged.a == ns.Me() and Data.CheckThanks(merged, ns.Now()) then
      Sync.PublishMine()
      ns.Extras.AddStat("received", 1)
    end
    ns.Fire("DATA_CHANGED", "request", r.id)
    ns.Fire("REQUEST_UPDATED", old, merged)
  end
end)

Comm.Register("M", function(sender, payload)
  local id, _, body = header2(payload)
  local run = body and ns.Dungeons.Sanitize(Codec.Deserialize(body))
  if not run or run.id ~= id or not Guild.Accepts(run.a) or not ns.G() then return end
  if Data.FromFuture(run, ns.Now()) then return end
  markInflight("M:" .. run.id, nil, ns.Dungeons.Hash(run))
  want.m[run.id] = nil
  local runsNow = ns.Dungeons.Runs() or {}
  if not runsNow[run.id] then
    local n = 0
    for _, other in pairs(runsNow) do if other.a == run.a then n = n + 1 end end
    if n >= 10 then return end -- nadie organiza tantos grupos a la vez
  end
  local changed, old, merged, behind = ns.Dungeons.Apply(run, ns.Now())
  if behind then
    schedule("M", run.id, rand(1.5, 5))
  else
    cancel("M", run.id)
  end
  if changed then
    ns.Fire("DATA_CHANGED", "dungeon", run.id)
    ns.Fire("RUN_UPDATED", old, merged)
  end
end)

-- Materiales de una receta (se piden al ver una receta que no conocemos).
function Sync.AskInfo(ik)
  local t = GetTime()
  if infoAsked[ik] and infoAsked[ik] > t - 60 then return end
  infoAsked[ik] = t
  Comm.Send("R", Codec.Serialize(ik), "GUILD", nil, "high")
end

Comm.Register("R", function(sender, payload)
  local ik = Codec.Deserialize(payload)
  if type(ik) ~= "string" or #ik > 40 then return end
  infoAsked[ik] = GetTime() -- otro ya lo ha pedido: no repetirlo
  local info = Data.GetInfo(ik)
  if info and info.v and #info.v > 0 then schedule("I", ik, rand(0.3, 2.5)) end
end)

Comm.Register("I", function(sender, payload)
  local ik, body = header1(payload)
  local d = body and Codec.Deserialize(body)
  if type(d) ~= "table" or d.k ~= ik then return end
  markInflight("I:" .. ik)
  cancel("I", d.k)
  if Data.MergeInfo(d.k, d) then ns.Fire("DATA_CHANGED", "info", d.k) end
end)

---------------------------------------------------------------------------
-- Mi ficha y acciones locales sobre peticiones
---------------------------------------------------------------------------
Sync.OWN_ENTRY_WAIT = 10

function Sync.PublishMine()
  if not ns.G() or not ns.MyChar() then return end
  if Sync.waitingOwn then return end -- esperando a recuperar mi ficha de la hermandad
  -- Antes de hablar con la hermandad no se crea mi ficha si este ordenador no la tiene:
  -- Sync.Start decide si hay que recuperarla primero.
  if not started and not ns.G().entries[ns.Me()] then return end
  local changed = Data.UpdateMyEntry(ns.Now())
  if changed then
    ns.Fire("DATA_CHANGED", "entry", ns.Me())
    if started then Sync.PushEntry(ns.Me()) end
  end
end

local function afterRequestAction(r, err)
  if not r then
    if err then ns.Print(err) end
    return nil, err
  end
  Sync.PushRequest(r.id, "high")
  ns.Fire("DATA_CHANGED", "request", r.id)
  return r
end

function Sync.CreateRequest(opts)
  local r, err = afterRequestAction(Data.CreateRequest(opts, ns.Now()))
  -- También en el chat de hermandad: queda en el historial para quien entre más tarde.
  if r and ns.ChatLog then ns.SafeCall(ns.ChatLog.Post, r) end
  return r, err
end

function Sync.Commit(id, when)
  local r, err = afterRequestAction(Data.Commit(id, when, ns.Now()))
  if r and r.demo and ns.Demo then ns.Demo.OnCommit(r) end
  return r, err
end

function Sync.Extend(id, when)
  return afterRequestAction(Data.Extend(id, when, ns.Now()))
end

function Sync.Release(id)
  return afterRequestAction(Data.Release(id, ns.Now()))
end

function Sync.Reject(id, crafter)
  return afterRequestAction(Data.Reject(id, crafter, ns.Now()))
end

function Sync.ConfirmDelivery(id, crafter, amount)
  local r, thanksChanged = Data.ConfirmDelivery(id, crafter, amount, ns.Now())
  if r and thanksChanged == true then
    Sync.PublishMine()
    ns.Extras.AddStat("received", 1)
  end
  return afterRequestAction(r, type(thanksChanged) == "string" and thanksChanged or nil)
end

function Sync.SetQuantity(id, q)
  return afterRequestAction(Data.SetQuantity(id, q, ns.Now()))
end

function Sync.Close(id)
  return afterRequestAction(Data.CloseRequest(id, ns.Now()))
end

function Sync.Renew(id)
  return afterRequestAction(Data.RenewRequest(id, ns.Now()))
end

-- Quedadas de mazmorra.
local function afterRunAction(r, err)
  if not r then
    if err then ns.Print(err) end
    return nil, err
  end
  Sync.PushRun(r.id, "high")
  ns.Fire("DATA_CHANGED", "dungeon", r.id)
  return r
end

function Sync.CreateRun(opts)
  return afterRunAction(ns.Dungeons.Create(opts, ns.Now()))
end

function Sync.SignUpRun(id, roles)
  return afterRunAction(ns.Dungeons.SignUp(id, roles, ns.Now()))
end

function Sync.LeaveRun(id)
  return afterRunAction(ns.Dungeons.Leave(id, ns.Now()))
end

function Sync.MakeGroup(id)
  return afterRunAction(ns.Dungeons.MakeGroup(id, ns.Now()))
end

function Sync.CancelRun(id)
  return afterRunAction(ns.Dungeons.Cancel(id, ns.Now()))
end

function Sync.FinishRun(id)
  local r = afterRunAction(ns.Dungeons.Finish(id, ns.Now()))
  if r then ns.Print("quedada cerrada. ¡Buena mazmorra!") end
  return r
end

function Sync.SetUnavailable(value)
  local c = ns.MyChar()
  if not c then return end
  c.u = value and true or nil
  Sync.PublishMine()
end

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
function Sync.Start()
  if started or not ns.G() or not ns.Me() then return end
  started = true
  Data.Purge(ns.Now())
  ns.Dungeons.Purge(ns.Now())
  -- Si este ordenador no tiene mi ficha (otro PC o reinstalación), primero la recupero de la
  -- hermandad: si publicase ya una nueva y vacía, pisaría la buena (karma, ofertas...).
  local g = ns.G()
  if g and not g.entries[ns.Me()] then
    Sync.waitingOwn, Sync.ownSeen, Sync.ownMissing = true, nil, 0
    local tries = 0
    local function giveUp()
      if not Sync.waitingOwn then return end
      -- si alguien dijo tenerla, darle algo más de tiempo para que llegue (hasta 30 s)
      tries = tries + 1
      if Sync.ownSeen and tries < 3 then return ns.After(Sync.OWN_ENTRY_WAIT, giveUp) end
      Sync.waitingOwn = nil
      Sync.PublishMine()
    end
    ns.After(Sync.OWN_ENTRY_WAIT, giveUp)
  else
    Sync.PublishMine()
  end
  ns.After(1, Sync.SendHello)
  -- Pedidos publicados mientras no estaba (del historial del chat de hermandad).
  ns.After(5, function() if started and ns.ChatLog then ns.SafeCall(ns.ChatLog.ReadHistory) end end)
  -- Resumen en el chat cuando ya se ha puesto al día.
  ns.After(45, function()
    local list = Data.ServableRequests(ns.Now())
    if #list > 0 then
      ns.Print("hay %d %s que puedes hacer. Míralas en el addon (pulsa la J).",
        #list, #list == 1 and "petición" or "peticiones")
      ns.Fire("DATA_CHANGED", "summary")
    end
  end)
  -- Resúmenes periódicos: recuperan lo que se haya perdido (mensajes cortados, alguien que se
  -- fue a medias...). El primero a los 3 minutos y luego cada 5 (con algo de azar para no
  -- coincidir todos). Si nadie tiene nada nuevo, solo cuesta un mensaje pequeño.
  local key = ns.guildKey
  local function again()
    if not started or ns.guildKey ~= key then return end
    Sync.SendHello()
    ns.After(Sync.RESYNC_EVERY + rand(0, 60), again)
  end
  ns.After(180, again)
end

function Sync.IsStarted()
  return started
end

ns.Listen("GUILD_CHANGED", function(key)
  started = false
  wipe(pending)
  wipe(want.e)
  wipe(want.r)
  wipe(want.m)
  Data.indexDirty = true
  ns.Fire("DATA_CHANGED", "guild")
  if key then ns.After(8, Sync.Start) end
end)

ns.Listen("LOGIN", function()
  C_Timer.NewTicker(300, function()
    ns.SafeCall(function()
      if not ns.G() then return end
      Data.Purge(ns.Now())
      ns.Dungeons.Purge(ns.Now())
      Sync.PublishMine() -- por si ha terminado algún cooldown
      ns.Fire("DATA_CHANGED", "tick")
    end)
  end)
end)
