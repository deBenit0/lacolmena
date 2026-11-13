-- Página "Miembros": la lista de la hermandad dentro del addon (sustituye a la de la J).
-- Filtros arriba (Todos, En línea, Con el addon, Artesanos, Oficiales) y buscador; una fila por
-- miembro con clase, nivel, rol, profesiones, si tiene el addon, rango, zona y conexión, y un
-- bocadillo para susurrarle. Los que llevan más de 3 días sin conectarse van plegados al final.
local _, ns = ...
local W = ns.W

local INACTIVE = 3 * 86400

local FILTERS = {
  { id = "all", label = "Todos" },
  { id = "online", label = "En línea" },
  { id = "addon", label = "Con el addon" },
  { id = "crafters", label = "Artesanos" },
  { id = "officers", label = "Oficiales" },
}

-- Columnas: título, x y ancho.
local COLS = {
  { id = "name", label = "Nombre", x = 4, w = 136 },
  { id = "class", label = "Clase", x = 142, w = 70 },
  { id = "level", label = "Niv.", x = 214, w = 28 },
  { id = "role", label = "Rol", x = 246, w = 56 },
  { id = "profs", label = "Profesiones", x = 304, w = 86 },
  { id = "addon", label = "Addon", x = 392, w = 92 },
  { id = "rank", label = "Rango", x = 486, w = 78 },
  { id = "zone", label = "Zona", x = 566, w = 92 },
  { id = "seen", label = "Conexión", x = 660, w = 62 },
}

local ROLE_SHORT = { [1] = "Tq", [2] = "Sn", [4] = "DPS" }

