-- Ventana principal: se abre desde una pestaña lateral pegada a la ventana de hermandad.
local _, ns = ...
local W = ns.W
local UI = { pages = {} }
ns.UI = UI

local panel
local hosts = {}
-- Secciones del addon (fila de arriba). Mazmorras y Eventos se ven pero aún no se pueden abrir.
local SECTIONS = {
  { id = "home", label = "Inicio" },
  { id = "orders", label = "Pedidos" },
  { id = "dungeons", label = "Mazmorras" },
  { id = "events", label = "Eventos", soon = true },
  { id = "raids", label = "Raids", soon = true },
}
ns.MOTTO = "Mi vida por el fundillo"

-- Todas las páginas. "tab" = pestaña de la sección Pedidos que se enciende con ella.
local PAGES = {
  { id = "home", section = "home" },
  { id = "board", section = "orders", label = "Tablón", tab = "board" },
  { id = "materials", section = "orders", label = "Pedir materiales", tab = "materials" },
  { id = "equipment", section = "orders", label = "Pedir equipo", tab = "equipment" },
  { id = "requests", section = "orders", tab = "board" }, -- detalle de un pedido (se entra desde el tablón)
  { id = "guild", section = "orders", label = "Hermandad", tab = "guild" },
  { id = "mine", section = "orders", label = "Mis cosas", tab = "mine" },
  { id = "dungeons", section = "dungeons" },
}
local PAGE_BY_ID = {}
for _, p in ipairs(PAGES) do PAGE_BY_ID[p.id] = p end

-- Cada página se registra con una función que construye su contenido.
function UI.RegisterPage(id, create)
  UI.pages[id] = create
end

local function setActive(b, active)
  local fs = b.GetFontString and b:GetFontString()
  -- La activa se queda con el brillo encendido (no gris, que parece bloqueada).
  if active then
    b:LockHighlight()
    if fs then fs:SetTextColor(1, 1, 1) end
  else
    b:UnlockHighlight()
    if fs then fs:SetTextColor(1, 0.82, 0) end
  end
end

local function createPanel()
  panel = W.Panel("HDFProfPanel", UIParent, 640, 512)
  panel:SetFrameStrata("HIGH")
  panel:SetToplevel(true)
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  -- Se puede arrastrar a cualquier sitio: se recuerda dónde la dejaste.
  panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
  panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    UI.SavePosition()
  end)
  panel:Hide()
  tinsert(UISpecialFrames, "HDFProfPanel")
  panel:SetScale(UI.SavedScale())

  -- Asa para cambiar el tamaño (escala) arrastrando la esquina. Clic derecho: por defecto.
  local grip = CreateFrame("Button", nil, panel)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -4, 4)
  grip:SetFrameLevel(panel:GetFrameLevel() + 20)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  grip:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" or not GetCursorPosition then return end
    local x = GetCursorPosition()
    self.startX, self.startScale = x / UIParent:GetEffectiveScale(), panel:GetScale()
  end)
  grip:SetScript("OnUpdate", function(self)
    if not self.startX or not GetCursorPosition then return end
    local x = GetCursorPosition() / UIParent:GetEffectiveScale()
    UI.SetScale(self.startScale * (1 + (x - self.startX) / (640 * self.startScale)))
  end)
  grip:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
      UI.ResetWindow()
    elseif self.startX then
      self.startX = nil
      ns.db.settings.panelScale = panel:GetScale()
    end
  end)
  grip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Tamaño de la ventana")
    GameTooltip:AddLine("Arrastra para hacerla más grande o más pequeña.", 1, 1, 1, true)
    GameTooltip:AddLine("Clic derecho: tamaño y posición por defecto.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
  panel.grip = grip

  panel.title = W.Text(panel, "GameFontNormal")
  panel.title:SetPoint("TOPLEFT", 22, -18)
  -- El lema de la hermandad, siempre a la vista.
  panel.motto = W.Text(panel, "GameFontNormalLarge", "RIGHT")
  panel.motto:SetPoint("TOPRIGHT", -38, -15)
  panel.motto:SetTextColor(1, 0.45, 0.1)
  panel.motto:SetText("\194\171" .. ns.MOTTO .. "\194\187")
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  -- Secciones (Inicio, Pedidos, Mazmorras, Eventos).
  panel.sections = {}
  for i, s in ipairs(SECTIONS) do
    local b = W.Button(panel, s.label, 116, 24)
    b:SetPoint("TOPLEFT", 20 + (i - 1) * 120, -40)
    if s.soon then
      b:Disable()
      if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(s.label)
        GameTooltip:AddLine("Próximamente", 0.8, 0.8, 0.8)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    elseif s.id == "orders" then
      b:SetScript("OnClick", function() UI.ShowPage(UI.lastOrders or "board") end)
    else
      b:SetScript("OnClick", function() UI.ShowPage(s.id) end)
    end
    panel.sections[s.id] = b
  end
  local line = panel:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 0.82, 0, 0.35)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 20, -68)
  line:SetPoint("TOPRIGHT", -20, -68)

  -- Pestañas de la sección Pedidos.
  panel.tabs = {}
  local i = 0
  for _, p in ipairs(PAGES) do
    if p.label then
      i = i + 1
      local b = W.Button(panel, p.label, 118, 22, function() UI.ShowPage(p.id) end)
      b:SetPoint("TOPLEFT", 20 + (i - 1) * 122, -74)
      panel.tabs[p.id] = b
    end
  end

  panel.content = CreateFrame("Frame", nil, panel)
  panel.content:SetPoint("TOPLEFT", 16, -100)
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
      if p.section ~= "orders" then
        f:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -76) -- sin pestañas debajo: más sitio
        f:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
      else
        f:SetAllPoints()
      end
      f:Hide()
      -- Cada página por separado: si una falla al montarse, las demás siguen funcionando y el
      -- error queda en el informe (Mis cosas → Copiar informe).
      if ns.SafeCall(create, f) then
        panel.pageFrames[p.id] = f
      else
        UI.brokenPages = UI.brokenPages or {}
        UI.brokenPages[p.id] = true
      end
    end
  end
  panel:SetScript("OnShow", function() UI.Refresh() end)
