local H = ...
-- Quedadas de mazmorra: proponer, apuntarse por rol, hacer grupo e invitar.
H.AddMember("Ana", "PALADIN", 30)
H.AddMember("Bea", "WARRIOR", 31)
H.AddMember("Cris", "PRIEST", 30)
H.AddMember("Dani", "MAGE", 29)
H.AddMember("Eva", "ROGUE", 32)
H.AddMember("Fran", "HUNTER", 20)
H.AddMember("Gus", "DRUID", 30)
local ana = H.Login("Ana", { class = "PALADIN", level = 30 })
local bea = H.Login("Bea", { class = "WARRIOR", level = 31 })
local cris = H.Login("Cris", { class = "PRIEST", level = 30 })
local dani = H.Login("Dani", { class = "MAGE", level = 29 })
local eva = H.Login("Eva", { class = "ROGUE", level = 32 })
local fran = H.Login("Fran", { class = "HUNTER", level = 20 })
H.Advance(20)
local D = ana.ns.Dungeons

-- Lista: clásicas y las 9 nuevas de WoW Forever, con id fijo y ordenadas por nivel.
local new = 0
for i, dg in ipairs(D.LIST) do
  if dg.new then new = new + 1 end
  if i > 1 then H.ok(dg.min >= D.LIST[i - 1].min, "ordenadas por nivel: " .. dg.name) end
