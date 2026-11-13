-- Avisos emergentes: peticiones nuevas que puedo fabricar y compromisos en mis peticiones.
-- En combate, mazmorras y bandas se guardan y se muestran al salir.
local _, ns = ...
local Data = ns.Data
local Alerts = {}
ns.Alerts = Alerts

local queue = {}
local frame, showing, hideToken

-- Tipos de aviso: cada uno se configura en Opciones (encendido, grande en el centro, sonido y
-- también en el chat).
Alerts.TYPES = {
  { id = "craft", label = "Pedido que puedes hacer" },
  { id = "accepted", label = "Novedades de tus pedidos" },
  { id = "run", label = "Quedada nueva" },
  { id = "signup", label = "Se apuntan a tu quedada" },
  { id = "group", label = "Te eligen para el grupo" },
  { id = "remind", label = "Recordatorio de la hora" },
  { id = "expire", label = "Algo tuyo caduca pronto" },
  { id = "other", label = "Plazos, ofertas y lo demás" },
}
local TYPE_BY_ID = {}
for _, t in ipairs(Alerts.TYPES) do TYPE_BY_ID[t.id] = t end

-- Ajustes de un tipo de aviso (se crean con los valores por defecto).
function Alerts.TypeSettings(id)
  local s = ns.db.settings
  s.alertTypes = s.alertTypes or {}
  local t = s.alertTypes[id]
  if not t then
    t = { on = true, big = false, sound = true, chat = false }
    s.alertTypes[id] = t
  end
  return t
end

-- De la 0.29: "avisos" y "sonido" eran un solo interruptor para todo. Se pasan a cada tipo.
ns.Listen("DB_READY", function()
  local s = ns.db.settings
  if (s.alertsVersion or 0) < 1 then
    for _, t in ipairs(Alerts.TYPES) do
      local ts = Alerts.TypeSettings(t.id)
      if s.alerts == false then ts.on = false end
      if s.sound == false then ts.sound = false end
    end
    s.alerts, s.sound = true, true
    s.alertsVersion = 1
  end
end)
local SHOW_SECONDS = 15
local MAX_AGE = 86400 -- no avisar de peticiones de hace más de un día

-- "No molestar": hasta esta hora (del addon) los avisos se guardan sin mostrarse.
function Alerts.QuietUntil()
  return ns.db and ns.db.settings.dndUntil or 0
end

function Alerts.IsQuiet()
  return ns.Now() < Alerts.QuietUntil()
end

-- Opciones de "No molestar": nil (no), 1 h, 3 h y hasta mañana a las 9:00.
Alerts.QUIET_OPTIONS = { { label = "no" }, { label = "1 hora", secs = 3600 }, { label = "3 horas", secs = 3 * 3600 },
  { label = "hasta mañana", tomorrow = true } }

function Alerts.SetQuiet(option, now)
  local o = Alerts.QUIET_OPTIONS[option]
  local untilT
  if o and o.secs then
    untilT = now + o.secs
  elseif o and o.tomorrow then
    -- mañana a las 9:00 (hora del ordenador); si no se puede saber, 12 horas
    local left = 12 * 3600
    local t = date and date("*t")
    if type(t) == "table" and t.hour then left = (24 - t.hour + 9) * 3600 - (t.min or 0) * 60 end
    untilT = now + left
  end
  ns.db.settings.dndUntil = untilT
  ns.db.settings.dndOption = untilT and option or 1
  if not untilT then ns.After(1, Alerts.Flush) end
end

