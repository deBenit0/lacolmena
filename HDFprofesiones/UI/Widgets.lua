-- Piezas de interfaz reutilizables.
local _, ns = ...
local W = {}
ns.W = W

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local listCounter = 0

local BOX = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local PANEL = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

function W.Panel(name, parent, width, height)
  local f = CreateFrame("Frame", name, parent or UIParent, BACKDROP_TEMPLATE)
  f:SetSize(width, height)
  if f.SetBackdrop then f:SetBackdrop(PANEL) end
  f:EnableMouse(true)
  return f
end

function W.Box(parent, width, height)
  local f = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
  f:SetSize(width, height)
  if f.SetBackdrop then
    f:SetBackdrop(BOX)
    f:SetBackdropColor(0, 0, 0, 0.55)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
  end
  return f
end

function W.Text(parent, font, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

function W.Button(parent, text, width, height, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, height or 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function W.Input(parent, width, numeric)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(width, 20)
  e:SetAutoFocus(false)
  if numeric then e:SetNumeric(true) end
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return e
end

-- Texto gris de ayuda dentro de una caja de texto vacía.
function W.Placeholder(edit, text)
  local fs = edit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  fs:SetPoint("LEFT", 2, 0)
  fs:SetText(text)
  local function update() fs:SetShown(edit:GetText() == "" and not edit:HasFocus()) end
  edit:HookScript("OnTextChanged", update)
  edit:HookScript("OnEditFocusGained", update)
  edit:HookScript("OnEditFocusLost", update)
  update()
  return fs
end

function W.Check(parent, text, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c.label = W.Text(c, "GameFontHighlightSmall")
  c.label:SetPoint("LEFT", c, "RIGHT", 2, 1)
  c.label:SetText(text)
  if onClick then c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end) end
  return c
end

-- Muestra el tooltip de una receta/objeto ("i123"/"e456") al pasar el ratón.
function W.KeyTooltip(frame, getKey)
  frame:SetScript("OnEnter", function(self)
    local key = getKey(self)
    local link = key and ns.KeyHyperlink(key)
    if not link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Lista desplazable con filas fijas.
--   opts = { rows, rowHeight, buildRow(row), updateRow(row, item, selected), onSelect(item), keyOf(item) }
function W.List(parent, width, height, opts)
  listCounter = listCounter + 1
  local box = W.Box(parent, width, height)
  box.items = {}
  local keyOf = opts.keyOf or function(item) return item end

  local scroll = CreateFrame("ScrollFrame", "HDFProfList" .. listCounter, box, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -5)
  scroll:SetPoint("BOTTOMRIGHT", -27, 5)
  box.scroll = scroll

  local rows = {}
  for i = 1, opts.rows do
    local row = CreateFrame("Button", nil, box)
    row:SetHeight(opts.rowHeight)
    row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * opts.rowHeight)
    row:SetPoint("RIGHT", box, "RIGHT", -28, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.selectedTex = row:CreateTexture(nil, "BACKGROUND")
    row.selectedTex:SetAllPoints()
    row.selectedTex:SetColorTexture(1, 0.82, 0, 0.18)
    row.selectedTex:Hide()
    opts.buildRow(row)
    row:SetScript("OnClick", function(self)
      if not self.item then return end
      box.selectedKey = keyOf(self.item)
      box:Refresh()
      if opts.onSelect then opts.onSelect(self.item) end
    end)
    rows[i] = row
  end
  box.rows = rows

  function box:Refresh()
    local items = self.items
    FauxScrollFrame_Update(scroll, #items, opts.rows, opts.rowHeight)
    local offset = FauxScrollFrame_GetOffset(scroll)
    for i, row in ipairs(rows) do
      local item = items[offset + i]
      row.item = item
      if item then
        local selected = self.selectedKey ~= nil and keyOf(item) == self.selectedKey
        row.selectedTex:SetShown(selected)
        opts.updateRow(row, item, selected)
        row:Show()
      else
        row:Hide()
      end
    end
  end

  function box:SetItems(items)
    self.items = items or {}
    self:Refresh()
  end

  function box:Selected()
    if self.selectedKey == nil then return nil end
    for _, item in ipairs(self.items) do
      if keyOf(item) == self.selectedKey then return item end
    end
  end

  function box:Select(key)
    self.selectedKey = key
    -- desplazar hasta el elemento elegido
    for i, item in ipairs(self.items) do
      if keyOf(item) == key then
        local offset = FauxScrollFrame_GetOffset(scroll)
        if i <= offset or i > offset + opts.rows then
          local newOffset = math.max(0, math.min(i - 1, #self.items - opts.rows))
          FauxScrollFrame_SetOffset(scroll, newOffset)
          local bar = scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"]
          if bar then bar:SetValue(newOffset * opts.rowHeight) end
        end
        break
      end
    end
    self:Refresh()
  end

  scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, opts.rowHeight, function() box:Refresh() end)
  end)
  return box
end

-- Ventanas de confirmación y de cantidad (usan las ventanas emergentes del juego).
local function popupEditBox(popup)
  return popup.editBox or popup.EditBox or (popup.GetName and popup:GetName() and _G[popup:GetName() .. "EditBox"])
end

StaticPopupDialogs["HDFPROF_AMOUNT"] = {
  text = "%s",
  button1 = ACCEPT or "Aceptar",
  button2 = CANCEL or "Cancelar",
  hasEditBox = true,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
  OnShow = function(self, data)
    local edit = popupEditBox(self)
    if edit then
      edit:SetNumeric(true)
      edit:SetText(tostring(data and data.default or 1))
      edit:HighlightText()
      edit:SetFocus()
    end
  end,
  OnHide = function(self)
    local edit = popupEditBox(self)
    if edit then edit:SetNumeric(false) end
  end,
  OnAccept = function(self, data)
    local edit = popupEditBox(self)
    local n = edit and tonumber(edit:GetText())
    if n and n > 0 and data and data.callback then data.callback(n) end
  end,
  EditBoxOnEnterPressed = function(self, data)
    local popup = self:GetParent()
    local n = tonumber(self:GetText())
    if n and n > 0 and data and data.callback then data.callback(n) end
    popup:Hide()
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

StaticPopupDialogs["HDFPROF_CONFIRM"] = {
  text = "%s",
  button1 = YES or "Sí",
  button2 = NO or "No",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
  OnAccept = function(self, data)
    if data and data.callback then data.callback() end
  end,
}

-- Según la versión del juego, los datos llegan antes o después de mostrarse: los ponemos siempre.
function W.AskAmount(text, default, callback)
  local data = { default = default, callback = callback }
  local popup = StaticPopup_Show("HDFPROF_AMOUNT", text, nil, data)
  if popup then
    popup.data = data
    local edit = popupEditBox(popup)
    if edit then
      edit:SetText(tostring(default or 1))
      edit:HighlightText()
    end
  end
end

function W.Confirm(text, callback)
  local data = { callback = callback }
  local popup = StaticPopup_Show("HDFPROF_CONFIRM", text, nil, data)
  if popup then popup.data = data end
end

-- Ventana pequeña con varios botones para elegir una opción (cuándo lo harás, por ejemplo).
local choice
function W.Choose(title, sub, labels, callback)
  if not choice then
    choice = W.Panel("HDFProfChoice", UIParent, 430, 118)
    choice:SetFrameStrata("DIALOG")
    choice:SetToplevel(true)
    choice:SetPoint("CENTER", 0, 120)
    choice:Hide()
    tinsert(UISpecialFrames, "HDFProfChoice")
    choice.title = W.Text(choice, "GameFontNormal", "CENTER")
    choice.title:SetPoint("TOP", 0, -16)
    choice.title:SetWidth(400)
    choice.sub = W.Text(choice, "GameFontHighlightSmall", "CENTER")
    choice.sub:SetPoint("TOP", choice.title, "BOTTOM", 0, -6)
    choice.sub:SetWidth(400)
    choice.buttons = {}
    for i = 1, 4 do
      local b = W.Button(choice, "", 124, 24)
      b:SetPoint("BOTTOMLEFT", 18 + (i - 1) * 132, 40)
      b:SetScript("OnClick", function()
        local cb = choice.callback
        choice:Hide()
        if cb then cb(i) end
      end)
      choice.buttons[i] = b
    end
    choice.cancel = W.Button(choice, "Cancelar", 96, 22, function() choice:Hide() end)
    choice.cancel:SetPoint("BOTTOM", 0, 12)
  end
  choice.title:SetText(title)
  choice.sub:SetText(sub or "")
  choice.callback = callback
  for i, b in ipairs(choice.buttons) do
    b:SetShown(labels[i] ~= nil)
    if labels[i] then b:SetText(labels[i]) end
  end
  local n = #labels
  local width = n * 132 - 8
  for i, b in ipairs(choice.buttons) do
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", choice, "BOTTOM", -width / 2 + (i - 1) * 132, 40)
  end
  choice:Show()
  return choice
end

-- "Aceptar encargo": elegir cuándo lo tendrás (y ver qué prisa tiene quien lo pide).
function W.AcceptRequest(r)
  local Data = ns.Data
  local info = Data.RequestInfo(r, ns.Now())
  local labels = {}
  for i, w in ipairs(Data.WHEN) do labels[i] = w.label end
  local sub = r.pr and ("|cffff9933" .. Data.WHEN[r.pr].need .. ".|r ") or "Sin prisa. "
  sub = sub .. string.format("Te quedas el pedido entero (%d). Si no lo entregas a tiempo, vuelve al tablón.", info.remaining)
  W.Choose(string.format("¿Cuándo tendrás %dx %s para %s?", info.remaining, ns.KeyLabel(r.k), ns.ShortName(r.a)),
    sub, labels, function(when) ns.Sync.Commit(r.id, when) end)
end

-- "Más tiempo": elegir un plazo más largo (solo una vez).
function W.ExtendRequest(r)
  local Data = ns.Data
  local options = Data.ExtendOptions(r, ns.Now())
  if #options == 0 then
    ns.Print("ya no puedes pedir más tiempo para este pedido.")
    return
  end
  local labels = {}
  for i, w in ipairs(options) do labels[i] = w.label end
  W.Choose(string.format("¿Para cuándo tendrás %s?", ns.KeyLabel(r.k)),
    "Solo puedes pedir más tiempo una vez. A " .. ns.ShortName(r.a) .. " le llegará un aviso.",
    labels, function(i) ns.Sync.Extend(r.id, options[i].id) end)
end
