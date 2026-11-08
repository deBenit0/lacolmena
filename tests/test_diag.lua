local H = ...
-- Autocomprobación e informe de errores.
H.AddMember("Ana")
H.AddMember("Bea")
local ana = H.Login("Ana")
H.Login("Bea")
H.Advance(20)
local ns, env = ana.ns, ana.env

-- Un error dentro del addon se guarda (una vez, con su contador).
local function broken() error("fallo de prueba") end
ns.SafeCall(broken)
ns.SafeCall(broken)
H.errors = {} -- son errores provocados a propósito
local errs = ns.db.errors
H.eq(#errs, 1, "se guarda el error una vez")
H.eq(errs[1].n, 2, "con cuántas veces ha pasado")
H.ok(errs[1].m:find("fallo de prueba", 1, true), "con el mensaje")
H.eq(errs[1].v, ns.VERSION, "y la versión")

-- Autocomprobación.
local results, good, bad, unknown = ns.Diag.Run()
H.ok(#results >= 15, "comprueba " .. #results .. " cosas")
H.ok(good > 0, "algunas bien: " .. good)
H.eq(good + bad + unknown, #results, "cada una con su resultado")
local byLabel = {}
for _, r in ipairs(results) do byLabel[r.label] = r end
H.eq(byLabel["Estás en una hermandad"].status, true, "hermandad: bien")
H.eq(byLabel["Otros con el addon conectados"].status, true, "ve a Bea con el addon")
H.eq(byLabel["Ventana de profesión"].status, nil, "sin abrir profesión: sin comprobar")

-- Ventana con el informe para copiar.
local gf = env.CreateFrame("Frame", "GuildFrame", env.UIParent)
ns.UI.AttachHost(gf)
env.HDFProfGuildTabGuildFrame:Click()
ns.UI.ShowPage("mine")
local mine = env.HDFProfPanel.pageFrames.mine
H.ok(mine.errors:GetText():find("1 error guardado", 1, true), "Mis cosas avisa del error guardado")
mine.report:Click()
local win = env.HDFProfReport
H.ok(win and win:IsShown(), "se abre el informe")
local report = win.edit:GetText()
H.ok(report:find(ns.VERSION, 1, true) and report:find("AUTOCOMPROBACIÓN", 1, true), "informe con versión y comprobación")
H.ok(report:find("fallo de prueba", 1, true), "informe con el error")
win.edit:SetText("borrado")
win.edit:GetScript("OnTextChanged")(win.edit, true)
H.eq(win.edit:GetText(), report, "el informe no se puede borrar a mano")
win.clear:Click()
H.eq(#ns.db.errors, 0, "Borrar errores")
H.ok(win.edit:GetText():find("(ninguno)", 1, true), "informe sin errores")

H.eq(#H.errors, 0, "sin errores de Lua")
