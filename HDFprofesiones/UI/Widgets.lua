-- Piezas de interfaz reutilizables.
local _, ns = ...
local W = {}
ns.W = W

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local listCounter = 0

-- Estilo «Armory»: fondo casi negro, tarjetas oscuras y bordes finos dorados.
local WHITE = "Interface\\Buttons\\WHITE8X8"
W.WHITE = WHITE
W.COLORS = {
  BG = { 0.047, 0.043, 0.039 },        -- fondo de la ventana
  BOX = { 0.063, 0.059, 0.055 },       -- fondo de los recuadros
  CARD = { 0.094, 0.086, 0.078 },      -- tarjetas y botones
  CARD_SEL = { 0.173, 0.141, 0.071 },  -- tarjeta elegida
  ON = { 0.275, 0.204, 0.047 },        -- botón encendido
  GOLD = { 1, 0.82, 0 },               -- borde vivo y letras doradas
  HEAD = { 0.9, 0.706, 0.275 },        -- títulos de sección
  LINE = { 0.588, 0.431, 0.157 },      -- bordes finos
  EDGE = { 0.3, 0.24, 0.13 },          -- borde apagado de las tarjetas
  DIM = { 0.6, 0.6, 0.6 },             -- texto gris
}
local C = W.COLORS

-- Mayúsculas también para las letras con tilde (string.upper solo cambia las de siempre).
local UPPER = {
  ["\195\161"] = "\195\129", ["\195\169"] = "\195\137", ["\195\173"] = "\195\141", ["\195\179"] = "\195\147",
  ["\195\186"] = "\195\154", ["\195\177"] = "\195\145", ["\195\188"] = "\195\156",
}
function W.Upper(s)
  return (tostring(s or ""):upper():gsub("\195[\161\169\173\179\186\177\188]", UPPER))
end

-- Borde de 1 px hecho con cuatro texturas. l, t, r, b: cuánto se mete hacia dentro cada lado.
function W.Border(f, color, layer, l, t, r, b)
  l, t, r, b = l or 0, t or 0, r or 0, b or 0
  local border = {}
  local function line()
    local tex = f:CreateTexture(nil, layer or "BORDER")
    tex:SetColorTexture(1, 1, 1, 1)
    return tex
  end
  border.top = line()
  border.top:SetPoint("TOPLEFT", l, -t)
  border.top:SetPoint("TOPRIGHT", -r, -t)
  border.top:SetHeight(1)
  border.bottom = line()
  border.bottom:SetPoint("BOTTOMLEFT", l, b)
  border.bottom:SetPoint("BOTTOMRIGHT", -r, b)
  border.bottom:SetHeight(1)
  border.left = line()
  border.left:SetPoint("TOPLEFT", l, -t)
  border.left:SetPoint("BOTTOMLEFT", l, b)
  border.left:SetWidth(1)
  border.right = line()
  border.right:SetPoint("TOPRIGHT", -r, -t)
  border.right:SetPoint("BOTTOMRIGHT", -r, b)
  border.right:SetWidth(1)
  border.lines = { border.top, border.bottom, border.left, border.right }
  function border:SetColor(cr, cg, cb, ca)
    for _, tex in ipairs(self.lines) do tex:SetColorTexture(cr, cg, cb, ca or 1) end
  end
  function border:SetShown(v)
    for _, tex in ipairs(self.lines) do tex:SetShown(v) end
  end
  border:SetColor(color[1], color[2], color[3], color[4])
  return border
end

-- Fondo plano con borde de 1 px (el backdrop de siempre, para que SetBackdropColor siga valiendo).
local BOX = {
  bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
W.BOX_BACKDROP = BOX

-- Esquinas doradas de la ventana (rayitas cortas encima del borde).
local function cornerAccents(f, size)
  size = size or 22
  local function bar(point, x, y, w, h)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 1)
    tex:SetSize(w, h)
    tex:SetPoint(point, x, y)
    return tex
  end
  f.accents = {
    bar("TOPLEFT", -1, 1, size, 2), bar("TOPLEFT", -1, 1, 2, size),
    bar("TOPRIGHT", 1, 1, size, 2), bar("TOPRIGHT", 1, 1, 2, size),
    bar("BOTTOMLEFT", -1, -1, size, 2), bar("BOTTOMLEFT", -1, -1, 2, size),
    bar("BOTTOMRIGHT", 1, -1, size, 2), bar("BOTTOMRIGHT", 1, -1, 2, size),
  }
