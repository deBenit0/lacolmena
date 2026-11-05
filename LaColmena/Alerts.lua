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
  local f = CreateFrame("Button", "LaColmenaAlert", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() Alerts.HideCurrent() end)
  f:SetScript("OnClick", function(self)
    local alert = self.alert
    Alerts.HideCurrent()
    if alert and ns.UI then ns.UI.Open("requests", alert.id) end
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
  frame.hint:SetText(alert.id and "Clic para verla" or "Clic para abrir La Colmena")
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
function Alerts.OnRequestUpdated(old, new)
  if not new then return end
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  if not g or not me then return end
  local info = Data.RequestInfo(new, now)
  local _, icon = ns.KeyInfo(new.k)

  -- Petición nueva de otro que puedo hacer (o dirigida a mí).
  if not old and new.a ~= me and info.state == "open" and (new.t or 0) > now - MAX_AGE and not g.alerted[new.id] then
    if new.to == me or (not new.to and Data.ICanCraft(new.k)) then
      g.alerted[new.id] = true
      local text = string.format("%s pide %dx %s", ns.ShortName(new.a), new.q, ns.KeyLabel(new.k))
      if new.to == me then text = text .. " (a ti)" end
      Alerts.Push({ id = new.id, icon = icon, text = text })
    end
  end

  -- Alguien se compromete en una de mis peticiones.
  if new.a == me and old then
    for name, cm in pairs(new.c or {}) do
      local before = old.c and old.c[name]
      if Data.CommitActive(cm, now) and (not before or before.rl or (before.n or 0) < cm.n) then
        Alerts.Push({
          id = new.id, icon = icon,
          text = string.format("%s hará %dx %s", ns.ShortName(name), cm.n - (cm.d or 0), ns.KeyLabel(new.k)),
        })
      end
    end
  end
end

ns.Listen("REQUEST_UPDATED", Alerts.OnRequestUpdated)
ns.On("PLAYER_REGEN_ENABLED", function() ns.After(1, Alerts.Flush) end)
ns.On("PLAYER_ENTERING_WORLD", function() ns.After(3, Alerts.Flush) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(3, Alerts.Flush) end)
