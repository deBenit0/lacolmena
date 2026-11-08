local H = ...
-- Hermandad: alts, oficiales (anuncio, prioridad, cerrar), necesidades con donaciones,
-- miembro de la semana, inactivos y la pestaña Raids.
H.AddMember("Ana", "PALADIN", 60)
H.AddMember("Bea", "WARRIOR", 60)
H.AddMember("Beita", "MAGE", 20) -- alt de Bea
H.AddMember("Cris", "PRIEST", 60)
H.AddMember("Dani", "ROGUE", 60) -- sin el addon
for _, m in ipairs(H.roster) do if m.name == "Ana" then m.rankIndex = 1 end end -- Ana es oficial
H.itemClass = { [13443] = { 0, 1 } }
local ana = H.Login("Ana", { class = "PALADIN" })
local bea = H.Login("Bea", { class = "WARRIOR", bags = { [13443] = 10 } })
local cris = H.Login("Cris", { class = "PRIEST" })
H.Advance(20)
local S = bea.ns.Social

-- Oficiales.
H.ok(ana.ns.Social.AmOfficer(), "Ana es oficial (rango 1)")
H.ok(not S.AmOfficer(), "Bea no")
H.ok(S.SetAnnouncement("hola", bea.ns.Now()) == nil, "Bea no puede publicar anuncios")
H.ok(ana.ns.Social.SetAnnouncement("Banda el sábado a las 21:00", ana.ns.Now()), "Ana publica un anuncio")
H.Advance(15)
local an = S.Announcement()
H.ok(an and an.name == "Ana-Reino" and an.x:find("sábado", 1, true), "Bea ve el anuncio de Ana")
-- Un no oficial que se cuela un anuncio en su ficha no cuenta.
bea.ns.MyChar().announce = { x = "falso", t = bea.ns.Now() + 10 }
bea.ns.Sync.PublishMine()
H.Advance(15)
H.eq(cris.ns.Social.Announcement().name, "Ana-Reino", "el anuncio de un no oficial no cuenta")
bea.ns.MyChar().announce = nil
bea.ns.Sync.PublishMine()

-- Prioridad y cerrar como oficial.
local req = cris.ns.Sync.CreateRequest({ k = "i13443", q = 5 })
H.Advance(15)
ana.ns.Social.SetPriority(req.id, true, ana.ns.Now())
H.Advance(15)
H.ok(S.IsPriority(req.id), "Bea ve la prioridad")
ana.ns.Social.ModClose(req.id, ana.ns.Now())
H.Advance(15)
local info = bea.ns.Data.RequestInfo(bea.ns.G().requests[req.id], bea.ns.Now())
H.ok(info.state == "closed" and info.moderated, "Bea lo ve cerrado por un oficial")
H.ok(bea.ns.Social.ModClose(req.id, bea.ns.Now()) == nil, "Bea no puede cerrar pedidos de otros")