local function canShowNow()
  if Alerts.IsQuiet() then return false end
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
  -- Rueda: lleva a la configuración de este tipo de aviso.
  f.gear = CreateFrame("Button", nil, f)
  f.gear:SetSize(14, 14)
  f.gear:SetPoint("RIGHT", f, "TOPRIGHT", -30, -16)
  local gearTex = f.gear:CreateTexture(nil, "ARTWORK")
  gearTex:SetAllPoints()
  gearTex:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  f.gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  f.gear:SetScript("OnClick", function()
    local alert = f.alert
    Alerts.HideCurrent()
    if ns.UI then
      local page = ns.UI.Open("mine")
      if page and page.FocusAlert then page:FocusAlert(alert and alert.type or "other") end
    end
  end)
  f.gear:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Configurar este aviso")
    GameTooltip:Show()
  end)
  f.gear:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    if alert and ns.UI then ns.UI.Open(alert.page or "market", alert.id) end
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
  -- Cartel pequeño arriba o aviso grande en el centro, según el tipo.
  local ts = Alerts.TypeSettings(alert.type or "other")
  frame:ClearAllPoints()
  if ts.big then
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    frame:SetScale(1.5)
  else
    frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    frame:SetScale(1)
  end
  frame:Show()
  if ts.sound then PlaySound(alert.sound or (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081) end
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

-- El mismo aviso no se repite en 10 minutos.
Alerts.DEDUP_SECONDS = 600
local recent = {}

function Alerts.Push(alert)
  if not ns.db or not ns.db.settings.alerts then return end
  local c = ns.MyChar()
  if c and c.u then return end -- "no disponible": sin avisos
  alert.type = TYPE_BY_ID[alert.type or ""] and alert.type or "other"
  local ts = Alerts.TypeSettings(alert.type)
  if not ts.on then return end
  local now, key = GetTime(), alert.text or ""
  if recent[key] and now - recent[key] < Alerts.DEDUP_SECONDS then return end
  recent[key] = now
  for k, t in pairs(recent) do
    if now - t > Alerts.DEDUP_SECONDS then recent[k] = nil end
  end
  if ts.chat then ns.Print(alert.text or "") end
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
      Alerts.Push({ id = new.id, icon = icon, text = text, canCommit = true, type = "craft" })
    end
  end

  -- Me han enviado por correo algo de una de mis peticiones.
  if new.a == me and old then
    for name, cm in pairs(new.c or {}) do
      local before = old.c and old.c[name]
      local sentBefore = before and before.s or 0
      if (cm.s or 0) > sentBefore then
        Alerts.Push({
          id = new.id, icon = icon, type = "accepted",
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
        id = new.id, icon = icon, type = "accepted",
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
      Alerts.Push({ id = new.id, icon = icon, type = "accepted",
        text = string.format("%s necesita más tiempo para %s%s", ns.ShortName(owner), ns.KeyLabel(new.k),
          w and (": " .. w.label:gsub("^Lo hago ", ""):lower()) or "") })
    end
  end

  -- El autor me ha quitado el encargo.
  if new.a ~= me and old and new.c and new.c[me] and Data.Rejected(new, me) and not Data.Rejected(old, me) then
    Alerts.Push({ id = new.id, icon = icon,
      text = string.format("%s te ha quitado el encargo: %s", ns.ShortName(new.a), ns.KeyLabel(new.k)) })
    return
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
        and now < cm.by + Data.COMMIT_GRACE + 86400 and not Data.Rejected(r, name)
      if expired then
        local info = Data.RequestInfo(r, now)
        expired = Data.IsActiveState(info.state) and info.late ~= nil and info.late.name == name
      end
      if name == me and r.a ~= me then
        if cm.by and Data.CommitActive(cm, now, r) and cm.by - now <= Alerts.WARN_BEFORE then
          local left = cm.by - now
          once(key .. ":soon", { id = id, icon = icon,
            text = string.format("%s para enviar %dx %s a %s",
              left > 60 and ("Te quedan " .. ns.FormatDuration(left)) or "Se acaba tu plazo", pendingUnits,
              ns.KeyLabel(r.k), ns.ShortName(r.a)) })
        elseif expired then
          once(key .. ":late", { id = id, icon = icon,
            text = string.format("Se pasó tu plazo: %s vuelve al Mercado", ns.KeyLabel(r.k)) })
        end
      elseif r.a == me and expired then
        once(key .. ":back", { id = id, icon = icon,
          text = string.format("%s no lo entregó a tiempo: %s vuelve al Mercado", ns.ShortName(name), ns.KeyLabel(r.k)) })
      end
    end
  end
  -- Lo mío que caduca en menos de un día (una vez por pedido u oferta y plazo).
  for id, r in pairs(g.requests) do
    if r.a == me then
      local info = Data.RequestInfo(r, now)
      local left = info.expires and (info.expires - now)
      if Data.IsActiveState(info.state) and left and left > 0 and left <= 86400 then
        local _, icon = ns.KeyInfo(r.k)
        once("exp:" .. id .. ":" .. info.expires, { id = id, icon = icon, type = "expire", page = "market",
          text = string.format("Tu pedido de %s caduca en %s: renuévalo si aún lo quieres", ns.KeyLabel(r.k),
            ns.FormatDuration(left)) })
      end
    end
  end
  for _, o in ipairs(ns.Offers.List(now)) do
    local left = (o.t or 0) + ns.Offers.OFFER_TTL - now
    if o.owner == me and left > 0 and left <= 86400 then
      local _, icon = ns.KeyInfo("i" .. o.id)
      once("expo:" .. o.key .. ":" .. (o.t or 0), { icon = icon, type = "expire", page = "market",
        text = string.format("Tu oferta de %s caduca en %s", ns.KeyLabel("i" .. o.id), ns.FormatDuration(left)) })
    end
  end
  -- Olvidar avisos viejos.
  for key, t in pairs(g.warned) do
    if type(t) ~= "number" or now - t > 3 * 86400 then g.warned[key] = nil end
  end
end
-- Quedadas de mazmorra: una nueva para mi nivel y si me han elegido para el grupo.
local DUNGEON_ICON = ns.Dungeons and ns.Dungeons.KEY_ICON or "Interface\\Icons\\INV_Misc_Key_03"
function Alerts.OnRunUpdated(old, new)
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  local D = ns.Dungeons
  if not new or not g or not me or D.State(new, now) ~= "open" then return end
  g.runAlerted = g.runAlerted or {}
  local dg = D.Dungeon(new.d)
  local when = new.at > now + 120 and (D.DayText(new.at, now) .. " a las " .. D.Clock(new.at)) or "ahora"
  if not old and new.a ~= me and not g.runAlerted[new.id] then
    local level = D.MyLevel()
    if level >= dg.min and level <= dg.max + 3 then
      g.runAlerted[new.id] = true
      Alerts.Push({ id = new.id, page = "dungeons", icon = DUNGEON_ICON, type = "run",
        text = string.format("%s propone %s %s", ns.ShortName(new.a), dg.name, when) })
    end
  end
  -- En mi quedada: aviso con el sonido de invitación a grupo del juego cuando alguien se apunta.
  if old and new.a == me then
    for name, su in pairs(new.s or {}) do
      local before = old.s and old.s[name]
      local active = not su.o and su.r and su.r > 0
      local wasActive = before and not before.o and before.r and before.r > 0
      if name ~= me and active and not wasActive then
        local roles = {}
        for _, ro in ipairs(D.ROLES) do
          if math.floor(su.r / ro.bit) % 2 == 1 then roles[#roles + 1] = ro.label end
        end
        Alerts.Push({ id = new.id, page = "dungeons", icon = DUNGEON_ICON, type = "signup",
          sound = (SOUNDKIT and SOUNDKIT.IG_PLAYER_INVITE) or 880,
          text = string.format("%s se apunta a %s (%s)", ns.ShortName(name), dg.name, table.concat(roles, "/")) })
      end
    end
  end
  local place = D.MyPlace(new)
  if place and place ~= "suplente" and new.a ~= me and D.MyPlace(old) ~= place then
    Alerts.Push({ id = new.id, page = "dungeons", icon = DUNGEON_ICON, type = "group",
      text = place == "en el grupo" and string.format("¡Vas al grupo de %s! Te invitará %s", dg.name, ns.ShortName(new.a))
        or string.format("¡Vas a %s de %s! Te invitará %s", dg.name, place, ns.ShortName(new.a)) })
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
      Alerts.Push({ id = id, page = "dungeons", icon = DUNGEON_ICON, type = "remind",
        text = string.format("%s empieza en %s", D.Dungeon(r.d).name, ns.FormatDuration(left)) })
    end
  end
end

C_Timer.NewTicker(60, function()
  ns.SafeCall(Alerts.CheckDeadlines)
  ns.SafeCall(Alerts.CheckRuns)
  ns.SafeCall(Alerts.Flush) -- lo guardado durante "No molestar" o el combate
  if ns.UI and ns.UI.IsShown() then ns.UI.Refresh() end -- para que corran los plazos en pantalla
end)
ns.On("PLAYER_REGEN_ENABLED", function() ns.After(1, Alerts.Flush) end)
ns.On("PLAYER_ENTERING_WORLD", function() ns.After(3, Alerts.Flush) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() ns.After(3, Alerts.Flush) end)
