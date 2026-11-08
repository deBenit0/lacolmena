local H = ...
H.AddMember("Ana", "MAGE")
H.AddMember("Bea")
H.AddMember("Cris")
local ana = H.Login("Ana", { class = "MAGE" })
H.Advance(20)
local ns = ana.ns
local Data, Codec = ns.Data, ns.Codec
H.ok(ns.G() ~= nil, "Ana está en la hermandad")
H.eq(ns.guildKey, "Los hijos del Fundillo-Reino", "clave de hermandad")

local function as(name, fn)
  local saved = ns.me
  ns.me = name .. "-Reino"
  local a, b = fn()
  ns.me = saved
  return a, b
end
local function now() return ns.Now() end

-- Ciclo completo de una petición.
local r = Data.CreateRequest({ k = "i100", q = 5, g = 5000, m = true }, now())
H.ok(r ~= nil, "crear petición")
H.eq(Data.RequestInfo(r, now()).state, "open", "nueva: abierta")
H.eq(Data.RequestInfo(r, now()).remaining, 5, "faltan 5")

-- Bea acepta "antes de 2 horas": se queda el pedido entero.
as("Bea", function() return Data.Commit(r.id, 2, now()) end)
local info = Data.RequestInfo(r, now())
H.eq(info.state, "accepted", "Bea lo acepta: aceptada")
H.eq(info.owner, "Bea-Reino", "es de Bea")
H.eq(r.c["Bea-Reino"].n, 5, "se queda las 5")
H.eq(r.c["Bea-Reino"].w, 2, "dijo antes de 2 horas")
H.eq(r.c["Bea-Reino"].by, now() + 7200, "plazo: 2 horas")

-- Cris llega tarde: no puede.
local okCris, errCris = as("Cris", function() return Data.Commit(r.id, 1, now()) end)
H.ok(okCris == nil and errCris and errCris:find("Bea", 1, true), "Cris no puede: ya lo aceptó Bea")

local okSelf, errSelf = Data.Commit(r.id, 1, now())
H.ok(okSelf == nil and errSelf, "el autor no puede aceptar su propia petición")

-- Si no lo entrega a tiempo (plazo + 15 min de margen), vuelve al tablón.
H.eq(Data.RequestInfo(r, now() + 7200 + 10 * 60).state, "accepted", "dentro del margen sigue aceptada")
H.eq(Data.RequestInfo(r, now() + 7200 + 16 * 60).state, "open", "pasado el plazo vuelve a abierta")

as("Bea", function() return Data.Release(r.id, now()) end)
info = Data.RequestInfo(r, now())
H.eq(info.state, "open", "Bea suelta: vuelve a abierta")
H.eq(info.owner, nil, "sin encargado")

-- Ahora la coge Cris "ya" y se la entregan en mano.
as("Cris", function() return Data.Commit(r.id, 1, now()) end)
H.eq(r.c["Cris-Reino"].by, now() + 3600, "lo hago ya: 1 hora")
local _, thanks = Data.ConfirmDelivery(r.id, "Cris-Reino", 5, now())
H.ok(thanks == true, "confirmar a Cris suma un encargo")
H.eq(ns.G().thanks["Ana-Reino"]["Cris-Reino"], 1, "contador de Cris")
info = Data.RequestInfo(r, now())
H.eq(info.state, "done", "todo entregado: hecha")
H.eq(Data.KarmaFor("Ana-Reino"), 0, "el karma propio se publica con la ficha (aún no)")
H.eq(ns.G().karma["Ana-Reino"].kc["Cris-Reino"], Data.KARMA_POINT, "Cris gana 1 punto por el pedido")

