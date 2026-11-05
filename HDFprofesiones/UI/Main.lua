-- Ventana principal: se abre desde una pestaña lateral pegada a la ventana de hermandad.
local _, ns = ...
local W = ns.W
local UI = { pages = {} }
ns.UI = UI

local panel
local hosts = {}
local PAGES = {
  { id = "materials", label = "Pedir materiales" },
  { id = "equipment", label = "Pedir equipo" },
  { id = "requests", label = "Peticiones" },
  { id = "mine", label = "Mis cosas" },
}

-- Cada página se registra con una función que construye su contenido.
function UI.RegisterPage(id, create)
  UI.pages[id] = create
end

local function createPanel()
  panel = W.Panel("HDFProfPanel", UIParent, 640, 480)
  panel:SetFrameStrata("HIGH")
  panel:SetToplevel(true)
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function(self)
    if not self.host then self:StartMoving() end
  end)
  panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  panel:Hide()
  tinsert(UISpecialFrames, "HDFProfPanel")

  panel.title = W.Text(panel, "GameFontNormal")
  panel.title:SetPoint("TOPLEFT", 22, -18)
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  panel.tabs = {}
  for i, p in ipairs(PAGES) do
    local b = W.Button(panel, p.label, 140, 22, function() UI.ShowPage(p.id) end)
    b:SetPoint("TOPLEFT", 20 + (i - 1) * 146, -40)
    panel.tabs[p.id] = b
  end

  panel.content = CreateFrame("Frame", nil, panel)
  panel.content:SetPoint("TOPLEFT", 16, -68)
  panel.content:SetPoint("BOTTOMRIGHT", -16, 16)

  panel.noGuild = W.Text(panel, "GameFontNormalLarge", "CENTER")
  panel.noGuild:SetTextColor(0.6, 0.6, 0.6)
  panel.noGuild:SetPoint("CENTER", panel.content, "CENTER")
  panel.noGuild:SetText("No estás en ninguna hermandad.")
  panel.noGuild:Hide()

  panel.pageFrames = {}
  for _, p in ipairs(PAGES) do
    local create = UI.pages[p.id]
    if create then
      local f = CreateFrame("Frame", nil, panel.content)
      f:SetAllPoints()
      f:Hide()
      create(f)
      panel.pageFrames[p.id] = f
    end
  end
  panel:SetScript("OnShow", function() UI.Refresh() end)
end

function UI.Refresh()
  if not panel or not panel:IsShown() then return end
  panel.title:SetText(ns.TITLE .. " - Profesiones"
    .. (ns.db and ns.db.settings.demo and "  |cffff8040(MODO DEMOSTRACIÓN)|r" or ""))
  local inGuild = ns.G() ~= nil
  panel.noGuild:SetShown(not inGuild)
  for id, f in pairs(panel.pageFrames) do
    f:SetShown(inGuild and id == UI.current)
  end
  local f = panel.pageFrames[UI.current]
  if inGuild and f and f.Refresh then ns.SafeCall(f.Refresh, f) end
end

function UI.ShowPage(id)
  if not panel then createPanel() end
  UI.current = id
  -- La pestaña activa se queda con el brillo del botón encendido (no gris, que parece bloqueada).
  for pid, b in pairs(panel.tabs) do
    local fs = b.GetFontString and b:GetFontString()
    if pid == id then
      b:LockHighlight()
      if fs then fs:SetTextColor(1, 1, 1) end
    else
      b:UnlockHighlight()
      if fs then fs:SetTextColor(1, 0.82, 0) end
    end
  end
  UI.Refresh()
end

-- Las ventanas antiguas tienen un margen transparente a la derecha.
local function hostOffset(host)
  local parent = host.GetParent and host:GetParent()
  if host.NineSlice or (parent and parent.NineSlice) then return 0 end
  return -32
end

local function visibleHost()
  for host in pairs(hosts) do
    if host:IsVisible() then return host end
  end
end

function UI.Open(pageId, selectId, host)
  if not panel then createPanel() end
  host = host or visibleHost()
  panel:ClearAllPoints()
  if host and host:IsVisible() then
    panel.host = host
    panel:SetPoint("TOPLEFT", host, "TOPRIGHT", hostOffset(host) + 50, 0)
  else
    panel.host = nil
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
  panel:Show()
  UI.ShowPage(pageId or UI.current or "materials")
  if selectId then
    local f = panel.pageFrames[UI.current]
    if f and f.SelectById then f:SelectById(selectId) end
  end
end

function UI.Toggle(host)
  if panel and panel:IsShown() and panel.host == host then
    panel:Hide()
  else
    UI.Open(nil, nil, host)
  end
end

function UI.IsShown()
  return panel and panel:IsShown()
end

-- Pestañas laterales de Blizzard en la ventana moderna "Hermandad y comunidades".
local BLIZZARD_TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" }

-- La pestaña va debajo de la pestaña lateral de Blizzard que esté más abajo
-- (no damos por hecho el orden: lo medimos en pantalla).
local function bottomOf(f)
  local b = f.GetBottom and f:GetBottom()
  return type(b) == "number" and b or nil
end

