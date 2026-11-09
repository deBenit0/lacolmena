-- Calidad de vida:
--  1. Tooltip "Lo fabrica": en cualquier objeto del juego, quién de la hermandad lo fabrica.
--  2. Comercio en mano: lo que das comerciando se apunta como entrega (igual que por correo).
--  3. Bienvenida a nuevos: aviso a los oficiales y susurro de bienvenida (lo envía un solo oficial).
--  4. Resumen al entrar: lo que ha pasado mientras no estabas.
-- Verificado contra la interfaz de WoW Forever (rama "forever" de la interfaz de Blizzard):
-- tooltips con TooltipDataProcessor, comercio con GetTradePlayerItemInfo y UI_INFO_MESSAGE.
local _, ns = ...
local Data = ns.Data
local QoL = {}
ns.QoL = QoL

---------------------------------------------------------------------------
-- 1. Tooltip: quién lo fabrica o lo recolecta en la hermandad
---------------------------------------------------------------------------
-- Líneas para el tooltip de un objeto (o nil si nadie lo da).
function QoL.TooltipLines(itemID)
  if not itemID or not ns.G() then return nil end
  local key = "i" .. itemID
  local rec = Data.GetIndex()[key]
  local names, seen = {}, {}
  local function add(name)
    if seen[name] then return end
    seen[name] = true
    names[#names + 1] = { name = name, online = ns.Guild.IsOnline(name) }
  end
  for _, cr in ipairs(rec and rec.crafters or {}) do add(cr.n) end
  local gatherers = Data.GatherersOf(key)
  for _, name in ipairs(gatherers) do add(name) end
  if #names == 0 then return nil end
  table.sort(names, function(a, b)
    if a.online ~= b.online then return a.online end
    return a.name < b.name
  end)
  local shown = {}
  for i = 1, math.min(4, #names) do
    local n = names[i]
    shown[#shown + 1] = (n.online and "|cff40ff40" or "|cff999999") .. ns.ShortName(n.name) .. "|r"
  end
  local more = #names > 4 and (" y " .. (#names - 4) .. " más") or ""
  return ns.TITLE .. ": lo dan " .. table.concat(shown, ", ") .. more
end

local function addToTooltip(tooltip, itemID)
  if not tooltip or not itemID or tooltip.hdfItem == itemID then return end
  tooltip.hdfItem = itemID
  local line = QoL.TooltipLines(itemID)
  if line then
    tooltip:AddLine(line, 1, 0.82, 0, true)
    tooltip:Show()
  end
end

local function itemFromTooltip(tooltip)
  if not tooltip.GetItem then return nil end
  local _, link = tooltip:GetItem()
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- Interfaz moderna (Forever): TooltipDataProcessor. Clásica: OnTooltipSetItem.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    ns.SafeCall(function()
      local id = (type(data) == "table" and data.id) or itemFromTooltip(tooltip)
      addToTooltip(tooltip, id)
    end)
  end)
end
for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
  if tip and tip.HookScript then
    pcall(tip.HookScript, tip, "OnTooltipSetItem", function(self) ns.SafeCall(addToTooltip, self, itemFromTooltip(self)) end)
    pcall(tip.HookScript, tip, "OnTooltipCleared", function(self) self.hdfItem = nil end)
    pcall(tip.HookScript, tip, "OnHide", function(self) self.hdfItem = nil end)
  end
end

---------------------------------------------------------------------------
-- 2. Comercio en mano: lo que doy se apunta como entrega al completarse el comercio
---------------------------------------------------------------------------
local trade = {}

local function snapshot()
  if not GetTradePlayerItemInfo then return end
  local items, any = {}, false
  for i = 1, (MAX_TRADABLE_ITEMS or 6) do
    -- nombre, icono, cantidad, calidad, encantamiento, transfiguración, ligado, id del objeto
    local name, _, count, _, _, _, _, itemID = GetTradePlayerItemInfo(i)
    if not itemID and name and GetTradePlayerItemLink then
      local link = GetTradePlayerItemLink(i)
      itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    end
    if itemID then
      items[itemID] = (items[itemID] or 0) + (tonumber(count) or 1)
      any = true
    end
  end
  trade.items = any and items or nil
end
QoL.TradeSnapshot = snapshot

local function tradePartner()
  local name = GetUnitName and GetUnitName("NPC", true) or (UnitName and UnitName("NPC"))
  return name and ns.FullName(name:gsub("%s", "")) or nil
end

ns.On("TRADE_SHOW", function()
  trade.to = tradePartner()
  trade.items = nil
end)
ns.On("TRADE_PLAYER_ITEM_CHANGED", function() snapshot() end)
ns.On("TRADE_ACCEPT_UPDATE", function() snapshot() end)
ns.On("UI_INFO_MESSAGE", function(_, message)
  if issecretvalue and issecretvalue(message) then return end
  local complete = ERR_TRADE_COMPLETE
  if complete and message == complete and trade.to and trade.items then
    local to, items = trade.to, trade.items
    trade.to, trade.items = nil, nil
    local n = ns.Mail.RegisterDelivery(to, items, "en mano")
    if n == 0 then return end
    ns.Print("comercio con %s apuntado.", ns.ShortName(to))
  end
end)
ns.On("TRADE_CLOSED", function()
  -- El mensaje de "comercio completado" puede llegar justo después: esperamos un poco.
  local token = {}
  trade.closing = token
  ns.After(3, function()
    if trade.closing == token then trade.to, trade.items = nil, nil end
  end)
end)

---------------------------------------------------------------------------
-- 3. Bienvenida a nuevos miembros
---------------------------------------------------------------------------
QoL.DEFAULT_WELCOME = "¡Bienvenido a %s, %s! Instala el addon \"%s\" (carpeta HDFprofesiones) para pedir y "
  .. "ofrecer cosas a la hermandad y apuntarte a mazmorras. ¡Mi vida por el fundillo!"

-- Convierte "%s se ha unido a la hermandad." en un patrón que captura el nombre.
local function joinPattern()
  local fmt = ERR_GUILD_JOIN_S
  if type(fmt) ~= "string" then return nil end
  local escaped = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  local pattern = escaped:gsub("%%s", "(.+)")
  return "^" .. pattern .. "$"
end
QoL.JoinPattern = joinPattern

function QoL.WelcomeSettings()
  local s = ns.db.settings
  s.welcome = s.welcome or { on = true }
  return s.welcome
end

-- ¿Soy yo el oficial que manda la bienvenida? (el primero por nombre de los oficiales
-- conectados que tienen el addon), para que no la mande cada oficial.
function QoL.IAmWelcomer()
  local me = ns.Me()
  if not ns.Social.AmOfficer() then return false end
  for name, info in pairs(ns.Guild.roster) do
    if name ~= me and info.online and ns.Social.IsOfficer(name) and ns.Sync.peers[name] and name < me then
      return false
    end
  end
  return true
end

function QoL.OnJoin(name)
  if not name or not ns.G() then return end
  name = ns.FullName(name)
  if ns.Social.AmOfficer() and ns.Alerts then
    ns.Alerts.Push({ page = "guild", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
      text = string.format("%s se ha unido a la hermandad", ns.ShortName(name)) })
  end
  local settings = QoL.WelcomeSettings()
  -- Forever: C_ChatInfo.SendChatMessage (la global SendChatMessage solo queda como obsoleta).
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if settings.on and QoL.IAmWelcomer() and send then
    local text = settings.text and settings.text ~= "" and settings.text or QoL.DEFAULT_WELCOME
    text = text:format(ns.guildName or ns.TITLE, ns.ShortName(name), ns.TITLE)
    ns.After(5, function() pcall(send, text:sub(1, 255), "WHISPER", nil, ns.ShortName(name)) end)
  end
end

ns.On("CHAT_MSG_SYSTEM", function(message)
  if issecretvalue and issecretvalue(message) then return end -- el juego a veces no deja leerlo
  local pattern = joinPattern()
  local name = pattern and type(message) == "string" and message:match(pattern)
  if name then QoL.OnJoin(name) end
end)

---------------------------------------------------------------------------
-- 4. Resumen al entrar: lo que ha pasado mientras no estabas
---------------------------------------------------------------------------
-- Líneas del resumen desde "since" (hora del addon).
function QoL.Summary(since, now)
  local g, me = ns.G(), ns.Me()
  local lines = {}
  if not g or not me or not since then return lines end
  for _, r in pairs(g.requests) do
    if r.a == me then
      for name, cm in pairs(r.c or {}) do
        if (cm.at or cm.cv or 0) > since and not cm.rl then
          lines[#lines + 1] = string.format("%s aceptó tu pedido de %dx %s", ns.ShortName(name), r.q, ns.KeyLabel(r.k))
        end
        if math.max(cm.sv or 0, cm.dv or 0) > since and Data.DeliveredOf(cm) > 0 then
          lines[#lines + 1] = string.format("%s te entregó %dx %s", ns.ShortName(name), Data.DeliveredOf(cm), ns.KeyLabel(r.k))
        end
      end
    end
  end
  local servable = 0
  for _, r in ipairs(Data.ServableRequests(now)) do
    if (r.t or 0) > since then servable = servable + 1 end
  end
  if servable > 0 then lines[#lines + 1] = string.format("%d pedidos nuevos que puedes hacer", servable) end
  for _, o in ipairs(ns.Offers.List(now)) do
    if o.owner == me then
      for _, c in ipairs(o.claims) do
        if (c.t or 0) > since then
          lines[#lines + 1] = string.format("%s quiere %dx %s de tu oferta", ns.ShortName(c.name), c.left, ns.KeyLabel("i" .. o.id))
        end
      end
    end
  end
  local needs = 0
  for _, n in ipairs(ns.Social.Needs(now)) do
    if (n.t or 0) > since and n.left > 0 then needs = needs + 1 end
  end
  if needs > 0 then lines[#lines + 1] = string.format("%d pedidos nuevos de la hermandad", needs) end
  local runs = 0
  for _, run in pairs(ns.Dungeons.Runs() or {}) do
    if (run.t or 0) > since and ns.Dungeons.State(run, now) == "open" then runs = runs + 1 end
  end
  if runs > 0 then lines[#lines + 1] = string.format("%d quedadas de mazmorra nuevas", runs) end
  local an = ns.Social.Announcement()
  if an and (an.t or 0) > since then
    lines[#lines + 1] = string.format("Anuncio de %s: %s", ns.ShortName(an.name), an.x)
  end
  return lines
end

local summaryFrame
function QoL.ShowSummary(lines, since)
  if #lines == 0 then return end
  if not summaryFrame then
    local W = ns.W
    local f = W.Panel("HDFProfSummary", UIParent, 400, 100)
    f:SetFrameStrata("DIALOG")
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f:Hide()
    tinsert(UISpecialFrames, "HDFProfSummary")
    f.title = W.Text(f, "GameFontNormal")
    f.title:SetPoint("TOP", 0, -14)
    f.text = W.Text(f, "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", 18, -36)
    f.text:SetWidth(364)
    f.text:SetJustifyV("TOP")
    f.text:SetSpacing(3)
    f.open = W.Button(f, "Ver el Mercado", 120, 22, function()
      f:Hide()
      ns.UI.Open("board")
    end)
    f.open:SetPoint("BOTTOMRIGHT", -16, 12)
    f.close = W.Button(f, "Cerrar", 80, 22, function() f:Hide() end)
    f.close:SetPoint("RIGHT", f.open, "LEFT", -6, 0)
    summaryFrame = f
  end
  local shown = {}
  for i = 1, math.min(8, #lines) do shown[i] = "· " .. lines[i] end
  if #lines > 8 then shown[#shown + 1] = string.format("· y %d cosas más", #lines - 8) end
  summaryFrame.title:SetText(string.format("%s: mientras no estabas (%s)", ns.TITLE,
    ns.FormatDuration(ns.Now() - since)))
  summaryFrame.text:SetText(table.concat(shown, "\n"))
  summaryFrame:SetHeight(84 + #shown * 15)
  summaryFrame:Show()
  return summaryFrame
end

-- La última vez que estuve conectado se guarda cada minuto (y al salir).
local lastActive
ns.Listen("LOGIN", function()
  local c = ns.MyChar()
  lastActive = c and c.lastActive
  C_Timer.NewTicker(60, function()
    local me = ns.MyChar()
    if me then me.lastActive = ns.Now() end
  end)
  -- Cuando ya se ha puesto al día con la hermandad, enseñar el resumen.
  ns.After(50, function()
    ns.SafeCall(function()
      local db = ns.db
      if not lastActive or not db or db.settings.summary == false then return end
      QoL.ShowSummary(QoL.Summary(lastActive, ns.Now()), lastActive)
    end)
  end)
end)
ns.On("PLAYER_LOGOUT", function()
  local c = ns.MyChar()
  if c then c.lastActive = ns.Now() end
end)
