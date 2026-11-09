-- Ventana principal: se abre desde una pestaña lateral pegada a la ventana de hermandad o desde
-- el minimapa. Pestañas arriba (Inicio · Mercado · Agenda · Hermandad) y la rueda de Opciones.
-- Se puede encoger a una tira pequeña con el número de avisos.
local _, ns = ...
local W = ns.W
local UI = { pages = {} }
ns.UI = UI

UI.WIDTH, UI.HEIGHT = 820, 540

local panel, mini
local hosts = {}
-- Pestañas de arriba. Eventos y raids van dentro de la Agenda.
local SECTIONS = {
  { id = "home", label = "Inicio", page = "home" },
  { id = "market", label = "Mercado", page = "market" },
  { id = "agenda", label = "Agenda", page = "dungeons" },
  { id = "guild", label = "Hermandad", page = "guild" },
}
ns.MOTTO = "Mi vida por el fundillo"

-- Todas las páginas y la pestaña que se enciende con cada una.
local PAGES = {
  { id = "home", section = "home" },
  { id = "market", section = "market" },
  { id = "ask", section = "market" },      -- «+ Pedir» y «+ Ofrecer»: el catálogo
  { id = "dungeons", section = "agenda" },
  { id = "guild", section = "guild" },
  { id = "mine", section = "options" },    -- Opciones (rueda dentada)
}
local PAGE_BY_ID = {}
for _, p in ipairs(PAGES) do PAGE_BY_ID[p.id] = p end

-- Nombres de páginas de la 0.29 (los usan los avisos y otros módulos): adónde van ahora.
local ALIASES = {
  board = { page = "market" },
  requests = { page = "market" },
  materials = { page = "ask", mode = "materials" },
  equipment = { page = "ask", mode = "equipment" },
  agenda = { page = "dungeons" },
  options = { page = "mine" },
}

local function resolve(id)
  local a = ALIASES[id]
  if a then return a.page, a.mode end
  return PAGE_BY_ID[id] and id or "home", nil
end
UI.Resolve = resolve

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

local function tip(frame, title, text)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(title)
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
UI.Tip = tip

-- La escala más grande con la que la ventana cabe en la pantalla.
local function fitScale(scale)
  local h = UIParent.GetHeight and UIParent:GetHeight()
  if type(h) == "number" and h > 0 then
    scale = math.min(scale, (h - 40) / UI.HEIGHT)
  end
  return math.max(UI.MIN_SCALE, scale)
end