end

function UI.Refresh()
  if not panel or not panel:IsShown() then return end
  panel.title:SetText(ns.TITLE .. "  |cff999999v" .. ns.VERSION .. "|r"
    .. (ns.db and ns.db.settings.demo and "  |cffff8040(MODO DEMOSTRACIÓN)|r" or ""))
  local inGuild = ns.G() ~= nil
  local home = UI.current == "home"
  panel.noGuild:SetShown(not inGuild and not home)
  for id, f in pairs(panel.pageFrames) do
    f:SetShown((inGuild or id == "home") and id == UI.current)
  end
  local f = panel.pageFrames[UI.current]
  if (inGuild or home) and f and f.Refresh then ns.SafeCall(f.Refresh, f) end
end

function UI.ShowPage(id)
  if not panel then createPanel() end
  UI.current = id
  local page = PAGE_BY_ID[id] or PAGE_BY_ID.board
  if page.section == "orders" then UI.lastOrders = (id == "requests") and "board" or id end
  for sid, b in pairs(panel.sections) do
    if b:IsEnabled() then setActive(b, sid == page.section) end
  end
  for pid, b in pairs(panel.tabs) do
    b:SetShown(page.section == "orders")
    setActive(b, pid == page.tab)
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
  local pos = ns.db and ns.db.settings.panelPos
  if pos then
    -- donde la dejó la última vez (sigue cerrándose con la ventana de hermandad)
    panel.host = host and host:IsVisible() and host or nil
    panel:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  elseif host and host:IsVisible() then
    panel.host = host
    panel:SetPoint("TOPLEFT", host, "TOPRIGHT", hostOffset(host) + 50, 0)
  else
    panel.host = nil
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
  panel:Show()
  UI.ShowPage(pageId or "home")
  if selectId then
    local f = panel.pageFrames[UI.current]
    if f and f.SelectById then f:SelectById(selectId) end
  end
end

-- Tamaño y posición de la ventana (se recuerdan).
UI.MIN_SCALE, UI.MAX_SCALE = 0.7, 1.6

function UI.SavedScale()
  local s = ns.db and tonumber(ns.db.settings.panelScale) or 1
  return math.max(UI.MIN_SCALE, math.min(UI.MAX_SCALE, s))
end

function UI.SetScale(scale)
  if not panel then return end
  scale = math.max(UI.MIN_SCALE, math.min(UI.MAX_SCALE, scale or 1))
  panel:SetScale(scale)
  if ns.db then ns.db.settings.panelScale = scale end
end

function UI.SavePosition()
  if not panel or not ns.db then return end
  local point, _, relPoint, x, y = panel:GetPoint(1)
  if point then ns.db.settings.panelPos = { point, relPoint or point, x or 0, y or 0 } end
end

function UI.ResetWindow()
  if not ns.db then return end
  ns.db.settings.panelPos = nil
  ns.db.settings.panelScale = nil
  if panel then
    panel:SetScale(1)
    if panel:IsShown() then UI.Open(UI.current, nil, panel.host) end
  end
end

function UI.Toggle(host)
  if panel and panel:IsShown() and panel.host == host then
    panel:Hide()
  else
    UI.Open(nil, nil, host)
  end
end

-- Ventanas en las que se ha puesto la pestaña (para el diagnóstico).
function UI.HostNames()
  local names = {}
  for host in pairs(hosts) do names[#names + 1] = host:GetName() or "?" end
  table.sort(names)
  return names
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
    GameTooltip:AddLine(ns.MOTTO, 1, 0.45, 0.1)
    GameTooltip:AddLine("Pedidos de la hermandad (pronto: mazmorras y eventos)", 1, 1, 1)
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
