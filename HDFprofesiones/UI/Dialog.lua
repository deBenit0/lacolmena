-- Ventana de petición. Solo se abre con el objeto ya elegido: desde la ventana de
-- profesión ("Pedir") o desde la página "Pedir materiales". El pedido va a toda la hermandad
-- y se lo queda el primero que lo acepte.
local _, ns = ...
local W, Data = ns.W, ns.Data

local dialog

-- Propinas sugeridas (en cobre).
local TIPS = {
  { label = "Nada", copper = 0 },
  { label = "50 plata", copper = 5000 },
  { label = "1 oro", copper = 10000 },
  { label = "2 oro", copper = 20000 },
  { label = "5 oro", copper = 50000 },
}

local function setKey(key, pk)
  dialog.key = key
  dialog.pk = pk or (key and Data.SingleProfession(key)) or nil
  local name, icon, link = ns.KeyInfo(key)
  dialog.iconTex:SetTexture(icon)
  dialog.itemName:SetText(link or name or ns.KeyName(key))
end

-- Botones que funcionan como opciones: el elegido se queda encendido.
local function markSelected(buttons, selected)
  for i, b in ipairs(buttons) do
    local fs = b.GetFontString and b:GetFontString()
    if i == selected then
      b:LockHighlight()
      if fs then fs:SetTextColor(1, 1, 1) end
    else
      b:UnlockHighlight()
      if fs then fs:SetTextColor(1, 0.82, 0) end
    end
  end
end

