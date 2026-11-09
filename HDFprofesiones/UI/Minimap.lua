-- Icono redondo en el borde del minimapa (como los del juego) para abrir el addon.
-- Se arrastra alrededor del minimapa y se recuerda dónde lo dejaste. Sin librerías.
-- Se puede quitar en Opciones (rueda dentada).
local _, ns = ...
local Minimap_ = Minimap
local ICON = "Interface\\Icons\\Trade_Engineering"
local button

local function settings()
  local s = ns.db.settings
  s.minimap = s.minimap or { angle = 200 }
  return s.minimap
end

-- Coloca el botón en el borde del minimapa según su ángulo (grados).
local function place()
  if not button then return end
  local angle = math.rad(settings().angle or 200)
  local radius = (Minimap_:GetWidth() / 2) + 5
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap_, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function dragUpdate()
  local mx, my = Minimap_:GetCenter()
  local scale = Minimap_:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  settings().angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
  place()
end

local function create()
  button = CreateFrame("Button", "HDFProfMinimapButton", Minimap_)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetPoint("TOPLEFT", 7, -5)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexture(ICON)
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  if button.CreateMaskTexture then
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
  end
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  button.icon = icon

  button:SetScript("OnClick", function() ns.UI.Toggle(nil) end)
  button:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", dragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
  end)
  button:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -7) end)
  button:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -6) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(ns.TITLE)
    GameTooltip:AddLine(ns.MOTTO, 1, 0.45, 0.1)
    GameTooltip:AddLine("Clic: abrir o cerrar.", 1, 1, 1)
    GameTooltip:AddLine("Arrastra para moverlo por el borde del minimapa.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  place()
end

local MinimapButton = {}
ns.MinimapButton = MinimapButton

function MinimapButton.Update()
  if not Minimap_ or not ns.db then return end
  local hide = settings().hide
  if hide then
    if button then button:Hide() end
    return
  end
  if not button then create() end
  button:Show()
  place()
end

function MinimapButton.SetShown(show)
  settings().hide = not show or nil
  MinimapButton.Update()
end

function MinimapButton.IsShown()
  return not settings().hide
end

ns.Listen("LOGIN", function() ns.SafeCall(MinimapButton.Update) end)
