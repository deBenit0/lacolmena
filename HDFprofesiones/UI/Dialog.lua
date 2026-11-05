-- Ventana "Nueva petición".
local _, ns = ...
local W, Data = ns.W, ns.Data

local dialog

local function itemIdFromText(text)
  return type(text) == "string" and tonumber(text:match("item:(%d+)")) or nil
end

local function setKey(key, pk)
  dialog.key = key
  if dialog.UpdatePrice and dialog:IsShown() then dialog:UpdatePrice() end
  dialog.pk = pk or (key and Data.SingleProfession(key)) or nil
  if key then
    local name, icon, link = ns.KeyInfo(key)
    dialog.iconTex:SetTexture(icon)
    dialog.itemName:SetText(link or name or ns.KeyName(key))
  else
    dialog.iconTex:SetTexture(ns.QUESTION_ICON)
    dialog.itemName:SetText("|cffbbbbbbNingún objeto elegido|r")
  end
end

local function setTarget(name)
  dialog.to = name
  dialog.toText:SetText(name and ns.ShortName(name) or "cualquiera de la hermandad")
  dialog.clearTo:SetShown(name ~= nil)
end

-- Caja de texto que acepta enlaces con mayús+clic.
local function linkInput(parent, width)
  local edit = W.Input(parent, width)
  edit.hdfLink = true
  return edit
end

local function takeCursorItem()
  local kind, id = GetCursorInfo()
  if kind == "item" and id then
    ClearCursor()
    setKey("i" .. id)
  end
end

local function create()
  dialog = W.Panel("HDFProfRequestDialog", UIParent, 400, 366)
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
  title:SetText("Nueva petición")
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
  dialog.itemButton:SetScript("OnReceiveDrag", takeCursorItem)
  dialog.itemButton:SetScript("OnClick", takeCursorItem)
  W.KeyTooltip(dialog.itemButton, function() return dialog.key end)
  dialog.itemName = W.Text(dialog, "GameFontHighlight")
  dialog.itemName:SetPoint("TOPLEFT", dialog.itemButton, "TOPRIGHT", 8, -1)
  dialog.itemName:SetPoint("RIGHT", dialog, "RIGHT", -24, 0)
  dialog.itemName:SetWordWrap(false)
  dialog.itemInput = linkInput(dialog, 290)
  dialog.itemInput:SetPoint("TOPLEFT", dialog.itemButton, "TOPRIGHT", 12, -14)
  dialog.itemInput:SetScript("OnTextChanged", function(self)
    local key = ns.KeyFromLink(self:GetText())
    if key then setKey(key) end
  end)
  W.Placeholder(dialog.itemInput, "Mayús+clic en un objeto, o arrástralo al icono")

  -- Cantidad y materiales
  local qtyLabel = W.Text(dialog, "GameFontNormalSmall")
  qtyLabel:SetPoint("TOPLEFT", 24, -112)
  qtyLabel:SetText("Cantidad")
  dialog.qty = W.Input(dialog, 50, true)
  dialog.qty:SetPoint("LEFT", qtyLabel, "RIGHT", 14, 0)
  dialog.qty:SetMaxLetters(4)

  -- Precio en la subasta y oferta sugerida (un poco menos).
  dialog.priceText = W.Text(dialog, "GameFontHighlightSmall")
  dialog.priceText:SetPoint("LEFT", dialog.qty, "RIGHT", 12, 0)
  dialog.priceText:SetPoint("RIGHT", dialog, "RIGHT", -20, 0)
  dialog.priceText:SetWordWrap(false)
  dialog.qty:HookScript("OnTextChanged", function() dialog:UpdatePrice() end)

  dialog.mats = W.Check(dialog, "Aporto yo los materiales")
  dialog.mats:SetPoint("TOPLEFT", 20, -132)

  -- Más opciones (pago y destinatario), ocultas al principio para que sea más corto.
  local more = CreateFrame("Frame", nil, dialog)
  more:SetAllPoints()
  dialog.more = more
  dialog.moreButton = W.Button(dialog, "Más opciones...", 130, 20)
  dialog.moreButton:SetPoint("TOPLEFT", 24, -164)
  dialog.moreButton:SetScript("OnClick", function() dialog:SetExpanded(not more:IsShown()) end)
  function dialog:SetExpanded(expanded)
    more:SetShown(expanded)
    self:SetHeight(expanded and 366 or 236)
    self.moreButton:SetText(expanded and "Menos opciones" or "Más opciones...")
  end

  -- Pago
  local payLabel = W.Text(more, "GameFontNormalSmall")
  payLabel:SetPoint("TOPLEFT", 24, -194)
  payLabel:SetText("Pago (opcional)")
  dialog.gold = W.Input(more, 56, true)
  dialog.gold:SetPoint("LEFT", payLabel, "RIGHT", 14, 0)
  dialog.gold:SetMaxLetters(6)
  local goldLabel = W.Text(more, "GameFontHighlightSmall")
  goldLabel:SetPoint("LEFT", dialog.gold, "RIGHT", 4, 0)
  goldLabel:SetText("oro")
  dialog.silver = W.Input(more, 30, true)
  dialog.silver:SetPoint("LEFT", goldLabel, "RIGHT", 14, 0)
  dialog.silver:SetMaxLetters(2)
  local silverLabel = W.Text(more, "GameFontHighlightSmall")
  silverLabel:SetPoint("LEFT", dialog.silver, "RIGHT", 4, 0)
  silverLabel:SetText("plata")

  local payItemsLabel = W.Text(more, "GameFontHighlightSmall")
  payItemsLabel:SetPoint("TOPLEFT", 24, -218)
  payItemsLabel:SetText("y/o en objetos (mayús+clic) y cuántos:")
  dialog.payRows = {}
  for i = 1, 2 do
    local link = linkInput(more, 250)
    link:SetPoint("TOPLEFT", 30, -234 - (i - 1) * 24)
    local count = W.Input(more, 40, true)
    count:SetPoint("LEFT", link, "RIGHT", 12, 0)
    count:SetMaxLetters(4)
    dialog.payRows[i] = { link = link, count = count }
  end

  -- Destinatario
  local toLabel = W.Text(more, "GameFontNormalSmall")
  toLabel:SetPoint("TOPLEFT", 24, -294)
  toLabel:SetText("Para:")
  dialog.toText = W.Text(more, "GameFontHighlightSmall")
  dialog.toText:SetPoint("LEFT", toLabel, "RIGHT", 8, 0)
  dialog.clearTo = W.Button(more, "Para todos", 90, 20, function() setTarget(nil) end)
  dialog.clearTo:SetPoint("LEFT", dialog.toText, "RIGHT", 10, 0)

  -- Botones
  dialog.info = W.Text(dialog, "GameFontHighlightSmall")
  dialog.info:SetPoint("BOTTOMLEFT", 24, 24)
  dialog.info:SetTextColor(0.7, 0.7, 0.7)
  local publish = W.Button(dialog, "Publicar", 96, 22, function() dialog:Publish() end)
  publish:SetPoint("BOTTOMRIGHT", -22, 18)
  local cancel = W.Button(dialog, "Cancelar", 86, 22, function() dialog:Hide() end)
  cancel:SetPoint("RIGHT", publish, "LEFT", -6, 0)

  -- Pone la oferta sugerida en el pago, salvo que el jugador lo haya cambiado a mano.
  local function payTouched(self, userInput)
    if userInput then dialog.payTouched = true end
  end
  dialog.gold:HookScript("OnTextChanged", payTouched)
  dialog.silver:HookScript("OnTextChanged", payTouched)

  function dialog:UpdatePrice()
    local kind, id = ns.ParseKey(self.key)
    if kind ~= "i" then
      self.priceText:SetText("")
      return
    end
    local q = math.max(1, tonumber(self.qty:GetText()) or 1)
    local offer, unit = ns.Prices.Suggest(id, q)
    if not unit then
      self.priceText:SetText("|cff999999Sin precio de subasta|r")
      return
    end
    self.priceText:SetText(string.format("Subasta: %s c/u. Ofreces %s", ns.FormatMoney(unit), ns.FormatMoney(offer or 0)))
    if not self.payTouched and offer then
      self.gold:SetText(tostring(math.floor(offer / 10000)))
      local silver = math.floor(offer / 100) % 100
      self.silver:SetText(silver > 0 and tostring(silver) or "")
    end
  end

  function dialog:Publish()
    if not self.key then
      ns.Print("elige primero qué necesitas (mayús+clic en un objeto).")
      return
    end
    local q = tonumber(self.qty:GetText()) or 1
    local copper = (tonumber(self.gold:GetText()) or 0) * 10000 + (tonumber(self.silver:GetText()) or 0) * 100
    local payItems, any = {}, false
    for _, row in ipairs(self.payRows) do
      local id = itemIdFromText(row.link:GetText())
      if id then
        payItems[id] = (payItems[id] or 0) + math.max(1, tonumber(row.count:GetText()) or 1)
        any = true
      end
    end
    local r = ns.Sync.CreateRequest({
      k = self.key, pk = self.pk, q = q, m = self.mats:GetChecked() and true or false,
      g = copper > 0 and copper or nil, pi = any and payItems or nil, to = self.to,
    })
    if r then
      self:Hide()
      ns.UI.Open("requests", r.id)
    end
  end
