-- Pedidos de fabricación de Blizzard (WoW Forever): cuando alguien publica en la mesa de pedidos
-- un pedido para la HERMANDAD, el addon lo cuenta a los demás y avisa a quien sabe fabricarlo
-- (el juego no avisa). El pedido se coge y se entrega en la propia ventana de Blizzard:
-- profesión → Pedidos → Hermandad.
--
-- Verificado contra la rama "forever" de la interfaz de Blizzard: C_CraftingOrders.PlaceNewOrder
-- recibe la orden con orderType = Enum.CraftingOrderType.Guild, y el formulario
-- ProfessionsCustomerOrdersFrame.Form.order guarda la receta en spellID.
--
-- Viaja en la ficha de quien lo pide: go = { { i = objeto, s = receta, t = hora }, ... }
local _, ns = ...
local Data = ns.Data
local Orders = {}
ns.Orders = Orders

Orders.TTL = 24 * 3600 -- se enseña un día (luego puede que ya esté hecho)
Orders.MAX = 5

function Orders.SanitizeInto(out, e)
  if type(e.go) ~= "table" then return end
  local list = {}
  for _, o in ipairs(e.go) do
    if type(o) == "table" and (tonumber(o.i) or tonumber(o.s)) and #list < Orders.MAX then
      list[#list + 1] = { i = tonumber(o.i), s = tonumber(o.s), t = tonumber(o.t) or 0 }
    end
  end
  if #list > 0 then out.go = list end
end

local function mine()
  local c = ns.MyChar()
  if c then c.guildOrders = c.guildOrders or {} end
  return c and c.guildOrders
end

function Orders.BuildInto(e, now)
  local list = mine()
  if not list then return end
  local out = {}
  for i = #list, 1, -1 do
    if now - (list[i].t or 0) > Orders.TTL then table.remove(list, i) end
  end
  for _, o in ipairs(list) do out[#out + 1] = { i = o.i, s = o.s, t = o.t } end
  if #out > 0 then e.go = out end
end

-- He publicado un pedido de hermandad con esta receta.
function Orders.Record(spellID, now)
  local list = mine()
  if not list or not spellID then return end
  local itemID
  if ns.Scan.ModernAPI() then
    itemID = ns.Scan.ModernOutput(spellID, C_TradeSkillUI.GetRecipeSchematic(spellID, false))
  end
  table.insert(list, 1, { i = itemID, s = spellID, t = now })
  while #list > Orders.MAX do table.remove(list) end
  ns.Sync.PublishMine()
  ns.Fire("DATA_CHANGED", "orders")
  ns.Print("pedido de fabricación de hermandad avisado a quien sabe hacerlo.")
end

-- La clave de receta del addon para un pedido ("i<objeto>" o "e<hechizo>").
local function keyOf(o)
  return o.i and ("i" .. o.i) or ("e" .. o.s)
end

-- Pedidos de hermandad recientes de los demás: { owner, key, i, s, t, id }.
function Orders.List(now)
  local g, list = ns.G(), {}
  if not g then return list end
  local dismissed = ns.db.settings.dismissedOrders or {}
  for owner, e in pairs(g.entries) do
    local src = e.go
    if owner == ns.Me() then src = mine() end
    for _, o in ipairs(src or {}) do
      local id = owner .. ":" .. (o.s or o.i or 0) .. ":" .. (o.t or 0)
      if now - (o.t or 0) <= Orders.TTL and not dismissed[id] then
        list[#list + 1] = { owner = owner, key = keyOf(o), i = o.i, s = o.s, t = o.t or 0, id = id }
      end
    end
  end
  table.sort(list, function(a, b) return a.t > b.t end)
  return list
end

function Orders.Dismiss(id)
  ns.db.settings.dismissedOrders = ns.db.settings.dismissedOrders or {}
  local list = ns.db.settings.dismissedOrders
  list[id] = ns.Now()
  for k, t in pairs(list) do -- olvidar los de hace más de 3 días (ya han caducado)
    if ns.Now() - t > Orders.TTL * 3 then list[k] = nil end
  end
  ns.Fire("DATA_CHANGED", "orders")
end

-- Borrar un pedido mío (deja de salir a los demás en cuanto se envía mi ficha).
function Orders.Remove(id)
  local list, me = mine(), ns.Me()
  if not list or not me then return end
  for i = #list, 1, -1 do
    local o = list[i]
    if me .. ":" .. (o.s or o.i or 0) .. ":" .. (o.t or 0) == id then table.remove(list, i) end
  end
  ns.Sync.PublishMine()
  ns.Fire("DATA_CHANGED", "orders")
end

-- ¿Sé fabricar lo de este pedido?
function Orders.CanMake(o)
  return Data.ICanCraft(o.key) or (o.s and Data.ICanCraft("e" .. o.s)) or false
end

-- Aviso a quien sabe hacerlo cuando llega uno nuevo.
function Orders.CheckNew(name)
  local g, me = ns.G(), ns.Me()
  local e = g and g.entries[name]
  if not e or not e.go or name == me then return end
  g.ordersSeen = g.ordersSeen or {}
  for _, o in ipairs(e.go) do
    local id = name .. ":" .. (o.s or o.i or 0) .. ":" .. (o.t or 0)
    local item = { key = keyOf(o), s = o.s }
    if not g.ordersSeen[id] and ns.Now() - (o.t or 0) <= Orders.TTL and Orders.CanMake(item) then
      g.ordersSeen[id] = ns.Now()
      if ns.Alerts then
        local _, icon = ns.KeyInfo(item.key)
        ns.Alerts.Push({ page = "board", icon = icon,
          text = string.format("%s pide %s en los pedidos de fabricación (hermandad)", ns.ShortName(name), ns.KeyLabel(item.key)) })
      end
    end
  end
  for id, t in pairs(g.ordersSeen) do
    if ns.Now() - t > Orders.TTL * 3 then g.ordersSeen[id] = nil end
  end
end

ns.Listen("DATA_CHANGED", function(kind, name)
  if kind == "entry" and name then ns.SafeCall(Orders.CheckNew, name) end
end)

-- Enganche: al publicar un pedido en la mesa de Blizzard.
if C_CraftingOrders and C_CraftingOrders.PlaceNewOrder then
  hooksecurefunc(C_CraftingOrders, "PlaceNewOrder", function(info)
    ns.SafeCall(function()
      local guildType = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Guild
      if type(info) ~= "table" or guildType == nil or info.orderType ~= guildType then return end
      local form = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
      local spellID = form and form.order and form.order.spellID
      if spellID then Orders.Record(spellID, ns.Now()) end
    end)
  end)
end
