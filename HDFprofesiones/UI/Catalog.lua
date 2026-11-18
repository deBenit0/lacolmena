-- Páginas para pedir: "Pedir materiales" (lo que usan tus recetas y da la hermandad,
-- fabricándolo o recolectándolo) y "Pedir equipo" (armas, armaduras, bolsas y encantamientos
-- que fabrica la hermandad). Al estilo de la ventana de profesiones del juego.
local _, ns = ...
local W, Data, Guild = ns.W, ns.Data, ns.Guild

local NON_GEAR = {
  INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true,
  INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true,
}

-- Equipo (armas y armaduras) que pide bastante menos nivel que el tuyo.
local function isLowGear(minLevel, equipLoc, playerLevel)
  if not equipLoc or equipLoc == "" or NON_GEAR[equipLoc] then return false end
  return minLevel and minLevel > 0 and minLevel < playerLevel - 10 or false
end

local function canUse(key, class, level, minLevel) return ns.CanUseItem(key, class, level, minLevel) end

local function qualityColor(quality)
  local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  return (c and c.hex) or "|cffffffff"
end

local function statusText(row, now)
  local parts = {}
  if row.unavailable then
    parts[#parts + 1] = "|cff999999No disponible|r"
  elseif row.online then
    parts[#parts + 1] = "|cff40ff40En línea|r"
  elseif row.seen then
    parts[#parts + 1] = "|cffbbbbbbvisto hace " .. ns.FormatDuration(now - row.seen) .. "|r"
  else
    parts[#parts + 1] = "|cff999999desconectado|r"
  end
  if row.cdRecipe then
    if row.cdLeft then
      parts[#parts + 1] = "|cffff8040cd " .. ns.FormatDuration(row.cdLeft) .. "|r"
    else
      parts[#parts + 1] = "|cff40ff40cd listo|r"
    end
  end
  return table.concat(parts, "  ")
end

-- Fabricantes de una receta, ordenados: disponibles, en línea, vistos hace poco.
local function crafterRows(key, withGatherers)
  local rec = Data.GetIndex()[key]
  local g = ns.G()
  if not g then return {} end
  local now = ns.Now()
  local byName, rows = {}, {}
  local list = {}
  for _, cr in ipairs(rec and rec.crafters or {}) do list[#list + 1] = cr end
  if withGatherers then
    local gatherers, skill = Data.GatherersOf(key)
    for _, name in ipairs(gatherers) do list[#list + 1] = { n = name, p = skill, gather = true } end
  end
  for _, cr in ipairs(list) do
    local e = g.entries[cr.n]
    local row = byName[cr.n]
    if not row then
      local info = Guild.Info(cr.n)
      row = {
        name = cr.n,
        class = (e and e.c) or (info and info.class),
        level = (e and e.l) or (info and info.level),
        unavailable = e and e.u or false,
        online = Guild.IsOnline(cr.n),
        seen = Guild.LastSeen(cr.n),
        thanks = Data.ThanksFor(cr.n),
        karma = Data.KarmaText(cr.n),
        profs = {},
      }
      byName[cr.n] = row
      rows[#rows + 1] = row
    end
    local p = e and e.p and e.p[cr.p]
    row.profs[#row.profs + 1] = { pk = cr.p, r = p and p.r, m = p and p.m }
    if cr.gather then p = nil end
    local cd = p and p.cd and p.cd[key]
    if cd and cd > now then row.cdLeft = cd - now end
    if Data.IsCooldownRecipe(Data.InfoKey(cr.p, key)) then row.cdRecipe = true end
  end
  for _, row in ipairs(rows) do row.status = statusText(row, now) end
  table.sort(rows, function(a, b)
    if a.unavailable ~= b.unavailable then return not a.unavailable end
    if a.online ~= b.online then return a.online end
    if (a.seen or 0) ~= (b.seen or 0) then return (a.seen or 0) > (b.seen or 0) end
    return a.name < b.name
  end)
  return rows
end

-- Materiales de una receta en una profesión: primera variante conocida y cuántas hay.
local function recipeInfo(key, pk)
  local ik = Data.InfoKey(pk, key)
  local info = Data.GetInfo(ik)
  if info and info.v and #info.v > 0 then return info.v[1], #info.v end
  ns.Sync.AskInfo(ik)
end

local MAX_REAGENTS = 8

local function myReagents() return Data.MyReagents() end

local NON_EQUIP = { [""] = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true }

-- Tipos de material (subclases de "Objetos comerciables" en Classic).
local MATERIAL_TYPES = {
  [0] = "Varios", [1] = "Piezas de ingeniería", [2] = "Explosivos", [3] = "Dispositivos",
  [4] = "Joyería", [5] = "Telas", [6] = "Cueros", [7] = "Metales y piedras", [8] = "Carne",
  [9] = "Hierbas", [10] = "Elementales", [11] = "Otros", [12] = "Encantamiento",
}

-- Grupo de material de un objeto ("t:6", "Cueros"...), o nil si no es un material.
local function materialGroup(key)
  local kind, id = ns.ParseKey(key)
  if kind ~= "i" then return nil end
  local _, classID, subclassID = ns.ItemInstant(id)
  if classID == 5 then return "t:r", "Componentes" end
  if classID == 7 then
    subclassID = MATERIAL_TYPES[subclassID] and subclassID or 11
    return "t:" .. subclassID, MATERIAL_TYPES[subclassID]
  end
  return nil
end

-- Tipos de equipo (por la ranura donde se pone), como los tipos de material.
local GEAR_GROUPS = {
  INVTYPE_WEAPON = "Armas", INVTYPE_2HWEAPON = "Armas", INVTYPE_WEAPONMAINHAND = "Armas",
  INVTYPE_WEAPONOFFHAND = "Armas", INVTYPE_RANGED = "Armas a distancia", INVTYPE_RANGEDRIGHT = "Armas a distancia",
  INVTYPE_THROWN = "Armas a distancia", INVTYPE_SHIELD = "Escudos y mano izquierda", INVTYPE_HOLDABLE = "Escudos y mano izquierda",
  INVTYPE_HEAD = "Cabeza", INVTYPE_NECK = "Cuello y anillos", INVTYPE_FINGER = "Cuello y anillos",
  INVTYPE_SHOULDER = "Hombros", INVTYPE_CLOAK = "Espalda", INVTYPE_CHEST = "Pecho", INVTYPE_ROBE = "Pecho",
  INVTYPE_WRIST = "Muñecas", INVTYPE_HAND = "Manos", INVTYPE_WAIST = "Cintura", INVTYPE_LEGS = "Piernas",
  INVTYPE_FEET = "Pies", INVTYPE_TRINKET = "Abalorios", INVTYPE_BAG = "Bolsas", INVTYPE_QUIVER = "Bolsas",
  INVTYPE_AMMO = "Munición", INVTYPE_BODY = "Camisas y tabardos", INVTYPE_TABARD = "Camisas y tabardos",
}

-- Grupo de equipo de un objeto ("g:Pecho", "Pecho"...).
local function gearGroup(key)
  local kind, id = ns.ParseKey(key)
  if kind == "e" then return "g:enchant", "Encantamientos" end
  local equipLoc = ns.ItemInstant(id)
  if equipLoc == nil then equipLoc = select(6, ns.KeyInfo(key)) end
  local label = GEAR_GROUPS[equipLoc or ""] or "Otros"
  return "g:" .. label, label
end

-- ¿Es equipo? (armas, armaduras, bolsas... y los encantamientos, que se ponen al equipo)
local function isEquipment(key)
  local kind, id = ns.ParseKey(key)
  if kind == "e" then return true end
  local equipLoc = ns.ItemInstant(id)
  if equipLoc == nil then equipLoc = select(6, ns.KeyInfo(key)) end
  return equipLoc ~= nil and not NON_EQUIP[equipLoc]
end

-- ¿Es consumible? (pociones, elixires, frascos, comida, vendas...)
local function isConsumable(key)
  local kind, id = ns.ParseKey(key)
  if kind ~= "i" then return false end
  local _, classID = ns.ItemInstant(id)
  return classID == 0
end

-- Categorías como las de la ventana de profesiones del juego: tipo de arma, ranura de la
-- armadura, bolsas, consumibles por tipo, materiales... Devuelve clave, nombre y orden.
local WEAPON_CATS = {
  { 0, "Hachas de una mano" }, { 1, "Hachas de dos manos" }, { 4, "Mazas de una mano" }, { 5, "Mazas de dos manos" },
  { 7, "Espadas de una mano" }, { 8, "Espadas de dos manos" }, { 6, "Armas de asta" }, { 10, "Bastones" },
  { 13, "Armas de puño" }, { 15, "Dagas" }, { 2, "Arcos" }, { 18, "Ballestas" }, { 3, "Armas de fuego" },
  { 16, "Armas arrojadizas" }, { 19, "Varitas" }, { 20, "Cañas de pescar" }, { 14, "Armas (varias)" },
}
local ARMOR_CATS = {
  { "INVTYPE_HEAD", "Cabeza" }, { "INVTYPE_SHOULDER", "Hombros" }, { "INVTYPE_CLOAK", "Capas" },
  { "INVTYPE_CHEST", "Pecho" }, { "INVTYPE_ROBE", "Pecho" }, { "INVTYPE_WRIST", "Muñecas" },
  { "INVTYPE_HAND", "Manos" }, { "INVTYPE_WAIST", "Cintura" }, { "INVTYPE_LEGS", "Piernas" },
  { "INVTYPE_FEET", "Pies" }, { "INVTYPE_NECK", "Cuello" }, { "INVTYPE_FINGER", "Anillos" },
  { "INVTYPE_TRINKET", "Abalorios" }, { "INVTYPE_SHIELD", "Escudos" }, { "INVTYPE_HOLDABLE", "Mano izquierda" },
  { "INVTYPE_BODY", "Camisas" }, { "INVTYPE_TABARD", "Tabardos" },
}
local CONSUMABLE_CATS = {
  [1] = "Pociones", [2] = "Elixires", [3] = "Frascos", [4] = "Pergaminos", [5] = "Comida y bebida",
  [6] = "Mejoras de objeto", [7] = "Vendas",
}
local WEAPON_RANK, ARMOR_RANK = {}, {}
for i, w in ipairs(WEAPON_CATS) do WEAPON_RANK[w[1]] = { rank = i, label = w[2] } end
for i, a in ipairs(ARMOR_CATS) do ARMOR_RANK[a[1]] = { rank = i, label = a[2] } end

local function craftCategory(key)
  local kind, id = ns.ParseKey(key)
  if kind == "e" then return "c:enchant", "Encantamientos", 600 end
  if kind ~= "i" then return "c:other", "Otros", 900 end
  local equipLoc, classID, subclassID = ns.ItemInstant(id)
  if classID == 2 then
    local w = WEAPON_RANK[subclassID] or WEAPON_RANK[14]
    return "c:w:" .. w.label, w.label, 100 + w.rank
  elseif classID == 4 then
    local a = ARMOR_RANK[equipLoc or ""]
    if a then return "c:a:" .. a.label, a.label, 200 + a.rank end
    return "c:a:other", "Armaduras (varias)", 290
  elseif classID == 1 then
    return "c:bags", "Bolsas", 300
  elseif classID == 11 then
    return "c:quiver", "Carcajes y cartucheras", 301
  elseif classID == 6 then
    return "c:ammo", "Munición", 302
  elseif classID == 0 then
    local label = CONSUMABLE_CATS[subclassID]
    if label then return "c:cons:" .. subclassID, label, 400 + subclassID end
    return "c:cons", "Consumibles", 409
  elseif classID == 7 or classID == 5 then
    local groupKey, label = materialGroup(key)
    if not groupKey or label == "Varios" or label == "Otros" then return "c:mats", "Materiales", 520 end
    return "c:" .. groupKey, label, 500 + ((classID == 7 and subclassID) or 19)
  end
  return "c:other", "Otros", 900
end

-- Nombres de los tipos de armadura y de arma (subclases de Classic), para la línea gris.
local ARMOR_NAMES = { [1] = "Tela", [2] = "Cuero", [3] = "Malla", [4] = "Placas", [6] = "Escudo" }
local WEAPON_NAMES = {
  [0] = "Hacha", [1] = "Hacha a dos manos", [2] = "Arco", [3] = "Arma de fuego", [4] = "Maza",
  [5] = "Maza a dos manos", [6] = "Arma de asta", [7] = "Espada", [8] = "Espada a dos manos", [10] = "Bastón",
  [13] = "Arma de puño", [15] = "Daga", [16] = "Arrojadiza", [18] = "Ballesta", [19] = "Varita",
}
local function typeName(key)
  local kind, id = ns.ParseKey(key)
  if kind == "e" then return "Encantamiento" end
  local _, classID, subclassID = ns.ItemInstant(id)
  if classID == 4 then return ARMOR_NAMES[subclassID] end
  if classID == 2 then return WEAPON_NAMES[subclassID] end
end

-- Clases para el filtro de «Pedir equipo» (iconos del juego, en un aro).
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_LABEL = {
  WARRIOR = "Guerrero", PALADIN = "Paladín", HUNTER = "Cazador", ROGUE = "Pícaro", PRIEST = "Sacerdote",
  SHAMAN = "Chamán", MAGE = "Mago", WARLOCK = "Brujo", DRUID = "Druida",
}
local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local TICK_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local STAR_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

local LIST_W, DETAIL_W, BODY_H = 400, 380, 386
local CARD_H, HEAD_H, LIST_ROWS = 44, 24, 8
local MAT_H = 18

-- Materiales de una receta: una fila cada uno (icono, «Barra de cobre x8» y «tienes 12», en verde
-- si llegan y en naranja si no); con más de 4, en dos columnas. Si aún no se saben, se piden a la
-- hermandad. Lo usan el catálogo y el detalle del Mercado.
local function reagentsBlock(parent, width)
  local block = { slots = {} }
  for i = 1, MAX_REAGENTS do
    local slot = CreateFrame("Button", nil, parent)
    slot:SetHeight(MAT_H)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetSize(16, 16)
    slot.icon:SetPoint("LEFT", 0, 0)
    slot.have = W.Text(slot, "GameFontHighlightSmall", "RIGHT")
    slot.have:SetPoint("RIGHT", -2, 0)
    slot.name = W.Text(slot, "GameFontHighlightSmall")
    slot.name:SetPoint("LEFT", slot.icon, "RIGHT", 6, 0)
    slot.name:SetPoint("RIGHT", slot.have, "LEFT", -6, 0)
    slot.name:SetWordWrap(false)
    W.KeyTooltip(slot, function(self) return self.itemID and ("i" .. self.itemID) end)
    slot:Hide()
    block.slots[i] = slot
  end
  block.note = W.Text(parent, "GameFontHighlightSmall")
  block.note:SetJustifyV("TOP")
  block.note:SetTextColor(0.75, 0.75, 0.75)
  block.note:Hide()

  function block:Hide()
    for _, slot in ipairs(self.slots) do slot:Hide() end
    self.note:Hide()
  end

  -- Pone los materiales de la receta (key en la profesión pk) desde (x, y), para «times» veces.
  -- Devuelve la variante (nil si aún no se sabe), cuántas recetas hay y el alto que ocupa.
  function block:Set(key, pk, x, y, times)
    times = times or 1
    local var, variants = recipeInfo(key, pk)
    local ids = {}
    if var then
      for id in pairs(var.r) do ids[#ids + 1] = id end
      table.sort(ids)
    end
    local two = #ids > 4
    local colW = two and math.floor((width - 4) / 2) or width
    local perCol = two and math.ceil(#ids / 2) or #ids
    for i, slot in ipairs(self.slots) do
      local id = ids[i]
      slot.itemID = id
      slot:SetShown(id ~= nil)
      if id then
        local col, line = 0, i - 1
        if two then col, line = math.floor((i - 1) / perCol), (i - 1) % perCol end
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", x + col * (colW + 4), y - line * MAT_H)
        slot:SetWidth(colW)
        local need = var.r[id] * times
        local have = ns.Scan.Have(id)
        local _, icon = ns.KeyInfo("i" .. id)
        slot.icon:SetTexture(icon)
        slot.name:SetText(ns.KeyName("i" .. id) .. " |cffffffffx" .. need .. "|r")
        slot.have:SetText((have >= need and "|cff40ff40" or "|cffff9933") .. "tienes " .. have .. "|r")
      end
    end
    self.note:SetShown(not var)
    if not var then
      self.note:ClearAllPoints()
      self.note:SetPoint("TOPLEFT", x, y)
      self.note:SetWidth(width)
      self.note:SetHeight(MAT_H * 2)
      self.note:SetText("Pidiendo los materiales a la hermandad...")
      return nil, nil, MAT_H * 2
    end
    return var, variants, math.max(1, perCol) * MAT_H
  end
  return block
end

-- Lo que tienes de un objeto: texto corto para la fila ("Bolsas"/"Banco") y la frase del detalle.
local function haveInfo(key)
  local kind, id = ns.ParseKey(key)
  if kind ~= "i" then return 0 end
  local total, bags, bank = ns.Scan.Have(id)
  return total or 0, bags or 0, bank or 0
end

local function buildCatalog(page, mode)
  local materials = mode == "materials"
  local consumables = mode == "consumables" -- como equipo, pero sin clases
  local state = { search = "", prof = nil, key = nil, pk = nil, gatherOnly = {} }
  -- «Pedir equipo» empieza en tu clase (lo que puede llevar). nil = todas.
  if not materials and not consumables then state.class = ns.Dungeons.MyClass() end

  -- Grupos plegados: se recuerda lo que elige el jugador; si no ha elegido, se pliegan
  -- todos salvo Favoritos y (en materiales) las profesiones que dan lo que usan tus recetas.
  local function savedCollapsed()
    ns.db.settings.collapsed = ns.db.settings.collapsed or {}
    ns.db.settings.collapsed[mode] = ns.db.settings.collapsed[mode] or {}
    return ns.db.settings.collapsed[mode]
  end
  local function favorites()
    ns.db.settings.favorites = ns.db.settings.favorites or {}
    return ns.db.settings.favorites
  end

  -- Barra superior: (en equipo) clases; búsqueda, profesión y la casilla de filtro.
  local x = 8
  if not materials and not consumables then
    page.classAll = W.Chip(page, "Todas", 50, function()
      state.class = nil
      page:Refresh()
    end)
    page.classAll:SetPoint("TOPLEFT", 0, -6)
    ns.UI.Tip(page.classAll, "Todas las clases", "Todo el equipo que fabrica la hermandad.")
    page.classButtons = {}
    for i, cls in ipairs(CLASS_ORDER) do
      local b = CreateFrame("Button", nil, page)
      b:SetSize(31, 31)
      b:SetPoint("TOPLEFT", 54 + (i - 1) * 32, -1)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetSize(20, 20)
      b.icon:SetPoint("TOPLEFT", 7, -5)
      b.icon:SetTexture(CLASS_ICONS)
      local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls]
      if coords then b.icon:SetTexCoord(unpack(coords)) end
      if b.CreateMaskTexture then
        local mask = b:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(b.icon)
        b.icon:AddMaskTexture(mask)
      end
      b.ring = b:CreateTexture(nil, "OVERLAY")
      b.ring:SetSize(53, 53)
      b.ring:SetPoint("TOPLEFT")
      b.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
      b.hl = b:CreateTexture(nil, "HIGHLIGHT")
      b.hl:SetSize(24, 24)
      b.hl:SetPoint("TOPLEFT", 5, -3)
      b.hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
      b:SetScript("OnClick", function()
        state.class = cls
        page:Refresh()
      end)
      ns.UI.Tip(b, CLASS_LABEL[cls], "Lo que puede llevar un " .. CLASS_LABEL[cls]:lower()
        .. " (tipo de armadura y armas).")
      b.class = cls
      page.classButtons[i] = b
    end
    x = 54 + #CLASS_ORDER * 32 + 10
  end

  local search = W.Input(page, materials and 160 or 132)
  search:SetPoint("TOPLEFT", x, -8)
  search:SetScript("OnTextChanged", function(self, userInput)
    state.search = self:GetText():lower()
    page:Refresh()
    if userInput and page.onSearch then page.onSearch(self:GetText()) end
  end)
  W.Placeholder(search, "Buscar objeto...")
  page.searchBox = search

  local profButton = W.Button(page, "Profesión: todas", materials and 160 or 124, 22)
  profButton:SetPoint("LEFT", search, "RIGHT", 8, 0)
  -- Menú desplegable con "Todas" y cada profesión publicada en la hermandad.
  local menu = W.Box(page, 180, 30)
  menu:SetPoint("TOPLEFT", profButton, "BOTTOMLEFT", 0, -2)
  menu:SetFrameStrata("DIALOG")
  menu:EnableMouse(true)
  menu:Hide()
  menu.buttons = {}
  local function menuButton(i)
    local b = menu.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, menu)
      b:SetSize(168, 18)
      b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 18)
      b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
      b.text = W.Text(b, "GameFontHighlightSmall")
      b.text:SetPoint("LEFT", 4, 0)
      b:SetScript("OnClick", function(self)
        state.prof = self.pk
        menu:Hide()
        page:Refresh()
      end)
      menu.buttons[i] = b
    end
    return b
  end
  function menu:Open()
    local options = { { pk = nil, label = "Todas" } }
    for _, pk in ipairs(page.profList or {}) do
      options[#options + 1] = { pk = pk, label = ns.ProfessionName(pk) }
    end
    for i, opt in ipairs(options) do
      local b = menuButton(i)
      b.pk = opt.pk
      local mark = (opt.pk == state.prof) and "|cffffd100> |r" or "   "
      b.text:SetText(mark .. opt.label)
      b:Show()
    end
    for i = #options + 1, #self.buttons do self.buttons[i]:Hide() end
    self:SetHeight(12 + #options * 18)
    self:Show()
  end
  page.profMenu = menu
  profButton:SetScript("OnClick", function()
    if menu:IsShown() then menu:Hide() else menu:Open() end
  end)
  page:HookScript("OnHide", function() menu:Hide() end)

  local filterSetting = materials and "onlyMyReagents" or "onlyUsable"
  local lowCheck = W.Check(page, materials and "Solo lo que usan mis recetas" or "Solo lo que puedo usar",
    function(checked)
      ns.db.settings[filterSetting] = checked
      page:Refresh()
    end)
  lowCheck:SetPoint("LEFT", profButton, "RIGHT", 6, 0)
  if consumables then
    ns.UI.Tip(lowCheck, "Solo lo que puedo usar", "Lo que puedes usar a tu nivel.")
  elseif not materials then
    ns.UI.Tip(lowCheck, "Solo lo que puedo usar", "Lo que puede llevar la clase elegida (o la tuya) a tu nivel, "
      .. "sin lo de mucho menos nivel.")
  end

  -- Debajo: esconder lo que nadie de la hermandad tiene publicado (se guarda; apagada al empezar).
  local madeSetting = materials and "onlyMadeMaterials" or (consumables and "onlyMadeConsumables") or "onlyMadeEquipment"
  local madeLabel = materials and "Solo lo que alguien da" or "Solo lo que alguien fabrica"
  local madeCheck = W.Check(page, madeLabel, function(checked)
    ns.db.settings[madeSetting] = checked
    page:Refresh()
  end)
  madeCheck:SetPoint("TOPLEFT", 2, -32)
  ns.UI.Tip(madeCheck, madeLabel, materials
    and "Esconde los materiales que nadie de la hermandad fabrica ni recolecta (o no lo tiene publicado)."
    or "Esconde lo que nadie de la hermandad sabe fabricar (o no lo tiene publicado).")
  page.madeCheck = madeCheck

  -- Lista: títulos de sección (tipo de material o ranura de equipo, plegables) y una tarjeta por
  -- objeto con su icono, el nombre en el color de su calidad y una línea gris debajo.
  local list = W.List(page, LIST_W, BODY_H - 26, {
    rows = LIST_ROWS - 1,
    rowHeight = CARD_H,
    maxRows = 16,
    card = true,
    heightOf = function(line) return line.header and HEAD_H or CARD_H end,
    isHeader = function(line) return line.header == true end,
    keyOf = function(line) return line.header and line.id or line.key end,
    buildRow = function(row)
      row.head = W.Header(row)
      row.head:SetPoint("TOPLEFT", 2, 0)
      row.head:SetPoint("BOTTOMRIGHT", -2, 2)
      row.fold = W.ListText(row.head, "GameFontHighlightSmall", "RIGHT")
      row.fold:SetPoint("BOTTOMRIGHT", -4, 5)
      row.fold:SetTextColor(0.6, 0.6, 0.6)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(32, 32)
      row.icon:SetPoint("LEFT", 6, 0)
      row.title = W.ListText(row, "GameFontHighlight")
      row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
      row.title:SetPoint("RIGHT", row, "RIGHT", -8, 0)
      row.title:SetWordWrap(false)
      row.sub = W.ListText(row, "GameFontHighlightSmall")
      row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -8, 0)
      row.sub:SetWordWrap(false)
      row.sub:SetTextColor(0.6, 0.6, 0.6)
      row.star = row:CreateTexture(nil, "ARTWORK")
      row.star:SetSize(16, 16)
      row.star:SetPoint("RIGHT", -8, 0)
      row.star:SetTexture(STAR_ICON)
      row.have = W.ListText(row, "GameFontHighlightSmall", "RIGHT")
      row.have:SetTextColor(0.25, 1, 0.25)
      row.tick = row:CreateTexture(nil, "ARTWORK")
      row.tick:SetSize(16, 16)
      row.tick:SetTexture(TICK_ICON)
      row.tick:SetPoint("RIGHT", row.have, "LEFT", -2, 0)
      row.parts = { row.icon, row.title, row.sub }
      W.KeyTooltip(row, function(self) return self.item and not self.item.header and self.item.key end)
    end,
    updateRow = function(row, line)
      row.head:SetShown(line.header == true)
      for _, p in ipairs(row.parts) do p:SetShown(not line.header) end
      if line.header then
        row.head:SetText(line.label, "(" .. line.count .. ")")
        row.fold:SetText(line.collapsed and "+" or "-")
        row.star:Hide()
        row.have:Hide()
        row.tick:Hide()
        return
      end
      row.icon:SetTexture(line.icon)
      row.title:SetText(line.label)
      row.sub:SetText(line.sub or "")
      -- A la derecha: favorito y si lo tienes (bolsas o banco).
      local right = -8
      row.star:SetShown(line.fav == true)
      if line.fav then right = right - 20 end
      local total, bags = haveInfo(line.key)
      local has = total > 0
      row.have:SetShown(has)
      row.tick:SetShown(has)
      if has then
        row.have:ClearAllPoints()
        row.have:SetPoint("RIGHT", row, "RIGHT", right, 0)
        row.have:SetText(bags > 0 and "Bolsas" or "Banco")
        right = right - 64
      end
      row.title:SetPoint("RIGHT", row, "RIGHT", right, 0)
      row.sub:SetPoint("RIGHT", row, "RIGHT", right, 0)
    end,
    onSelect = function(line)
      if line.header then
        savedCollapsed()[line.pk] = not line.collapsed
        page:Refresh()
        return
      end
      state.key, state.pk = line.key, line.pk
      page:RefreshDetail(true)
    end,
  })
  list:SetPoint("TOPLEFT", 0, -60)

  -----------------------------------------------------------------------
  -- Detalle del objeto elegido.
  -----------------------------------------------------------------------
  local detail = W.Box(page, DETAIL_W, BODY_H)
  detail:SetPoint("TOPLEFT", page, "TOPLEFT", LIST_W + 8, -34)

  detail.icon = CreateFrame("Button", nil, detail)
  detail.icon:SetSize(40, 40)
  detail.icon:SetPoint("TOPLEFT", 10, -10)
  detail.iconTex = detail.icon:CreateTexture(nil, "ARTWORK")
  detail.iconTex:SetAllPoints()
  W.KeyTooltip(detail.icon, function() return state.key end)

  detail.name = W.Text(detail, "GameFontNormalLarge")
  detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 10, -2)
  detail.name:SetPoint("RIGHT", detail, "RIGHT", -34, 0)
  detail.name:SetWordWrap(false)

  -- Favoritos: lo que pides a menudo sale arriba del todo (la estrella, apagada si no lo es).
  detail.fav = CreateFrame("Button", nil, detail)
  detail.fav:SetSize(20, 20)
  detail.fav:SetPoint("TOPRIGHT", -10, -10)
  detail.fav.tex = detail.fav:CreateTexture(nil, "ARTWORK")
  detail.fav.tex:SetAllPoints()
  detail.fav.tex:SetTexture(STAR_ICON)
  detail.fav:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  detail.fav:SetScript("OnClick", function()
    if not state.key then return end
    local favs = favorites()
    favs[state.key] = not favs[state.key] or nil
    page:Refresh()
  end)
  ns.UI.Tip(detail.fav, "Favorito", "Los favoritos salen arriba del todo de la lista.")

  detail.sub = W.Text(detail, "GameFontHighlightSmall")
  detail.sub:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -5)
  detail.sub:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.sub:SetWordWrap(false)
  detail.sub:SetTextColor(0.75, 0.75, 0.75)

  -- "Tienes N en las bolsas", con el visto bueno.
  detail.haveTick = detail:CreateTexture(nil, "ARTWORK")
  detail.haveTick:SetSize(16, 16)
  detail.haveTick:SetTexture(TICK_ICON)
  detail.haveText = W.Text(detail, "GameFontHighlight")
  detail.haveText:SetPoint("LEFT", detail.haveTick, "RIGHT", 6, 0)
  detail.haveText:SetTextColor(0.25, 1, 0.25)

  detail.craftersLabel = W.Header(detail)
  detail.craftersLabel:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
  local crafters = W.Crafters(detail, DETAIL_W - 16, 3, 26, true)
  detail.crafters = crafters
  detail.noCrafters = W.Text(detail, "GameFontHighlightSmall")
  detail.noCrafters:SetTextColor(0.6, 0.6, 0.6)
  detail.noCrafters:SetText("Nadie lo tiene publicado aún, pero puedes pedirlo.")

  detail.matsLabel = W.Header(detail)
  detail.matsLabel:SetPoint("RIGHT", detail, "RIGHT", -8, 0)

  -- Materiales: una fila cada uno ("Barra de cobre x8 ... tienes 12"); con más de 4, en dos columnas.
  local reagents = reagentsBlock(detail, DETAIL_W - 24)
  detail.reagents, detail.slots, detail.matsNote = reagents, reagents.slots, reagents.note

  -- Cantidad con - y +, como el "Crear" de la ventana de profesiones.
  detail.qtyLabel = W.Text(detail, "GameFontNormalSmall")
  detail.qtyLabel:SetPoint("BOTTOMLEFT", 12, 50)
  detail.qtyLabel:SetText("Cantidad:")
  detail.minus = W.Button(detail, "-", 24, 20)
  detail.minus:SetPoint("LEFT", detail.qtyLabel, "RIGHT", 8, 0)
  detail.qty = W.Input(detail, 44, true)
  detail.qty:SetPoint("LEFT", detail.minus, "RIGHT", 10, 0)
  detail.qty:SetMaxLetters(4)
  detail.plus = W.Button(detail, "+", 24, 20)
  detail.plus:SetPoint("LEFT", detail.qty, "RIGHT", 4, 0)
  detail.made = W.Text(detail, "GameFontHighlightSmall")
  detail.made:SetPoint("LEFT", detail.plus, "RIGHT", 8, 0)
  detail.made:SetTextColor(0.75, 0.75, 0.75)

  local function quantity()
    return math.max(1, math.min(Data.MAX_QTY, tonumber(detail.qty:GetText()) or 1))
  end
  local function setQuantity(n)
    detail.qty:SetText(tostring(math.max(1, math.min(Data.MAX_QTY, n))))
  end
  detail.minus:SetScript("OnClick", function() setQuantity(quantity() - (state.step or 1)) end)
  detail.plus:SetScript("OnClick", function() setQuantity(quantity() + (state.step or 1)) end)

  local function requestOptions()
    return { k = state.key, pk = state.pk or Data.SingleProfession(state.key), q = quantity() }
  end

  -- El pedido va siempre a toda la hermandad (se lo queda el primero que lo acepte).
  detail.askAll = W.Button(detail, "PEDIR", DETAIL_W - 16, 30, function()
    if state.key then ns.UI.OpenRequestDialog(requestOptions()) end
  end)
  detail.askAll:SetPoint("BOTTOMLEFT", 8, 8)
  detail.askAll:SetFontSize("large")
  detail.askAll:SetPrimary(true)
  ns.UI.Tip(detail.askAll, "Pedir a la hermandad", "Lo ve toda la hermandad y se lo queda el primero que lo acepte.")

  detail.empty = W.Text(detail, "GameFontNormal", "CENTER")
  detail.empty:SetTextColor(0.6, 0.6, 0.6)
  detail.empty:SetPoint("CENTER")
  detail.empty:SetWidth(DETAIL_W - 50)

  -- Referencias para depurar y para las pruebas.
  page.state, page.list, page.detail, page.search, page.profButton = state, list, detail, search, profButton

  function page:RefreshButtons()
    detail.askAll:SetEnabled(state.key ~= nil)
  end

  -- Coloca una pieza del detalle a la altura y (de arriba abajo).
  local function place(region, y, left)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", left or 8, y)
    if region == detail.craftersLabel or region == detail.matsLabel or region == detail.matsNote then
      region:SetPoint("RIGHT", detail, "RIGHT", region == detail.matsNote and -12 or -8, 0)
    end
  end

  -- Materiales de la receta, desde la altura y. Devuelve cuántos salen por vez.
  local function showMaterials(key, pk, y)
    local var, variants = reagents:Set(key, pk, 12, y)
    detail.matsLabel:SetText("Materiales", variants and variants > 1
      and string.format("(hay %d recetas; se muestra una)", variants) or nil)
    if not var then
      place(detail.matsNote, y, 12)
      detail.matsNote:SetHeight(MAT_H * 2)
    end
    local made = var and var.m or 1
    state.step = made
    detail.made:SetText(made > 1 and string.format("(salen %d por vez)", made) or "")
    return made
  end

  function page:RefreshDetail(newSelection)
    local key = state.key
    local rec = key and Data.GetIndex()[key]
    local hasKey = key ~= nil and (rec ~= nil or state.gatherOnly[key] ~= nil)
    local regions = {
      detail.fav,
      detail.icon, detail.name, detail.sub, detail.matsLabel, detail.craftersLabel, crafters,
      detail.qtyLabel, detail.minus, detail.qty, detail.plus, detail.made, detail.askAll,
    }
    for _, region in ipairs(regions) do region:SetShown(hasKey) end
    detail.haveTick:Hide()
    detail.haveText:Hide()
    detail.noCrafters:Hide()
    detail.empty:SetShown(not hasKey)
    if not hasKey then
      for _, slot in ipairs(detail.slots) do slot:Hide() end
      detail.matsNote:Hide()
      if #list.items > 0 then
        detail.empty:SetText("Elige un objeto de la lista.")
      elseif materials and ns.db.settings.onlyMyReagents then
        detail.empty:SetText("No hay materiales de tus recetas que dé la hermandad. Abre tus profesiones "
          .. "para que el addon sepa qué usas, o desmarca \"Solo lo que usan mis recetas\".")
      elseif ns.db.settings[madeSetting] then
        detail.empty:SetText("Nadie de la hermandad tiene publicado nada de esto. Desmarca \"" .. madeLabel
          .. "\" para verlo todo.")
      else
        detail.empty:SetText("Aún no hay nada. Cada miembro debe abrir la ventana de sus profesiones una vez.")
      end
      return
    end
    local profs = rec and rec.profs or {}
    local pk = (state.pk and profs[state.pk]) and state.pk or Data.SingleProfession(key) or next(profs)
    local name, icon, _, quality, minLevel, equipLoc = ns.KeyInfo(key)
    detail.iconTex:SetTexture(icon)
    detail.name:SetText(qualityColor(quality) .. (name or ns.KeyName(key)) .. "|r")
    local isFav = favorites()[key] and true or false
    detail.fav.tex:SetDesaturated(not isFav)
    detail.fav.tex:SetAlpha(isFav and 1 or 0.45)

    -- Línea gris: ranura o tipo · armadura/arma · nivel · para ti · profesiones.
    local subParts = {}
    if materials then
      local _, groupLabel = materialGroup(key)
      subParts[#subParts + 1] = groupLabel
    else
      local _, slotLabel = gearGroup(key)
      if slotLabel ~= "Otros" and slotLabel ~= "Encantamientos" then subParts[#subParts + 1] = slotLabel end
      subParts[#subParts + 1] = typeName(key)
      if minLevel and minLevel > 1 then subParts[#subParts + 1] = "requiere nivel " .. minLevel end
      local playerLevel = UnitLevel("player") or 60
      if canUse(key, ns.Dungeons.MyClass(), playerLevel, minLevel) and not isLowGear(minLevel, equipLoc, playerLevel) then
        subParts[#subParts + 1] = "|cff40ff40para ti|r"
      end
    end
    local profNames = {}
    for p in pairs(profs) do profNames[#profNames + 1] = ns.ProfessionName(p) end
    local gatherers, skill = Data.GatherersOf(key)
    if materials and skill and #gatherers > 0 then profNames[#profNames + 1] = ns.ProfessionName(skill) end
    table.sort(profNames)
    if #profNames > 0 then subParts[#subParts + 1] = table.concat(profNames, ", ") end
    detail.sub:SetText(table.concat(subParts, " · "))

    -- Lo que tienes.
    local y = -60
    local total, bags, bank = haveInfo(key)
    if total > 0 then
      detail.haveTick:ClearAllPoints()
      detail.haveTick:SetPoint("TOPLEFT", 12, y)
      local where
      if bank == 0 then
        where = "en las bolsas"
      elseif bags == 0 then
        where = "en el banco"
      else
        where = string.format("(%d en las bolsas y %d en el banco)", bags, bank)
      end
      detail.haveText:SetText(string.format("Tienes %d %s", total, where))
      detail.haveTick:Show()
      detail.haveText:Show()
      y = y - 24
    end

    -- Quién lo fabrica (o lo da), en línea primero.
    local rows = ns.UI.CrafterRows(key, materials)
    place(detail.craftersLabel, y)
    detail.craftersLabel:SetText(materials and "Quién lo da" or "Quién lo fabrica", "(" .. #rows .. ")")
    y = y - 24
    if #rows > 0 then
      local shown = math.min(3, #rows)
      crafters:SetHeight(shown * 26)
      place(crafters, y)
      crafters:SetItems(rows)
      y = y - shown * 26 - 8
    else
      crafters:Hide()
      place(detail.noCrafters, y - 2, 12)
      detail.noCrafters:Show()
      y = y - 22
    end

    -- Materiales (equipo) o en qué recetas tuyas se usa (materiales).
    place(detail.matsLabel, y)
    y = y - 26
    local _, itemID = ns.ParseKey(key)
    local made = 1
    if materials then
      for _, slot in ipairs(detail.slots) do slot:Hide() end
      detail.matsLabel:SetText("Lo usas en")
      local uses, names = myReagents()[itemID or 0], {}
      for k in pairs(uses or {}) do names[#names + 1] = ns.KeyName(k) end
      table.sort(names)
      place(detail.matsNote, y, 12)
      detail.matsNote:SetHeight(math.max(MAT_H, (BODY_H - 76) + y))
      detail.matsNote:SetText(#names > 0 and table.concat(names, "\n") or "Ninguna receta tuya conocida.")
      detail.matsNote:Show()
      state.step = 1
      detail.made:SetText("")
      if pk then
        local var = recipeInfo(key, pk)
        made = var and var.m or 1
      end
    else
      made = showMaterials(key, pk, y)
    end
    if newSelection then setQuantity(made) end
    page:RefreshButtons()
  end

  function page:Refresh()
    if ns.db.settings[filterSetting] == nil then ns.db.settings[filterSetting] = not materials end
    lowCheck:SetChecked(ns.db.settings[filterSetting])
    local onlyMade = ns.db.settings[madeSetting] and true or false
    madeCheck:SetChecked(onlyMade)
    local index = Data.GetIndex()
    local profSet, groups = {}, {}
    local playerLevel = UnitLevel("player") or 60
    local myClass = ns.Dungeons.MyClass()
    local mine = materials and myReagents() or nil
    local onlyMine = materials and ns.db.settings.onlyMyReagents
    local onlyUsable = not materials and ns.db.settings.onlyUsable
    if onlyMine and not next(mine) then
      onlyMine = false -- no sabemos qué usan tus recetas: mejor enseñar todo que una lista vacía
      lowCheck.label:SetText("Solo lo que usan mis recetas |cffff8040(sin datos: se muestra todo)|r")
    elseif materials then
      lowCheck.label:SetText("Solo lo que usan mis recetas")
    end
    wipe(state.gatherOnly)

    -- Filtro de clase (en equipo): el aro dorado en la elegida.
    if page.classButtons then
      page.classAll:SetOn(state.class == nil)
      for _, b in ipairs(page.classButtons) do
        local on = b.class == state.class
        if on then b.ring:SetVertexColor(1, 0.82, 0) else b.ring:SetVertexColor(0.55, 0.45, 0.25) end
        b.icon:SetDesaturated(state.class ~= nil and not on)
      end
    end
    -- Clase con la que se mira qué se puede llevar: la elegida o, con la casilla, la tuya.
    local useClass = state.class or (onlyUsable and myClass) or nil

    local groupLabels = {}

    -- Añade un objeto a un grupo (tipo de material en materiales, ranura en equipo).
    local function add(key, pk, rec, groupKey, groupLabel)
      local name, icon, _, quality, minLevel, equipLoc = ns.KeyInfo(key)
      if ns.IsSoulbound(key) then return end -- se liga al recogerlo: no se puede pedir
      local label = name or ns.KeyName(key)
      local lower = label:lower()
      if state.search ~= "" and not lower:find(state.search, 1, true) then return end
      -- Equipo: lo que puede llevar la clase elegida (y, con la casilla, a mi nivel y no lo de
      -- mucho menos nivel).
      if not materials then
        if useClass and not canUse(key, useClass, onlyUsable and playerLevel or 60, onlyUsable and minLevel or nil) then
          return
        end
        if onlyUsable and isLowGear(minLevel, equipLoc, playerLevel) then return end
      end
      local seen, makers, gather, online = {}, 0, 0, 0
      local firstMaker, firstOnline
      local function countWho(who, isGather)
        if seen[who] then return end
        seen[who] = true
        if isGather then gather = gather + 1 else makers = makers + 1 end
        firstMaker = firstMaker or who
        if Guild.IsOnline(who) then
          online = online + 1
          firstOnline = firstOnline or who
        end
      end
      for _, cr in ipairs(rec and rec.crafters or {}) do
        if materials or cr.p == pk then countWho(cr.n) end
      end
      if materials or not rec then
        for _, who in ipairs((Data.GatherersOf(key))) do countWho(who, true) end
      end
      -- «Solo lo que alguien fabrica»: fuera lo que nadie tiene publicado (en esa profesión, si se eligió).
      if onlyMade and makers + gather == 0 then
        local anyone = false
        for _, cr in ipairs(rec and rec.crafters or {}) do
          if not state.prof or cr.p == state.prof then anyone = true break end
        end
        if not anyone then return end
      end
      -- Línea gris de la tarjeta.
      local parts = {}
      if materials then
        parts[#parts + 1] = groupLabel
      else
        parts[#parts + 1] = typeName(key)
        if minLevel and minLevel > 1 then parts[#parts + 1] = "nivel " .. minLevel end
      end
      local count = makers + gather
      if count == 0 then
        parts[#parts + 1] = "nadie lo tiene publicado"
      elseif count == 1 then
        parts[#parts + 1] = (gather == 1 and "solo lo recolecta " or "solo lo hace ") .. ns.DisplayName(firstMaker)
      else
        if makers > 0 then parts[#parts + 1] = (makers == 1 and "lo hace 1" or ("lo hacen " .. makers)) end
        if gather > 0 then parts[#parts + 1] = (gather == 1 and "lo recolecta 1" or ("lo recolectan " .. gather)) end
      end
      if online == 1 then
        parts[#parts + 1] = "|cff40ff40" .. ns.DisplayName(firstOnline) .. " en línea|r"
      elseif online > 1 then
        parts[#parts + 1] = "|cff40ff40" .. online .. " en línea|r"
      end
      groupKey = groupKey or pk
      groupLabels[groupKey] = groupLabel or ns.ProfessionName(pk)
      groups[groupKey] = groups[groupKey] or {}
      table.insert(groups[groupKey], {
        id = tostring(groupKey) .. ":" .. key, key = key, pk = pk, sort = lower, icon = icon,
        count = count, online = online, label = qualityColor(quality) .. label .. "|r",
        sub = table.concat(parts, " · "),
      })
    end

    if materials then
      -- Solo materiales de verdad, una vez cada uno, agrupados por tipo.
      for key, rec in pairs(index) do
        local _, id = ns.ParseKey(key)
        local groupKey, groupLabel = materialGroup(key)
        if groupKey and (not onlyMine or mine[id]) then
          local profs = {}
          for pk in pairs(rec.profs) do
            profSet[pk] = true
            profs[#profs + 1] = pk
          end
          table.sort(profs, function(x1, y1) return tostring(x1) < tostring(y1) end)
          if not state.prof or rec.profs[state.prof] then
            add(key, rec.profs[state.prof or false] and state.prof or profs[1], rec, groupKey, groupLabel)
          end
        end
      end
      -- Materiales de mis recetas que solo se consiguen recolectando.
      for id in pairs(mine) do
        local key = "i" .. id
        if not index[key] then
          local gatherers, skill = Data.GatherersOf(key)
          if skill and #gatherers > 0 then
            state.gatherOnly[key] = skill
            profSet[skill] = true
            local groupKey, groupLabel = materialGroup(key)
            if not state.prof or state.prof == skill then
              add(key, skill, nil, groupKey or "t:11", groupLabel or "Otros")
            end
          end
        end
      end
    else
      -- Equipo: una vez cada objeto, agrupado por ranura. Consumibles: por tipo (pociones...).
      for key, rec in pairs(index) do
        if (consumables and isConsumable(key)) or (not consumables and isEquipment(key)) then
          local profs = {}
          for pk in pairs(rec.profs) do
            profSet[pk] = true
            profs[#profs + 1] = pk
          end
          table.sort(profs, function(x1, y1) return tostring(x1) < tostring(y1) end)
          if not state.prof or rec.profs[state.prof] then
            local groupKey, groupLabel
            if consumables then
              local _, label = craftCategory(key)
              groupKey, groupLabel = "k:" .. label, label
            else
              groupKey, groupLabel = gearGroup(key)
            end
            add(key, rec.profs[state.prof or false] and state.prof or profs[1], rec, groupKey, groupLabel)
          end
        end
      end
    end

    local profList = {}
    for pk in pairs(profSet) do profList[#profList + 1] = pk end
    table.sort(profList, function(a, b) return ns.ProfessionName(a) < ns.ProfessionName(b) end)
    page.profList = profList
    if state.prof and not profSet[state.prof] then state.prof = nil end
    profButton:SetText("Profesión: " .. (state.prof and ns.ProfessionName(state.prof) or "todas"))

    -- Grupos ordenados por nombre.
    local groupKeys = {}
    for k in pairs(groups) do groupKeys[#groupKeys + 1] = k end
    table.sort(groupKeys, function(a, b) return groupLabels[a] < groupLabels[b] end)
    page.groupKeys = groupKeys

    -- Cabecera de cada grupo y sus objetos debajo (si no está plegado).
    local saved, favs = savedCollapsed(), favorites()
    local function isCollapsed(k, default)
      if state.search ~= "" then return false end -- al buscar, todo abierto
      if saved[k] ~= nil then return saved[k] end
      return default
    end
    local items, favItems = {}, {}
    for _, k in ipairs(groupKeys) do
      for _, item in ipairs(groups[k]) do
        if favs[item.key] then
          item.fav = true
          favItems[#favItems + 1] = {
            id = "fav:" .. item.key, key = item.key, pk = item.pk, sort = item.sort, icon = item.icon,
            count = item.count, online = item.online, label = item.label, sub = item.sub, fav = true,
          }
        end
      end
    end
    if #favItems > 0 then
      table.sort(favItems, function(a, b) return a.sort < b.sort end)
      local collapsed = isCollapsed("fav", false)
      items[#items + 1] = { id = "h:fav", header = true, pk = "fav", label = "Favoritos", count = #favItems, collapsed = collapsed }
      if not collapsed then
        for _, item in ipairs(favItems) do items[#items + 1] = item end
      end
    end
    for _, k in ipairs(groupKeys) do
      local group = groups[k]
      table.sort(group, function(a, b) return a.sort < b.sort end)
      -- abierto por defecto si tiene algo que usan tus recetas (en materiales)
      local useful = false
      if materials then
        for _, item in ipairs(group) do
          local _, id = ns.ParseKey(item.key)
          if mine[id] then useful = true break end
        end
      end
      local collapsed = isCollapsed(k, not useful and not consumables) -- consumibles: abiertos
      items[#items + 1] = {
        id = "h:" .. tostring(k), header = true, pk = k, label = groupLabels[k],
        count = #group, collapsed = collapsed,
      }
      if not collapsed then
        for _, item in ipairs(group) do items[#items + 1] = item end
      end
    end
    page.items = items
    -- Cuántos objetos salen con la búsqueda (sin contar las cabeceras ni los repetidos de Favoritos).
    local n = 0
    for _, it in ipairs(items) do
      if not it.header and not tostring(it.id):find("^fav:") then n = n + 1 end
    end
    page.matches = n
    list.selectedKey = state.key
    list:SetItems(items)
    page:RefreshDetail()
  end
end

-- «Pedir» tiene tres tipos (Materiales, Equipo, Consumibles) con un solo buscador: lo que se
-- escribe vale para los tres, cada tipo dice cuántos encuentra y, si en el tipo abierto no
-- sale nada, se pasa solo al que sí tiene.
local ASK_TYPES = {
  { id = "materials", label = "Materiales", tip = "Minerales, hierbas, telas, pieles... lo que se recolecta o se fabrica para otras recetas." },
  { id = "equipment", label = "Equipo", tip = "Armas, armaduras, bolsas y abalorios, por ranura y por clase." },
  { id = "consumables", label = "Consumibles", tip = "Pociones, elixires, frascos, comida y vendas." },
}
local function isAskType(mode)
  for _, t in ipairs(ASK_TYPES) do if t.id == mode then return true end end
  return false
end
ns.UI.RegisterPage("ask", function(page)
  page.back = W.Button(page, "< Mercado", 90, 22, function() ns.UI.ShowPage("market") end)
  page.back:SetPoint("TOPLEFT", 0, -2)
  page.types, page.frames = {}, {}
  local x = 100
  for _, t in ipairs(ASK_TYPES) do
    local b = W.Chip(page, t.label, 100, function() page:SetMode(t.id) end)
    b:SetPoint("TOPLEFT", x, -2)
    x = x + 102
    ns.UI.Tip(b, t.label, t.tip)
    page.types[t.id] = b
  end
  local function newFrame(id)
    local f = CreateFrame("Frame", nil, page)
    f:SetPoint("TOPLEFT", 0, -28)
    f:SetPoint("BOTTOMRIGHT")
    f:SetSize(ns.UI.CONTENT_W, ns.UI.CONTENT_H - 28)
    f:Hide()
    page.frames[id] = f
    return f
  end
  for _, t in ipairs(ASK_TYPES) do buildCatalog(newFrame(t.id), t.id) end
  page.mode = "materials"

  -- Un solo buscador para los tres tipos de «Pedir».
  local search = ""
  local function typeLabels()
    for _, t in ipairs(ASK_TYPES) do
      local f, b = page.frames[t.id], page.types[t.id]
      if search ~= "" and f.matches then
        b:SetText(t.label .. " " .. (f.matches > 0 and "|cffffffff" or "|cff808080") .. f.matches .. "|r")
      else
        b:SetText(t.label)
      end
    end
  end
  for _, t in ipairs(ASK_TYPES) do
    page.frames[t.id].onSearch = function(text)
      search = text
      for _, o in ipairs(ASK_TYPES) do
        local f = page.frames[o.id]
        if o.id ~= t.id and f.searchBox:GetText() ~= text then f.searchBox:SetText(text) end
      end
      -- Si aquí no sale nada y en otro tipo sí, se pasa a ese.
      local here = page.frames[page.mode]
      if text ~= "" and here and here.matches == 0 then
        for _, o in ipairs(ASK_TYPES) do
          local f = page.frames[o.id]
          if (f.matches or 0) > 0 then
            page:SetMode(o.id)
            f.searchBox:SetFocus()
            f.searchBox:SetCursorPosition(#text)
            break
          end
        end
      end
      typeLabels()
    end
  end

  function page:SetMode(mode)
    if mode == "ask" then mode = page.lastAsk or "materials" end
    if not page.frames[mode] then mode = "materials" end
    page.mode = mode
    if isAskType(mode) then page.lastAsk = mode end
    page:Refresh()
  end

  function page:Refresh()
    local asking = isAskType(page.mode)
    for id, f in pairs(page.frames) do f:SetShown(id == page.mode) end
    for id, b in pairs(page.types) do
      b:SetShown(asking)
      b:SetOn(id == page.mode)
    end
    local f = page.frames[page.mode]
    if f and f.Refresh then f:Refresh() end
    if asking then typeLabels() end
  end
end)

-- Abre «+ Pedir».
function ns.UI.OpenAsk(mode)
  local f = ns.UI.Open("ask")
  if f and f.SetMode then f:SetMode(mode or "ask") end
end

-- Pedir un objeto concreto (arrastrado al botón «+ Pedir»).
function ns.UI.AskFor(key)
  ns.UI.OpenRequestDialog({ k = key, pk = Data.SingleProfession(key), q = 1 })
end

-- Para el Mercado y Hermandad: quién fabrica (o recolecta) algo, una fila por profesión, con
-- su nivel. Tú primero.
function ns.UI.CrafterRows(key, withGatherers)
  local out, me = {}, ns.Me()
  for _, row in ipairs(crafterRows(key, withGatherers)) do
    -- Recetas con tiempo de espera: cuánto le queda o si ya está lista.
    local extra
    if row.cdRecipe then
      extra = row.cdLeft and ("|cffff8040cd " .. ns.FormatDuration(row.cdLeft) .. "|r") or "|cff40ff40cd listo|r"
    end
    for _, p in ipairs(row.profs) do
      out[#out + 1] = { name = row.name, class = row.class, pk = p.pk, r = p.r, online = row.online,
        seen = row.seen, unavailable = row.unavailable, karma = row.karma, thanks = row.thanks,
        level = row.level, extra = extra }
    end
  end
  -- Tú primero; los demás, en el orden de antes (disponibles, en línea, vistos hace poco).
  local sorted = {}
  for _, c in ipairs(out) do if c.name == me then sorted[#sorted + 1] = c end end
  for _, c in ipairs(out) do if c.name ~= me then sorted[#sorted + 1] = c end end
  return sorted
end
ns.UI.GearGroup = gearGroup
ns.UI.CraftCategory, ns.UI.ReagentsBlock = craftCategory, reagentsBlock