end
W.CornerAccents = cornerAccents

function W.Panel(name, parent, width, height)
  local f = CreateFrame("Frame", name, parent or UIParent, BACKDROP_TEMPLATE)
  f:SetSize(width, height)
  if f.SetBackdrop then
    f:SetBackdrop(BOX)
    f:SetBackdropColor(C.BG[1], C.BG[2], C.BG[3], 0.98)
    f:SetBackdropBorderColor(C.LINE[1], C.LINE[2], C.LINE[3], 1)
  else
    local solid = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    solid:SetColorTexture(C.BG[1], C.BG[2], C.BG[3], 0.98)
    solid:SetAllPoints()
    f.bgSolid = solid
  end
  cornerAccents(f)
  f:EnableMouse(true)
  return f
end

function W.Box(parent, width, height)
  local f = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
  f:SetSize(width, height)
  if f.SetBackdrop then
    f:SetBackdrop(BOX)
    f:SetBackdropColor(C.BOX[1], C.BOX[2], C.BOX[3], 0.96)
    f:SetBackdropBorderColor(C.LINE[1], C.LINE[2], C.LINE[3], 0.75)
  end
  return f
end

-- Tarjeta: fondo oscuro con borde de 1 px. f:SetSelected(true) la marca con borde dorado.
-- inset: hueco arriba y abajo (para que las tarjetas de una lista no se toquen).
function W.Card(f, inset)
  inset = inset or 0
  f.cardBg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
  f.cardBg:SetPoint("TOPLEFT", 0, -inset)
  f.cardBg:SetPoint("BOTTOMRIGHT", 0, inset)
  f.cardBorder = W.Border(f, C.EDGE, "BORDER", 0, inset, 0, inset)
  function f:SetSelected(on)
    self.cardSelected = on and true or false
    local bg = on and C.CARD_SEL or C.CARD
    self.cardBg:SetColorTexture(bg[1], bg[2], bg[3], 0.95)
    local e = on and C.GOLD or C.EDGE
    self.cardBorder:SetColor(e[1], e[2], e[3], 1)
  end
  function f:SetCardShown(v)
    self.cardBg:SetShown(v)
    self.cardBorder:SetShown(v)
  end
  f:SetSelected(false)
  return f
end

-- Título de sección: letras doradas en mayúsculas y una raya fina debajo.
-- h:SetText(título, nota) — la nota va al lado, en gris y sin mayúsculas.
function W.Header(parent, text, note)
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(20)
  h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h.text:SetPoint("BOTTOMLEFT", 2, 4)
  h.text:SetJustifyH("LEFT")
  h.text:SetTextColor(C.HEAD[1], C.HEAD[2], C.HEAD[3])
  h.note = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  h.note:SetPoint("BOTTOMLEFT", h.text, "BOTTOMRIGHT", 6, 1)
  h.note:SetPoint("RIGHT", h, "RIGHT", -2, 0)
  h.note:SetJustifyH("LEFT")
  h.note:SetWordWrap(false)
  h.note:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
  h.line = h:CreateTexture(nil, "ARTWORK")
  h.line:SetColorTexture(C.LINE[1], C.LINE[2], C.LINE[3], 0.9)
  h.line:SetPoint("BOTTOMLEFT", 0, 0)
  h.line:SetPoint("BOTTOMRIGHT", 0, 0)
  h.line:SetHeight(1)
  function h:SetText(title, n)
    self.text:SetText(W.Upper(title))
    self.note:SetText(n or "")
  end
  function h:GetText() return self.text:GetText() end
  h:SetText(text or "", note)
  return h
end

-- Barra de progreso dorada con el texto encima ("aportado 3 de 10").
function W.Progress(parent, width, height)
  local p = CreateFrame("Frame", nil, parent)
  p:SetSize(width, height or 16)
  p.bg = p:CreateTexture(nil, "BACKGROUND")
  p.bg:SetAllPoints()
  p.bg:SetColorTexture(C.CARD[1], C.CARD[2], C.CARD[3], 1)
  p.fill = p:CreateTexture(nil, "ARTWORK")
  p.fill:SetPoint("TOPLEFT", 1, -1)
  p.fill:SetPoint("BOTTOMLEFT", 1, 1)
  p.fill:SetColorTexture(0.78, 0.58, 0.12, 1)
  p.border = W.Border(p, C.LINE, "OVERLAY")
  p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  p.text:SetPoint("CENTER", 0, 0)
  function p:SetValue(cur, max, text)
    local frac = (max and max > 0) and math.max(0, math.min(1, (cur or 0) / max)) or 0
    self.fill:SetWidth(math.max(1, (width - 2) * frac))
    self.fill:SetShown(frac > 0)
    self.text:SetText(text or "")
  end
  return p