end

-- opts = { k = receta, pk = profesión, q = cantidad, to = fabricante }
function ns.UI.OpenRequestDialog(opts)
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  if not dialog then create() end
  opts = opts or {}
  dialog.itemInput:SetText("")
  setKey(opts.k, opts.pk)
  setTarget(opts.to)
  dialog.qty:SetText(tostring(opts.q or 1))
  dialog:SetExpanded(opts.to ~= nil)
  dialog.payTouched = false
  dialog.mats:SetChecked(true)
  dialog.gold:SetText("")
  dialog.silver:SetText("")
  for _, row in ipairs(dialog.payRows) do
    row.link:SetText("")
    row.count:SetText("")
  end
  local open = Data.CountOpenBy(ns.Me(), ns.Now())
  dialog.info:SetText(string.format("Tienes %d de %d peticiones abiertas.", open, Data.MAX_OPEN))
  dialog:Show()
  dialog:UpdatePrice()
  local kind, id = ns.ParseKey(opts.k)
  if kind == "i" then ns.Prices.Query(id) end -- si la subasta está abierta, precio al momento
  if not opts.k then dialog.itemInput:SetFocus() end
end

-- Mayús+clic en un objeto mientras escribes en una de nuestras cajas: pegar el enlace ahí.
if ChatEdit_InsertLink then
  hooksecurefunc("ChatEdit_InsertLink", function(link)
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus and focus.hdfLink and type(link) == "string" then
      focus:SetText(link)
    end
  end)
end

ns.Listen("PRICES_CHANGED", function()
  if dialog and dialog:IsShown() then dialog:UpdatePrice() end
end)
