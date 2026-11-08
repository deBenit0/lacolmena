local H = ...
-- Pedidos en el chat de hermandad: llegan aunque quien pide ya se haya ido.
H.AddMember("Ana")
H.AddMember("Bea")
H.AddMember("Cris")
local ana = H.Login("Ana")
H.Advance(20)

-- 1) Ana pide sola (nadie más conectado) y se va.
local r = ana.ns.Sync.CreateRequest({ k = "i2840", q = 5, g = 5000, pr = 1 })
H.ok(r, "pedido creado")
H.Advance(2)
H.eq(#H.guildChat, 1, "sale una línea en el chat de hermandad")
local line = H.guildChat[1] and H.guildChat[1].content or ""
H.ok(line:find("Pido 5x", 1, true), "se lee bien: " .. line)
H.ok(line:find("propina 50 plata", 1, true), "con la propina")
H.ok(line:find("(HDF1 ", 1, true), "con la marca para el addon")
H.ok(#line <= 255, "cabe en una línea")
local id = r.id
local saved = H.Logout(ana)
H.Advance(60)

-- 2) Bea entra después: lo recupera del historial.
local bea = H.Login("Bea")
H.Advance(20)
local got = bea.ns.G().requests[id]
H.ok(got, "Bea tiene el pedido de Ana aunque nunca coincidieron")
if got then
  H.eq(got.a, "Ana-Reino", "de Ana")
  H.eq(got.k, "i2840", "el mismo objeto")
  H.eq(got.q, 5, "la misma cantidad")
  H.eq(got.g, 5000, "la misma propina")
  H.eq(got.pr, 1, "la misma prisa")
  H.eq(bea.ns.Data.RequestInfo(got, bea.ns.Now()).state, "open", "abierto")
end
H.eq(bea.ns.ChatLog.found, 1, "la comprobación cuenta un pedido recuperado")

-- 3) Bea lo acepta; cuando Ana vuelve, se juntan bien (gana la versión de verdad de Ana).
bea.ns.Sync.Commit(id, 2)
H.Advance(5)
ana = H.Login("Ana", { savedDB = saved })
H.Advance(30)
local a1 = ana.ns.G().requests[id]
local b1 = bea.ns.G().requests[id]
H.ok(a1 and a1.c and a1.c["Bea-Reino"], "a Ana le llega que Bea lo hace")
H.eq(ana.ns.Data.RequestHash(a1), bea.ns.Data.RequestHash(b1), "los dos tienen lo mismo")
H.eq(b1.av, a1.av, "Bea ya tiene la versión de Ana")
H.eq(a1.av, r.av, "la de Ana no se ha pisado con la del chat")

-- 4) Nadie puede publicar un pedido en nombre de otro: el autor lo pone el servidor.
local fake = line:gsub("Pido 5x", "Pido 9x")
local cris = H.Login("Cris")
H.Advance(20)
bea.ns.ChatLog.Consider(fake, "Cris-Reino", bea.ns.Now())
local stolen = bea.ns.G().requests["Cris-Reino:" .. id:match(":(.+)$")]
H.ok(stolen == nil or stolen.a == "Cris-Reino", "una línea copiada solo vale como pedido de quien la escribe")
H.ok(not bea.ns.ChatLog.Consider("(HDF1 zz zz)", "Cris-Reino", bea.ns.Now()), "una marca rota no hace nada")
H.ok(not bea.ns.ChatLog.Consider(line, "Extraño-Reino", bea.ns.Now()), "de fuera de la hermandad, no")

-- 5) Borrado y purgado: no vuelve desde el historial.
ana.ns.Sync.Close(id)
H.Advance(10)
H.eq(bea.ns.Data.RequestInfo(bea.ns.G().requests[id], bea.ns.Now()).state, "closed", "Bea lo ve borrado")
H.Advance(3 * 86400)
bea.ns.Data.Purge(bea.ns.Now())
H.ok(bea.ns.G().requests[id] == nil, "se purga")
bea.ns.ChatLog.ReadDownloaded()
H.ok(bea.ns.G().requests[id] == nil, "y no vuelve desde el historial")

-- 6) Desactivado en Mis cosas: no escribe.
local before = #H.guildChat
cris.ns.db.settings.chatPost = false
cris.ns.Sync.CreateRequest({ k = "i2841", q = 1 })
H.Advance(2)
H.eq(#H.guildChat, before, "sin línea si está desactivado")

-- 7) Nombres largos: la marca siempre entera.
local long = { id = "Ana-Reino:" .. ana.ns.Codec.EncodeUInt(999999999) .. "a", a = "Ana-Reino", k = "i2840", q = 200, g = 999999, pr = 3, m = true }
local text = ana.ns.ChatLog.Text(long)
H.ok(#text <= 255, "cabe")
local back = ana.ns.ChatLog.Parse(text, "Ana-Reino")
H.ok(back and back.q == 200 and back.m == true and back.pr == 3 and back.g == 999999, "se recupera entero")

H.eq(#H.errors, 0, "sin errores de Lua")
