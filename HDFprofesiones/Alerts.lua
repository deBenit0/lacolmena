-- Avisos emergentes: peticiones nuevas que puedo fabricar y compromisos en mis peticiones.
-- En combate, mazmorras y bandas se guardan y se muestran al salir.
local _, ns = ...
local Data = ns.Data
local Alerts = {}
ns.Alerts = Alerts

local queue = {}
local frame, showing, hideToken
local SHOW_SECONDS = 15
local MAX_AGE = 86400 -- no avisar de peticiones de hace más de un día

local function canShowNow()
  if InCombatLockdown and InCombatLockdown() then return false end
  if UnitAffectingCombat and UnitAffectingCombat("player") then return false end
  local inInstance = IsInInstance and IsInInstance()
  return not inInstance
end

local function createFrame()
  local f = CreateFrame("Button", "HDFProfAlert", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(360, 64)
  f:SetPoint("TOP", UIParent, "TOP", 0, -140)
  f:SetFrameStrata("DIALOG")
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    f:SetBackdropBorderColor(1, 0.82, 0, 1)
  end
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(36, 36)
  f.icon:SetPoint("LEFT", 12, 0)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -1)
  f.title:SetText(ns.TITLE)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
  f.text:SetPoint("RIGHT", f, "RIGHT", -34, 0)
  f.text:SetJustifyH("LEFT")
  f.text:SetWordWrap(false)
  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.hint:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 10, 0)
  f.hint:SetText("Clic para verla")
  f.commit = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.commit:SetSize(90, 20)
  f.commit:SetPoint("BOTTOMRIGHT", -10, 7)
  f.commit:SetText("Lo hago yo")
  f.commit:SetScript("OnClick", function()
    local alert = f.alert
    Alerts.HideCurrent()
    local g = ns.G()
    local r = alert and g and g.requests[alert.id]
    if not r or not Data.CanServe(r, ns.Now()) then return end
    ns.W.AcceptRequest(r)
  end)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() Alerts.HideCurrent() end)
  f:SetScript("OnClick", function(self)
    local alert = self.alert
    Alerts.HideCurrent()
    if alert and ns.UI then ns.UI.Open(alert.page or "requests", alert.id) end
  end)
  f:Hide()
  return f
end

function Alerts.HideCurrent()
  showing = nil
  hideToken = nil
  if frame then frame:Hide() end
  ns.After(0.5, Alerts.Flush)
end

