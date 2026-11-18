-- Mercado › MIS PEDIDOS: lo que he pedido yo.
--   Cada pedido con sus pasos (Pedido › Aceptado › Enviado › Recibido) y UN botón, el que toca:
--   ¡ME HA LLEGADO! (te lo han mandado por correo), RENOVAR (caduca pronto o ya caducó),
--   SUSURRAR (alguien lo está haciendo) o QUITAR (nadie lo ha cogido). Debajo, en pequeño,
--   «renovar · quitar». Al final, los ya terminados en gris. Pulsar la tarjeta abre el detalle.
local _, ns = ...
local W, Data = ns.W, ns.Data

local MAX_ENDED = 20

local STEPS = { "Pedido", "Aceptado", "Enviado", "Recibido" }
-- En qué paso está uno de mis pedidos (1 a 4).
local function stepOf(r, info, M)
  if M.SentToMe(r) then return 3 end
  if info.state == "done" then return 4 end
  for _, c in ipairs(info.commits) do
    if (c.mailed or 0) > 0 or (c.delivered or 0) > 0 then return 3 end
  end
  if #info.owners > 0 then return 2 end
  return 1
end

local function stepsText(step)
  local parts = {}
  for i, label in ipairs(STEPS) do
    if i < step then
      parts[i] = "|cff40ff40" .. label .. "|r"
    elseif i == step then
      parts[i] = "|cffffffff[" .. label .. "]|r"
    else
      parts[i] = "|cff777777" .. label .. "|r"
    end
  end
  return table.concat(parts, " |cff999999›|r ")
end

