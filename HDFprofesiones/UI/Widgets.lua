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

-- Ventana opaca, como las del juego: el fondo de diálogo de Blizzard es medio transparente,
-- así que debajo va un color sólido oscuro (el backdrop solo pone el borde).
local PANEL_EDGE = {
  edgeFile = PANEL.edgeFile, tile = true, tileSize = 32, edgeSize = 32,
  insets = PANEL.insets,
}

function W.Panel(name, parent, width, height)
  local f = CreateFrame("Frame", name, parent or UIParent, BACKDROP_TEMPLATE)
  f:SetSize(width, height)
  local solid = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  solid:SetColorTexture(0.05, 0.045, 0.04, 1)
  solid:SetPoint("TOPLEFT", 11, -12)
  solid:SetPoint("BOTTOMRIGHT", -12, 11)
  local tex = f:CreateTexture(nil, "BACKGROUND", nil, -7)
  tex:SetTexture(PANEL.bgFile, "REPEAT", "REPEAT")
  if tex.SetHorizTile then
    tex:SetHorizTile(true)
    tex:SetVertTile(true)
  end
  tex:SetAllPoints(solid)
  f.bgSolid, f.bgTex = solid, tex
  if f.SetBackdrop then f:SetBackdrop(PANEL_EDGE) end
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

-- Abrir un susurro (función nueva del juego o la antigua).
function ns.SendTell(name)
  if not name then return end
  if ChatFrameUtil and ChatFrameUtil.SendTell then
    ChatFrameUtil.SendTell(name)
  elseif ChatFrame_SendTell then
    ChatFrame_SendTell(name)
  end
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

-- Botón pequeño de texto (filtros rápidos, interruptores). SetOn lo deja encendido.
function W.Chip(parent, text, width, onClick)
  local b = W.Button(parent, text, width, 22, onClick)
  function b:SetOn(on)
    local fs = self:GetFontString()
    if on then
      self:LockHighlight()
      if fs then fs:SetTextColor(1, 1, 1) end
    else
      self:UnlockHighlight()
      if fs then fs:SetTextColor(1, 0.82, 0) end
    end
    self.on = on and true or false
  end
  return b
end

-- Lista de quién fabrica algo: icono de la profesión, nombre con su color, nivel, si está en
-- línea y un botón para susurrarle. La usan el Mercado y Hermandad.
--   rows = { { name, class, pk, r (nivel), online, seen, unavailable, gather }, ... }
function W.Crafters(parent, width, nrows)
  local list = W.List(parent, width, nrows * 22 + 12, {
    rows = nrows,
    rowHeight = 22,
    keyOf = function(c) return c.name .. ":" .. tostring(c.pk) end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(18, 18)
      row.icon:SetPoint("LEFT", 2, 0)
      row.name = W.ListText(row, "GameFontHighlightSmall")
      row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.name:SetWidth(width * 0.28)
      row.name:SetWordWrap(false)
      row.level = W.ListText(row, "GameFontHighlightSmall")
      row.level:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
      row.level:SetPoint("RIGHT", row, "RIGHT", -62, 0)
      row.level:SetWordWrap(false)
      row.tell = W.Button(row, "Susurrar", 58, 18)
      if row.tell.SetNormalFontObject then
        row.tell:SetNormalFontObject("GameFontNormalSmall")
        row.tell:SetHighlightFontObject("GameFontHighlightSmall")
      end
      row.tell:SetPoint("RIGHT", -2, 0)
      row.tell:SetScript("OnClick", function(self) ns.SendTell(self:GetParent().item.name) end)
    end,
    updateRow = function(row, c)
      row.icon:SetTexture(ns.ProfessionIcon(c.pk))
      local me = c.name == ns.Me()
      row.name:SetText(me and "|cffffd100Tú|r" or ns.ColoredName(c.name, c.class))
      local lv = ns.ProfessionName(c.pk) .. (c.r and (" " .. c.r) or "")
      local state
      if c.unavailable then
        state = "|cff999999no disponible|r"
      elseif c.online then
        state = "|cff40ff40en línea|r"
      elseif c.seen then
        state = "|cff999999visto hace " .. ns.FormatDuration(ns.Now() - c.seen) .. "|r"
      end
      row.level:SetText("|cffbbbbbb" .. lv .. "|r" .. (state and ("  " .. state) or ""))
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