-- Circulito rojo con un número (pestañas y tira pequeña).
function UI.Badge(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(18, 18)
  f:SetFrameLevel(parent:GetFrameLevel() + 5)
  local dot = f:CreateTexture(nil, "ARTWORK")
  dot:SetAllPoints()
  dot:SetColorTexture(0.8, 0.1, 0.1, 0.95)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("CENTER", 0, 0)
  function f:SetCount(n)
    n = n or 0
    self:SetShown(n > 0)
    self.text:SetText(n > 9 and "9+" or tostring(n))
  end
  f:Hide()
  return f
end

local function createPanel()
  panel = W.Panel("HDFProfPanel", UIParent, UI.WIDTH, UI.HEIGHT)
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
  panel:SetScale(fitScale(UI.SavedScale()))

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
    UI.SetScale(self.startScale * (1 + (x - self.startX) / (UI.WIDTH * self.startScale)))
  end)
  grip:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
      UI.ResetWindow()
    elseif self.startX then
      self.startX = nil
      ns.db.settings.panelScale = panel:GetScale()
    end
  end)
  tip(grip, "Tamaño de la ventana", "Arrastra para hacerla más grande o más pequeña.\nClic derecho: tamaño y posición por defecto.")
  panel.grip = grip

  -- Barra de arriba: título, lema, encoger y cerrar.
  -- El escudo de NorrisPlay, pequeño, junto al título (en todas las pestañas).
  panel.logo = panel:CreateTexture(nil, "ARTWORK")
  panel.logo:SetSize(14, 28)
  panel.logo:SetPoint("TOPLEFT", 20, -9)
  panel.logo:SetTexture("Interface\\AddOns\\HDFprofesiones\\Media\\norrisplay")
  panel.title = W.Text(panel, "GameFontNormal")
  panel.title:SetPoint("TOPLEFT", 40, -18)
  panel.motto = W.Text(panel, "GameFontNormal", "RIGHT")
  panel.motto:SetPoint("TOPRIGHT", -62, -18)
  panel.motto:SetTextColor(1, 0.45, 0.1)
  panel.motto:SetText("\194\171" .. ns.MOTTO .. "\194\187")
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  local shrink = W.Button(panel, "_", 22, 20, function() UI.SetMini(true) end)
  shrink:SetPoint("RIGHT", close, "LEFT", 2, 0)
  tip(shrink, "Encoger", "Deja solo una tira pequeña con tus avisos. Púlsala para volver.")
  panel.shrink = shrink

  -- Pestañas (Inicio, Mercado, Agenda, Hermandad) y la rueda de Opciones.
  panel.sections = {}
  for i, s in ipairs(SECTIONS) do
    local b = W.Button(panel, s.label, 124, 26, function() UI.ShowPage(s.page) end)
    b:SetPoint("TOPLEFT", 20 + (i - 1) * 128, -40)
    b.badge = UI.Badge(b)
    b.badge:SetPoint("TOPRIGHT", 4, 6)
    panel.sections[s.id] = b
  end
  local gear = CreateFrame("Button", nil, panel)
  gear:SetSize(26, 26)
  gear:SetPoint("TOPRIGHT", -24, -40)
  local gearIcon = gear:CreateTexture(nil, "ARTWORK")
  gearIcon:SetAllPoints()
  gearIcon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  gear:SetScript("OnClick", function() UI.ShowPage("mine") end)
  tip(gear, "Opciones", "Tu personaje, los avisos y lo demás.")
  panel.gear = gear
  local line = panel:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 0.82, 0, 0.35)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 20, -70)
  line:SetPoint("TOPRIGHT", -20, -70)

  panel.content = CreateFrame("Frame", nil, panel)
  panel.content:SetPoint("TOPLEFT", 16, -76)
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
      f:SetSize(UI.WIDTH - 32, UI.HEIGHT - 92)
      f:Hide()
      -- Cada página por separado: si una falla al montarse, las demás siguen funcionando y el
      -- error queda en el informe (Opciones → Copiar informe).
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
  UI.UpdateBadges()
  panel.title:SetText(ns.TITLE .. "  |cff999999v" .. ns.VERSION .. "|r"
    .. (ns.db and ns.db.settings.demo and "  |cffff8040(DEMOSTRACIÓN)|r" or ""))
  local inGuild = ns.G() ~= nil
  local free = UI.current == "home" or UI.current == "mine"
  panel.noGuild:SetShown(not inGuild and not free)
  for id, f in pairs(panel.pageFrames) do
    f:SetShown((inGuild or id == "home" or id == "mine") and id == UI.current)
  end
  local f = panel.pageFrames[UI.current]
  if (inGuild or free) and f and f.Refresh then ns.SafeCall(f.Refresh, f) end
end

function UI.ShowPage(id)
  if not panel then createPanel() end
  local pageId, mode = resolve(id)
  UI.current = pageId
  local page = PAGE_BY_ID[pageId]
  for sid, b in pairs(panel.sections) do setActive(b, sid == page.section) end
  local f = panel.pageFrames[pageId]
  if mode and f and f.SetMode then ns.SafeCall(f.SetMode, f, mode) end
  UI.Refresh()
  return f
end

-- Página que se ve ahora (su marco), para que otras partes puedan pedirle cosas.
function UI.PageFrame(id)
  return panel and panel.pageFrames[resolve(id)]
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
  if mini and mini:IsShown() then mini:Hide() end
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
  panel:SetScale(fitScale(UI.SavedScale()))
  panel:Show()
  local f = UI.ShowPage(pageId or "home")
  if selectId and f and f.SelectById then f:SelectById(selectId) end
  return f
end

-- Tamaño y posición de la ventana (se recuerdan).
UI.MIN_SCALE, UI.MAX_SCALE = 0.6, 1.5

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
    panel:SetScale(fitScale(1))
    if panel:IsShown() then UI.Open(UI.current, nil, panel.host) end
  end
end

---------------------------------------------------------------------------
-- Tira pequeña: el addon encogido, con el número de avisos. Al pulsarla vuelve la ventana
-- entera en la página donde estabas.
---------------------------------------------------------------------------
-- Cada icono de la tira: qué cuenta y adónde lleva.
local MINI_ITEMS = {
  { id = "commits", icon = "Interface\\Icons\\Trade_BlackSmithing", title = "Encargos",
    text = "Lo que tienes que enviar.", open = function() UI.OpenMarket("involved") end },
  { id = "market", icon = "Interface\\Icons\\INV_Misc_Bag_10", title = "Mercado",
    text = "Lo que piden y puedes fabricar.", open = function() UI.OpenMarket("craft") end },
  { id = "agenda", icon = "Interface\\Icons\\INV_Misc_Key_03", title = "Agenda",
    text = "Quedadas a las que no te has apuntado.", open = function() UI.Open("dungeons") end },
}

