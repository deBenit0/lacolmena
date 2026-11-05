-- Ventana principal: se abre desde una pestaña lateral pegada a la ventana de hermandad.
local _, ns = ...
local W = ns.W
local UI = { pages = {} }
ns.UI = UI

local panel
local hosts = {}
local PAGES = {
  { id = "recipes", label = "Recetas" },
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
    local b = W.Button(panel, p.label, 120, 22, function() UI.ShowPage(p.id) end)
    b:SetPoint("TOPLEFT", 20 + (i - 1) * 126, -40)
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
  panel.title:SetText(ns.TITLE .. " - Profesiones")
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
  for pid, b in pairs(panel.tabs) do
    if pid == id then b:Disable() else b:Enable() end
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
  UI.ShowPage(pageId or UI.current or "recipes")
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

-- La pestaña va debajo de la última pestaña lateral de Blizzard que se vea;
-- si no hay ninguna, arriba a la derecha de la ventana.
function UI.PlaceTab(tab, host)
  local last
  for _, key in ipairs(BLIZZARD_TABS) do
    local t = host[key]
    if type(t) == "table" and t.IsShown and t:IsShown() then last = t end -- van de arriba abajo
  end
  tab:ClearAllPoints()
  if last then
    tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 2, -18)
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
  local tab = CreateFrame("Button", "HDFProfGuildTab" .. (host:GetName() or ""), host)
  tab:SetSize(32, 32)
  UI.PlaceTab(tab, host)
  host:HookScript("OnShow", function() UI.PlaceTab(tab, host) end)
  local bg = tab:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
  bg:SetSize(64, 64)
  bg:SetPoint("TOPLEFT", -3, 11)
  local icon = tab:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture("Interface\\Icons\\Trade_Engineering")
  tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  tab:SetScript("OnClick", function() UI.Toggle(host) end)
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

local function scheduleRefresh()
  if UI.IsShown() then ns.Coalesce("uiRefresh", 0.3, UI.Refresh) end
end
ns.Listen("DATA_CHANGED", scheduleRefresh)
ns.Listen("ROSTER_UPDATED", scheduleRefresh)
ns.Listen("NEW_VERSION", scheduleRefresh)
ns.Listen("BAGS_CHANGED", scheduleRefresh)
ns.On("GET_ITEM_INFO_RECEIVED", function()
  if UI.IsShown() then ns.Coalesce("uiItems", 0.5, UI.Refresh) end
end)
