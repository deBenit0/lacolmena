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
  dialog = W.Panel("HDFProfRequestDialog", UIParent, 420, 252)
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
  title:SetText("Pedir a la hermandad")
  local close = W.CloseButton(dialog)
  close:SetPoint("TOPRIGHT", -10, -10)

  -- Objeto
  dialog.itemButton = CreateFrame("Button", nil, dialog)
  dialog.itemButton:SetSize(32, 32)
  dialog.itemButton:SetPoint("TOPLEFT", 24, -44)
  dialog.iconTex = dialog.itemButton:CreateTexture(nil, "ARTWORK")
  dialog.iconTex:SetAllPoints()
  W.KeyTooltip(dialog.itemButton, function() return dialog.key end)
  dialog.itemName = W.Text(dialog, "GameFontHighlight")
  dialog.itemName:SetPoint("LEFT", dialog.itemButton, "RIGHT", 10, 0)
  dialog.itemName:SetPoint("RIGHT", dialog, "RIGHT", -24, 0)
  dialog.itemName:SetWordWrap(false)

  -- Cantidad con - y +.
  local qtyLabel = W.Text(dialog, "GameFontNormalSmall")
  qtyLabel:SetPoint("TOPLEFT", 24, -94)
  qtyLabel:SetText("Cantidad")
  local function qtyValue() return math.max(1, tonumber(dialog.qty:GetText()) or 1) end
  dialog.minus = W.Button(dialog, "-", 24, 22, function() dialog.qty:SetText(tostring(math.max(1, qtyValue() - 1))) end)
  dialog.minus:SetPoint("LEFT", qtyLabel, "RIGHT", 14, 0)
  dialog.qty = W.Input(dialog, 50, true)
  dialog.qty:SetPoint("LEFT", dialog.minus, "RIGHT", 8, 0)
  dialog.qty:SetMaxLetters(4)
  dialog.qty:SetJustifyH("CENTER")
  dialog.plus = W.Button(dialog, "+", 24, 22, function()
    dialog.qty:SetText(tostring(math.min(Data.MAX_QTY, qtyValue() + 1)))
  end)
  dialog.plus:SetPoint("LEFT", dialog.qty, "RIGHT", 4, 0)

  -- Solo oficiales: pedido de la hermandad (lo abastecen entre varios, cada uno lo que pueda).
  -- Propina: a la derecha de la cantidad, escrita a mano (oro y plata) para dar un precio justo.
  -- (el botón que iba pasando por cantidades fijas queda escondido)
  dialog.tipButton = W.Button(dialog, "Sin propina", 120, 22, function()
    local copper, nextIdx = dialog:Tip(), 1
    for i, tip in ipairs(TIPS) do
      if tip.copper == copper then nextIdx = i % #TIPS + 1 end
    end
    dialog:SetTip(TIPS[nextIdx].copper)
  end)
  dialog.tipButton:SetPoint("LEFT", dialog.plus, "RIGHT", 16, 0)
  dialog.tipButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Propina")
    GameTooltip:AddLine("Pulsa para cambiarla. Se cobra con el correo (contra reembolso).", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  dialog.tipButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  dialog.tipButton:Hide()

  -- Más opciones (materiales, prisa y propina): ocultas para que pedir sea directo.
  dialog.moreButton = W.Button(dialog, "Más opciones", 110, 20)
  dialog.moreButton:SetPoint("TOPLEFT", 24, -180)
  local more = CreateFrame("Frame", nil, dialog)
  more:SetAllPoints()
  dialog.more = more
  dialog.summary = W.Text(dialog, "GameFontHighlightSmall")
  dialog.summary:SetPoint("LEFT", dialog.moreButton, "RIGHT", 10, 0)
  dialog.summary:SetTextColor(0.7, 0.7, 0.7)
  function dialog:SetExpanded(expanded)
    more:SetShown(expanded)
    self:SetHeight(expanded and 316 or 252)
    self.moreButton:SetText(expanded and "Menos opciones" or "Más opciones")
    self:UpdateSummary()
  end
  dialog.moreButton:SetScript("OnClick", function() dialog:SetExpanded(not more:IsShown()) end)
  -- Resumen de lo elegido, para verlo sin abrir "Más opciones".
  function dialog:UpdateSummary()
    if more:IsShown() then
      self.summary:SetText("")
      return
    end
    -- (la propina ya se ve en su botón, junto a la cantidad)
    local parts = { self.pr and Data.WHEN[self.pr].need:lower() or "sin prisa" }
    self.summary:SetText(table.concat(parts, ", "))
  end

  dialog.mats = W.Check(more, "Aporto yo los materiales")
  dialog.mats:SetPoint("TOPLEFT", 20, -206)
  -- Solo oficiales: pedido de la hermandad (lo abastecen entre varios, cada uno lo que pueda).
  dialog.guild = W.Check(more, "Para la hermandad")
  dialog.guild:SetPoint("TOPLEFT", 220, -206)

  -- Prisa: los mismos botones que verá el que lo acepte.
  local rushLabel = W.Text(more, "GameFontNormalSmall")
  rushLabel:SetPoint("TOPLEFT", 24, -238)
  rushLabel:SetText("¿Qué prisa tienes?")
  dialog.rush = {}
  local rushLabels = { "Sin prisa" }
  for _, w in ipairs(Data.WHEN) do rushLabels[#rushLabels + 1] = w.ask end
  for i, label in ipairs(rushLabels) do
    local b = W.Button(more, label, i == 3 and 110 or 86, 22)
    if i == 1 then
      b:SetPoint("TOPLEFT", 24, -254)
    else
      b:SetPoint("LEFT", dialog.rush[i - 1], "RIGHT", 4, 0)
    end
    b:SetScript("OnClick", function() dialog:SetRush(i - 1) end)
    dialog.rush[i] = b
  end
  function dialog:SetRush(pr)
    self.pr = (pr and pr > 0) and pr or nil
    markSelected(self.rush, (self.pr or 0) + 1)
    self:UpdateSummary()
  end

  -- Valores internos de la propina (los botones antiguos y "otra cantidad", ocultos: el
  -- botón de propina de arriba es el que se usa).
  local hidden = CreateFrame("Frame", nil, dialog)
  hidden:Hide()
  dialog.tips = {}
  for i, tip in ipairs(TIPS) do
    local b = W.Button(hidden, tip.label, 70, 22)
    if i == 1 then
      b:SetPoint("TOPLEFT", 24, -246)
    else
      b:SetPoint("LEFT", dialog.tips[i - 1], "RIGHT", 4, 0)
    end
    b:SetScript("OnClick", function() dialog:SetTip(tip.copper) end)
    dialog.tips[i] = b
  end
  -- Propina a la vista, junto a la cantidad: «Propina [  ] oro [  ] plata».
  local otherLabel = W.Text(dialog, "GameFontNormalSmall")
  otherLabel:SetPoint("TOPLEFT", 24, -124)
  otherLabel:SetText("Propina")
  -- - y + suman o restan 10 de plata; también se puede escribir la cantidad.
  dialog.tipMinus = W.Button(dialog, "-", 24, 22, function()
    dialog:SetTip(math.max(0, dialog:Tip() - 1000))
  end)
  dialog.tipMinus:SetPoint("LEFT", otherLabel, "RIGHT", 14, 0)
  dialog.gold = W.Input(dialog, 40, true)
  dialog.gold:SetPoint("LEFT", dialog.tipMinus, "RIGHT", 8, 0)
  dialog.gold:SetMaxLetters(4)
  local goldLabel = W.Text(dialog, "GameFontHighlightSmall")
  goldLabel:SetPoint("LEFT", dialog.gold, "RIGHT", 3, 0)
  goldLabel:SetText("oro")
  dialog.silver = W.Input(dialog, 26, true)
  dialog.silver:SetPoint("LEFT", goldLabel, "RIGHT", 8, 0)
  dialog.silver:SetMaxLetters(2)
  local silverLabel = W.Text(dialog, "GameFontHighlightSmall")
  silverLabel:SetPoint("LEFT", dialog.silver, "RIGHT", 3, 0)
  silverLabel:SetText("plata")
  dialog.tipPlus = W.Button(dialog, "+", 24, 22, function()
    dialog:SetTip(math.min(99999 * 10000, dialog:Tip() + 1000))
  end)
  dialog.tipPlus:SetPoint("LEFT", silverLabel, "RIGHT", 8, 0)
  -- Nota libre (trueque, precio a convenir, por Discord...).
  local noteLabel = W.Text(dialog, "GameFontNormalSmall")
  noteLabel:SetPoint("TOPLEFT", 24, -152)
  noteLabel:SetText("Nota")
  dialog.note = W.Input(dialog, 316)
  dialog.note:SetPoint("LEFT", noteLabel, "RIGHT", 14, 0)
  dialog.note:SetMaxLetters(ns.NOTE_MAX)
  W.Placeholder(dialog.note, "opcional: trueque, precio a convenir, por Discord...")
  ns.UI.Tip(dialog.note, "Nota", "Por ejemplo: «hago trueque», «precio a convenir», «escríbeme por Discord», «mándamelo por correo»... Lo verán todos en el Mercado y en el anuncio.")
  local tipNote = W.Text(dialog, "GameFontHighlightSmall")
  tipNote:SetPoint("LEFT", dialog.tipPlus, "RIGHT", 8, 0)
  tipNote:SetTextColor(0.6, 0.6, 0.6)
  tipNote:SetText("(de 10 en 10 plata)")
  for _, box in ipairs({ dialog.gold, dialog.silver }) do
    box:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Propina")
      GameTooltip:AddLine("Lo que quieras pagar a quien lo haga: un precio justo, ni de más ni regalado. "
        .. "Se cobra con el correo (contra reembolso). Vacío: sin propina.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    box:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end
  local codNote = W.Text(hidden, "GameFontHighlightSmall")
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
    self.tipButton:SetText(copper > 0 and ("Propina: " .. TIPS[selected or 1].label) or "Sin propina")
    self:UpdateSummary()
  end
  dialog.gold:HookScript("OnTextChanged", function() if not dialog.settingTip then dialog:MarkTip() end end)
  dialog.silver:HookScript("OnTextChanged", function() if not dialog.settingTip then dialog:MarkTip() end end)

  -- Botones
  dialog.info = W.Text(dialog, "GameFontHighlightSmall")
  dialog.info:SetPoint("BOTTOMLEFT", 24, 24)
  dialog.info:SetTextColor(0.7, 0.7, 0.7)
  local publish = W.Button(dialog, "Pedir", 96, 22, function() dialog:Publish() end)
  publish:SetPoint("BOTTOMRIGHT", -22, 18)
  local cancel = W.Button(dialog, "Cancelar", 86, 22, function() dialog:Hide() end)
  cancel:SetPoint("RIGHT", publish, "LEFT", -6, 0)

  function dialog:Publish()
    if not self.key then return end
    local q = tonumber(self.qty:GetText()) or 1
    if self.guild:IsShown() and self.guild:GetChecked() then
      local kind, id = ns.ParseKey(self.key)
      local ok, err = ns.Social.AddNeed(kind == "i" and id or nil, q, ns.Now())
      if not ok then
        ns.Print(err)
        return
      end
      self:Hide()
      ns.Print("pedido de la hermandad publicado: %dx %s. Todos pueden aportar.", q, ns.KeyLabel(self.key))
      ns.UI.Open("board")
      return
    end
    local copper = self:Tip()
    local r = ns.Sync.CreateRequest({
      k = self.key, pk = self.pk, q = q, m = self.mats:GetChecked() and true or false,
      g = copper > 0 and copper or nil, pr = self.pr, nt = ns.CleanNote(self.note:GetText()),
    })
    if r then
      self:Hide()
      -- Que se vea en el Tablón: fuera los filtros de tipo y categoría.
      local board = ns.db.settings.board
      if board then board.show, board.cat = 1, 1 end
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
  dialog.note:SetText("")
  dialog:SetExpanded(false)
  dialog.guild:SetShown(ns.Social.AmOfficer())
  dialog.guild:SetChecked(false)
  local open = Data.CountOpenBy(ns.Me(), ns.Now())
  dialog.info:SetText(string.format("Va a toda la hermandad (%d/%d abiertas).", open, Data.MAX_OPEN))
  dialog:Show()
end
