-- Página "Recetas": todo lo que se puede fabricar en la hermandad, al estilo de la ventana
-- de profesiones del juego: lista por profesiones, materiales en casillas y "Pedir" con cantidad.
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
local function crafterRows(key)
  local rec = Data.GetIndex()[key]
  local g = ns.G()
  if not rec or not g then return {} end
  local now = ns.Now()
  local byName, rows = {}, {}
  for _, cr in ipairs(rec.crafters) do
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
        profs = {},
      }
      byName[cr.n] = row
      rows[#rows + 1] = row
    end
    local p = e and e.p and e.p[cr.p]
    row.profs[#row.profs + 1] = { pk = cr.p, r = p and p.r, m = p and p.m }
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

ns.UI.RegisterPage("recipes", function(page)
  local state = { search = "", prof = nil, key = nil, pk = nil, collapsed = {} }

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
  profButton:SetScript("OnClick", function()
    local list = page.profList or {}
    local current = 0
    for i, pk in ipairs(list) do
      if pk == state.prof then current = i end
    end
    state.prof = list[current + 1] -- después de la última vuelve a "todas"
    page:Refresh()
  end)

  local lowCheck = W.Check(page, "Ocultar equipo de nivel bajo", function(checked)
    ns.db.settings.hideLowGear = checked
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
        state.collapsed[item.pk] = not state.collapsed[item.pk]
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
  detail.name:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.name:SetWordWrap(false)
  detail.sub = W.Text(detail, "GameFontHighlightSmall")
  detail.sub:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
  detail.sub:SetPoint("RIGHT", detail, "RIGHT", -10, 0)

  detail.matsLabel = W.Text(detail, "GameFontNormalSmall")
  detail.matsLabel:SetPoint("TOPLEFT", 12, -54)
  detail.matsLabel:SetText("Materiales necesarios:")

  -- Casillas de materiales (2 columnas), como en la ventana de profesiones.
  detail.slots = {}
  for i = 1, MAX_REAGENTS do
    local slot = CreateFrame("Button", nil, detail)
    slot:SetSize(160, 28)
    local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
    slot:SetPoint("TOPLEFT", 10 + col * 166, -70 - line * 30)
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
  detail.matsNote:SetPoint("TOPLEFT", 12, -72)
  detail.matsNote:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.matsNote:SetTextColor(0.75, 0.75, 0.75)

  detail.craftersLabel = W.Text(detail, "GameFontNormalSmall")
  detail.craftersLabel:SetPoint("TOPLEFT", 12, -194)
  detail.craftersLabel:SetText("Quién lo fabrica")

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
      row.status:SetPoint("RIGHT", row, "RIGHT", -44, 0)
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
        GameTooltip:AddLine("Encargos completados: " .. c.thanks, 0.8, 0.8, 0.8)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    updateRow = function(row, c)
      row.name:SetText(ns.ColoredName(c.name, c.class))
      row.status:SetText(c.status)
      row.count:SetText(c.thanks > 0 and (c.thanks .. " enc.") or "")
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

  local function requestOptions(to)
    return { k = state.key, pk = state.pk or Data.SingleProfession(state.key), q = quantity(), to = to }
  end

  detail.askAll = W.Button(detail, "Pedir a todos", 104, 22, function()
    if state.key then ns.UI.OpenRequestDialog(requestOptions(nil)) end
  end)
  detail.askAll:SetPoint("BOTTOMLEFT", 8, 8)
  detail.askOne = W.Button(detail, "Pedir a...", 124, 22, function()
    local c = crafters:Selected()
    if state.key and c then ns.UI.OpenRequestDialog(requestOptions(c.name)) end
  end)
  detail.askOne:SetPoint("LEFT", detail.askAll, "RIGHT", 4, 0)
  detail.whisper = W.Button(detail, "Susurrar", 96, 22, function()
    local c = crafters:Selected()
    if c and ChatFrame_SendTell then ChatFrame_SendTell(c.name) end
  end)
  detail.whisper:SetPoint("LEFT", detail.askOne, "RIGHT", 4, 0)

  detail.empty = W.Text(detail, "GameFontNormal", "CENTER")
  detail.empty:SetTextColor(0.6, 0.6, 0.6)
  detail.empty:SetPoint("CENTER")
  detail.empty:SetWidth(300)

  -- Referencias para depurar y para las pruebas.
  page.state, page.list, page.detail, page.search, page.profButton = state, list, detail, search, profButton

  function page:RefreshButtons()
    local c = crafters:Selected()
    local me = ns.Me()
    local other = c and c.name ~= me
    detail.askAll:SetEnabled(state.key ~= nil)
    detail.askOne:SetEnabled(state.key ~= nil and other or false)
    detail.askOne:SetText(other and ("Pedir a " .. ns.ShortName(c.name)) or "Pedir a...")
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
    local hasKey = rec ~= nil
    local regions = {
      detail.icon, detail.name, detail.sub, detail.matsLabel, detail.craftersLabel, crafters,
      detail.qtyLabel, detail.minus, detail.qty, detail.plus, detail.made,
      detail.askAll, detail.askOne, detail.whisper,
    }
    for _, region in ipairs(regions) do region:SetShown(hasKey) end
    detail.empty:SetShown(not hasKey)
    if not hasKey then
      for _, slot in ipairs(detail.slots) do slot:Hide() end
      detail.matsNote:Hide()
      detail.empty:SetText(next(Data.GetIndex()) and "Elige un objeto de la lista."
        or "Aún no hay recetas. Cada miembro debe abrir la ventana de sus profesiones una vez para publicarlas.")
      return
    end
    local pk = (state.pk and rec.profs[state.pk]) and state.pk or Data.SingleProfession(key) or next(rec.profs)
    local name, icon, link = ns.KeyInfo(key)
    detail.iconTex:SetTexture(icon)
    detail.name:SetText(link or name or ns.KeyName(key))
    local profNames = {}
    for p in pairs(rec.profs) do profNames[#profNames + 1] = ns.ProfessionName(p) end
    table.sort(profNames)
    detail.sub:SetText(table.concat(profNames, ", "))
    detail.matsLabel:SetText("Materiales necesarios:")
    local made = showMaterials(key, pk)
    if newSelection then setQuantity(made) end
    local rows = crafterRows(key)
    crafters:SetItems(rows)
    detail.craftersLabel:SetText("Quién lo fabrica (" .. #rows .. ")")
    page:RefreshButtons()
  end

  function page:Refresh()
    lowCheck:SetChecked(ns.db.settings.hideLowGear)
    local index = Data.GetIndex()
    local profSet, groups = {}, {}
    local playerLevel = UnitLevel("player") or 60
    for key, rec in pairs(index) do
      local name, icon, _, quality, minLevel, equipLoc = ns.KeyInfo(key)
      local label = name or ns.KeyName(key)
      local lower = label:lower()
      local visible = state.search == "" or lower:find(state.search, 1, true) ~= nil
      if visible and ns.db.settings.hideLowGear and isLowGear(minLevel, equipLoc, playerLevel) then visible = false end
      for pk in pairs(rec.profs) do
        profSet[pk] = true
        if visible and (not state.prof or state.prof == pk) then
          local seen, count, online = {}, 0, 0
          for _, cr in ipairs(rec.crafters) do
            if cr.p == pk and not seen[cr.n] then
              seen[cr.n] = true
              count = count + 1
              if Guild.IsOnline(cr.n) then online = online + 1 end
            end
          end
          groups[pk] = groups[pk] or {}
          table.insert(groups[pk], {
            id = tostring(pk) .. ":" .. key, key = key, pk = pk, sort = lower, icon = icon,
            count = count, online = online, label = qualityColor(quality) .. label .. "|r",
          })
        end
      end
    end
    local profList = {}
    for pk in pairs(profSet) do profList[#profList + 1] = pk end
    table.sort(profList, function(a, b) return ns.ProfessionName(a) < ns.ProfessionName(b) end)
    page.profList = profList
    if state.prof and not profSet[state.prof] then state.prof = nil end
    profButton:SetText("Profesión: " .. (state.prof and ns.ProfessionName(state.prof) or "todas"))

    -- Cabecera por profesión y sus objetos debajo (si no está plegada).
    local items = {}
    for _, pk in ipairs(profList) do
      local group = groups[pk]
      if group then
        table.sort(group, function(a, b) return a.sort < b.sort end)
        local collapsed = state.collapsed[pk] and state.search == ""
        items[#items + 1] = {
          id = "h:" .. tostring(pk), header = true, pk = pk, label = ns.ProfessionName(pk),
          count = #group, collapsed = collapsed,
        }
        if not collapsed then
          for _, item in ipairs(group) do items[#items + 1] = item end
        end
      end
    end
    list:SetItems(items)
    page:RefreshDetail()
  end
end)