local function show(alert)
  frame = frame or createFrame()
  showing = alert
  frame.alert = alert
  frame.icon:SetTexture(alert.icon or ns.QUESTION_ICON)
  frame.text:SetText(alert.text)
  frame.hint:SetText(alert.id and "Clic para verla" or "Clic para abrir Profesiones")
  local g = ns.G()
  local r = alert.id and g and g.requests[alert.id]
  frame.commit:SetShown(alert.canCommit and r and Data.CanServe(r, ns.Now()) or false)
  frame:Show()
  if ns.db.settings.sound then PlaySound((SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081) end
  local token = {}
  hideToken = token
  ns.After(SHOW_SECONDS, function()
    if hideToken == token then Alerts.HideCurrent() end
  end)
end

function Alerts.Flush()
  if showing or #queue == 0 or not canShowNow() then return end
  if #queue > 3 then
    local n = #queue
    wipe(queue)
    show({ text = string.format("Hay %d novedades en las peticiones.", n), icon = "Interface\\Icons\\INV_Misc_Note_01" })
    return
  end
  show(table.remove(queue, 1))
end

function Alerts.Push(alert)
  if not ns.db or not ns.db.settings.alerts then return end
  local c = ns.MyChar()
  if c and c.u then return end -- "no disponible": sin avisos
  queue[#queue + 1] = alert
  Alerts.Flush()
end

-- Decide si una petición nueva o cambiada merece aviso.
function Alerts.OnRequestUpdated(old, new, retry)
  if not new then return end
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  if not g or not me then return end
  local info = Data.RequestInfo(new, now)
  local _, icon = ns.KeyInfo(new.k)

  -- Petición nueva de otro que puedo hacer o conseguir (o dirigida a mí).
  if not old and new.a ~= me and info.state == "open" and (new.t or 0) > now - MAX_AGE and not g.alerted[new.id] then
    local canGather = Data.ICanGather(new.k)
    if canGather == nil and not retry then
      -- el juego aún no sabe qué objeto es: volver a mirarlo en un momento
      ns.After(3, function() Alerts.OnRequestUpdated(nil, g.requests[new.id], true) end)
    end
    if Data.ICanCraft(new.k) or canGather then
      g.alerted[new.id] = true
      local text = string.format("%s pide %dx %s", ns.ShortName(new.a), new.q, ns.KeyLabel(new.k))
      if new.pr then text = text .. " (" .. Data.WHEN[new.pr].ask:lower() .. ")" end
      Alerts.Push({ id = new.id, icon = icon, text = text, canCommit = true })
    end
  end

  -- Me han enviado por correo algo de una de mis peticiones.
  if new.a == me and old then
    for name, cm in pairs(new.c or {}) do
      local before = old.c and old.c[name]
      local sentBefore = before and before.s or 0
      if (cm.s or 0) > sentBefore then
        Alerts.Push({
          id = new.id, icon = icon,
          text = string.format("%s te ha enviado %dx %s por correo", ns.ShortName(name), cm.s - sentBefore, ns.KeyLabel(new.k)),
        })
      end
    end
  end

  -- Alguien acepta una de mis peticiones.
  if new.a == me and old then
    local owner, cm = Data.OwnerOf(new, now)
    local before = Data.OwnerOf(old, now)
    if owner and owner ~= before then
      local w = cm.w and Data.WHEN[cm.w]
      Alerts.Push({
        id = new.id, icon = icon,
        text = string.format("%s te hace %dx %s%s", ns.ShortName(owner), new.q, ns.KeyLabel(new.k),
          w and (" (" .. w.label:gsub("^Lo hago ", ""):lower() .. ")") or ""),
      })
    end
  end

  -- Mi encargado pide más tiempo.
  if new.a == me and old then
    local owner, cm = Data.OwnerOf(new, now)
    local before = owner and old.c and old.c[owner]
    if owner and cm.ex and before and not before.ex and before.n then
      local w = cm.w and Data.WHEN[cm.w]
      Alerts.Push({ id = new.id, icon = icon,
        text = string.format("%s necesita más tiempo para %s%s", ns.ShortName(owner), ns.KeyLabel(new.k),
          w and (": " .. w.label:gsub("^Lo hago ", ""):lower()) or "") })
    end
  end

  -- Lo acepté a la vez que otro y él lo hizo antes: me quedo sin él.
  if new.a ~= me and old and new.c and new.c[me] then
    local mineBefore = old.c and old.c[me] and Data.CommitActive(old.c[me], now, old)
    local owner = Data.OwnerOf(new, now)
    if mineBefore and owner and owner ~= me then
      Alerts.Push({ id = new.id, icon = icon,
        text = string.format("%s aceptó antes que tú: %s", ns.ShortName(owner), ns.KeyLabel(new.k)) })
    end
  end
end

ns.Listen("REQUEST_UPDATED", Alerts.OnRequestUpdated)

-- Plazos: aviso al encargado poco antes de que se acabe, y a los dos si se pasa.
Alerts.WARN_BEFORE = 15 * 60
function Alerts.CheckDeadlines()
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  if not g or not me then return end
  g.warned = g.warned or {}
  local function once(key, alert)
    if g.warned[key] then return end
    g.warned[key] = now
    Alerts.Push(alert)
  end
  for id, r in pairs(g.requests) do
    local _, icon = ns.KeyInfo(r.k)
    for name, cm in pairs(r.c or {}) do
      local key = id .. ":" .. name .. ":" .. (cm.by or 0)
      local pendingUnits = cm.n and (cm.n - Data.DeliveredOf(cm)) or 0
      local expired = cm.by and not cm.rl and pendingUnits > 0 and now > cm.by + Data.COMMIT_GRACE
        and now < cm.by + Data.COMMIT_GRACE + 86400 and Data.IsActiveState(Data.RequestInfo(r, now).state)
      if name == me and r.a ~= me then
        if cm.by and Data.CommitActive(cm, now, r) and cm.by - now <= Alerts.WARN_BEFORE then
          local left = cm.by - now
          once(key .. ":soon", { id = id, icon = icon,
            text = string.format("%s para enviar %dx %s a %s",
              left > 60 and ("Te quedan " .. ns.FormatDuration(left)) or "Se acaba tu plazo", pendingUnits,
              ns.KeyLabel(r.k), ns.ShortName(r.a)) })
        elseif expired then
          once(key .. ":late", { id = id, icon = icon,
            text = string.format("Se pasó tu plazo: %s vuelve al tablón", ns.KeyLabel(r.k)) })
        end
      elseif r.a == me and expired then
        once(key .. ":back", { id = id, icon = icon,
          text = string.format("%s no lo entregó a tiempo: %s vuelve al tablón", ns.ShortName(name), ns.KeyLabel(r.k)) })
      end
    end
  end
  -- Olvidar avisos viejos.
  for key, t in pairs(g.warned) do
    if type(t) ~= "number" or now - t > 3 * 86400 then g.warned[key] = nil end
  end
end
-- Quedadas de mazmorra: una nueva para mi nivel y si me han elegido para el grupo.
local DUNGEON_ICON = "Interface\\Icons\\INV_Misc_Key_03"
function Alerts.OnRunUpdated(old, new)
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  local D = ns.Dungeons
  if not new or not g or not me or D.State(new, now) ~= "open" then return end
  g.runAlerted = g.runAlerted or {}
  local dg = D.Dungeon(new.d)
  local when = new.at > now + 120 and ("a las " .. D.Clock(new.at)) or "ahora"
  if not old and new.a ~= me and not g.runAlerted[new.id] then
    local level = D.MyLevel()
    if level >= dg.min and level <= dg.max + 3 then
      g.runAlerted[new.id] = true
      Alerts.Push({ id = new.id, page = "dungeons", icon = DUNGEON_ICON,
        text = string.format("%s propone %s %s", ns.ShortName(new.a), dg.name, when) })
    end
  end
  local place = D.MyPlace(new)
  if place and place ~= "suplente" and new.a ~= me and D.MyPlace(old) ~= place then
    Alerts.Push({ id = new.id, page = "dungeons", icon = DUNGEON_ICON,
      text = string.format("¡Vas a %s de %s! Te invitará %s", dg.name, place, ns.ShortName(new.a)) })
  end
end
ns.Listen("RUN_UPDATED", function(old, new) ns.SafeCall(Alerts.OnRunUpdated, old, new) end)

-- Recordatorio a los apuntados poco antes de la hora.
function Alerts.CheckRuns()
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  local D = ns.Dungeons
  if not g or not me then return end
  g.warned = g.warned or {}
  for id, r in pairs(D.Runs() or {}) do
    local su = r.s and r.s[me]
    local left = r.at - now
    local key = "run:" .. id .. ":" .. r.at
    if su and not su.o and D.State(r, now) == "open" and left > 0 and left <= D.REMIND_BEFORE and not g.warned[key] then
      g.warned[key] = now
      Alerts.Push({ id = id, page = "dungeons", icon = DUNGEON_ICON,
        text = string.format("%s empieza en %s", D.Dungeon(r.d).name, ns.FormatDuration(left)) })
    end
  end
end

C_Timer.NewTicker(60, function()
  ns.SafeCall(Alerts.CheckDeadlines)
  ns.SafeCall(Alerts.CheckRuns)
  if ns.UI and ns.UI.IsShown() then ns.UI.Refresh() end -- para que corran los plazos en pantalla
end)
ns.On("PLAYER_REGEN_ENABLED", function() ns.After(1, Alerts.Flush) end)
ns.On("PLAYER_ENTERING_WORLD", function() ns.After(3, Alerts.Flush) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(3, Alerts.Flush) end)