end

function W.Text(parent, font, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

-- Botones del juego (UIPanelButtonTemplate, rojos). Al pedirlo él, vuelven los de antes; las
-- listas de tarjetas siguen con el estilo nuevo.
function W.Button(parent, text, width, height, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, height or 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", onClick) end
  -- Botón principal (PEDIR, APORTAR...): con la plantilla del juego basta la letra grande.
  function b:SetPrimary(v) end
  -- Letra: "small", "normal" o "large".
  function b:SetFontSize(size)
    if not self.SetNormalFontObject then return end
    if size == "small" then
      self:SetNormalFontObject("GameFontNormalSmall")
      self:SetHighlightFontObject("GameFontHighlightSmall")
      if self.SetDisabledFontObject then self:SetDisabledFontObject("GameFontDisableSmall") end
    elseif size == "large" then
      self:SetNormalFontObject("GameFontNormalLarge")
      self:SetHighlightFontObject("GameFontHighlightLarge")
      if self.SetDisabledFontObject then self:SetDisabledFontObject("GameFontDisableLarge") end
    else
      self:SetNormalFontObject("GameFontNormal")
      self:SetHighlightFontObject("GameFontHighlight")
      if self.SetDisabledFontObject then self:SetDisabledFontObject("GameFontDisable") end
    end
  end
  return b
end

-- Botón de cerrar del juego (la X roja).
function W.CloseButton(parent)
  return CreateFrame("Button", nil, parent, "UIPanelCloseButton")
end

-- Pestaña de arriba: botón del juego; la elegida se queda con el brillo y letras blancas.
function W.Tab(parent, text, width, height, onClick)
  local b = W.Button(parent, text, width, height or 26, onClick)
  function b:SetOn(on)
    if on then self:LockHighlight() else self:UnlockHighlight() end
    if self.SetNormalFontObject then self:SetNormalFontObject(on and "GameFontHighlight" or "GameFontNormal") end
    self.on = on and true or false
  end
  b:SetOn(false)
  return b
end

function W.Input(parent, width, numeric)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(width, 20)
  -- Caja oscura con borde fino (se esconden las piezas de la plantilla del juego).
  for _, key in ipairs({ "Left", "Middle", "Right", "Mid" }) do
    local tex = e[key]
    if type(tex) == "table" and tex.Hide then tex:Hide() end
  end
  e.bg = e:CreateTexture(nil, "BACKGROUND")
  e.bg:SetPoint("TOPLEFT", -5, 0)
  e.bg:SetPoint("BOTTOMRIGHT", 0, 0)
  e.bg:SetColorTexture(C.CARD[1], C.CARD[2], C.CARD[3], 1)
  e.border = W.Border(e, C.LINE, "BORDER", -5, 0, 0, 0)
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
-- Opcional:
--   card = true        cada fila es una tarjeta (W.Card) y la elegida lleva borde dorado
--   bare = true        sin recuadro alrededor (listas dentro de otro recuadro)
--   heightOf(item)     alto de cada fila (p. ej. títulos de sección más bajos que las tarjetas);
--                      se ven las que quepan en el alto de la lista
--   isHeader(item)     filas que no se eligen (títulos de sección): al pulsarlas solo se llama a onSelect
function W.List(parent, width, height, opts)
  listCounter = listCounter + 1
  local box = W.Box(parent, width, height)
  if opts.bare and box.SetBackdrop then box:SetBackdrop(nil) end
  box.items = {}
  local keyOf = opts.keyOf or function(item) return item end
  local pad = opts.bare and 0 or 6

  local scroll = CreateFrame("ScrollFrame", "HDFProfList" .. listCounter, box, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -5)
  scroll:SetPoint("BOTTOMRIGHT", -27, 5)
  box.scroll = scroll

  local rows = {}
  local nFrames = opts.heightOf and (opts.maxRows or opts.rows * 2) or opts.rows
  for i = 1, nFrames do
    local row = CreateFrame("Button", nil, box)
    row:SetHeight(opts.rowHeight)
    row:SetPoint("TOPLEFT", pad, -pad - (i - 1) * opts.rowHeight)
    row:SetPoint("RIGHT", box, "RIGHT", -28, 0)
    if opts.card then
      W.Card(row, 2)
      local hl = row:CreateTexture(nil, "HIGHLIGHT")
      hl:SetPoint("TOPLEFT", 1, -3)
      hl:SetPoint("BOTTOMRIGHT", -1, 3)
      hl:SetColorTexture(1, 0.82, 0, 0.07)
      row.hl = hl
    else
      row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    end
    row.selectedTex = row:CreateTexture(nil, "BACKGROUND")
    row.selectedTex:SetAllPoints()
    row.selectedTex:SetColorTexture(1, 0.82, 0, 0.18)
    row.selectedTex:Hide()
    if opts.card then row.selectedTex:SetAlpha(0) end
    opts.buildRow(row)
    row:SetScript("OnClick", function(self)
      if not self.item then return end
      if opts.isHeader and opts.isHeader(self.item) then
        if opts.onSelect then opts.onSelect(self.item) end
        return
      end
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
    -- Sin barra (cabe todo), las filas llegan hasta el borde.
    local right = scroll:IsShown() and -28 or -(pad + 2)
    local y, room = -pad, (self:GetHeight() or height) - 2 * pad
    local full = false
    for i, row in ipairs(rows) do
      local item = not full and items[offset + i] or nil
      local h = item and opts.heightOf and opts.heightOf(item) or opts.rowHeight
      if item and opts.heightOf and (-y - pad) + h > room + 0.5 then
        item, full = nil, true
      end
      row.item = item
      if item then
        row:SetHeight(h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", pad, y)
        row:SetPoint("RIGHT", box, "RIGHT", right, 0)
        y = y - h
        local header = opts.isHeader and opts.isHeader(item)
        local selected = not header and self.selectedKey ~= nil and keyOf(item) == self.selectedKey
        row.selectedTex:SetShown(selected)
        if opts.card then
          row:SetCardShown(not header)
          row:SetSelected(selected)
          row.hl:SetShown(not header)
        end
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
  if popup.GetEditBox then
    local ok, edit = pcall(popup.GetEditBox, popup)
    if ok and edit then return edit end
  end
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
  sub = sub .. string.format("Te quedas el pedido entero (%d). Si no lo entregas a tiempo, vuelve al Mercado.", info.remaining)
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

---------------------------------------------------------------------------
-- Mayús+clic en un objeto con una de nuestras cajas activa (las marcadas con hdfLink):
-- pega el enlace en ella. El juego actual usa ChatFrameUtil.InsertLink; ChatEdit_InsertLink
-- es solo un alias antiguo al que el juego ya no llama, así que nos enganchamos a los dos.
---------------------------------------------------------------------------
local function onInsertLink(link)
  local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if focus and focus.hdfLink and type(link) == "string" and link:find("item:", 1, true) then
    focus:SetText(link)
  end
end
W.OnInsertLink = onInsertLink
local hookedInsert = false
if ChatFrameUtil and ChatFrameUtil.InsertLink then
  hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink)
  hookedInsert = true
end
if ChatEdit_InsertLink and not (ChatFrameUtil and ChatEdit_InsertLink == ChatFrameUtil.InsertLink and hookedInsert) then
  hooksecurefunc("ChatEdit_InsertLink", onInsertLink)
  hookedInsert = true
end
W.LinkHooked = hookedInsert

-- Nombre con el que se le puede susurrar a alguien de la hermandad. En WoW Forever cada uno
-- guarda su nombre con el reino interno que le da su juego ("Kael-CAMWOWEU4Realm4PvP") y el
-- servidor no encuentra a nadie así (el mismo fallo que tuvo invitar en la 0.28). Vale el nombre
-- tal como lo da la lista de la hermandad y, si es de mi reino o no está en la lista, el corto.
function ns.TellName(name)
  if type(name) ~= "string" or name == "" then return nil end
  local short = ns.ShortName(name)
  -- ¿Hay otro en la hermandad con el mismo nombre corto? Entonces el corto no basta.
  local twins = 0
  for n in pairs(ns.Guild and ns.Guild.roster or {}) do
    if ns.ShortName(n):lower() == short:lower() then twins = twins + 1 end
  end
  if twins > 1 then
    local info = ns.Guild.Find and ns.Guild.Find(name)
    if info and type(info.raw) == "string" and info.raw ~= "" then return info.raw end
    return name
  end
  return short
end

-- Abrir un susurro: la función nueva del juego o la antigua y, si fallan, la caja del chat con
-- "/w Nombre " ya escrito. Devuelve el nombre usado.
function ns.SendTell(name)
  local target = ns.TellName(name)
  if not target then return nil end
  local send = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
  if send and pcall(send, target) then return target, "tell" end
  local text = "/w " .. target .. " "
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if open and pcall(open, text) then return target, "open" end
  local edit = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend())
    or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
  if edit then
    if ChatEdit_ActivateChat then pcall(ChatEdit_ActivateChat, edit) end
    pcall(edit.SetText, edit, text)
    return target, "edit"
  end
  return target, nil
end

---------------------------------------------------------------------------
-- Piezas de la 0.30
---------------------------------------------------------------------------
-- Icono de cada profesión (los del juego).
ns.PROFESSION_ICONS = {
  [171] = "Interface\\Icons\\Trade_Alchemy", [164] = "Interface\\Icons\\Trade_BlackSmithing",
  [333] = "Interface\\Icons\\Trade_Engraving", [202] = "Interface\\Icons\\Trade_Engineering",
  [165] = "Interface\\Icons\\INV_Misc_ArmorKit_17", [197] = "Interface\\Icons\\Trade_Tailoring",
  [185] = "Interface\\Icons\\INV_Misc_Food_15", [129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
  [186] = "Interface\\Icons\\Trade_Mining", [755] = "Interface\\Icons\\INV_Misc_Gem_01",
  [773] = "Interface\\Icons\\INV_Inscription_Tradeskill01", [40] = "Interface\\Icons\\Trade_BrewPoison",
  [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", [182] = "Interface\\Icons\\Spell_Nature_NatureTouchGrow",
}
function ns.ProfessionIcon(pk)
  return ns.PROFESSION_ICONS[pk] or ns.QUESTION_ICON
end

-- Clase de un jugador de la hermandad (de su ficha o de la lista de la hermandad).
function ns.ClassOf(name)
  local g = ns.G()
  local e = g and g.entries[name]
  if e and e.c then return e.c end
  local info = ns.Guild and ns.Guild.Info(name)
  return info and info.class
end

-- Nombre con el color de su clase (y su personaje principal entre paréntesis si es un alt).
function ns.WhoColored(name)
  local text = ns.ColoredName(name, ns.ClassOf(name))
  local main = ns.Social and ns.Social.MainOf(name)
  if main and main ~= name then text = text .. " |cff999999(" .. ns.ShortName(main) .. ")|r" end
  return text
end

-- Quien pide u ofrece algo, con su color y «(alt de Principal)» si es un alt.
function ns.AuthorText(name)
  local text = ns.ColoredName(name, ns.ClassOf(name))
  local main = ns.Social and ns.Social.MainOf(name)
  if main and main ~= name then text = text .. " |cff999999(alt de " .. ns.ShortName(main) .. ")|r" end
  return text
end

-- Botón pequeño de texto (filtros rápidos, interruptores). SetOn lo deja encendido.
function W.Chip(parent, text, width, onClick)
  local b = W.Button(parent, text, width, 22, onClick)
  function b:SetOn(on)
    if on then self:LockHighlight() else self:UnlockHighlight() end
    if self.SetNormalFontObject then self:SetNormalFontObject(on and "GameFontHighlight" or "GameFontNormal") end
    self.on = on and true or false
  end
  return b
end

-- Lista de quién fabrica algo: icono de la profesión, nombre con su color, nivel, si está en
-- línea y un botón para susurrarle. Cada uno en su tarjeta. La usan el Mercado, el catálogo y
-- Hermandad.
--   rows = { { name, class, pk, r (nivel), online, seen, unavailable, gather, extra, karma, level }, ... }
--   rowHeight: alto de cada fila (22 si no se dice); bare: sin recuadro alrededor.
function W.Crafters(parent, width, nrows, rowHeight, bare)
  rowHeight = rowHeight or 22
  -- Con sitio, el estado (en línea, visto hace...) va en su columna; si no, junto al nivel.
  local wide = width >= 380
  local list = W.List(parent, width, nrows * rowHeight + (bare and 0 or 12), {
    rows = nrows,
    rowHeight = rowHeight,
    card = true,
    bare = bare,
    keyOf = function(c) return c.name .. ":" .. tostring(c.pk) end,
    buildRow = function(row)
      local iconSize = math.min(20, rowHeight - 6)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(iconSize, iconSize)
      row.icon:SetPoint("LEFT", 4, 0)
      row.name = W.ListText(row, "GameFontHighlightSmall")
      row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.name:SetWidth(math.floor(width * (wide and 0.24 or 0.28)))
      row.name:SetWordWrap(false)
      row.level = W.ListText(row, "GameFontHighlightSmall")
      row.level:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
      row.level:SetWordWrap(false)
      if wide then
        row.level:SetWidth(math.floor(width * 0.24))
        row.state = W.ListText(row, "GameFontHighlightSmall")
        row.state:SetPoint("LEFT", row.level, "RIGHT", 4, 0)
        row.state:SetPoint("RIGHT", row, "RIGHT", -64, 0)
        row.state:SetWordWrap(false)
      else
        row.level:SetPoint("RIGHT", row, "RIGHT", -62, 0)
      end
      row.tell = W.Button(row, "Susurrar", 56, math.min(20, rowHeight - 6))
      row.tell:SetFontSize("small")
      row.tell:SetPoint("RIGHT", -4, 0)
      row.tell:SetScript("OnClick", function(self) ns.SendTell(self:GetParent().item.name) end)
      row:SetScript("OnEnter", function(self)
        local c = self.item
        if not c then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.ColoredName(c.name, c.class) .. (c.level and (" (nivel " .. c.level .. ")") or ""))
        GameTooltip:AddLine(ns.ProfessionName(c.pk) .. (c.r and (" " .. c.r) or ""), 1, 1, 1)
        if c.karma then GameTooltip:AddLine("Karma: " .. c.karma .. "   Encargos completados: " .. (c.thanks or 0), 0.8, 0.8, 0.8) end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    updateRow = function(row, c)
      row.icon:SetTexture(ns.ProfessionIcon(c.pk))
      local me = c.name == ns.Me()
      row.name:SetText(me and "|cffffd100Tú|r" or ns.ColoredName(c.name, c.class))
      row.level:SetText("|cffbbbbbb" .. ns.ProfessionName(c.pk) .. (c.r and (" " .. c.r) or "") .. "|r")
      local state
      if c.unavailable then
        state = "|cff999999no disponible|r"
      elseif c.online then
        state = "|cff40ff40en línea|r"
      elseif c.seen then
        state = "|cff999999visto hace " .. ns.FormatDuration(ns.Now() - c.seen) .. "|r"
      end
      if c.extra then state = (state and (state .. "  ") or "") .. c.extra end
      if me then state = nil end
      if row.state then
        row.state:SetText(state or "")
      elseif state then
        row.level:SetText(row.level:GetText() .. "  " .. state)
      end
      row.tell:SetShown(not me)
    end,
  })
  return list
end

-- Letra de las listas (Opciones → Otros): pequeña, normal o grande. Los textos de las listas se
-- crean con W.ListText y cambian todos a la vez con W.SetListFont.
W.FONT_SIZES = {
  { id = "small", label = "Pequeña", factor = 0.88 },
  { id = "normal", label = "Normal", factor = 1 },
  { id = "large", label = "Grande", factor = 1.15 },
}
local listTexts = setmetatable({}, { __mode = "k" })

function W.ListFontSize()
  local id = ns.db and ns.db.settings.listFont
  for _, s in ipairs(W.FONT_SIZES) do
    if s.id == id then return s end
  end
  return W.FONT_SIZES[2]
end

local function applyListFont(fs, base)
  local obj = _G[base]
  if type(obj) ~= "table" or not obj.GetFont then return end
  local path, size, flags = obj:GetFont()
  if type(path) == "string" and type(size) == "number" then
    fs:SetFont(path, math.floor(size * W.ListFontSize().factor + 0.5), flags or "")
  end
end

function W.ListText(parent, font, justify)
  font = font or "GameFontHighlightSmall"
  local fs = W.Text(parent, font, justify)
  listTexts[fs] = font
  applyListFont(fs, font)
  return fs
end

function W.SetListFont(id)
  if not ns.db then return end
  ns.db.settings.listFont = id
  for fs, base in pairs(listTexts) do applyListFont(fs, base) end
  if ns.UI.Refresh then ns.UI.Refresh() end
end
