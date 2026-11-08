local H = ...
-- Borrar un pedido propio desde el Tablón, versión en el título y resúmenes periódicos.
H.AddMember("Ana")
H.AddMember("Bea")
local ana = H.Login("Ana")
local bea = H.Login("Bea")
H.Advance(20)
local ns, env = ana.ns, ana.env
local gf = env.CreateFrame("Frame", "GuildFrame", env.UIParent)
ns.UI.AttachHost(gf)
env.HDFProfGuildTabGuildFrame:Click()
H.ok(env.HDFProfPanel.title:GetText():find("v" .. ns.VERSION, 1, true), "la versión sale en el título")

ns.UI.OpenRequestDialog({ k = "i2840", q = 5 })
env.HDFProfRequestDialog:Publish()
H.Advance(10)
local id
for rid, r in pairs(ns.G().requests) do if r.a == ns.Me() then id = rid end end
H.ok(bea.ns.G().requests[id], "Bea ve el pedido")

ns.UI.ShowPage("board")
local board = env.HDFProfPanel.pageFrames.board
board:Refresh()
local row
for _, f in ipairs(board.list.rows or {}) do
  if f:IsShown() and f.item and f.item.id == id then row = f end
end
if not row then
  for _, f in pairs(board.list.rows or {}) do
    if f.accept and f.accept:GetText() == "Borrar pedido" then row = f end
  end
end
H.ok(row, "fila de mi pedido con el botón Borrar pedido")
if row then
  H.eq(row.accept:GetText(), "Borrar pedido", "el botón dice Borrar pedido")
  H.ok(row.accept:IsEnabled(), "y se puede pulsar")
  row.accept:Click()
  ana.popups[#ana.popups].data.callback()
end
H.Advance(10)
H.eq(ns.Data.RequestInfo(ns.G().requests[id], ns.Now()).state, "closed", "mi pedido queda borrado")
H.eq(bea.ns.Data.RequestInfo(bea.ns.G().requests[id], bea.ns.Now()).state, "closed", "y a Bea también")
board:Refresh()
local still = false
for _, it in ipairs(board.list.items) do if it.id == id then still = true end end
H.ok(not still, "ya no sale en el Tablón")

-- Un pedido que se perdió por el camino llega con el resumen periódico.
bea.online = false -- Bea no oye nada un rato (como si se hubieran perdido los mensajes)
ns.UI.OpenRequestDialog({ k = "i2841", q = 2 })
env.HDFProfRequestDialog:Publish()
H.Advance(5)
bea.online = true
local function beaHas()
  for _, r in pairs(bea.ns.G().requests) do if r.k == "i2841" then return true end end
  return false
end
H.ok(not beaHas(), "Bea no lo ha recibido")
H.Advance(500)
H.ok(beaHas(), "con el resumen periódico le llega")
H.ok(ns.Sync.lastHello ~= nil, "se apunta cuándo llegó el último resumen")

H.eq(#H.errors, 0, "sin errores de Lua")
