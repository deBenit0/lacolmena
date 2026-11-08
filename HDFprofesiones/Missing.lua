-- "Pedir en la hermandad": botón en la ventana de profesión que abre una ventana con los
-- materiales que faltan para la receta elegida (bolsas + banco), para elegir qué pedir.
local _, ns = ...
local Data = ns.Data
local Missing = {}
ns.Missing = Missing

local function itemIdFromLink(link)
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- Ventana de profesiones moderna (WoW Forever): el formulario de la receta elegida.
local function modernForm()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  return page and page.SchematicForm, page
end
Missing.ModernForm = modernForm

-- Materiales de la receta elegida: lista de { id, need } o nil si no hay ninguna elegida.
local function selectedReagents()
  local form, page = modernForm()
  if form and ProfessionsFrame:IsShown() and form.GetRecipeInfo and C_TradeSkillUI then
    local info = form:GetRecipeInfo()
    if type(info) ~= "table" or not info.recipeID then return nil end
    local reagents = ns.Scan.ModernReagents(C_TradeSkillUI.GetRecipeSchematic(info.recipeID, false)) or {}
    local list = {}
    for id, n in pairs(reagents) do list[#list + 1] = { id = id, need = n } end
    table.sort(list, function(x, y) return x.id < y.id end)
    local box = page.CreateMultipleInputBox
    local times = box and box.GetValue and tonumber(box:GetValue()) or 1
    return list, math.max(1, times or 1), info.name
  end
  if CraftFrame and CraftFrame:IsShown() and GetCraftSelectionIndex then
    local i = GetCraftSelectionIndex()
    if not i or i == 0 then return nil end
    local list = {}
    for r = 1, (GetCraftNumReagents(i) or 0) do
      local _, _, count = GetCraftReagentInfo(i, r)
      local id = itemIdFromLink(GetCraftReagentItemLink(i, r))
      if id and count then list[#list + 1] = { id = id, need = count } end
    end
    return list, 1, (GetCraftInfo(i))
  end
  if GetTradeSkillSelectionIndex then
    local i = GetTradeSkillSelectionIndex()
    if not i or i == 0 then return nil end
    local list = {}
    for r = 1, (GetTradeSkillNumReagents(i) or 0) do
      local _, _, count = GetTradeSkillReagentInfo(i, r)
      local id = itemIdFromLink(GetTradeSkillReagentItemLink(i, r))
      if id and count then list[#list + 1] = { id = id, need = count } end
    end
    -- cuántas veces quiere fabricarla (la caja de cantidad de la ventana)
    local times = TradeSkillInputBox and tonumber(TradeSkillInputBox:GetText()) or 1
    return list, math.max(1, times or 1), (GetTradeSkillInfo(i))
  end
end

-- Lo que falta para fabricar "times" veces, con qué hacer con cada material:
--   { id, missing, guild = quién lo da en la hermandad (texto) o nil, self = puedo yo,
--     existing = mi petición abierta de ese material, checked = marcado por defecto }
function Missing.Compute(reagents, times)
  local now, me, out = ns.Now(), ns.Me(), {}
  local index = Data.GetIndex()
  for _, re in ipairs(reagents or {}) do
    local missing = re.need * times - ns.Scan.Have(re.id)
    if missing > 0 then
      local key = "i" .. re.id
      local row = { id = re.id, missing = missing }
      -- ¿Quién de la hermandad (que no sea yo) lo fabrica o lo recolecta?
      local profs, crafters = {}, {}
      local rec = index[key]
      for _, cr in ipairs(rec and rec.crafters or {}) do
        if cr.n ~= me then
          crafters[cr.n] = true
          profs[ns.ProfessionName(cr.p)] = true
        end
      end
      local gatherers, skill = Data.GatherersOf(key)
      for _, name in ipairs(gatherers) do
        if name ~= me then
          crafters[name] = true
          profs[ns.ProfessionName(skill)] = true
        end
      end
      local n, names = 0, {}
      for _ in pairs(crafters) do n = n + 1 end
      for name in pairs(profs) do names[#names + 1] = name end
      table.sort(names)
      if n > 0 then row.guild = table.concat(names, ", ") .. " (" .. n .. ")" end
      row.self = Data.ICanCraft(key) or Data.ICanGather(key) or false
      row.existing = Data.MyActiveRequestFor(key, now)
      row.checked = row.guild ~= nil and not row.self
      out[#out + 1] = row
    end
  end
  return out
end

local function noteFor(row, qty)
  if row.existing then
    local info = Data.RequestInfo(row.existing, ns.Now())
    local target = info.delivered + qty
    if target > row.existing.q then
      return string.format("|cffffd100Ya pedido: se amplía a %d|r", target)
    end
    return "|cffbbbbbbYa lo tienes pedido|r"
  end
  if row.self then return "|cff40ff40Puedes conseguirlo tú|r" end
  if row.guild then return "|cff40ff40Lo dan: " .. row.guild .. "|r" end
  return "|cffff8040Nadie de la hermandad lo da (¿vendedor?)|r"
end

-- Crea o amplía las peticiones de las filas marcadas. Devuelve creadas, ampliadas, omitidas.
function Missing.Request(list)
  local now = ns.Now()
  local created, extended, skipped = {}, {}, {}
  for _, m in ipairs(list) do
    local key = "i" .. m.id
    local existing = Data.MyActiveRequestFor(key, now)
    if existing then
      local target = Data.RequestInfo(existing, now).delivered + m.missing
      if target > existing.q and ns.Sync.SetQuantity(existing.id, target) then
        extended[#extended + 1] = { id = m.id, missing = target }
      else
        skipped[#skipped + 1] = m
      end
    else
      local r = ns.Sync.CreateRequest({ k = key, pk = Data.SingleProfession(key), q = m.missing })
      if r then created[#created + 1] = m else skipped[#skipped + 1] = m end
    end
  end
  return created, extended, skipped
end

local function describe(list)
  local parts = {}
  for _, m in ipairs(list) do parts[#parts + 1] = m.missing .. "x " .. ns.KeyName("i" .. m.id) end
  return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- Ventana para elegir qué pedir
---------------------------------------------------------------------------
local MAX_ROWS = 8
local picker

local function createPicker()
  local W = ns.W
  picker = W.Panel("HDFProfMissingDialog", UIParent, 460, 150 + MAX_ROWS * 30)
  picker:SetFrameStrata("DIALOG")
  picker:SetToplevel(true)
  picker:SetPoint("CENTER", 0, 40)
  picker:SetMovable(true)
  picker:SetClampedToScreen(true)
  picker:RegisterForDrag("LeftButton")
  picker:SetScript("OnDragStart", picker.StartMoving)
  picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
  picker:Hide()
  tinsert(UISpecialFrames, "HDFProfMissingDialog")

  local title = W.Text(picker, "GameFontNormal")
  title:SetPoint("TOP", 0, -18)
  title:SetText("Pedir en la hermandad")
  local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  picker.recipe = W.Text(picker, "GameFontHighlight")
  picker.recipe:SetPoint("TOPLEFT", 24, -44)
  picker.recipe:SetPoint("RIGHT", picker, "RIGHT", -24, 0)
  picker.recipe:SetWordWrap(false)

  local timesLabel = W.Text(picker, "GameFontNormalSmall")
  timesLabel:SetPoint("TOPLEFT", 24, -70)
  timesLabel:SetText("Veces a fabricar:")
  picker.minus = W.Button(picker, "-", 24, 20, function() picker:SetTimes(picker.times - 1) end)
  picker.minus:SetPoint("LEFT", timesLabel, "RIGHT", 8, 0)
  picker.timesText = W.Text(picker, "GameFontHighlight", "CENTER")
  picker.timesText:SetWidth(36)
  picker.timesText:SetPoint("LEFT", picker.minus, "RIGHT", 2, 0)
  picker.plus = W.Button(picker, "+", 24, 20, function() picker:SetTimes(picker.times + 1) end)
  picker.plus:SetPoint("LEFT", picker.timesText, "RIGHT", 2, 0)

  picker.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, picker)
    row:SetSize(412, 28)
    row:SetPoint("TOPLEFT", 20, -96 - (i - 1) * 30)
    row.check = W.Check(row, "")
    row.check:SetPoint("LEFT", 0, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
    row.qty = W.Input(row, 40, true)
    row.qty:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
    row.qty:SetMaxLetters(4)
    row.name = W.Text(row, "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row.qty, "TOPRIGHT", 8, 2)
    row.name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.name:SetWordWrap(false)
    row.note = W.Text(row, "GameFontHighlightSmall")
    row.note:SetPoint("BOTTOMLEFT", row.qty, "BOTTOMRIGHT", 8, -3)
    row.note:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.note:SetWordWrap(false)
    row.qty:HookScript("OnTextChanged", function(self)
      if row.data then row.note:SetText(noteFor(row.data, tonumber(self:GetText()) or 0)) end
    end)
    picker.rows[i] = row
  end

  picker.empty = W.Text(picker, "GameFontNormal", "CENTER")
  picker.empty:SetPoint("TOP", 0, -110)
  picker.empty:SetTextColor(0.6, 0.6, 0.6)
  picker.empty:SetText("Ya tienes todos los materiales (contando el banco).")

  local ask = W.Button(picker, "Pedir", 96, 22, function() picker:Submit() end)
  ask:SetPoint("BOTTOMRIGHT", -22, 18)
  picker.askButton = ask
  local cancel = W.Button(picker, "Cancelar", 86, 22, function() picker:Hide() end)
  cancel:SetPoint("RIGHT", ask, "LEFT", -6, 0)

  function picker:SetTimes(n)
    self.times = math.max(1, math.min(200, n))
    self.timesText:SetText(self.times)
    self.list = Missing.Compute(self.reagents, self.times)
    for i, row in ipairs(self.rows) do
      local m = self.list[i]
      row.data = m
      row:SetShown(m ~= nil)
      if m then
        local _, icon = ns.KeyInfo("i" .. m.id)
        row.icon:SetTexture(icon)
        row.name:SetText(ns.KeyName("i" .. m.id))
        row.check:SetChecked(m.checked)
        row.qty:SetText(tostring(m.missing))
        row.note:SetText(noteFor(m, m.missing))
      end
    end
    self.empty:SetShown(#self.list == 0)
    self.askButton:SetEnabled(#self.list > 0)
  end

  function picker:Submit()
    local chosen = {}
    for _, row in ipairs(self.rows) do
      local qty = tonumber(row.qty:GetText()) or 0
      if row.data and row:IsShown() and row.check:GetChecked() and qty > 0 then
        chosen[#chosen + 1] = { id = row.data.id, missing = qty }
      end
    end
    if #chosen == 0 then
      ns.Print("no has marcado ningún material.")
      return
    end
    self:Hide()
    local created, extended, skipped = Missing.Request(chosen)
    if #created > 0 then ns.Print("pedido a la hermandad: %s.", describe(created)) end
    if #extended > 0 then ns.Print("ampliado lo que ya tenías pedido: %s.", describe(extended)) end
    if #skipped > 0 then
      ns.Print("no se ha pedido (ya estaba pedido o tienes %d abiertas): %s.", Data.MAX_OPEN, describe(skipped))
    end
  end
end

function Missing.OnClick()
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  local reagents, times, recipeName = selectedReagents()
  if not reagents then
    ns.Print("elige primero una receta en la ventana de profesión.")
    return
  end
  if not picker then createPicker() end
  picker.reagents = reagents
  picker.recipe:SetText(recipeName or "")
  picker:SetTimes(times)
  picker:Show()
end

-- Botón encima del de "Crear" (o arriba a la derecha si no lo encuentra).
local buttons = {}
local function addButton(frame, createButton)
  if not frame or buttons[frame] then return end
  local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  b:SetSize(160, 22)
  b:SetText("Pedir en la hermandad")
  if createButton then
    b:SetPoint("BOTTOMRIGHT", createButton, "TOPRIGHT", 0, 4)
  else
    b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -40)
  end
  b:SetScript("OnClick", function() ns.SafeCall(Missing.OnClick) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(ns.TITLE)
    GameTooltip:AddLine("Pide a la hermandad los materiales que te faltan para la receta elegida.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  buttons[frame] = b
end

---------------------------------------------------------------------------
-- Botón "Pedir" al pasar el ratón por un material de la receta elegida
---------------------------------------------------------------------------
local hover = {}

local function reagentOfSlot(slot)
  local r = slot:GetID()
  if slot.hdfCraft then
    local i = GetCraftSelectionIndex and GetCraftSelectionIndex()
    if not i or i == 0 then return nil end
    local _, _, count = GetCraftReagentInfo(i, r)
    return itemIdFromLink(GetCraftReagentItemLink(i, r)), count or 1, 1
  end
  local i = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex()
  if not i or i == 0 then return nil end
  local _, _, count = GetTradeSkillReagentInfo(i, r)
  local times = TradeSkillInputBox and tonumber(TradeSkillInputBox:GetText()) or 1
  return itemIdFromLink(GetTradeSkillReagentItemLink(i, r)), count or 1, math.max(1, times or 1)
end

-- Abre la petición de ese material con lo que falta (o 1 si ya lo tienes todo).
function Missing.AskReagent(slot)
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  local id, need, times = reagentOfSlot(slot)
  if not id then return end
  local key = "i" .. id
  local missing = math.max(1, need * times - ns.Scan.Have(id))
  ns.UI.OpenRequestDialog({ k = key, pk = Data.SingleProfession(key), q = missing })
end

local function hoverButton()
  if hover.button then return hover.button end
  local b = CreateFrame("Button", "HDFProfReagentAsk", UIParent, "UIPanelButtonTemplate")
  b:SetSize(56, 18)
  b:SetText("Pedir")
  b:Hide()
  b:SetScript("OnClick", function(self)
    self:Hide()
    if hover.slot then ns.SafeCall(Missing.AskReagent, hover.slot) end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Pedir en la hermandad")
    GameTooltip:AddLine("Pide este material a toda la hermandad.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Se oculta cuando el ratón ya no está ni en el botón ni en el material.
  b:SetScript("OnUpdate", function(self, elapsed)
    local over = self:IsMouseOver() or (hover.slot and hover.slot:IsVisible() and hover.slot:IsMouseOver())
    if over == true then
      self.away = 0
    else
      self.away = (self.away or 0) + (elapsed or 0)
      if self.away > 0.4 then self:Hide() end
    end
  end)
  hover.button = b
  return b
end

local function showHover(slot)
  local b = hoverButton()
  hover.slot = slot
  b:SetParent(slot)
  b:ClearAllPoints()
  b:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
  b:SetFrameStrata(slot:GetFrameStrata() or "HIGH")
  b:SetFrameLevel(slot:GetFrameLevel() + 10)
  b.away = 0
  b:Show()
end

local function hookReagents(prefix, isCraft)
  for i = 1, (MAX_TRADE_SKILL_REAGENTS or 8) do
    local slot = _G[prefix .. i]
    if slot and not slot.hdfHooked then
      slot.hdfHooked = true
      slot.hdfCraft = isCraft
      slot:HookScript("OnEnter", function(self) ns.SafeCall(showHover, self) end)
    end
  end
end

---------------------------------------------------------------------------
-- Botón "Ofrecer" en el objeto que fabrica la receta elegida (al pasar el ratón o pulsarlo)
---------------------------------------------------------------------------
local offer = {}

-- Objeto que fabrica la receta elegida (nil si es un encantamiento u otra cosa).
local function productOf(isCraft)
  if isCraft then
    local i = GetCraftSelectionIndex and GetCraftSelectionIndex()
    if not i or i == 0 or not GetCraftItemLink then return nil end
    return itemIdFromLink(GetCraftItemLink(i))
  end
  local i = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex()
  if not i or i == 0 or not GetTradeSkillItemLink then return nil end
  return itemIdFromLink(GetTradeSkillItemLink(i))
end

function Missing.OfferProduct(isCraft)
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  local id = productOf(isCraft)
  if not id then
    ns.Print("esta receta no fabrica un objeto: no se puede ofrecer.")
    return
  end
  local have = ns.ItemCount(id)
  ns.UI.OpenOfferDialog(id, have > 0 and have or 1)
end

local function offerButton()
  if offer.button then return offer.button end
  local b = CreateFrame("Button", "HDFProfOfferButton", UIParent, "UIPanelButtonTemplate")
  b:SetSize(64, 18)
  b:SetText("Ofrecer")
  b:Hide()
  b:SetScript("OnClick", function(self)
    self:Hide()
    ns.SafeCall(Missing.OfferProduct, offer.isCraft)
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Ofrecer a la hermandad")
    GameTooltip:AddLine("Lo ves en el Tablón como oferta; quien lo quiera te lo pide.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnUpdate", function(self, elapsed)
    local over = self:IsMouseOver() or (offer.icon and offer.icon:IsVisible() and offer.icon:IsMouseOver())
    if over == true then
      self.away = 0
    else
      self.away = (self.away or 0) + (elapsed or 0)
      if self.away > 0.6 then self:Hide() end
    end
  end)
  offer.button = b
  return b
end

local function showOffer(icon, isCraft)
  if not productOf(isCraft) then return end
  local b = offerButton()
  offer.icon, offer.isCraft = icon, isCraft
  b:SetParent(icon)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -2, -2)
  b:SetFrameStrata(icon:GetFrameStrata() or "HIGH")
  b:SetFrameLevel(icon:GetFrameLevel() + 10)
  b.away = 0
  b:Show()
end

local function hookProduct(icon, isCraft)
  if not icon or icon.hdfOffer then return end
  icon.hdfOffer = true
  icon:HookScript("OnEnter", function(self) ns.SafeCall(showOffer, self, isCraft) end)
  icon:HookScript("OnClick", function(self) ns.SafeCall(showOffer, self, isCraft) end)
end

---------------------------------------------------------------------------
-- Ventana de profesiones moderna (WoW Forever)
-- Las casillas de materiales se crean y reciclan sobre la marcha y Blizzard les cambia
-- OnEnter/OnLeave al elegir otra receta, así que no nos enganchamos a ellas: ponemos
-- botones propios junto a cada material y junto al objeto, y los recolocamos cada vez
-- que el formulario monta una receta (Init).
---------------------------------------------------------------------------
local function modernSlotItem(slot)
  local schematic = slot.GetReagentSlotSchematic and slot:GetReagentSlotSchematic()
  local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
  if type(schematic) ~= "table" or (basic and schematic.reagentType ~= basic) then return nil end
  local first = schematic.reagents and schematic.reagents[1]
  return first and first.itemID, schematic.quantityRequired or 1
end

function Missing.AskModernReagent(id, need)
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  local _, page = modernForm()
  local box = page and page.CreateMultipleInputBox
  local times = math.max(1, box and box.GetValue and tonumber(box:GetValue()) or 1)
  local key = "i" .. id
  ns.UI.OpenRequestDialog({ k = key, pk = Data.SingleProfession(key), q = math.max(1, need * times - ns.Scan.Have(id)) })
end

local function smallButton(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 18)
  b:SetText(text)
  local fs = b.GetFontString and b:GetFontString()
  if fs and fs.SetFontObject then fs:SetFontObject("GameFontHighlightSmall") end
  return b
end

function Missing.LayoutModern(form)
  if not form or not form.reagentSlotPool then return end
  -- "Pedir" en cada material básico.
  for slot in form.reagentSlotPool:EnumerateActive() do
    local id, need = modernSlotItem(slot)
    if not slot.hdfAsk then
      slot.hdfAsk = smallButton(slot, "Pedir", 38)
      slot.hdfAsk:SetHeight(14)
    end
    -- Sobre la parte de abajo del icono del material: así no tapa el nombre (a la derecha)
    -- ni la casilla de abajo (en Forever van muy juntas).
    local icon = type(slot.Button) == "table" and slot.Button or slot
    slot.hdfAsk:ClearAllPoints()
    slot.hdfAsk:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
    slot.hdfAsk:SetFrameLevel(icon:GetFrameLevel() + 10)
    slot.hdfAsk:SetShown(id ~= nil)
    slot.hdfAsk:SetScript("OnClick", function() ns.SafeCall(Missing.AskModernReagent, id, need) end)
  end
  -- "Ofrecer" junto al objeto que fabrica la receta.
  if form.OutputIcon then
    if not form.hdfOffer then
      form.hdfOffer = smallButton(form, "Ofrecer", 64)
      form.hdfOffer:SetPoint("TOP", form.OutputIcon, "BOTTOM", 0, -2)
      form.hdfOffer:SetFrameLevel(form.OutputIcon:GetFrameLevel() + 10)
    end
    local info = form.GetRecipeInfo and form:GetRecipeInfo()
    local itemID
    if type(info) == "table" and info.recipeID and C_TradeSkillUI then
      itemID = ns.Scan.ModernOutput(info.recipeID, C_TradeSkillUI.GetRecipeSchematic(info.recipeID, false))
    end
    form.hdfOffer:SetShown(itemID ~= nil and form.OutputIcon:IsShown())
    form.hdfOffer:SetScript("OnClick", function()
      if not ns.G() then return ns.Print("no estás en ninguna hermandad.") end
      local have = ns.ItemCount(itemID)
      ns.UI.OpenOfferDialog(itemID, have > 0 and have or 1)
    end)
  end
end

local function attachModern()
  local form, page = modernForm()
  if not form or form.hdfHooked then return end
  form.hdfHooked = true
  if form.Init then
    hooksecurefunc(form, "Init", function(self) ns.SafeCall(Missing.LayoutModern, self) end)
  end
  -- "Pedir en la hermandad" (varios materiales a la vez), junto a la casilla de cantidad.
  if not buttons[page] then
    local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    b:SetSize(160, 22)
    b:SetText("Pedir en la hermandad")
    -- Blizzard pone "Crear todo" 30 píxeles a la izquierda de la cantidad: vamos encima de
    -- "Crear" para no taparlo.
    if page.CreateButton then
      b:SetPoint("BOTTOMRIGHT", page.CreateButton, "TOPRIGHT", 0, 4)
    elseif page.CreateAllButton then
      b:SetPoint("RIGHT", page.CreateAllButton, "LEFT", -8, 0)
    else
      b:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", 8, 8)
    end
    b:SetScript("OnClick", function() ns.SafeCall(Missing.OnClick) end)
    buttons[page] = b
  end
  ns.SafeCall(Missing.LayoutModern, form)
end
Missing.AttachModern = attachModern

-- Engancha los botones en las ventanas de profesión. La interfaz de Blizzard las crea en
-- el momento de abrirlas por primera vez (se cargan bajo demanda), así que se intenta en
-- varios momentos: al cargarse esa parte de la interfaz, al abrirlas y un instante después.
-- Es seguro repetirlo: lo ya enganchado no se vuelve a enganchar.
local function attachTrade()
  if not TradeSkillFrame then return end
  addButton(TradeSkillFrame, TradeSkillCreateButton)
  hookReagents("TradeSkillReagent", false)
  hookProduct(TradeSkillSkillIcon, false)
end
local function attachCraft()
  if not CraftFrame then return end
  addButton(CraftFrame, CraftCreateButton)
  hookReagents("CraftReagent", true)
  hookProduct(CraftIcon, true)
end
Missing.Attach = function()
  attachTrade()
  attachCraft()
  attachModern()
end

ns.On("ADDON_LOADED", function(name)
  if name == "Blizzard_Professions" then attachModern() end
  if name == "Blizzard_TradeSkillUI" then attachTrade() end
  if name == "Blizzard_CraftUI" then attachCraft() end
end)
ns.On("TRADE_SKILL_SHOW", function()
  attachTrade()
  attachModern()
  ns.After(0.1, attachTrade)
  ns.After(0.1, attachModern)
end)
ns.On("CRAFT_SHOW", function()
  attachCraft()
  ns.After(0.1, attachCraft)
end)
-- Por si esas ventanas ya estaban cargadas antes que el addon (otro addon las cargó antes).
ns.Listen("LOGIN", Missing.Attach)