local function create()
  dialog = W.Panel("HDFProfRequestDialog", UIParent, 420, 330)
  dialog:SetFrameStrata("DIALOG")
  dialog:SetToplevel(true)
  dialog:SetPoint("CENTER", 0, 60)
  dialog:SetMovable(true)
  dialog:SetClampedToScreen(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", dialog.StartMoving)
  dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
  dialog:Hide()
  tinsert(UISpecialFrames, "HDFProfRequestDialog")

  local title = W.Text(dialog, "GameFontNormal")
  title:SetPoint("TOP", 0, -18)
  title:SetText("Pedir en la hermandad")
  local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  -- Objeto
  local itemLabel = W.Text(dialog, "GameFontNormalSmall")
  itemLabel:SetPoint("TOPLEFT", 24, -46)
  itemLabel:SetText("Qué necesitas")
  dialog.itemButton = CreateFrame("Button", nil, dialog)
  dialog.itemButton:SetSize(32, 32)
  dialog.itemButton:SetPoint("TOPLEFT", 24, -62)
  dialog.iconTex = dialog.itemButton:CreateTexture(nil, "ARTWORK")
  dialog.iconTex:SetAllPoints()
  W.KeyTooltip(dialog.itemButton, function() return dialog.key end)
  dialog.itemName = W.Text(dialog, "GameFontHighlight")
  dialog.itemName:SetPoint("TOPLEFT", dialog.itemButton, "TOPRIGHT", 8, -1)
  dialog.itemName:SetPoint("RIGHT", dialog, "RIGHT", -24, 0)
  dialog.itemName:SetWordWrap(false)

  -- Cantidad y materiales
  local qtyLabel = W.Text(dialog, "GameFontNormalSmall")
  qtyLabel:SetPoint("TOPLEFT", 24, -112)
  qtyLabel:SetText("Cantidad")
  dialog.qty = W.Input(dialog, 50, true)
  dialog.qty:SetPoint("LEFT", qtyLabel, "RIGHT", 14, 0)
  dialog.qty:SetMaxLetters(4)
  dialog.mats = W.Check(dialog, "Aporto yo los materiales")
  dialog.mats:SetPoint("LEFT", dialog.qty, "RIGHT", 16, 0)

  -- Prisa: los mismos botones que verá el que lo acepte.
  local rushLabel = W.Text(dialog, "GameFontNormalSmall")
  rushLabel:SetPoint("TOPLEFT", 24, -142)
  rushLabel:SetText("¿Qué prisa tienes?")
  dialog.rush = {}
  local rushLabels = { "Sin prisa" }
  for _, w in ipairs(Data.WHEN) do rushLabels[#rushLabels + 1] = w.ask end
  for i, label in ipairs(rushLabels) do
    local b = W.Button(dialog, label, i == 3 and 110 or 86, 22)
    if i == 1 then
      b:SetPoint("TOPLEFT", 24, -158)
    else
      b:SetPoint("LEFT", dialog.rush[i - 1], "RIGHT", 4, 0)
    end
    b:SetScript("OnClick", function() dialog:SetRush(i - 1) end)
    dialog.rush[i] = b
  end
  function dialog:SetRush(pr)
    self.pr = (pr and pr > 0) and pr or nil
    markSelected(self.rush, (self.pr or 0) + 1)
  end

  -- Propina
  local tipLabel = W.Text(dialog, "GameFontNormalSmall")
  tipLabel:SetPoint("TOPLEFT", 24, -194)
  tipLabel:SetText("Ofrecer propina (opcional)")
  dialog.tips = {}
  for i, tip in ipairs(TIPS) do
    local b = W.Button(dialog, tip.label, 70, 22)
    if i == 1 then
      b:SetPoint("TOPLEFT", 24, -210)
    else
      b:SetPoint("LEFT", dialog.tips[i - 1], "RIGHT", 4, 0)
    end
    b:SetScript("OnClick", function() dialog:SetTip(tip.copper) end)
    dialog.tips[i] = b
  end
  local otherLabel = W.Text(dialog, "GameFontHighlightSmall")
  otherLabel:SetPoint("TOPLEFT", 26, -244)
  otherLabel:SetText("u otra:")
  dialog.gold = W.Input(dialog, 50, true)
  dialog.gold:SetPoint("LEFT", otherLabel, "RIGHT", 12, 0)
  dialog.gold:SetMaxLetters(5)
  local goldLabel = W.Text(dialog, "GameFontHighlightSmall")
  goldLabel:SetPoint("LEFT", dialog.gold, "RIGHT", 4, 0)
  goldLabel:SetText("oro")
  dialog.silver = W.Input(dialog, 30, true)
  dialog.silver:SetPoint("LEFT", goldLabel, "RIGHT", 14, 0)
  dialog.silver:SetMaxLetters(2)
  local silverLabel = W.Text(dialog, "GameFontHighlightSmall")
  silverLabel:SetPoint("LEFT", dialog.silver, "RIGHT", 4, 0)
  silverLabel:SetText("plata")
  local codNote = W.Text(dialog, "GameFontHighlightSmall")
  codNote:SetPoint("LEFT", silverLabel, "RIGHT", 10, 0)
  codNote:SetTextColor(0.7, 0.7, 0.7)
  codNote:SetText("(se cobra con el correo)")

  function dialog:Tip()
    return (tonumber(self.gold:GetText()) or 0) * 10000 + (tonumber(self.silver:GetText()) or 0) * 100
  end
  function dialog:SetTip(copper)
    self.settingTip = true
    local g = math.floor(copper / 10000)
    local sv = math.floor(copper / 100) % 100
    self.gold:SetText(g > 0 and tostring(g) or "")
    self.silver:SetText(sv > 0 and tostring(sv) or "")
    self.settingTip = false
    self:MarkTip()
  end
  function dialog:MarkTip()
    local copper, selected = self:Tip(), nil
    for i, tip in ipairs(TIPS) do
      if tip.copper == copper then selected = i end
    end
    markSelected(self.tips, selected)
  end
  dialog.gold:HookScript("OnTextChanged", function() if not dialog.settingTip then dialog:MarkTip() end end)
  dialog.silver:HookScript("OnTextChanged", function() if not dialog.settingTip then dialog:MarkTip() end end)

  -- Botones
  dialog.info = W.Text(dialog, "GameFontHighlightSmall")
  dialog.info:SetPoint("BOTTOMLEFT", 24, 24)
  dialog.info:SetTextColor(0.7, 0.7, 0.7)
  local publish = W.Button(dialog, "Publicar", 96, 22, function() dialog:Publish() end)
  publish:SetPoint("BOTTOMRIGHT", -22, 18)
  local cancel = W.Button(dialog, "Cancelar", 86, 22, function() dialog:Hide() end)
  cancel:SetPoint("RIGHT", publish, "LEFT", -6, 0)

  function dialog:Publish()
    if not self.key then return end
    local q = tonumber(self.qty:GetText()) or 1
    local copper = self:Tip()
    local r = ns.Sync.CreateRequest({
      k = self.key, pk = self.pk, q = q, m = self.mats:GetChecked() and true or false,
      g = copper > 0 and copper or nil, pr = self.pr,
    })
    if r then
      self:Hide()
      ns.UI.Open("board")
    end
  end
end

-- opts = { k = objeto, pk = profesión, q = cantidad }
function ns.UI.OpenRequestDialog(opts)
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  opts = opts or {}
  if not ns.ParseKey(opts.k) then return end -- sin objeto elegido no hay petición
  if not dialog then create() end
  setKey(opts.k, opts.pk)
  dialog.qty:SetText(tostring(opts.q or 1))
  dialog.mats:SetChecked(true)
  dialog:SetRush(nil)
  dialog:SetTip(0)
  local open = Data.CountOpenBy(ns.Me(), ns.Now())
  dialog.info:SetText(string.format("Va a toda la hermandad. Tienes %d de %d abiertas.", open, Data.MAX_OPEN))
  dialog:Show()
end