local function roleText(mask)
  local D = ns.Dungeons
  mask = D and D.CleanRole(mask)
  if not mask then return "-" end
  local parts = {}
  for _, bit in ipairs({ 1, 2, 4 }) do
    if D.HasRole(mask, bit) then parts[#parts + 1] = ROLE_SHORT[bit] end
  end
  return table.concat(parts, "/")
end

local function profsText(e)
  if not e or type(e.p) ~= "table" then return "-" end
  local names = {}
  for pk in pairs(e.p) do
    local n = ns.ProfessionName(pk)
    if type(n) == "string" and n ~= "" then
      -- tres letras sin partir una con tilde
      local short, count = "", 0
      for ch in n:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if count == 3 then break end
        short, count = short .. ch, count + 1
      end
      names[#names + 1] = short
    end
  end
  table.sort(names)
  if #names == 0 then return "-" end
  return table.concat(names, " · ", 1, math.min(2, #names))
end

local function ago(seconds)
  if not seconds then return "|cff888888?|r" end
  seconds = math.max(0, seconds)
  if seconds < 3600 then return string.format("hace %d min", math.max(1, math.floor(seconds / 60))) end
  if seconds < 86400 then return string.format("hace %d h", math.floor(seconds / 3600)) end
  return string.format("hace %d d", math.floor(seconds / 86400))
end

-- Nombre para enseñar: con apellido si lo tiene (sin el reino).
local function displayName(name, info)
  local raw = info and info.raw
  local full = (type(raw) == "string" and raw:match("^([^%-]+)")) or (ns.TellName and ns.TellName(name)) or name
  return (full:gsub("%-.*$", ""))
end

local function addonText(e)
  if not e then return "|cffe04040" .. "\194\183 Sin addon|r", 0 end
  local Sync = ns.Sync
  local mine = Sync and Sync.VersionNumber and Sync.VersionNumber(ns.VERSION) or 0
  local theirs = Sync and Sync.VersionNumber and Sync.VersionNumber(e.av) or 0
  if theirs >= mine then return "|cff40c040\194\183 Al día|r", 2 end
  return "|cffff9933\194\183 Versión antigua|r", 1
end

-- Ventana para escribir a quién invitar.
StaticPopupDialogs["HDFPROF_INVITE"] = {
  text = "¿A quién invitas a la hermandad?\n(nombre del personaje)",
  button1 = ACCEPT or "Aceptar",
  button2 = CANCEL or "Cancelar",
  hasEditBox = true,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
  OnAccept = function(self)
    local edit = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
    local name = edit and edit:GetText() or ""
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return end
    local invite = (C_GuildInfo and C_GuildInfo.Invite) or GuildInvite
    if invite then pcall(invite, name) end
  end,
  EditBoxOnEnterPressed = function(self)
    local popup = self:GetParent()
    StaticPopupDialogs["HDFPROF_INVITE"].OnAccept(popup)
    popup:Hide()
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

ns.UI.RegisterPage("members", function(page)
  local filter, query, showInactive = "all", "", false
  -- Orden: pulsar el título de una columna ordena por ella; otra vez, al revés.
  local sortCol, sortDesc = nil, false
  local W_LIST = 788

  -- Filtros y buscador.
  page.chips = {}
  local x = 0
  for _, f in ipairs(FILTERS) do
    local width = f.id == "addon" and 104 or (f.id == "crafters" or f.id == "officers") and 90 or 80
    local chip = W.Chip(page, f.label, width, function()
      filter = f.id
      page:Refresh()
    end)
    chip:SetPoint("TOPLEFT", x, 0)
    chip.id = f.id
    page.chips[#page.chips + 1] = chip
    x = x + width + 6
  end
  page.search = W.Input(page, 170)
  page.search:SetPoint("TOPRIGHT", -4, 0)
  W.Placeholder(page.search, "nombre...")
  page.search:SetScript("OnTextChanged", function(self)
    query = (self:GetText() or ""):lower()
    page:Refresh()
  end)
  local searchLabel = W.Text(page, "GameFontHighlightSmall")
  searchLabel:SetPoint("RIGHT", page.search, "LEFT", -8, 0)
  searchLabel:SetTextColor(0.6, 0.6, 0.6)
  searchLabel:SetText("Buscar")

  -- Títulos de las columnas: se pueden pulsar para ordenar.
  page.heads = {}
  for _, c in ipairs(COLS) do
    local b = CreateFrame("Button", nil, page)
    b:SetSize(c.w, 16)
    b:SetPoint("TOPLEFT", c.x + 4, -30)
    b.text = W.Text(b, "GameFontNormalSmall")
    b.text:SetPoint("LEFT", 2, 0)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnClick", function()
      if sortCol == c.id then
        sortDesc = not sortDesc
      else
        sortCol, sortDesc = c.id, (c.id == "level")
      end
      page:Refresh()
    end)
    ns.UI.Tip(b, c.label, "Pulsa para ordenar por esta columna; otra vez, al revés.")
    b.col = c
    page.heads[#page.heads + 1] = b
  end
  local line = page:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(W.COLORS.LINE[1], W.COLORS.LINE[2], W.COLORS.LINE[3], 0.6)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 0, -46)
  line:SetPoint("TOPRIGHT", 0, -46)

  page.list = W.List(page, W_LIST, 342, {
    rows = 16, rowHeight = 20, bare = true,
    keyOf = function(item) return item.header and "#inactivos" or item.name end,
    isHeader = function(item) return item.header end,
    onSelect = function(item)
      if item.header then
        showInactive = not showInactive
        page:Refresh()
      end
    end,
    buildRow = function(row)
      row.cols = {}
      for _, c in ipairs(COLS) do
        local t = W.Text(row, "GameFontHighlightSmall")
        t:SetPoint("LEFT", c.x + 2, 0)
        t:SetWidth(c.w)
        t:SetWordWrap(false)
        row.cols[c.id] = t
      end
      row.stripe = row:CreateTexture(nil, "BACKGROUND")
      row.stripe:SetAllPoints()
      row.stripe:SetColorTexture(1, 1, 1, 0.03)
      -- Bocadillo: susurrarle.
      row.tell = CreateFrame("Button", nil, row)
      row.tell:SetSize(18, 18)
      row.tell:SetPoint("RIGHT", -4, 0)
      row.tell.icon = row.tell:CreateTexture(nil, "ARTWORK")
      row.tell.icon:SetAllPoints()
      row.tell.icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
      row.tell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      row.tell:SetScript("OnClick", function(self)
        local item = self:GetParent().item
        if item and item.name then ns.SendTell(item.name) end
      end)
      row.tell:SetScript("OnEnter", function(self)
        local item = self:GetParent().item
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Susurrar")
        if item and item.display then GameTooltip:AddLine(item.display, 1, 1, 1) end
        GameTooltip:Show()
      end)
      row.tell:SetScript("OnLeave", function() GameTooltip:Hide() end)
      -- El grupo plegado de inactivos.
      row.headerText = W.Text(row, "GameFontNormal")
      row.headerText:SetPoint("LEFT", 8, 0)
    end,
    updateRow = function(row, item)
      if item.header then
        for _, t in pairs(row.cols) do t:SetText("") end
        row.tell:Hide()
        row.stripe:SetColorTexture(1, 0.82, 0, 0.08)
        row.stripe:Show()
        row.headerText:SetText(string.format("%s  Sin conectarse más de 3 días (%d)   |cff999999%s|r",
          showInactive and "-" or "+", item.count, showInactive and "pulsa para plegarlos" or "pulsa para verlos"))
        return
      end
      row.headerText:SetText("")
      row.stripe:SetColorTexture(1, 1, 1, 0.03)
      row.stripe:SetShown(item.index % 2 == 0)
      local r, g, b = ns.ClassColor(item.class)
      row.cols.name:SetText(item.display)
      row.cols.class:SetText(item.className or "")
      row.cols.class:SetTextColor(r, g, b)
      row.cols.level:SetText(item.level and tostring(item.level) or "")
      row.cols.role:SetText(item.role)
      row.cols.profs:SetText(item.profs)
      row.cols.addon:SetText(item.addon)
      row.cols.rank:SetText(item.rankName or "")
      row.cols.zone:SetText(item.zone or "")
      if item.online then
        row.cols.seen:SetText("|cff40c040Conectado|r")
      else
        row.cols.seen:SetText("|cff999999" .. ago(item.since) .. "|r")
      end
      row.tell:Show()
      row.tell.icon:SetDesaturated(not item.online)
      row.tell:SetAlpha(item.online and 1 or 0.5)
    end,
  })
  page.list:SetPoint("TOPLEFT", 0, -50)

  -- Abajo: invitar, la ventana del juego y la ayuda.
  page.invite = W.Button(page, "Invitar a miembro", 140, 22, function()
    StaticPopup_Show("HDFPROF_INVITE")
  end)
  page.invite:SetPoint("BOTTOMLEFT", 0, 2)
  page.gameGuild = W.Button(page, "Ventana del juego", 140, 22, function() ns.UI.OpenGameGuild() end)
  page.gameGuild:SetPoint("LEFT", page.invite, "RIGHT", 8, 0)
  ns.UI.Tip(page.gameGuild, "Ventana de hermandad del juego", "La de siempre: rangos, noticias, notas...")
  local hint = W.Text(page, "GameFontHighlightSmall", "RIGHT")
  hint:SetPoint("BOTTOMRIGHT", -4, 8)
  hint:SetTextColor(0.6, 0.6, 0.6)
  hint:SetText("Bocadillo: susurrarle")

  function page:Refresh()
    for _, chip in ipairs(self.chips) do chip:SetOn(chip.id == filter) end
    for _, h in ipairs(self.heads) do
      local on = h.col.id == sortCol
      h.text:SetText(h.col.label .. (on and (sortDesc and " v" or " ^") or ""))
      if on then h.text:SetTextColor(1, 0.82, 0) else h.text:SetTextColor(0.75, 0.7, 0.6) end
    end
    local g = ns.G()
    local now = ns.Now()
    local active, inactive = {}, {}
    for name, info in pairs(ns.Guild.roster) do
      local e = g and g.entries[name]
      local addon, addonState = addonText(e)
      local since = not info.online and info.seen and (now - info.seen) or nil
      local item = {
        name = name, display = displayName(name, info), online = info.online, class = info.class,
        className = info.className, level = info.level, rankName = info.rankName, rank = info.rank,
        zone = info.zone, since = since, role = roleText(e and e.ro), profs = profsText(e),
        addon = addon, hasAddon = addonState > 0, addonState = addonState, crafter = e and type(e.p) == "table" and next(e.p) ~= nil,
      }
      local ok = true
      if filter == "online" then ok = item.online
      elseif filter == "addon" then ok = item.hasAddon
      elseif filter == "crafters" then ok = item.crafter
      elseif filter == "officers" then ok = (item.rank or 9) <= 1 end
      if ok and query ~= "" then
        ok = item.display:lower():find(query, 1, true) ~= nil
      end
      if ok then
        if not item.online and since and since > INACTIVE then
          inactive[#inactive + 1] = item
        else
          active[#active + 1] = item
        end
      end
    end
    local KEY = {
      name = function(x) return x.display:lower() end,
      class = function(x) return (x.className or ""):lower() end,
      level = function(x) return x.level or 0 end,
      role = function(x) return x.role end,
      profs = function(x) return x.profs end,
      addon = function(x) return x.addonState end,
      rank = function(x) return x.rank or 99 end,
      zone = function(x) return (x.zone or ""):lower() end,
      seen = function(x) return x.online and -1 or (x.since or 1e12) end,
    }
    local function order(a, b)
      local key = sortCol and KEY[sortCol]
      if key then
        local ka, kb = key(a), key(b)
        if ka ~= kb then
          if sortDesc then return ka > kb end
          return ka < kb
        end
        return a.display < b.display
      end
      if a.online ~= b.online then return a.online end
      if not a.online and (a.since or 0) ~= (b.since or 0) then return (a.since or 0) < (b.since or 0) end
      if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
      return a.display < b.display
    end
    table.sort(active, order)
    table.sort(inactive, order)
    local items = {}
    for i, it in ipairs(active) do it.index = i; items[#items + 1] = it end
    if #inactive > 0 then
      items[#items + 1] = { header = true, count = #inactive }
      if showInactive or query ~= "" then
        for i, it in ipairs(inactive) do it.index = i; items[#items + 1] = it end
      end
    end
    self.list:SetItems(items)
  end
end)