local function lowestSideTab(host, mine)
  local candidates, seen = {}, {}
  for _, key in ipairs(BLIZZARD_TABS) do
    local t = host[key]
    if type(t) == "table" and not seen[t] then
      seen[t] = true
      candidates[#candidates + 1] = t
    end
  end
  -- Cualquier otro botón pegado por fuera del borde derecho de la ventana.
  local right = host.GetRight and host:GetRight()
  if type(right) == "number" and host.GetChildren then
    for _, child in ipairs({ host:GetChildren() }) do
      local left = child.GetLeft and child:GetLeft()
      if not seen[child] and type(left) == "number" and left >= right - 8 then
        seen[child] = true
        candidates[#candidates + 1] = child
      end
    end
  end
  local last, lastBottom
  for _, t in ipairs(candidates) do
    if t ~= mine and t.IsShown and t:IsShown() then
      local b = bottomOf(t)
      if not last or (b and (not lastBottom or b < lastBottom)) then
        last, lastBottom = t, b
      end
    end
  end
  return last
end

function UI.PlaceTab(tab, host)
  local last = lowestSideTab(host, tab)
  tab:ClearAllPoints()
  if last then
    -- Mismo tamaño y separación que las de Blizzard: parece un icono más de la columna.
    local w, h = last:GetSize()
    if type(w) == "number" and w > 0 then tab:SetSize(w, h) end
    tab:SetPoint("TOP", last, "BOTTOM", 0, -20)
  else
    tab:SetPoint("TOPLEFT", host, "TOPRIGHT", hostOffset(host) + 2, -64)
  end
  tab:SetFrameStrata(host:GetFrameStrata() or "MEDIUM")
  tab:SetFrameLevel(host:GetFrameLevel() + 20)
end

-- Pestaña lateral con el icono del addon en la ventana de hermandad.
function UI.AttachHost(host)
  if not host or hosts[host] then return end
  hosts[host] = true
  local name = "HDFProfGuildTab" .. (host:GetName() or "")
  local ICON = "Interface\\Icons\\Trade_Engineering"
  -- Si existe, usamos la plantilla de Blizzard de esas pestañas para que se vea igual.
  local ok, tab = pcall(CreateFrame, "CheckButton", name, host, "CommunitiesFrameTabTemplate")
  if ok and tab and type(tab.Icon) == "table" and tab.Icon.SetTexture then
    tab.Icon:SetTexture(ICON)
    tab:SetScript("OnShow", nil)
  else
    tab = CreateFrame("Button", name, host)
    tab:SetSize(32, 32)
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    bg:SetSize(64, 64)
    bg:SetPoint("TOPLEFT", -3, 11)
    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(ICON)
    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  end
  -- Las posiciones solo se pueden medir con la ventana ya dibujada: recolocar al abrirla.
  local function place() UI.PlaceTab(tab, host) end
  place()
  host:HookScript("OnShow", function()
    place()
    ns.After(0.1, place)
    ns.After(0.5, place)
  end)
  -- Número de peticiones que puedo atender, en la esquina de la pestaña.
  tab.badge = CreateFrame("Frame", nil, tab)
  tab.badge:SetSize(20, 20)
  tab.badge:SetPoint("TOPRIGHT", 6, 6)
  tab.badge:SetFrameLevel(tab:GetFrameLevel() + 5)
  local dot = tab.badge:CreateTexture(nil, "ARTWORK")
  dot:SetAllPoints()
  dot:SetColorTexture(0.8, 0.1, 0.1, 0.95)
  tab.badge.text = tab.badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tab.badge.text:SetPoint("CENTER", 0, 0)
  tab.badge:Hide()
  UI.tabs = UI.tabs or {}
  UI.tabs[#UI.tabs + 1] = tab
  UI.UpdateBadges()
  tab:SetScript("OnClick", function(self)
    if self.SetChecked then self:SetChecked(false) end -- no se queda marcada como las de Blizzard
    UI.Toggle(host)
  end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.TITLE)
    GameTooltip:AddLine("Profesiones y peticiones de la hermandad", 1, 1, 1)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  host:HookScript("OnHide", function()
    if panel and panel.host == host then panel:Hide() end
  end)
end

local function attachHosts()
  if GuildFrame then UI.AttachHost(GuildFrame) end
  if CommunitiesFrame then UI.AttachHost(CommunitiesFrame) end
end

ns.Listen("LOGIN", function()
  attachHosts()
  -- Plan B: si este cliente no tiene esas ventanas, la pestaña va en la ventana Social,
  -- que en Classic es donde está la pestaña de la hermandad.
  ns.After(5, function()
    if not next(hosts) and FriendsFrame then UI.AttachHost(FriendsFrame) end
  end)
end)
ns.On("ADDON_LOADED", function(name)
  if name == "Blizzard_GuildUI" or name == "Blizzard_Communities" then attachHosts() end
end)

-- Actualiza el número de peticiones pendientes para mí en las pestañas.
function UI.UpdateBadges()
  if not UI.tabs then return end
  local n = ns.G() and #ns.Data.ServableRequests(ns.Now()) or 0
  for _, tab in ipairs(UI.tabs) do
    tab.badge:SetShown(n > 0)
    tab.badge.text:SetText(n > 9 and "9+" or tostring(n))
  end
end

local function scheduleRefresh()
  if UI.IsShown() then ns.Coalesce("uiRefresh", 0.3, UI.Refresh) end
end
ns.Listen("DATA_CHANGED", scheduleRefresh)
ns.Listen("DATA_CHANGED", function() ns.Coalesce("badges", 1, UI.UpdateBadges) end)
ns.Listen("ROSTER_UPDATED", scheduleRefresh)
ns.Listen("NEW_VERSION", scheduleRefresh)
ns.Listen("BAGS_CHANGED", scheduleRefresh)
ns.On("GET_ITEM_INFO_RECEIVED", function()
  if UI.IsShown() then ns.Coalesce("uiItems", 0.5, UI.Refresh) end
end)
