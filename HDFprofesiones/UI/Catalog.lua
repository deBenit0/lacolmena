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

-- Materiales que usan mis recetas: [objeto] = { claves de mis recetas que lo usan }.
local function myReagents()
  local c, out = ns.MyChar(), {}
  for pk, prof in pairs(c and c.profs or {}) do
    for key in pairs(prof.recipes or {}) do
      local info = Data.GetInfo(Data.InfoKey(pk, key))
      for _, var in ipairs(info and info.v or {}) do
        for id in pairs(var.r) do
          out[id] = out[id] or {}
          out[id][key] = true
        end
      end
    end
  end
  return out
end

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

local function buildCatalog(page, mode)
  local materials = mode == "materials"
  local state = { search = "", prof = nil, key = nil, pk = nil, gatherOnly = {} }

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

  -- Barra superior: búsqueda, profesión y filtro de equipo bajo.
  local search = W.Input(page, 160)
  search:SetPoint("TOPLEFT", 8, -4)
  search:SetScript("OnTextChanged", function(self)
    state.search = self:GetText():lower()
    page:Refresh()
  end)
  W.Placeholder(search, "Buscar objeto...")

  local profButton = W.Button(page, "Profesión: todas", 160, 22)
  profButton:SetPoint("LEFT", search, "RIGHT", 10, 0)
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

  local filterSetting = materials and "onlyMyReagents" or "hideLowGear"
  local lowCheck = W.Check(page, materials and "Solo lo que usan mis recetas" or "Ocultar equipo de nivel bajo",
    function(checked)
      ns.db.settings[filterSetting] = checked
      page:Refresh()
    end)
  lowCheck:SetPoint("LEFT", profButton, "RIGHT", 10, 0)

  -- Lista agrupada por profesión, con cabeceras plegables como en la ventana de profesiones.
  local list = W.List(page, 250, 368, {
    rows = 16,
    rowHeight = 22,
    keyOf = function(item) return item.id end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(18, 18)
      row.icon:SetPoint("LEFT", 12, 0)
      row.count = W.Text(row, "GameFontNormalSmall", "RIGHT")
      row.count:SetPoint("RIGHT", -2, 0)
      row.text = W.Text(row, "GameFontHighlightSmall")
      row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.text:SetPoint("RIGHT", row, "RIGHT", -36, 0)
      row.text:SetWordWrap(false)
      row.header = W.Text(row, "GameFontNormal")
      row.header:SetPoint("LEFT", 2, 0)
      row.header:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      W.KeyTooltip(row, function(self) return self.item and not self.item.header and self.item.key end)
    end,
    updateRow = function(row, item)
      row.header:SetShown(item.header)
      row.icon:SetShown(not item.header)
      row.text:SetShown(not item.header)
      row.count:SetShown(not item.header)
      if item.header then
        row.header:SetText((item.collapsed and "[+] " or "[-] ") .. item.label .. " |cffbbbbbb(" .. item.count .. ")|r")
        return
      end
      row.icon:SetTexture(item.icon)
      row.text:SetText(item.label)
      if item.online > 0 then
        row.count:SetText("|cff40ff40" .. item.online .. "|r/" .. item.count)
      else
        row.count:SetText(item.count)
      end
    end,
    onSelect = function(item)
      if item.header then
        savedCollapsed()[item.pk] = not item.collapsed
        page:Refresh()
        return
      end
      state.key, state.pk = item.key, item.pk
      page:RefreshDetail(true)
    end,
  })
  list:SetPoint("TOPLEFT", 0, -30)

  -- Detalle del objeto elegido.
  local detail = W.Box(page, 350, 368)
  detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0)

  detail.icon = CreateFrame("Button", nil, detail)
  detail.icon:SetSize(36, 36)
  detail.icon:SetPoint("TOPLEFT", 10, -10)
  detail.iconTex = detail.icon:CreateTexture(nil, "ARTWORK")
  detail.iconTex:SetAllPoints()
  W.KeyTooltip(detail.icon, function() return state.key end)

  detail.name = W.Text(detail, "GameFontNormal")
  detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 8, -2)
  detail.name:SetPoint("RIGHT", detail, "RIGHT", -104, 0)

  -- Favoritos: lo que pides a menudo sale arriba del todo.
  detail.fav = W.Button(detail, "+ Favorito", 90, 20, function()
    if not state.key then return end
    local favs = favorites()
    favs[state.key] = not favs[state.key] or nil
    page:Refresh()
  end)
  detail.fav:SetPoint("TOPRIGHT", -8, -10)
  detail.name:SetWordWrap(false)
  detail.sub = W.Text(detail, "GameFontHighlightSmall")
  detail.sub:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
  detail.sub:SetPoint("RIGHT", detail, "RIGHT", -10, 0)


  detail.matsLabel = W.Text(detail, "GameFontNormalSmall")
  detail.matsLabel:SetPoint("TOPLEFT", 12, -62)
  detail.matsLabel:SetText("Materiales necesarios:")

  -- Casillas de materiales (2 columnas), como en la ventana de profesiones.
  detail.slots = {}
  for i = 1, MAX_REAGENTS do
    local slot = CreateFrame("Button", nil, detail)
    slot:SetSize(160, 28)
    local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
    slot:SetPoint("TOPLEFT", 10 + col * 166, -78 - line * 30)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetSize(26, 26)
    slot.icon:SetPoint("LEFT", 0, 0)
    slot.need = W.Text(slot, "NumberFontNormal", "RIGHT")
    slot.need:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", 0, 1)
    slot.name = W.Text(slot, "GameFontHighlightSmall")
    slot.name:SetPoint("TOPLEFT", slot.icon, "TOPRIGHT", 4, -1)
    slot.name:SetPoint("RIGHT", slot, "RIGHT", 0, 0)
    slot.name:SetWordWrap(false)
    slot.have = W.Text(slot, "GameFontHighlightSmall")
    slot.have:SetPoint("BOTTOMLEFT", slot.icon, "BOTTOMRIGHT", 4, 1)
    W.KeyTooltip(slot, function(self) return self.itemID and ("i" .. self.itemID) end)
    detail.slots[i] = slot
  end
  detail.matsNote = W.Text(detail, "GameFontHighlightSmall")
  detail.matsNote:SetPoint("TOPLEFT", 12, -78)
  detail.matsNote:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.matsNote:SetHeight(110)
  detail.matsNote:SetJustifyV("TOP")
  detail.matsNote:SetTextColor(0.75, 0.75, 0.75)

  detail.craftersLabel = W.Text(detail, "GameFontNormalSmall")
  detail.craftersLabel:SetPoint("TOPLEFT", 12, -194)
  detail.craftersLabel:SetText(materials and "Quién lo da" or "Quién lo fabrica")

  local crafters = W.List(detail, 334, 94, {
    rows = 4,
    rowHeight = 20,
    keyOf = function(row) return row.name end,
    buildRow = function(row)
      row.name = W.Text(row, "GameFontHighlightSmall")
      row.name:SetPoint("LEFT", 4, 0)
      row.name:SetWidth(100)
      row.name:SetWordWrap(false)
      row.status = W.Text(row, "GameFontHighlightSmall")
      row.status:SetPoint("LEFT", 108, 0)
      row.status:SetPoint("RIGHT", row, "RIGHT", -70, 0)
      row.status:SetWordWrap(false)
      row.count = W.Text(row, "GameFontNormalSmall", "RIGHT")
      row.count:SetPoint("RIGHT", -2, 0)
      row:SetScript("OnEnter", function(self)
        local c = self.item
        if not c then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.ColoredName(c.name, c.class) .. (c.level and (" (nivel " .. c.level .. ")") or ""))
        for _, p in ipairs(c.profs) do
          GameTooltip:AddLine(ns.ProfessionName(p.pk) .. (p.r and string.format(" %d/%d", p.r, p.m or 0) or ""), 1, 1, 1)
        end
        GameTooltip:AddLine("Karma: " .. c.karma .. "   Encargos completados: " .. c.thanks, 0.8, 0.8, 0.8)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    updateRow = function(row, c)
      row.name:SetText(ns.ColoredName(c.name, c.class))
      row.status:SetText(c.status)
      row.count:SetText("karma " .. c.karma)
    end,
    onSelect = function() page:RefreshButtons() end,
  })
  crafters:SetPoint("TOPLEFT", 8, -208)
  detail.crafters = crafters

  -- Cantidad con − y +, como el "Crear" de la ventana de profesiones.
  detail.qtyLabel = W.Text(detail, "GameFontNormalSmall")
  detail.qtyLabel:SetPoint("BOTTOMLEFT", 12, 42)
  detail.qtyLabel:SetText("Cantidad:")
  detail.minus = W.Button(detail, "-", 24, 20)
  detail.minus:SetPoint("LEFT", detail.qtyLabel, "RIGHT", 8, 0)
  detail.qty = W.Input(detail, 44, true)
  detail.qty:SetPoint("LEFT", detail.minus, "RIGHT", 8, 0)
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
  detail.askAll = W.Button(detail, "Pedir a la hermandad", 150, 22, function()
    if state.key then ns.UI.OpenRequestDialog(requestOptions()) end
  end)
  detail.askAll:SetPoint("BOTTOMLEFT", 8, 8)
  detail.whisper = W.Button(detail, "Susurrar", 96, 22, function()
    local c = crafters:Selected()
    if c then ns.SendTell(c.name) end
  end)
  detail.whisper:SetPoint("LEFT", detail.askAll, "RIGHT", 4, 0)

  detail.empty = W.Text(detail, "GameFontNormal", "CENTER")
  detail.empty:SetTextColor(0.6, 0.6, 0.6)
  detail.empty:SetPoint("CENTER")
  detail.empty:SetWidth(300)

  -- Referencias para depurar y para las pruebas.
  page.state, page.list, page.detail, page.search, page.profButton = state, list, detail, search, profButton

  -- Pliega o despliega todos los grupos (y lo recuerda).
  function page:SetAllCollapsed(value)
    page:Refresh() -- recalcular qué profesiones hay con los filtros actuales
    local saved = savedCollapsed()
    for _, k in ipairs(page.groupKeys or {}) do saved[k] = value end
    saved.fav = value
    page:Refresh()
  end

  function page:RefreshButtons()
    local c = crafters:Selected()
    local me = ns.Me()
    local other = c and c.name ~= me
    detail.askAll:SetEnabled(state.key ~= nil)
    detail.whisper:SetEnabled(other or false)
  end

  local function showMaterials(key, pk)
    local var, variants = recipeInfo(key, pk)
    local ids = {}
    if var then
      for id in pairs(var.r) do ids[#ids + 1] = id end
      table.sort(ids)
    end
    for i, slot in ipairs(detail.slots) do
      local id = ids[i]
      slot.itemID = id
      slot:SetShown(id ~= nil)
      if id then
        local need = var.r[id]
        local have = ns.Scan.Have(id)
        local _, icon = ns.KeyInfo("i" .. id)
        slot.icon:SetTexture(icon)
        slot.need:SetText(need > 1 and need or "")
        slot.name:SetText(ns.KeyName("i" .. id))
        slot.have:SetText((have >= need and "|cff40ff40" or "|cffff5050") .. have .. "/" .. need .. "|r")
      end
    end
    if not var then
      detail.matsNote:SetText("Pidiendo los materiales a la hermandad...")
    elseif variants > 1 then
      detail.matsNote:SetText("")
      detail.matsLabel:SetText(string.format("Materiales necesarios (hay %d recetas; se muestra una):", variants))
    else
      detail.matsNote:SetText("")
    end
    detail.matsNote:SetShown(not var)
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
      detail.qtyLabel, detail.minus, detail.qty, detail.plus, detail.made,
      detail.askAll, detail.whisper,
    }
    for _, region in ipairs(regions) do region:SetShown(hasKey) end
    detail.empty:SetShown(not hasKey)
    if not hasKey then
      for _, slot in ipairs(detail.slots) do slot:Hide() end
      detail.matsNote:Hide()
      if #list.items > 0 then
        detail.empty:SetText("Elige un objeto de la lista.")
      elseif materials and ns.db.settings.onlyMyReagents then
        detail.empty:SetText("No hay materiales de tus recetas que dé la hermandad. Abre tus profesiones "
          .. "para que el addon sepa qué usas, o desmarca \"Solo lo que usan mis recetas\".")
      else
        detail.empty:SetText("Aún no hay nada. Cada miembro debe abrir la ventana de sus profesiones una vez.")
      end
      return
    end
    local profs = rec and rec.profs or {}
    local pk = (state.pk and profs[state.pk]) and state.pk or Data.SingleProfession(key) or next(profs)
    local name, icon, link = ns.KeyInfo(key)
    detail.iconTex:SetTexture(icon)
    detail.name:SetText(link or name or ns.KeyName(key))
    detail.fav:SetText(favorites()[key] and "- Favorito" or "+ Favorito")
    local profNames = {}
    for p in pairs(profs) do profNames[#profNames + 1] = ns.ProfessionName(p) end
    local _, skill = Data.GatherersOf(key)
    if materials and skill and #(Data.GatherersOf(key)) > 0 then profNames[#profNames + 1] = ns.ProfessionName(skill) end
    table.sort(profNames)
    detail.sub:SetText(table.concat(profNames, ", "))
    local _, itemID = ns.ParseKey(key)
    local made = 1
    if materials then
      -- En materiales: para qué recetas tuyas sirve.
      for _, slot in ipairs(detail.slots) do slot:Hide() end
      detail.matsLabel:SetText("Lo usas en:")
      local uses, names = myReagents()[itemID or 0], {}
      for k in pairs(uses or {}) do names[#names + 1] = ns.KeyName(k) end
      table.sort(names)
      detail.matsNote:SetText(#names > 0 and table.concat(names, "\n") or "Ninguna receta tuya conocida.")
      detail.matsNote:Show()
      state.step = 1
      detail.made:SetText("")
      if pk then
        local var = recipeInfo(key, pk)
        made = var and var.m or 1
      end
    else
      detail.matsLabel:SetText("Materiales necesarios:")
      made = showMaterials(key, pk)
    end
    if newSelection then setQuantity(made) end
    local rows = crafterRows(key, materials)
    crafters:SetItems(rows)
    detail.craftersLabel:SetText((materials and "Quién lo da (" or "Quién lo fabrica (") .. #rows .. ")"
      .. (#rows == 0 and " |cff999999- nadie lo tiene publicado aún, pero puedes pedirlo|r" or ""))
    page:RefreshButtons()
  end

  function page:Refresh()
    if ns.db.settings[filterSetting] == nil then ns.db.settings[filterSetting] = not materials end
    lowCheck:SetChecked(ns.db.settings[filterSetting])
    local index = Data.GetIndex()
    local profSet, groups = {}, {}
    local playerLevel = UnitLevel("player") or 60
    local mine = materials and myReagents() or nil
    local onlyMine = materials and ns.db.settings.onlyMyReagents
    if onlyMine and not next(mine) then
      onlyMine = false -- no sabemos qué usan tus recetas: mejor enseñar todo que una lista vacía
      lowCheck.label:SetText("Solo lo que usan mis recetas |cffff8040(sin datos: se muestra todo)|r")
    elseif materials then
      lowCheck.label:SetText("Solo lo que usan mis recetas")
    end
    wipe(state.gatherOnly)

    local groupLabels = {}

    -- Añade un objeto a un grupo (tipo de material en materiales, profesión en equipo).
    local function add(key, pk, rec, groupKey, groupLabel)
      local name, icon, _, quality, minLevel, equipLoc = ns.KeyInfo(key)
      local label = name or ns.KeyName(key)
      local lower = label:lower()
      if state.search ~= "" and not lower:find(state.search, 1, true) then return end
      if not materials and ns.db.settings.hideLowGear and isLowGear(minLevel, equipLoc, playerLevel) then return end
      local seen, count, online = {}, 0, 0
      local function countWho(who)
        if not seen[who] then
          seen[who] = true
          count = count + 1
          if Guild.IsOnline(who) then online = online + 1 end
        end
      end
      for _, cr in ipairs(rec and rec.crafters or {}) do
        if materials or cr.p == pk then countWho(cr.n) end
      end
      if materials or not rec then
        for _, who in ipairs((Data.GatherersOf(key))) do countWho(who) end
      end
      groupKey = groupKey or pk
      groupLabels[groupKey] = groupLabel or ns.ProfessionName(pk)
      groups[groupKey] = groups[groupKey] or {}
      table.insert(groups[groupKey], {
        id = tostring(groupKey) .. ":" .. key, key = key, pk = pk, sort = lower, icon = icon,
        count = count, online = online, label = qualityColor(quality) .. label .. "|r",
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
          table.sort(profs, function(x, y) return tostring(x) < tostring(y) end)
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
      -- Equipo: una vez cada objeto, agrupado por tipo (como los materiales).
      for key, rec in pairs(index) do
        if isEquipment(key) then
          local profs = {}
          for pk in pairs(rec.profs) do
            profSet[pk] = true
            profs[#profs + 1] = pk
          end
          table.sort(profs, function(x, y) return tostring(x) < tostring(y) end)
          if not state.prof or rec.profs[state.prof] then
            local groupKey, groupLabel = gearGroup(key)
            add(key, rec.profs[state.prof or false] and state.prof or profs[1], rec, groupKey, groupLabel)
          end
        end
      end
    end

    local profList = {}
    for pk in pairs(profSet) do profList[#profList + 1] = pk end
    table.sort(profList, function(x, y) return ns.ProfessionName(x) < ns.ProfessionName(y) end)
    page.profList = profList
    if state.prof and not profSet[state.prof] then state.prof = nil end
    profButton:SetText("Profesión: " .. (state.prof and ns.ProfessionName(state.prof) or "todas"))

    -- Grupos ordenados por nombre.
    local groupKeys = {}
    for k in pairs(groups) do groupKeys[#groupKeys + 1] = k end
    table.sort(groupKeys, function(x, y) return groupLabels[x] < groupLabels[y] end)
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
          item.label = "|cffffd100*|r " .. item.label
          favItems[#favItems + 1] = {
            id = "fav:" .. item.key, key = item.key, pk = item.pk, sort = item.sort, icon = item.icon,
            count = item.count, online = item.online, label = item.label,
          }
        end
      end
    end
    if #favItems > 0 then
      table.sort(favItems, function(x, y) return x.sort < y.sort end)
      local collapsed = isCollapsed("fav", false)
      items[#items + 1] = { id = "h:fav", header = true, pk = "fav", label = "Favoritos", count = #favItems, collapsed = collapsed }
      if not collapsed then
        for _, item in ipairs(favItems) do items[#items + 1] = item end
      end
    end
    for _, k in ipairs(groupKeys) do
      local group = groups[k]
      table.sort(group, function(x, y) return x.sort < y.sort end)
      -- abierto por defecto si tiene algo que usan tus recetas (en materiales)
      local useful = false
      if materials then
        for _, item in ipairs(group) do
          local _, id = ns.ParseKey(item.key)
          if mine[id] then useful = true break end
        end
      end
      local collapsed = isCollapsed(k, not useful)
      items[#items + 1] = {
        id = "h:" .. tostring(k), header = true, pk = k, label = groupLabels[k],
        count = #group, collapsed = collapsed,
      }
      if not collapsed then
        for _, item in ipairs(group) do items[#items + 1] = item end
      end
    end
    list:SetItems(items)
    page:RefreshDetail()
  end
end

ns.UI.RegisterPage("materials", function(page) buildCatalog(page, "materials") end)
ns.UI.RegisterPage("equipment", function(page) buildCatalog(page, "equipment") end)