end
H.eq(new, 9, "las 9 mazmorras nuevas de WoW Forever")
H.eq(#D.LIST, 28, "28 mazmorras en total")
H.eq(D.Dungeon(104).name, "Ciudad de Dalaran", "se buscan por id")
H.ok(D.Dungeon(D.Recommended(30)).min <= 30 and D.Dungeon(D.Recommended(30)).max >= 30, "recomienda una de tu nivel")

-- Roles por clase: un mago no puede tanquear.
H.eq(D.RolesFor("MAGE"), 4, "mago: solo DPS")
H.eq(D.RolesFor("PALADIN"), 7, "paladín: los tres")

-- Ana propone Ciudad de Dalaran dentro de 30 minutos y va de sanadora o DPS.
local run = ana.ns.Sync.CreateRun({ d = 104, at = ana.ns.Now() + 1800, roles = D.HEAL + D.DPS })
H.ok(run ~= nil, "quedada creada")
H.Advance(10)
H.ok(bea.ns.Dungeons.Runs()[run.id] ~= nil, "Bea la ve")
H.ok(bea.env.HDFProfAlert and bea.env.HDFProfAlert:IsShown()
  and bea.env.HDFProfAlert.text:GetText():find("Ciudad de Dalaran", 1, true), "aviso a Bea: propone Dalaran")
H.ok(not fran.ns.G().runAlerted or not fran.ns.G().runAlerted[run.id], "Fran (nivel 20) no recibe aviso")

-- Se apuntan. El mago intenta tanquear: solo le cuenta DPS.
bea.ns.Sync.SignUpRun(run.id, D.TANK + D.DPS)
cris.ns.Sync.SignUpRun(run.id, D.HEAL)
dani.ns.Sync.SignUpRun(run.id, D.TANK + D.DPS)
eva.ns.Sync.SignUpRun(run.id, D.DPS)
fran.ns.Sync.SignUpRun(run.id, D.DPS)
H.Advance(15)
local r = ana.ns.Dungeons.Runs()[run.id]
H.eq(r.s["Dani-Reino"].r, D.DPS, "el mago solo cuenta como DPS")
H.eq(#ana.ns.Dungeons.SignUps(r), 6, "6 apuntados (con Ana)")
local okNone, errNone = dani.ns.Dungeons.SignUp(run.id, D.TANK, dani.ns.Now())
H.ok(okNone == nil and errNone, "si ningún rol vale para su clase, no se apunta")

-- Solo quien la propuso hace el grupo.
local okMake = bea.ns.Dungeons.MakeGroup(run.id, bea.ns.Now())
H.ok(okMake == nil, "Bea no puede hacer el grupo")

-- Ana hace el grupo: Bea tanque, y para sanar Cris (Ana pasa a DPS porque así se llena todo).
ana.ns.Sync.MakeGroup(run.id)
r = ana.ns.Dungeons.Runs()[run.id]
H.eq(r.gp.t, "Bea-Reino", "tanque: Bea")
H.ok(r.gp.h == "Cris-Reino" or r.gp.h == "Ana-Reino", "sanador elegido: " .. tostring(r.gp.h))
H.eq(#r.gp.d, 3, "3 DPS")
H.eq(#ana.ns.Dungeons.Missing(r.gp), 0, "grupo completo")
H.eq(#(r.gp.b or {}), 1, "un suplente")
local inGroup = {}
for _, n in ipairs(r.gp.d) do inGroup[n] = true end
H.ok(not inGroup["Fran-Reino"], "Fran (nivel bajo) queda de suplente antes que los que llegan al nivel")
H.Advance(15)
H.ok(bea.env.HDFProfAlert.text:GetText():find("de tanque", 1, true), "aviso a Bea: vas de tanque")
H.eq(fran.ns.Dungeons.MyPlace(fran.ns.Dungeons.Runs()[run.id]), "suplente", "Fran ve que es suplente")
local seen = {}
for _, c in ipairs({ ana, bea, cris, dani, eva, fran }) do
  seen[#seen + 1] = c.ns.Dungeons.Hash(c.ns.Dungeons.Runs()[run.id])
end
for i = 2, #seen do H.eq(seen[i], seen[1], "todos ven la misma quedada") end

-- Invitar: Ana invita a los otros 4.
local invited = {}
ana.env.InviteUnit = function(name) invited[#invited + 1] = name end
H.eq(D.Invite(r), 4, "4 invitaciones")
H.ok(invited[1] and not invited[1]:find("-", 1, true), "con el nombre corto (mismo reino)")

-- Si alguien se desapunta y se rehace, entra el suplente.
eva.ns.Sync.LeaveRun(run.id)
H.Advance(10)
ana.ns.Sync.MakeGroup(run.id)
r = ana.ns.Dungeons.Runs()[run.id]
inGroup = {}
for _, n in ipairs(r.gp.d) do inGroup[n] = true end
H.ok(inGroup["Fran-Reino"] and not inGroup["Eva-Reino"], "Eva fuera, entra Fran")

-- Alguien que se conecta tarde la recibe.
H.AddMember("Gus", "DRUID", 30)
local gus = H.Login("Gus", { class = "DRUID", level = 30 })
H.Advance(40)
H.ok(gus.ns.Dungeons.Runs()[run.id] and gus.ns.Dungeons.Runs()[run.id].gp ~= nil, "Gus la recibe al entrar, con el grupo")

-- Recordatorio 10 minutos antes.
local pushes = {}
local push = cris.ns.Alerts.Push
cris.ns.Alerts.Push = function(a) pushes[#pushes + 1] = a.text end
cris.ns.Dungeons.Runs()[run.id].at = cris.ns.Now() + 300
cris.ns.Alerts.CheckRuns()
cris.ns.Alerts.CheckRuns()
cris.ns.Alerts.Push = push
H.eq(#pushes, 1, "un solo recordatorio")
H.ok(pushes[1] and pushes[1]:find("empieza en", 1, true), "recordatorio: empieza en 5 min")

-- Cancelar.
ana.ns.Sync.CancelRun(run.id)
H.Advance(10)
H.eq(bea.ns.Dungeons.State(bea.ns.Dungeons.Runs()[run.id], bea.ns.Now()), "cancelled", "Bea la ve cancelada")
local okJoin = gus.ns.Dungeons.SignUp(run.id, D.DPS, gus.ns.Now())
H.ok(okJoin == nil, "no se puede apuntar a una cancelada")

-- Pantalla: Mazmorras se abre y muestra la quedada; proponer desde la ventana.
local penv = ana.env
local gf = penv.CreateFrame("Frame", "GuildFrame", penv.UIParent)
ana.ns.UI.AttachHost(gf)
penv.HDFProfGuildTabGuildFrame:Click()
local panel = penv.HDFProfPanel
panel.sections.dungeons:Click()
local page = panel.pageFrames.dungeons
H.ok(page:IsShown(), "página de mazmorras")
H.ok(not panel.tabs.board:IsShown(), "sin las pestañas de Pedidos")
page.propose:Click()
local dlg = penv.HDFProfDungeonDialog
H.ok(dlg:IsShown(), "ventana de proponer")
H.ok(D.Dungeon(dlg.d).min <= 30, "mazmorra recomendada para su nivel")
dlg.dungeonButton:Click()
H.ok(dlg.menu:IsShown(), "menú de mazmorras")
H.ok(dlg.menu.buttons[2].text:GetText():find("nueva", 1, true), "las nuevas van marcadas")
dlg.menu.buttons[2]:Click()
H.eq(dlg.d, 101, "elige Salón de los Thanes")
dlg.plus:Click()
dlg.plus:Click()
H.ok(dlg.timeText:GetText():find("a las", 1, true), "hora concreta")
dlg:Publish()
H.ok(not dlg:IsShown(), "propuesta")
H.ok(page.detail.title:GetText():find("Salón de los Thanes", 1, true), "se ve en el detalle")
H.ok(page.detail.make:IsShown(), "Hacer grupo para quien la propone")

-- Modo demostración: quedada propia de ejemplo para probar "Hacer grupo".
ana.ns.Demo.Set(true)
local demoRun = ana.ns.Dungeons.Runs()["Ana-Reino:quedadademo"]
H.ok(demoRun and demoRun.demo, "quedada de ejemplo")
ana.ns.Sync.MakeGroup(demoRun.id)
H.ok(demoRun.gp and demoRun.gp.t and demoRun.gp.h and demoRun.gp.d and #demoRun.gp.d == 3, "grupo de ejemplo completo")
H.Advance(20)
H.eq(bea.ns.Dungeons.Runs()["Ana-Reino:quedadademo"], nil, "lo de ejemplo no sale de su ordenador")
ana.ns.Demo.Set(false)
H.eq(ana.ns.Dungeons.Runs()["Ana-Reino:quedadademo"], nil, "al quitar el modo desaparece")

H.eq(#H.errors, 0, "sin errores de Lua")