-- Quién me lo ha mandado por correo sin que yo lo haya dado por recibido.
local function sentBy(r)
  local names = {}
  for name, cm in pairs(r.c or {}) do
    if (cm.s or 0) > (cm.d or 0) then names[#names + 1] = name end
  end
  table.sort(names)
  return names
end

local function payText(r)
  local parts = {}
  if r.g then parts[#parts + 1] = ns.FormatMoney(r.g) end
  if r.pi then
    local ids = {}
    for id in pairs(r.pi) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do parts[#parts + 1] = r.pi[id] .. "x " .. ns.KeyName("i" .. id) end
  end
  return #parts > 0 and ("Propina: " .. table.concat(parts, " + ")) or "|cff999999Sin propina|r"
end

local function renew(r) ns.Sync.Renew(r.id) end
local function remove(r)
  W.Confirm("¿Quitar este pedido? Desaparecerá del Mercado de todos.", function() ns.Sync.Close(r.id) end)
end

-- Mis pedidos: los vivos (y los completos por correo sin recibir), los caducados y los terminados.
local function collectMine(g, me, now, M)
  local live, ended = {}, {}
  for _, r in pairs(g.requests) do
    if r.a == me then
      local info = Data.RequestInfo(r, now)
      local item = { kind = "req", id = r.id, k = r.k, author = r.a, t = r.t or 0, r = r, info = info, me = me,
        now = now, mine = true, pending = 0, karma = Data.KarmaFor(r.a) }
      local arrived = M.SentToMe(r) and info.state ~= "closed"
      if Data.IsActiveState(info.state) or arrived or info.state == "expired" then
        item.arrived = arrived
        live[#live + 1] = item
      else
        item.ended = true
        ended[#ended + 1] = item
      end
    end
  end
  -- primero lo que espera algo de mí (me ha llegado, caduca), luego lo más nuevo
  local function weight(it)
    if it.arrived then return 0 end
    if it.info.state == "expired" then return 1 end
    if it.info.state == "open" and M.Soon(it.info.expires, now) then return 1 end
    return 2
  end
  table.sort(live, function(a, b)
    local wa, wb = weight(a), weight(b)
    if wa ~= wb then return wa < wb end
    if a.t ~= b.t then return a.t > b.t end
    return a.id < b.id
  end)
  table.sort(ended, function(a, b)
    local ea, eb = a.info.ended or a.t, b.info.ended or b.t
    if ea ~= eb then return ea > eb end
    return a.id < b.id
  end)
  local out = live
  local nLive = #live
  for i = 1, math.min(MAX_ENDED, #ended) do out[#out + 1] = ended[i] end
  return out, nLive
end
ns.UI.MarketMineItems = collectMine

-- Lo que se enseña de cada pedido.
local function fill(M)
  return function(it)
    local r, info, now = it.r, it.info, it.now or ns.Now()
    local s = { title = ns.KeyLabel(r.k), qty = r.q, money = payText(r) }
    if it.ended then
      s.grey = true
      s.sub = "|cff999999" .. (Data.STATE_LABEL[info.state] or info.state) .. " · hace "
        .. ns.FormatDuration(math.max(0, now - (info.ended or r.t or now))) .. "|r"
      s.hint = info.state == "done" and "|cff40ff40Recibido|r" or nil
      return s
    end
    local who = {}
    for i = 1, math.min(2, #info.owners) do who[i] = ns.DisplayName(info.owners[i]) end
    local whoText = #who > 0 and ("|cff66ccfflo hace " .. table.concat(who, ", ") .. (#info.owners > 2 and "…" or "") .. "|r")
    s.sub = stepsText(stepOf(r, info, M)) .. (whoText and (" |cff666666·|r " .. whoText) or "")
    local active = Data.IsActiveState(info.state)
    if it.arrived then
      local list = {}
      for i, n in ipairs(sentBy(r)) do list[i] = ns.DisplayName(n) end
      s.hint = "|cff40ff40" .. table.concat(list, ", ") .. " te lo ha enviado por correo|r"
      s.gold = true
      s.button = { label = "¡ME HA LLEGADO!", color = W.GREEN, fn = function() ns.Sync.MarkArrived(r.id) end,
        tip = "Ya lo tienes: lo das por recibido. (Se marca solo al sacarlo del buzón.)" }
    elseif info.state == "expired" then
      s.hint = "|cffff4040Ha caducado sin que nadie lo coja|r"
      s.button = { label = "RENOVAR", color = W.GREEN, fn = function() renew(r) end,
        tip = "Vuelve a ponerlo en el Tablón 7 días más." }
      s.small = { { label = "quitar", fn = function() remove(r) end } }
      return s
    elseif info.state == "open" and M.Soon(info.expires, now) then
      s.hint = M.ExpiresText(info.expires, now)
      s.button = { label = "RENOVAR", color = W.GREEN, fn = function() renew(r) end,
        tip = "Vuelve a contar los 7 días desde ahora." }
    elseif #info.owners > 0 then
      s.hint = M.ExpiresText(info.expires, now)
      s.button = { label = "SUSURRAR", fn = function()
        M.PickName(info.owners, "¿A quién le susurras?", ns.SendTell)
      end, tip = "Hablar con quien lo está haciendo." }
    else
      s.hint = M.ExpiresText(info.expires, now)
      s.button = { label = "QUITAR", fn = function() remove(r) end, tip = "Ya no lo necesitas: lo quitas del Tablón." }
    end
    -- en pequeño, lo demás
    local small = {}
    if active and s.button.label ~= "RENOVAR" then
      small[#small + 1] = { label = "renovar", fn = function() renew(r) end, tip = "Vuelve a contar los 7 días." }
    end
    if active and s.button.label ~= "QUITAR" then
      small[#small + 1] = { label = "quitar", fn = function() remove(r) end }
    end
    s.small = #small > 0 and small or nil
    return s
  end
end

ns.UI.MarketView("mine", function(view, M)
  view.title = W.Text(view, "GameFontNormal")
  view.title:SetPoint("TOPLEFT", 4, -8)
  view.title:SetText("Lo que has pedido tú")
  view.count = W.Text(view, "GameFontHighlightSmall", "RIGHT")
  view.count:SetPoint("TOPRIGHT", -4, -10)
  view.count:SetTextColor(0.7, 0.7, 0.7)
  M.CardList(view, 30, fill(M), "No has pedido nada todavía.",
    { label = "+ PEDIR", fn = function() ns.UI.OpenAsk("ask") end })

  function view:Refresh(data)
    if not data then return end
    view.data = data
    local items, live = collectMine(data.g, data.me, data.now, M)
    view:SetCards(items)
    view.count:SetText(string.format("%d en marcha · %d terminados", live, #items - live))
    ns.UI.MarketDetail.Refresh(items)
  end

  function view:Select(id)
    for _, it in ipairs(view.shown or {}) do
      if it.id == id then return ns.UI.MarketDetail.Show(it) end
    end
  end
end)