local function createMini()
  mini = CreateFrame("Button", "HDFProfMini", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  mini:SetSize(34 + #MINI_ITEMS * 46, 34)
  mini:SetFrameStrata("HIGH")
  mini:SetClampedToScreen(true)
  mini:SetMovable(true)
  mini:RegisterForDrag("LeftButton")
  if mini.SetBackdrop then
    mini:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    mini:SetBackdropColor(0.05, 0.045, 0.04, 0.95)
    mini:SetBackdropBorderColor(1, 0.82, 0, 0.8)
  end
  -- El icono del addon: vuelve a la ventana entera donde estabas.
  local icon = mini:CreateTexture(nil, "ARTWORK")
  icon:SetSize(22, 22)
  icon:SetPoint("LEFT", 6, 0)
  icon:SetTexture("Interface\\Icons\\Trade_Engineering")
  mini:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  mini:SetScript("OnDragStart", function(self) self:StartMoving() end)
  mini:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    if point and ns.db then ns.db.settings.miniPos = { point, relPoint or point, x or 0, y or 0 } end
  end)
  mini:SetScript("OnClick", function() UI.SetMini(false) end)
  tip(mini, ns.TITLE, "Pulsa para abrir la ventana entera. Arrastra para moverla.")
  -- Un icono con su número por cada sitio; al pulsarlo se abre ese sitio.
  mini.items = {}
  for i, it in ipairs(MINI_ITEMS) do
    local b = CreateFrame("Button", nil, mini)
    b:SetSize(24, 24)
    b:SetPoint("LEFT", 34 + (i - 1) * 46, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(it.icon)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.count = W.Text(b, "GameFontNormal")
    b.count:SetPoint("LEFT", b, "RIGHT", 3, 0)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() mini:StartMoving() end)
    b:SetScript("OnDragStop", function() mini:GetScript("OnDragStop")(mini) end)
    b:SetScript("OnClick", function()
      mini:Hide()
      it.open()
    end)
    tip(b, it.title, it.text)
    b.def = it
    mini.items[it.id] = b
  end
  mini:Hide()
end

function UI.SetMini(on)
  if on then
    if not mini then createMini() end
    UI.miniPage = UI.current
    mini:ClearAllPoints()
    local pos = ns.db and ns.db.settings.miniPos
    if pos then
      mini:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    elseif panel then
      mini:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    else
      mini:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
    if panel then panel:Hide() end
    mini:Show()
    UI.UpdateBadges()
  else
    if mini then mini:Hide() end
    UI.Open(UI.miniPage or "home")
  end
end

function UI.IsMini()
  return mini and mini:IsShown()
end

-- Abrir (desde la pestaña o el minimapa) siempre lleva a Inicio.
function UI.Toggle(host)
  if panel and panel:IsShown() and (panel.host == host or not host) then
    panel:Hide()
  else
    UI.Open("home", nil, host)
  end
end

-- Lo que te espera, por sitios:
--   commits = lo que tienes que enviar (encargos y ofertas que te han pedido)
--   market  = lo que puedes fabricar de lo que piden
--   agenda  = quedadas abiertas de otros a las que no te has apuntado
--   guild   = pedidos de la hermandad abiertos
function UI.Counts()
  local c = { commits = 0, market = 0, agenda = 0, guild = 0 }
  if not ns.G() then return c end
  local stats = UI.BoardStats and UI.BoardStats()
  if stats then
    c.commits, c.market, c.guild = stats.toSend or 0, stats.servable or 0, stats.guild or 0
  end
  local D, me, now = ns.Dungeons, ns.Me(), ns.Now()
  for _, r in pairs(D and D.Runs() or {}) do
    local su = r.s and r.s[me]
    local signed = su and not su.o and (su.r or 0) > 0
    if r.a ~= me and not signed and D.State(r, now) == "open" then c.agenda = c.agenda + 1 end
  end
  return c
end

-- Cuántas cosas te esperan: lo que puedes hacer y lo que tienes que enviar.
function UI.PendingCount()
  local c = UI.Counts()
  return c.commits + c.market
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
    GameTooltip:AddLine("Pedidos y mazmorras de la hermandad", 1, 1, 1)
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
  local c = UI.Counts()
  if mini and mini:IsShown() then
    for id, b in pairs(mini.items) do
      local n = c[id] or 0
      b.count:SetText(n > 0 and string.format("|cffff4040%d|r", n) or "|cff999999·|r")
      b.icon:SetDesaturated(n == 0)
    end
  end
  if panel then
    panel.sections.market.badge:SetCount(c.market + c.commits)
    panel.sections.agenda.badge:SetCount(c.agenda)
    panel.sections.guild.badge:SetCount(c.guild)
  end
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