-- Más tiempo: no cambia quién lo tiene, solo una vez; y si se pasa el plazo, aviso al autor.
local re = Data.CreateRequest({ k = "i102", q = 2 }, now())
as("Bea", function() return Data.Commit(re.id, 1, now()) end)
re.c["Cris-Reino"] = { n = 2, cv = now() + 5, at = now() + 5, w = 3, by = now() + 99999 } -- Cris, más tarde
H.eq(Data.RequestInfo(re, now()).owner, "Bea-Reino", "Bea lo aceptó antes")
local okExt = as("Bea", function() return Data.Extend(re.id, 3, now() + 60) end)
H.ok(okExt ~= nil, "Bea pide más tiempo")
H.eq(Data.RequestInfo(re, now() + 60).owner, "Bea-Reino", "sigue siendo de Bea aunque cambie su versión")
local okTwice, errTwice = as("Bea", function() return Data.Extend(re.id, 3, now() + 120) end)
H.ok(okTwice == nil and errTwice, "solo una vez")
re.c["Cris-Reino"] = nil
local pushes = {}
local push = ns.Alerts.Push
ns.Alerts.Push = function(a) pushes[#pushes + 1] = a.text end
re.c["Bea-Reino"].by = now() - 20 * 60
ns.Alerts.CheckDeadlines()
ns.Alerts.Push = push
H.ok(pushes[1] and pushes[1]:find("no lo entregó a tiempo", 1, true), "aviso al autor: vuelve al tablón")
H.eq(Data.RequestInfo(re, now()).state, "open", "y vuelve a estar abierto")
re.x = now()

-- "Hoy": hasta medianoche y como mínimo 3 horas.
H.ok(Data.Deadline(3, 1000) >= 1000 + 3 * 3600, "hoy: al menos 3 horas")

-- Prisa del que pide.
local rp = Data.CreateRequest({ k = "i101", q = 1, pr = 1 }, now())
H.eq(rp.pr, 1, "prisa guardada")
H.eq(Data.SanitizeRequest(rp).pr, 1, "la prisa sobrevive al saneado")
rp.x = now() -- cerrada: no cuenta para el límite

-- Límite de 10 peticiones abiertas.
local created = 0
for i = 1, 12 do
  if Data.CreateRequest({ k = "i" .. (200 + i), q = 1 }, now()) then created = created + 1 end
end
H.eq(created, 10, "como mucho 10 abiertas")
H.eq(Data.CountOpenBy("Ana-Reino", now()), 10, "cuenta de abiertas")

-- Caducidad, renovación y limpieza.
local g = ns.G()
local old
for _, req in pairs(g.requests) do
  if req.k == "i201" then old = req end
end
H.eq(Data.RequestInfo(old, now() + 8 * 86400).state, "expired", "a los 8 días: caducada")
old.t = now() - 8 * 86400
old.av = old.t
H.eq(Data.RequestInfo(old, now()).state, "expired", "caducada")
H.ok(Data.RenewRequest(old.id, now()) ~= nil, "renovar una caducada")
H.eq(Data.RequestInfo(old, now()).state, "open", "renovada: abierta otra vez")
Data.CloseRequest(old.id, now())
H.eq(Data.RequestInfo(old, now()).state, "closed", "cerrada")
Data.Purge(now() + Data.KEEP_AFTER - 10)
H.ok(g.requests[old.id] ~= nil, "una cerrada se ve un tiempo")
Data.Purge(now() + Data.KEEP_AFTER + 10)
H.ok(g.requests[old.id] == nil, "y luego se borra")
-- Una petición borrada no resucita si alguien manda una copia antigua.
local changed = Data.ApplyRequest(Data.SanitizeRequest(old), now() + Data.KEEP_AFTER + 20)
H.ok(not changed, "no se resucitan peticiones terminadas hace tiempo")

-- Fusión: conmutativa, asociativa e idempotente con variantes aleatorias.
local base = Data.SanitizeRequest({ id = "Ana-Reino:x", a = "Ana-Reino", t = 10, k = "i500", q = 4, av = 1 })
local names = { "Bea-Reino", "Cris-Reino", "Dani-Reino" }
local function variant()
  local v = H.copy(base)
  if math.random() < 0.5 then
    v.av = math.random(1, 4)
    v.q = math.random(1, 9)
    if math.random() < 0.3 then v.x = math.random(1, 9) end
    if math.random() < 0.3 then v.g = math.random(1, 3) * 100 end
  end
  v.c = {}
  for _, name in ipairs(names) do
    if math.random() < 0.7 then
      local cm = {}
      if math.random() < 0.6 then
        cm.n = math.random(1, 5)
        cm.cv = math.random(1, 4)
        if math.random() < 0.3 then cm.rl = true end
      end
      if math.random() < 0.5 then
        cm.d = math.random(1, 5)
        cm.dv = math.random(1, 4)
      end
      if next(cm) then v.c[name] = cm end
    end
  end
  return Data.SanitizeRequest(v)
end
local S, M = Codec.Serialize, Data.MergeRequests
local good = true
for i = 1, 500 do
  local a, b, c = variant(), variant(), variant()
  if S(M(a, b)) ~= S(M(b, a)) then good = false; H.ok(false, "no conmutativa: " .. S(a) .. " / " .. S(b)) break end
  if S(M(M(a, b), c)) ~= S(M(a, M(b, c))) then good = false; H.ok(false, "no asociativa") break end
  if S(M(a, a)) ~= S(a) then good = false; H.ok(false, "no idempotente: " .. S(a)) break end
  if S(M(M(a, b), b)) ~= S(M(a, b)) then good = false; H.ok(false, "volver a fusionar cambia el resultado") break end
end
H.ok(good, "fusión conmutativa, asociativa e idempotente (500 casos)")

-- Mi ficha: la versión solo sube si cambia algo.
local c = ns.MyChar()
c.profs[171] = { recipes = { i100 = true, i101 = true }, cd = {}, r = 300, m = 300 }
H.ok(Data.UpdateMyEntry(now()), "primera ficha")
local v1 = g.entries["Ana-Reino"].v
H.Advance(5)
H.ok(not Data.UpdateMyEntry(now()), "sin cambios no sube versión")
H.eq(g.entries["Ana-Reino"].v, v1, "misma versión")
c.profs[171].recipes.i102 = true
H.ok(Data.UpdateMyEntry(now()), "receta nueva sube versión")
H.ok(g.entries["Ana-Reino"].v > v1, "versión mayor")
local idx = Data.GetIndex()
H.ok(idx.i102 and idx.i102.crafters[1].n == "Ana-Reino", "índice: Ana fabrica i102")
H.ok(Data.ICanCraft("i101"), "sé fabricar i101")
H.ok(not Data.ICanCraft("i999"), "no sé fabricar i999")

-- Materiales: variantes de una misma receta y cooldowns conocidos.
H.ok(Data.AddInfoVariant("171:i7080", 1, { [7076] = 1 }), "variante 1")
H.ok(Data.AddInfoVariant("171:i7080", 1, { [12808] = 1 }), "variante 2 (otra receta, mismo objeto)")
H.ok(not Data.AddInfoVariant("171:i7080", 1, { [7076] = 1 }), "variante repetida")
H.eq(#Data.GetInfo("171:i7080").v, 2, "dos variantes")
H.ok(Data.IsCooldownRecipe("171:i12360"), "arcanita tiene cooldown")
H.ok(not Data.IsCooldownRecipe("171:i100"), "receta normal sin cooldown")