-- Necesidades: Ana pide 10 pociones; Bea dona 4 por correo.
H.ok(ana.ns.Social.AddNeed(13443, 10, ana.ns.Now()), "Ana añade una necesidad")
H.ok(S.AddNeed(13443, 5, bea.ns.Now()) == nil, "Bea no puede añadir necesidades")
H.Advance(15)
local needs = S.Needs(bea.ns.Now())
H.eq(#needs, 1, "Bea ve la necesidad")
H.eq(needs[1].left, 10, "faltan 10")
H.SendMail(bea, "Ana", { { 13443, 4 } })
H.Advance(15)
needs = cris.ns.Social.Needs(cris.ns.Now())
H.eq(needs[1].given, 4, "Cris ve 4 aportadas")
H.eq(needs[1].donors[1].name, "Bea-Reino", "por Bea")
H.SendMail(bea, "Ana", { { 13443, 9 } })
H.Advance(15)
needs = cris.ns.Social.Needs(cris.ns.Now())
H.ok(needs[1].given == 10 and needs[1].left == 0, "solo cuenta hasta lo que hacía falta")

-- Miembro de la semana: Bea aportó dos veces a la MISMA necesidad: cuenta como 1 ayuda
-- (trocear los envíos no infla las ayudas).
local ranking = cris.ns.Social.Ranking("this", cris.ns.Now())
H.ok(ranking[1] and ranking[1].name == "Bea-Reino" and ranking[1].n == 1, "Bea lidera esta semana (1 ayuda, no 2)")
H.Advance(7 * 86400)
H.Advance(30)
bea.ns.Sync.PublishMine()
H.Advance(30)
local best = cris.ns.Social.MemberOfTheWeek(cris.ns.Now())
H.ok(best and best.name == "Bea-Reino" and best.n == 1, "la semana siguiente, Bea es el miembro de la semana")

-- Alts: Bea entra con Beita (misma cuenta). Su principal es Bea (más nivel).
local beaDB = H.Logout(bea)
local beita = H.Login("Beita", { class = "MAGE", level = 20, savedDB = beaDB })
H.Advance(30)
H.eq(beita.ns.Social.MyMain(), "Bea-Reino", "el principal es el de más nivel")
-- Hasta que Bea no lo confirme (al entrar con ella), no cuenta: nadie se puede declarar alt de otro.
H.eq(cris.ns.Social.MainOf("Beita-Reino"), "Beita-Reino", "sin confirmar por la principal, no cuenta")
local beitaDB = H.Logout(beita)
local bea2 = H.Login("Bea", { class = "WARRIOR", savedDB = beitaDB })
H.Advance(30)
local beaDB2 = H.Logout(bea2)
beita = H.Login("Beita", { class = "MAGE", level = 20, savedDB = beaDB2 })
H.Advance(30)
H.eq(cris.ns.Social.MainOf("Beita-Reino"), "Bea-Reino", "los demás saben que Beita es alt de Bea")
H.eq(cris.ns.Social.Who("Beita-Reino"), "Beita (Bea)", "se muestra como Beita (Bea)")
-- Karma por persona: lo que haga Beita suma a Bea.
local kBea = cris.ns.Data.KarmaFor("Bea-Reino")
local r2 = cris.ns.Sync.CreateRequest({ k = "i13443", q = 1 })
H.Advance(15)
beita.ns.Sync.Commit(r2.id, 1)
H.Advance(15)
H.SendMail(beita, "Cris", { { 13443, 1 } })
H.Advance(30)
H.eq(cris.ns.Data.KarmaFor("Bea-Reino") - kBea, 1, "lo entregado por Beita suma karma a Bea")
H.eq(cris.ns.Data.KarmaFor("Beita-Reino"), cris.ns.Data.KarmaFor("Bea-Reino"), "mismo karma para los dos personajes")
-- Elegir otro principal.
beita.ns.Social.SetMyMain("Beita-Reino")
H.Advance(15)
H.eq(cris.ns.Social.MainOf("Beita-Reino"), "Beita-Reino", "cambiar de principal")

-- Inactivos y sin el addon (para oficiales).
local _, noAddon = ana.ns.Social.Inactive(ana.ns.Now())
local hasDani = false
for _, n in ipairs(noAddon) do if n == "Dani-Reino" then hasDani = true end end
H.ok(hasDani, "Dani sale como sin el addon")

-- Pantallas: Raids sin poder pulsarse, pestaña Hermandad, anuncio en el Inicio.
local env = cris.env
local gf = env.CreateFrame("Frame", "GuildFrame", env.UIParent)
cris.ns.UI.AttachHost(gf)
env.HDFProfGuildTabGuildFrame:Click()
local panel = env.HDFProfPanel
H.ok(panel.sections.raids and not panel.sections.raids:IsEnabled(), "pestaña Raids, sin poder pulsarse")
H.ok(panel.pageFrames.home.announce:GetText():find("sábado", 1, true), "el anuncio sale en el Inicio")
cris.ns.UI.ShowPage("guild")
local gpage = panel.pageFrames.guild
H.ok(gpage:IsShown(), "pestaña Hermandad")
H.eq(#gpage.list.items, 1, "se ve la necesidad")
H.ok(not gpage.addNeed:IsShown(), "Cris no ve Añadir (no es oficial)")
H.ok(gpage.notOfficer:IsShown(), "explica las herramientas de oficial")
-- Ana (oficial) ve sus herramientas.
local aenv = ana.env
local agf = aenv.CreateFrame("Frame", "GuildFrame", aenv.UIParent)
ana.ns.UI.AttachHost(agf)
aenv.HDFProfGuildTabGuildFrame:Click()
ana.ns.UI.ShowPage("guild")
local apage = aenv.HDFProfPanel.pageFrames.guild
H.ok(apage.addNeed:IsShown() and apage.publish:IsShown() and apage.inactive:IsShown(), "Ana ve las herramientas de oficial")
H.ok(apage.inactive:GetText():find("Sin el addon", 1, true), "lista de quien no tiene el addon")
apage.addNeed:Click()
H.ok(aenv.HDFProfPanel.pageFrames.materials:IsShown(), "Añadir lleva a Pedir materiales")
-- Un oficial crea un pedido de hermandad desde la ventana normal de pedir.
ana.ns.UI.OpenRequestDialog({ k = "i13446", q = 1 })
local rd = aenv.HDFProfRequestDialog
H.ok(rd.guild:IsShown(), "el oficial ve la casilla Para la hermandad")
rd.qty:SetText("30")
rd.guild:SetChecked(true)
rd:Publish()
H.Advance(15)
local found
for _, n in ipairs(cris.ns.Social.Needs(cris.ns.Now())) do if n.id == 13446 then found = n end end
H.ok(found and found.q == 30 and found.owner == "Ana-Reino", "pedido de hermandad creado (30)")
-- Cris (no oficial) no ve la casilla.
cris.ns.UI.OpenRequestDialog({ k = "i13446", q = 1 })
H.ok(not env.HDFProfRequestDialog.guild:IsShown(), "los demás no ven la casilla")
env.HDFProfRequestDialog:Hide()
-- En el tablón de Cris sale como [Hermandad] con Aportar, y aportan varios.
cris.ns.UI.ShowPage("board")
local cboard = env.HDFProfPanel.pageFrames.board
cboard:Refresh()
local needRow
for _, row in ipairs(cboard.list.rows) do
  if row.item and row.item.kind == "need" and row.item.need.id == 13446 then needRow = row end
end
H.ok(needRow and needRow.title:GetText():find("[Hermandad]", 1, true), "sale en el Tablón como [Hermandad]")
H.eq(needRow.accept:GetText(), "Aportar", "con el botón Aportar")
H.eq(cboard.offer, nil, "en el Tablón ya no hay Ofrecer objeto (se ofrece desde la profesión)")

-- Modo demostración: Gerda hace de oficial con anuncio y necesidades.
cris.ns.Demo.Set(true)
H.eq(cris.ns.Social.Announcement().name, "Gerda-Demo", "anuncio de ejemplo")
local demoNeeds = 0
for _, n in ipairs(cris.ns.Social.Needs(cris.ns.Now())) do if n.owner == "Gerda-Demo" then demoNeeds = demoNeeds + 1 end end
H.eq(demoNeeds, 2, "necesidades de ejemplo")
H.eq(cris.ns.Social.Who("Olaf-Demo"), "Olaf (Bruno)", "alt de ejemplo")
cris.ns.Demo.Set(false)

H.eq(#H.errors, 0, "sin errores de Lua")
