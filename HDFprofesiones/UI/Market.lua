-- Página "Mercado": lo que se busca y lo que se ofrece. Sustituye al Tablón, a "Ver pedido" y
-- a Mis pedidos de la 0.29.
-- Arriba: Se busca / Se ofrece, buscar, «+ Pedir» y «+ Ofrecer». Debajo, filtros rápidos y
-- «Filtros ▾». A la izquierda la lista (el mismo objeto pedido por varios se junta en una
-- fila); a la derecha el detalle de lo elegido, con quién lo fabrica.
local _, ns = ...
local W, Data, Guild = ns.W, ns.Data, ns.Guild

local LIST_W, DETAIL_W, BODY_H = 444, 334, 372
local ROWS, ROW_H = 7, 52

-- Filtros rápidos.
local CHIPS = {
  { id = "craft", label = "Puedo hacerlo" },
  { id = "new", label = "Nuevos" },
  { id = "mine", label = "Míos" },
  { id = "involved", label = "Mis encargos" },
}
-- Tipo de objeto (como en la 0.29).
local TYPES = {
  { id = nil, label = "Todo" },
  { id = "mats", label = "Materiales" },
  { id = "cons", label = "Pociones y comida" },
  { id = "bags", label = "Bolsas" },
  { id = "gear", label = "Armas y armaduras" },
  { id = "other", label = "Otros" },
}
local ARMOR = {
  { id = nil, label = "Armadura: toda" },
  { id = 1, label = "Tela" }, { id = 2, label = "Cuero" }, { id = 3, label = "Malla" }, { id = 4, label = "Placas" },
}
local SLOTS = {
  { id = nil, label = "Ranura: todas" },
  { id = "Armas", label = "Armas" }, { id = "Armas a distancia", label = "A distancia" },
  { id = "Escudos y mano izquierda", label = "Escudos" }, { id = "Cabeza", label = "Cabeza" },
  { id = "Cuello y anillos", label = "Cuello y anillos" }, { id = "Hombros", label = "Hombros" },
  { id = "Espalda", label = "Espalda" }, { id = "Pecho", label = "Pecho" }, { id = "Muñecas", label = "Muñecas" },
  { id = "Manos", label = "Manos" }, { id = "Cintura", label = "Cintura" }, { id = "Piernas", label = "Piernas" },
  { id = "Pies", label = "Pies" }, { id = "Abalorios", label = "Abalorios" }, { id = "Bolsas", label = "Bolsas" },
}
local SORTS = {
  { id = "best", label = "Ordenar: lo tuyo primero" },
  { id = "new", label = "Ordenar: nuevos" },
  { id = "rush", label = "Ordenar: prisa" },
  { id = "tip", label = "Ordenar: propina" },
  { id = "karma", label = "Ordenar: karma" },
}
local PROF_FILTER = { 164, 165, 197, 171, 202, 333, 185, 186, 393, 182 }

local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
-- Etiquetas de las filas (de izquierda a derecha).
local TAGS = {
  { icon = "Interface\\Icons\\Trade_BlackSmithing", title = "Ofrecen fabricarlo",
    text = "Lo hacen por encargo: pídeselo.", test = function(it) return it.kind == "craft" end },
  { icon = "Interface\\GossipFrame\\TabardGossipIcon", title = "Pedido de la hermandad",
    text = "Lo ha puesto un oficial y pueden aportar varios.", test = function(it) return it.kind == "need" end },
  { icon = "Interface\\GossipFrame\\AvailableQuestIcon", title = "Prioridad",
    text = "Un oficial lo ha puesto arriba del todo.", test = function(it) return it.priority == true end },
  { icon = "Interface\\Icons\\INV_Scroll_03", title = "Pedido de Blizzard",
    text = "Hecho en la mesa de pedidos del juego: se coge en tu profesión.", test = function(it) return it.kind == "co" end },
  { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", title = "Nuevo",
    text = "Ha salido desde la última vez que miraste el Mercado.", test = function(it) return it.new == true end },
  { icon = "Interface\\Icons\\INV_Misc_Note_01", title = "Tuyo",
    text = "Lo has puesto tú.", test = function(it) return it.mine == true end },
}
local MAX_TAGS = 3
local RUSH_ICON = "Interface\\Icons\\Spell_Holy_BorrowedTime"

local STATE_COLOR = {
  open = "|cffffd100", accepted = "|cff66ccff", done = "|cff40ff40", closed = "|cff999999", expired = "|cff999999",
}

local function settings()
  local s = ns.db.settings
  s.market = s.market or {}
  local m = s.market
  m.type, m.armor, m.slot, m.sort = m.type or 1, m.armor or 1, m.slot or 1, m.sort or 1
  return m
end

-- Lo que me queda por enviar de un pedido que acepté (0 si nada).
local function toSend(r, me, now)
  local cm = r.a ~= me and r.c and r.c[me]
  if not cm or not Data.CommitActive(cm, now, r) then return 0 end
  return math.max(0, (cm.n or 0) - Data.DeliveredOf(cm))
end

local function payText(r)
  local parts = {}
  if r.g then parts[#parts + 1] = ns.FormatMoney(r.g) end
  if r.pi then
    local ids = {}
    for id in pairs(r.pi) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do parts[#parts + 1] = r.pi[id] .. "x " .. ns.KeyLabel("i" .. id) end
  end
  return #parts > 0 and table.concat(parts, " + ") or nil
end

-- Materiales que hacen falta para toda la petición (primera variante conocida).
local function neededMaterials(r)
  local rec = Data.GetIndex()[r.k]
  local profs = {}
  if r.pk then profs[#profs + 1] = r.pk end
  if rec then
    for pk in pairs(rec.profs) do
      if pk ~= r.pk then profs[#profs + 1] = pk end
    end
  end
  for _, pk in ipairs(profs) do
    local ik = Data.InfoKey(pk, r.k)
    local info = Data.GetInfo(ik)
    local var = info and info.v and info.v[1]
    if var then
      local times = math.ceil(r.q / math.max(1, var.m or 1))
      local ids, parts = {}, {}
      for id in pairs(var.r) do ids[#ids + 1] = id end
      table.sort(ids)
      for _, id in ipairs(ids) do parts[#parts + 1] = (var.r[id] * times) .. "x " .. ns.KeyName("i" .. id) end
      return table.concat(parts, ", ")
    end
    if rec then ns.Sync.AskInfo(ik) end
  end
end

-- Pasos de un pedido: pedido → aceptado → enviado → entregado. Devuelve el texto con el paso
-- en el que está encendido.
local STEPS = { "Pedido", "Aceptado", "Enviado", "Entregado" }
local function stepsText(r, info)
  local step = 1
  if info.state == "done" then
    step = 4
  elseif info.owner or info.pending > 0 then
    step = 2
    for _, c in ipairs(info.commits or {}) do
      if (c.mailed or 0) > 0 or (c.delivered or 0) > 0 then step = 3 end
    end
  end
  if info.state == "closed" or info.state == "expired" then
    return "|cff999999" .. (Data.STATE_LABEL[info.state] or info.state) .. "|r"
  end
  local parts = {}
  for i, label in ipairs(STEPS) do
    if i < step then
      parts[i] = "|cff40ff40" .. label .. "|r"
    elseif i == step then
      parts[i] = "|cffffffff[" .. label .. "]|r"
    else
      parts[i] = "|cff777777" .. label .. "|r"
    end
  end
  return table.concat(parts, " |cff999999›|r ")
end
ns.UI.RequestSteps = stepsText

-- Cuándo caduca algo, en corto ("caduca en 2 d"); en rojo si queda menos de un día.
local function expiresText(at, now)
  if not at then return nil end
  local left = at - now
  if left <= 0 then return "|cffff4040caducado|r" end
  local color = left < 86400 and "|cffff4040" or "|cffbbbbbb"
  return color .. "caduca en " .. ns.FormatDuration(left) .. "|r"
end

-- Pedidos que ya terminaron y en los que estuve (los míos o los que hice): el historial.
local function endedItems(g, me, now)
  local out = {}
  for _, r in pairs(g.requests) do
    local info = Data.RequestInfo(r, now)
    if not Data.IsActiveState(info.state) and (r.a == me or (r.c and r.c[me])) then
      out[#out + 1] = {
        kind = "req", id = r.id, k = r.k, author = r.a, t = r.t or 0, r = r, info = info, me = me, now = now,
        mine = r.a == me, pending = 0, karma = Data.KarmaFor(r.a), ended = true,
      }
    end
  end
  return out
end

ns.UI.RegisterPage("market", function(page)
  local state = { side = "want", chip = nil, search = "", expanded = {}, selected = nil, showFilters = false }
  page.state = state

  -----------------------------------------------------------------------
  -- Fila 1: Se busca / Se ofrece, buscar, + Pedir y + Ofrecer.
  -----------------------------------------------------------------------
  page.want = W.Chip(page, "Se busca", 116, function() page:SetSide("want") end)
  page.want:SetPoint("TOPLEFT", 0, -2)
  page.offer = W.Chip(page, "Se ofrece", 116, function() page:SetSide("offer") end)
  page.offer:SetPoint("LEFT", page.want, "RIGHT", 2, 0)

  page.search = W.Input(page, 200)
  page.search:SetPoint("LEFT", page.offer, "RIGHT", 16, 0)
  page.search.hdfLink = true
  W.Placeholder(page.search, "Buscar objeto o persona…")
  page.search:HookScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    -- Un enlace pegado con mayús+clic se busca por su nombre.
    local name = text:match("|h%[(.-)%]|h")
    if name then
      self:SetText(name)
      return
    end
    state.search = text:lower()
    page:Refresh()
  end)

  -- Arrastrar un objeto a «+ Pedir» o «+ Ofrecer» lo deja ya elegido.
  local function cursorItem()
    if not GetCursorInfo then return nil end
    local kind, id = GetCursorInfo()
    if kind == "item" and id then
      if ClearCursor then ClearCursor() end
      return tonumber(id)
    end
  end
  page.addOffer = W.Button(page, "+ Ofrecer", 104, 24, function()
    local id = cursorItem()
    if id then ns.UI.OpenOfferDialog(id) else ns.UI.OpenAsk("offer") end
  end)
  page.addOffer:SetPoint("TOPRIGHT", 0, 0)
  page.addOffer:SetScript("OnReceiveDrag", function()
    local id = cursorItem()
    if id then ns.UI.OpenOfferDialog(id) end
  end)
  page.addAsk = W.Button(page, "+ Pedir", 104, 24, function()
    local id = cursorItem()
    if id then ns.UI.AskFor("i" .. id) else ns.UI.OpenAsk("ask") end
  end)
  page.addAsk:SetPoint("RIGHT", page.addOffer, "LEFT", -6, 0)
  page.addAsk:SetScript("OnReceiveDrag", function()
    local id = cursorItem()
    if id then ns.UI.AskFor("i" .. id) end
  end)
  ns.UI.Tip(page.addAsk, "+ Pedir", "Elige qué pedir en el catálogo, o arrastra aquí un objeto de tus bolsas.")
  ns.UI.Tip(page.addOffer, "+ Ofrecer", "Elige qué ofrecer de tus bolsas (o arrastra aquí el objeto), o qué recetas "
    .. "tuyas ofreces fabricar.")

  -----------------------------------------------------------------------
  -- Fila 2: filtros rápidos, «Filtros ▾» y ordenar.
  -----------------------------------------------------------------------
  page.chips = {}
  for i, c in ipairs(CHIPS) do
    local b = W.Chip(page, c.label, 112, function()
      state.chip = (state.chip ~= c.id) and c.id or nil
      state.selected = nil
      page:Refresh()
    end)
    b:SetPoint("TOPLEFT", (i - 1) * 114, -30)
    page.chips[c.id] = b
  end
  page.filtersButton = W.Chip(page, "Filtros »", 92, function()
    state.showFilters = not state.showFilters
    page:Refresh()
  end)
  page.filtersButton:SetPoint("TOPLEFT", 4 * 114, -30)
  page.sortButton = W.Button(page, "", 184, 22, function()
    local m = settings()
    m.sort = m.sort % #SORTS + 1
    page:Refresh()
  end)
  page.sortButton:SetPoint("TOPRIGHT", 0, -30)

  -----------------------------------------------------------------------
  -- Lista
  -----------------------------------------------------------------------
  -- Etiquetas de la fila: iconos pequeños que se explican al pasar el ratón.
  local function rowTags(item)
    local tags = {}
    for _, t in ipairs(TAGS) do
      if t.test(item) then tags[#tags + 1] = t end
    end
    return tags
  end

  local function rowSub(item)
    local now = item.now or ns.Now()
    if item.kind == "group" then
      local names = {}
      for i = 1, math.min(3, #item.children) do names[i] = ns.WhoColored(item.children[i].author) end
      return string.format("|cffffffff%d pedidos|r · %s%s", #item.children, table.concat(names, ", "),
        #item.children > 3 and "…" or "")
    end
    local parts = { ns.WhoColored(item.author), ns.FormatDuration(now - (item.t or now)) }
    if item.kind == "req" then
      local r, info = item.r, item.info
      if item.pending > 0 then
        local by = r.c[item.me].by
        parts[#parts + 1] = by and ("|cff66ccfftu plazo: " .. ns.FormatDuration(math.max(0, by - now)) .. "|r")
          or "|cff66ccffpor enviar|r"
      elseif info.owner then
        parts[#parts + 1] = "lo hace " .. ns.ShortName(info.owner)
      end
      if info.delivered > 0 and info.delivered < r.q then
        parts[#parts + 1] = string.format("|cff40ff40%d/%d entregadas|r", info.delivered, r.q)
      end
      if item.mine and not item.ended then parts[#parts + 1] = expiresText(info.expires, now) end
      if item.ended then parts[#parts + 1] = STATE_COLOR[info.state] .. (Data.STATE_LABEL[info.state] or "") .. "|r" end
    elseif item.kind == "offer" then
      local o = item.o
      parts[#parts + 1] = ns.UI.PriceText(o.g)
      if item.mine and #o.claims > 0 then
        parts[#parts + 1] = "|cff66ccfflo quieren " .. #o.claims .. "|r"
      elseif o.free <= 0 then
        parts[#parts + 1] = "|cffff9933todo pedido|r"
      end
      if item.mine then parts[#parts + 1] = expiresText((o.t or 0) + ns.Offers.OFFER_TTL, now) end
    elseif item.kind == "craft" then
      local cr, names, cheapest = item.craft.crafters, {}, nil
      for i = 1, math.min(2, #cr) do names[i] = cr[i].name == item.me and "|cffffd100tú|r" or ns.WhoColored(cr[i].name) end
      for _, c in ipairs(cr) do
        if not cheapest or (c.g or 0) < cheapest then cheapest = c.g or 0 end
      end
      parts = { "lo fabrica" .. (#cr > 1 and "n " or " ") .. table.concat(names, ", ")
        .. (#cr > 2 and string.format(" y %d más", #cr - 2) or ""), ns.UI.PriceText(cheapest) }
      if item.mine then parts[#parts + 1] = expiresText((item.craft.myT or 0) + ns.Offers.CRAFT_TTL, now) end
    elseif item.kind == "need" then
      local n = item.need
      parts[#parts + 1] = string.format("aportado %d de %d", n.given, n.q)
    elseif item.kind == "co" then
      parts[#parts + 1] = "se coge en tu profesión"
    end
    if item.canServe and item.pending == 0 then parts[#parts + 1] = "|cff40ff40puedes hacerlo|r" end
    return table.concat(parts, " |cff666666·|r ")
  end

  local function rowQty(item)
    if item.kind == "req" then return item.ended and item.r.q or item.info.remaining end
    if item.kind == "offer" then return item.o.free > 0 and item.o.free or item.o.q end
    if item.kind == "need" then return item.need.left end
    if item.kind == "group" then return item.total end
  end

  local list = W.List(page, LIST_W, BODY_H, {
    rows = ROWS,
    rowHeight = ROW_H,
    keyOf = function(item) return item.id end,
    buildRow = function(row)
      row.pin = row:CreateTexture(nil, "BACKGROUND")
      row.pin:SetPoint("TOPLEFT")
      row.pin:SetPoint("BOTTOMLEFT")
      row.pin:SetWidth(3)
      row.pin:SetColorTexture(1, 0.5, 0.1, 0.9)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(36, 36)
      row.icon:SetPoint("LEFT", 8, 0)
      row.qty = row:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
      row.qty:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)
      row.title = W.ListText(row, "GameFontHighlight")
      row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
      row.title:SetPoint("RIGHT", row, "RIGHT", -44, 0)
      row.title:SetWordWrap(false)
      row.sub = W.ListText(row, "GameFontHighlightSmall")
      row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row.sub:SetWordWrap(false)
      row.coin = row:CreateTexture(nil, "ARTWORK")
      row.coin:SetSize(16, 16)
      row.coin:SetPoint("TOPRIGHT", -4, -6)
      row.coin:SetTexture(COIN_ICON)
      row.rush = row:CreateTexture(nil, "ARTWORK")
      row.rush:SetSize(16, 16)
      row.rush:SetPoint("RIGHT", row.coin, "LEFT", -2, 0)
      row.rush:SetTexture(RUSH_ICON)
      row.tags = {}
      for i = 1, MAX_TAGS do
        local tb = CreateFrame("Button", nil, row)
        tb:SetSize(16, 16)
        tb.tex = tb:CreateTexture(nil, "ARTWORK")
        tb.tex:SetAllPoints()
        tb:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText(self.def.title)
          GameTooltip:AddLine(self.def.text, 1, 1, 1, true)
          GameTooltip:Show()
        end)
        tb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Pulsar la etiqueta es pulsar la fila.
        tb:SetScript("OnClick", function() row:Click() end)
        tb:Hide()
        row.tags[i] = tb
      end
      row.arrow = W.Text(row, "GameFontNormal")
      row.arrow:SetPoint("RIGHT", -6, 0)
      W.KeyTooltip(row, function(self) return self.item and self.item.k end)
    end,
    updateRow = function(row, item)
      local _, icon = ns.KeyInfo(item.k)
      row.icon:SetTexture(icon)
      local q = rowQty(item)
      row.qty:SetText(q and q > 1 and tostring(q) or "")
      row.title:SetText(ns.KeyLabel(item.k))
      -- Iconos a la derecha del título: etiquetas, y propina y prisa en los pedidos.
      local tags = item.kind == "group" and {} or rowTags(item)
      local x = -4
      local r = item.r
      local coin = item.kind == "req" and r ~= nil and (r.g ~= nil or r.pi ~= nil)
      local rush = item.kind == "req" and r ~= nil and r.pr ~= nil
      row.coin:SetShown(coin)
      row.rush:SetShown(rush)
      for _, tex in ipairs({ coin and row.coin, rush and row.rush }) do
        if tex then
          tex:ClearAllPoints()
          tex:SetPoint("TOPRIGHT", x, -6)
          x = x - 18
        end
      end
      for i, tb in ipairs(row.tags) do
        local t = tags[i]
        tb:SetShown(t ~= nil)
        if t then
          tb.tex:SetTexture(t.icon)
          tb.def = t
          tb:ClearAllPoints()
          tb:SetPoint("TOPRIGHT", x, -6)
          x = x - 18
        end
      end
      row.title:SetPoint("RIGHT", row, "RIGHT", math.min(-44, x - 2), 0)
      row.sub:SetText(rowSub(item))
      row.pin:SetShown(item.kind == "need" or item.priority == true)
      if item.kind == "group" then
        row.arrow:SetText(state.expanded[item.k] and "-" or "+")
        row.coin:Hide()
        row.rush:Hide()
      else
        row.arrow:SetText("")
      end
      -- Los pedidos dentro de un grupo abierto, un poco metidos hacia dentro.
      row.icon:SetPoint("LEFT", item.child and 22 or 8, 0)
    end,
    onSelect = function(item)
      if item.kind == "group" then
        state.expanded[item.k] = not state.expanded[item.k]
        state.selected = state.expanded[item.k] and item.children[1].id or nil
      else
        state.selected = item.id
      end
      page:Refresh()
    end,
  })
  list:SetPoint("TOPLEFT", 0, -58)
  page.list = list

  page.empty = W.Text(page, "GameFontNormal", "CENTER")
  page.empty:SetPoint("CENTER", list, "CENTER", 0, 24)
  page.empty:SetWidth(LIST_W - 40)
  page.empty:SetTextColor(0.7, 0.7, 0.7)
  page.emptyButton = W.Button(page, "", 160, 24)
  page.emptyButton:SetPoint("TOP", page.empty, "BOTTOM", 0, -12)

  -----------------------------------------------------------------------
  -- Filtros ▾ (encima de la lista)
  -----------------------------------------------------------------------
  local fbox = W.Box(page, LIST_W, 196)
  fbox:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
  fbox:SetFrameLevel(list:GetFrameLevel() + 10)
  if fbox.SetBackdropColor then fbox:SetBackdropColor(0.05, 0.045, 0.04, 0.97) end
  fbox:Hide()
  page.filterBox = fbox
  local function label(text, y)
    local fs = W.Text(fbox, "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 12, y)
    fs:SetText(text)
    return fs
  end
  label("Tipo", -10)
  fbox.types = {}
  for i, t in ipairs(TYPES) do
    local b = W.Chip(fbox, t.label, i == 4 and 70 or (i == 3 or i == 5) and 128 or 84, function()
      settings().type = i
      page:Refresh()
    end)
    if i == 1 then b:SetPoint("TOPLEFT", 10, -24) elseif i == 4 then b:SetPoint("TOPLEFT", 10, -48)
    else b:SetPoint("LEFT", fbox.types[i - 1], "RIGHT", 2, 0) end
    fbox.types[i] = b
  end
  label("Profesión (quién lo fabrica)", -76)
  fbox.profs = {}
  for i, pk in ipairs(PROF_FILTER) do
    local b = CreateFrame("Button", nil, fbox)
    b:SetSize(26, 26)
    b:SetPoint("TOPLEFT", 10 + (i - 1) * 30, -90)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexture(ns.ProfessionIcon(pk))
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function()
      local m = settings()
      m.prof = (m.prof ~= pk) and pk or nil
      page:Refresh()
    end)
    ns.UI.Tip(b, ns.ProfessionName(pk))
    b.pk = pk
    fbox.profs[i] = b
  end
  label("Equipo", -122)
  -- Ranuras: se pueden marcar varias a la vez (como el filtro de la ventana de profesión).
  -- m.slots = nil son todas; si no, las marcadas.
  fbox.slot = W.Button(fbox, "", 140, 22, function()
    state.slotMenu = true
    page:Refresh()
  end)
  fbox.slot:SetPoint("TOPLEFT", 10, -136)
  -- Ocupa el sitio del cuadro de filtros mientras se eligen (así no tapa nada); «‹ Volver» regresa.
  local menu = W.Box(page, LIST_W, 196)
  menu:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
  menu:SetFrameLevel(list:GetFrameLevel() + 12)
  if menu.SetBackdropColor then menu:SetBackdropColor(0.05, 0.045, 0.04, 0.98) end
  menu:Hide()
  fbox.slotMenu = menu
  local function setAll(on)
    settings().slots = (not on) and {} or nil
    page:Refresh()
  end
  menu.all = W.Button(menu, "Marcar todo", 136, 20, function() setAll(true) end)
  menu.all:SetPoint("TOPLEFT", 10, -8)
  menu.none = W.Button(menu, "Desmarcar todo", 136, 20, function() setAll(false) end)
  menu.none:SetPoint("LEFT", menu.all, "RIGHT", 6, 0)
  menu.back = W.Button(menu, "‹ Volver", 90, 20, function()
    state.slotMenu = nil
    page:Refresh()
  end)
  menu.back:SetPoint("TOPRIGHT", -8, -8)
  menu.checks = {}
  for i = 2, #SLOTS do
    local s = SLOTS[i]
    local n = i - 2
    local cb = W.Check(menu, s.label, function(on)
      local m = settings()
      local set = m.slots
      if not set then
        set = {}
        for j = 2, #SLOTS do set[SLOTS[j].id] = true end
      end
      set[s.id] = on or nil
      local all = true
      for j = 2, #SLOTS do if not set[SLOTS[j].id] then all = false end end
      m.slots = (not all) and set or nil
      page:Refresh()
    end)
    cb:SetPoint("TOPLEFT", 8 + math.floor(n / 5) * 146, -36 - (n % 5) * 22)
    cb.slotId = s.id
    menu.checks[#menu.checks + 1] = cb
  end
  fbox.armor = W.Button(fbox, "", 130, 22, function()
    local m = settings()
    m.armor = m.armor % #ARMOR + 1
    page:Refresh()
  end)
  fbox.armor:SetPoint("LEFT", fbox.slot, "RIGHT", 4, 0)
  fbox.level = W.Check(fbox, "Hasta mi nivel", function(on) settings().myLevel = on or nil page:Refresh() end)
  fbox.level:SetPoint("LEFT", fbox.armor, "RIGHT", 6, 0)
  fbox.tip = W.Check(fbox, "Con propina", function(on) settings().tip = on or nil page:Refresh() end)
  fbox.tip:SetPoint("TOPLEFT", 8, -164)
  fbox.rush = W.Check(fbox, "Corre prisa", function(on) settings().rush = on or nil page:Refresh() end)
  fbox.rush:SetPoint("LEFT", fbox.tip, "RIGHT", 90, 0)
  fbox.ended = W.Check(fbox, "Terminados", function(on) state.ended = on or nil page:Refresh() end)
  fbox.ended:SetPoint("LEFT", fbox.rush, "RIGHT", 90, 0)
  fbox.clear = W.Button(fbox, "Quitar filtros", 100, 20, function()
    local m = settings()
    m.type, m.armor, m.slot, m.prof, m.myLevel, m.tip, m.rush = 1, 1, 1, nil, nil, nil, nil
    m.slots = nil
    state.ended = nil
    page:Refresh()
  end)
  fbox.clear:SetPoint("TOPRIGHT", -8, -8)

  -----------------------------------------------------------------------
  -- Detalle (derecha)
  -----------------------------------------------------------------------
  local detail = W.Box(page, DETAIL_W, BODY_H)
  detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0)
  page.detail = detail
  detail.icon = CreateFrame("Button", nil, detail)
  detail.icon:SetSize(40, 40)
  detail.icon:SetPoint("TOPLEFT", 10, -10)
  detail.iconTex = detail.icon:CreateTexture(nil, "ARTWORK")
  detail.iconTex:SetAllPoints()
  W.KeyTooltip(detail.icon, function() return detail.item and detail.item.k end)
  detail.title = W.Text(detail, "GameFontNormal")
  detail.title:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 8, -2)
  detail.title:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.title:SetWordWrap(false)
  detail.sub = W.Text(detail, "GameFontHighlightSmall")
  detail.sub:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -4)
  detail.sub:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.sub:SetWordWrap(false)
  detail.steps = W.Text(detail, "GameFontHighlightSmall")
  detail.steps:SetPoint("TOPLEFT", 12, -58)
  detail.steps:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.info = W.Text(detail, "GameFontHighlightSmall")
  detail.info:SetPoint("TOPLEFT", 12, -76)
  detail.info:SetSize(DETAIL_W - 24, 96)
  detail.info:SetJustifyV("TOP")
  detail.info:SetSpacing(1)
  detail.whoLabel = W.Text(detail, "GameFontNormalSmall")
  detail.whoLabel:SetPoint("TOPLEFT", 12, -174)
  detail.crafters = W.Crafters(detail, DETAIL_W - 16, 4)
  detail.crafters:SetPoint("TOPLEFT", 8, -188)

  -- b1 es la acción principal (grande, abajo); b2, b3, x1, x2 y x3, pequeñas, encima en filas de 3.
  detail.b1 = W.Button(detail, "", DETAIL_W - 16, 28)
  detail.b1:SetPoint("BOTTOMLEFT", 8, 8)
  if detail.b1.SetNormalFontObject then detail.b1:SetNormalFontObject("GameFontNormalLarge") end
  if detail.b1.SetHighlightFontObject then detail.b1:SetHighlightFontObject("GameFontHighlightLarge") end
  if detail.b1.SetDisabledFontObject then detail.b1:SetDisabledFontObject("GameFontDisableLarge") end
  detail.small = {}
  for _, key in ipairs({ "b2", "b3", "x1", "x2", "x3" }) do
    detail[key] = W.Button(detail, "", 104, 20)
    detail.small[#detail.small + 1] = detail[key]
  end
  -- Coloca las pequeñas que se ven, de izquierda a derecha y de abajo arriba.
  function detail:LayoutButtons()
    local n = 0
    for _, b in ipairs(self.small) do
      if b:IsShown() then
        local col, line = n % 3, math.floor(n / 3)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", self.b1, "TOPLEFT", col * 108, 3 + line * 22)
        n = n + 1
      end
    end
  end
  for _, b in ipairs({ detail.b1, detail.b2, detail.b3, detail.x1, detail.x2, detail.x3 }) do
    if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
    b:SetScript("OnEnter", function(self)
      if not self.tip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  detail.empty = W.Text(detail, "GameFontNormal", "CENTER")
  detail.empty:SetPoint("CENTER", 0, 20)
  detail.empty:SetWidth(DETAIL_W - 40)
  detail.empty:SetTextColor(0.6, 0.6, 0.6)

  local function setButton(b, text, enabled, onClick, tipText)
    if not text then
      b:Hide()
      return
    end
    b:SetText(text)
    b:SetEnabled(enabled and true or false)
    b:SetScript("OnClick", onClick)
    b.tip = tipText
    b:Show()
  end

  local function setWho(key, withGatherers, labelText)
    local rows = ns.UI.CrafterRows and ns.UI.CrafterRows(key, withGatherers) or {}
    detail.whoLabel:SetText(#rows > 0 and labelText or (labelText .. ": |cffff8040nadie de la hermandad lo tiene publicado|r"))
    detail.crafters:SetItems(rows)
    detail.whoLabel:Show()
    detail.crafters:Show()
  end

  -- Pedido normal.
  local function showRequest(item)
    local r, now, me = item.r, ns.Now(), ns.Me()
    local info = Data.RequestInfo(r, now)
    local _, _, link = ns.KeyInfo(r.k)
    detail.title:SetText(string.format("%dx %s", r.q, link or ns.KeyName(r.k)))
    detail.sub:SetText("pide " .. ns.WhoColored(r.a) .. " |cffbbbbbb(karma " .. Data.KarmaText(r.a) .. ") · hace "
      .. ns.FormatDuration(now - (r.t or now)) .. "|r")
    detail.steps:SetText(stepsText(r, info))
    local lines = {}
    if info.moderated then lines[#lines + 1] = "|cffff8040Lo ha cerrado un oficial.|r" end
    if ns.Social.IsPriority(r.id) then lines[#lines + 1] = "|cffff80ffPrioridad de la hermandad.|r" end
    if Data.IsActiveState(info.state) then
      lines[#lines + 1] = string.format("Entregadas: %d de %d   %s", info.delivered, r.q, expiresText(info.expires, now) or "")
    end
    lines[#lines + 1] = r.m and "Materiales: |cff40ff40los pone quien pide|r" or "Materiales: |cffffd100los pone quien fabrica|r"
    local needed = neededMaterials(r)
    if needed then lines[#lines + 1] = "|cffbbbbbbHace falta: " .. needed .. "|r" end
    lines[#lines + 1] = "Propina: " .. (payText(r) or "|cffbbbbbbninguna|r")
    lines[#lines + 1] = "Prisa: " .. (r.pr and ("|cffff9933" .. Data.WHEN[r.pr].need .. "|r") or "sin prisa")
    if info.owner then
      local cm = r.c[info.owner]
      local w = cm.w and Data.WHEN[cm.w]
      lines[#lines + 1] = "Lo hace: " .. ns.WhoColored(info.owner) .. (w and (" (" .. w.label:lower() .. ")") or "")
        .. (cm.by and (", plazo " .. ns.FormatDuration(math.max(0, cm.by - now))) or "")
    end
    if not item.mine then
      local mats = ns.UI.MaterialsStatus(r, item.pending > 0 and item.pending or info.remaining)
      if mats then lines[#lines + 1] = mats end
    end
    local mineCommit = r.c and r.c[me]
    if mineCommit and Data.CommitActive(mineCommit, now, r) then
      lines[#lines + 1] = string.format("|cff40ff40Envíale %d por correo a %s: se completa solo.|r",
        mineCommit.n - Data.DeliveredOf(mineCommit), ns.ShortName(r.a))
    end
    if r.demo then lines[#lines + 1] = "|cffff8040Pedido de ejemplo: acéptalo y pulsa «Enviar (ejemplo)».|r" end
    detail.info:SetText(table.concat(lines, "\n"))
    setWho(r.k, true, "Quién lo fabrica")

    local active = Data.IsActiveState(info.state)
    local officer = ns.Social.AmOfficer() and active
    if r.a == me then
      -- Mi pedido: recibido en mano, renovar, borrar.
      local target
      for _, c in ipairs(info.commits) do
        if c.active then
          if target then target = nil break end -- hay varios: se elige en el aviso de correo
          target = c
        end
      end
      setButton(detail.b1, "Recibido", active and target ~= nil, function()
        local left = math.max(1, (target.pending > 0) and target.pending or (r.q - info.delivered))
        local byMail = target.mailed or 0
        local text = byMail > 0
          and string.format("%s ya te ha enviado %d por correo (contado). ¿Cuántos MÁS te ha dado en mano?",
            ns.ShortName(target.name), byMail)
          or string.format("¿Cuántos te ha dado %s en mano? (lo del correo se cuenta solo)", ns.ShortName(target.name))
        W.AskAmount(text, left, function(n) ns.Sync.ConfirmDelivery(r.id, target.name, n) end)
      end, "Apunta lo que te han dado en mano. Lo del correo se cuenta solo.")
      setButton(detail.b2, "Renovar", active or info.state == "expired", function() ns.Sync.Renew(r.id) end,
        "Vuelve a contar los 7 días desde ahora.")
      setButton(detail.b3, "Borrar pedido", active or info.state == "expired", function()
        W.Confirm("¿Borrar este pedido? Desaparecerá del Mercado de todos.", function() ns.Sync.Close(r.id) end)
      end)
      setButton(detail.x1, active and "Anunciar" or nil, true, function()
        if ns.Extras.Announce("request", r, r.id) then ns.Print("anunciado en el chat de hermandad.") end
      end, "Anunciarlo en el chat de hermandad (para los que no tienen el addon).")
    else
      local myActive = mineCommit and Data.CommitActive(mineCommit, now, r)
      if myActive then
        setButton(detail.b1, "Más tiempo", #Data.ExtendOptions(r, now) > 0, function() W.ExtendRequest(r) end,
          "Pedir un plazo más largo (solo una vez).")
      else
        setButton(detail.b1, "Aceptar encargo", info.state == "open" and not info.owner, function() W.AcceptRequest(r) end,
          "Te lo quedas tú y dices cuándo lo tendrás.")
      end
      if r.demo and myActive and mineCommit.n > Data.DeliveredOf(mineCommit) then
        setButton(detail.b2, "Enviar (ejemplo)", true, function() ns.Demo.SimulateMail(r) end)
      elseif myActive then
        local can = ns.Mail.CanPrepare()
        setButton(detail.b2, "Preparar correo", can, function() ns.Mail.Prepare(r, mineCommit.n - Data.DeliveredOf(mineCommit)) end,
          not can and "Abre el buzón para preparar el correo." or nil)
      else
        setButton(detail.b2, nil)
      end
      setButton(detail.b3, "Susurrar", true, function() ns.SendTell(r.a) end)
      setButton(detail.x1, myActive and "Soltar" or nil, true, function()
        W.Confirm("¿Seguro que ya no lo vas a hacer?", function() ns.Sync.Release(r.id) end)
      end, "Lo dejas y vuelve al Mercado para otro.")
    end
    if officer then
      local isPri = ns.Social.IsPriority(r.id)
      setButton(detail.x2, isPri and "Quitar prioridad" or "Prioridad", true,
        function() ns.Social.SetPriority(r.id, not isPri, ns.Now()) end, "Solo oficiales: lo pone arriba del todo.")
      setButton(detail.x3, r.a ~= me and "Cerrar (oficial)" or nil, true, function()
        W.Confirm("¿Cerrar este pedido de " .. ns.ShortName(r.a) .. " como oficial?", function()
          ns.Social.ModClose(r.id, ns.Now())
        end)
      end)
    else
      setButton(detail.x2, nil)
      setButton(detail.x3, nil)
    end
  end

  -- Oferta.
  local function showOffer(item)
    local o, now = item.o, ns.Now()
    local _, _, link = ns.KeyInfo(item.k)
    detail.title:SetText(string.format("%dx %s", o.q, link or ns.KeyName(item.k)))
    detail.sub:SetText("ofrece " .. ns.WhoColored(o.owner) .. " |cffbbbbbb(karma " .. Data.KarmaText(o.owner) .. ") · hace "
      .. ns.FormatDuration(now - (o.t or now)) .. "|r")
    detail.steps:SetText("Precio: " .. ns.UI.PriceText(o.g) .. "   " .. (expiresText((o.t or 0) + ns.Offers.OFFER_TTL, now) or ""))
    local lines = {}
    lines[#lines + 1] = o.free > 0 and string.format("Quedan |cffffffff%d|r libres de %d.", o.free, o.q)
      or "|cffff9933Ya está todo pedido.|r"
    if item.mine then
      if #o.claims > 0 then
        lines[#lines + 1] = "|cff66ccffLo quieren:|r"
        for _, c in ipairs(o.claims) do lines[#lines + 1] = "  " .. ns.WhoColored(c.name) .. " " .. c.left end
        lines[#lines + 1] = "|cffbbbbbbMándaselo por correo: se apunta solo.|r"
      else
        lines[#lines + 1] = "|cff999999Nadie lo ha pedido todavía.|r"
      end
    elseif item.claimed then
      lines[#lines + 1] = string.format("|cff66ccffHas pedido %d. %s te lo mandará por correo.|r", o.myClaim, ns.ShortName(o.owner))
    else
      local have = ns.Scan.Have(o.id)
      if have > 0 then lines[#lines + 1] = string.format("|cffbbbbbbTienes %d.|r", have) end
    end
    detail.info:SetText(table.concat(lines, "\n"))
    detail.whoLabel:Hide()
    detail.crafters:Hide()
    if item.mine then
      local first = o.claims[1]
      if first then
        local can = ns.Mail.CanPrepare()
        setButton(detail.b1, "Preparar correo", can, function() ns.Mail.PrepareOffer(first.name, o.id, first.left, o.g) end,
          not can and "Abre el buzón para preparar el correo." or nil)
      else
        setButton(detail.b1, "Anunciar", true, function()
          if ns.Extras.Announce("offer", o, o.key) then ns.Print("oferta anunciada en el chat de hermandad.") end
        end, "Anunciarla en el chat de hermandad (para los que no tienen el addon).")
      end
      setButton(detail.b2, "Quitar oferta", true, function()
        W.Confirm("¿Quitar esta oferta?", function() ns.Offers.Remove(o.id) end)
      end)
      setButton(detail.b3, "Editar", true, function()
        ns.UI.OpenOfferDialog(o.id, o.q, nil, { edit = true, price = o.g })
      end, "Cambiar la cantidad o el precio.")
    elseif item.claimed then
      setButton(detail.b1, "Ya no lo quiero", true, function() ns.Offers.Unclaim(o.key) end)
      setButton(detail.b2, "Susurrar", true, function() ns.SendTell(o.owner) end)
      setButton(detail.b3, nil)
    else
      setButton(detail.b1, "Lo quiero", o.free > 0, function()
        if o.free <= 1 then
          ns.Offers.Claim(o.key, 1, ns.Now())
        else
          W.AskAmount(string.format("¿Cuántos quieres? (quedan %d)", o.free), 1, function(n)
            local ok, err = ns.Offers.Claim(o.key, n, ns.Now())
            if not ok and err then ns.Print(err) end
          end)
        end
      end)
      setButton(detail.b2, "Susurrar", true, function() ns.SendTell(o.owner) end)
      setButton(detail.b3, nil)
    end
    setButton(detail.x1, nil)
    setButton(detail.x2, nil)
    setButton(detail.x3, nil)
  end

  -- Ofrecen fabricarlo (una fila con todos los que lo ofrecen).
  local function showCraft(item)
    local grp, me, now = item.craft, ns.Me(), ns.Now()
    local _, _, link = ns.KeyInfo(item.k)
    detail.title:SetText(link or ns.KeyName(item.k))
    local n = #grp.crafters
    detail.sub:SetText(n == 1 and ("ofrece fabricarlo " .. ns.WhoColored(grp.crafters[1].name))
      or string.format("ofrecen fabricarlo |cffffffff%d|r personas", n))
    detail.steps:SetText(grp.mine and (expiresText((grp.myT or 0) + ns.Offers.CRAFT_TTL, now) or "")
      or "Pídeselo y te lo fabrican.")
    local lines = {}
    for i = 1, math.min(4, n) do
      local c = grp.crafters[i]
      local who = c.name == me and "|cffffd100Tú|r" or ns.WhoColored(c.name)
      lines[#lines + 1] = string.format("%s: %s · %s", who, ns.UI.PriceText(c.g),
        c.m and "pone los materiales" or "|cffbbbbbbmateriales de quien lo pide|r")
    end
    if n > 4 then lines[#lines + 1] = string.format("|cffbbbbbby %d más|r", n - 4) end
    detail.info:SetText(table.concat(lines, "\n"))
    local offering, rows = {}, {}
    for _, c in ipairs(grp.crafters) do offering[c.name] = true end
    for _, r in ipairs(ns.UI.CrafterRows and ns.UI.CrafterRows(item.k) or {}) do
      if offering[r.name] then rows[#rows + 1] = r end
    end
    detail.whoLabel:SetText("Quién lo ofrece")
    detail.crafters:SetItems(rows)
    detail.whoLabel:Show()
    detail.crafters:Show()
    if grp.mine then
      setButton(detail.b1, "Renovar 30 días", true, function()
        ns.Offers.RenewCrafts(ns.Now())
        ns.Print("tus recetas ofrecidas duran otros 30 días.")
      end)
      setButton(detail.b2, "Dejar de ofrecer", true, function() ns.Offers.RemoveCraft(item.k) end)
      setButton(detail.b3, "Editar", true, function()
        local kind, id = ns.ParseKey(item.k)
        local o = ns.Offers.MyCrafts()[item.k]
        if kind == "i" and o then
          ns.UI.OpenOfferDialog(id, nil, nil, { edit = true, craft = true, price = o.g, mats = o.m == 1 })
        else
          ns.UI.OpenAsk("craft")
        end
      end, "Cambiar el precio o quién pone los materiales.")
    else
      setButton(detail.b1, "Pedírselo", true, function()
        ns.UI.OpenRequestDialog({ k = item.k, pk = Data.SingleProfession(item.k), q = 1 })
      end)
      local first = grp.crafters[1]
      setButton(detail.b2, "Susurrar", true, function() ns.SendTell(first.name) end,
        "Susurrar a " .. ns.ShortName(first.name) .. ".")
      setButton(detail.b3, nil)
    end
    setButton(detail.x1, nil)
    setButton(detail.x2, nil)
    setButton(detail.x3, nil)
  end

  -- Pedido de la hermandad (aportan varios).
  local function showNeed(item)
    local n = item.need
    local _, _, link = ns.KeyInfo(item.k)
    detail.title:SetText(string.format("%dx %s", n.q, link or ns.KeyName(item.k)))
    detail.sub:SetText("|cffff9933para la hermandad|r · lo pide " .. ns.WhoColored(n.owner))
    detail.steps:SetText(string.format("Aportado |cffffffff%d|r de %d · faltan |cffffffff%d|r", n.given, n.q, n.left))
    local lines = {}
    for i = 1, math.min(5, #n.donors) do
      lines[#lines + 1] = "  " .. ns.WhoColored(n.donors[i].name) .. " " .. n.donors[i].n
    end
    if #lines > 0 then table.insert(lines, 1, "Aportan:") end
    local have = ns.ItemCount(n.id)
    if have > 0 and not item.mine then lines[#lines + 1] = string.format("|cff40ff40Tienes %d.|r", have) end
    detail.info:SetText(table.concat(lines, "\n"))
    setWho(item.k, true, "Quién lo fabrica")
    if item.mine then
      setButton(detail.b1, "Quitar", true, function()
        W.Confirm("¿Quitar este pedido de la hermandad?", function() ns.Social.RemoveNeed(n.id) end)
      end)
    else
      setButton(detail.b1, "Aportar", true, function() ns.UI.ContributeNeed(n) end, "Se lo mandas por correo y se apunta solo.")
    end
    setButton(detail.b2, nil)
    setButton(detail.b3, nil)
    setButton(detail.x1, nil)
    setButton(detail.x2, nil)
    setButton(detail.x3, nil)
  end

  -- Pedido de fabricación de Blizzard: se coge en la ventana de profesión.
  local function showOrder(item)
    local o = item.order
    detail.title:SetText(ns.KeyLabel(item.k))
    detail.sub:SetText("pide " .. ns.WhoColored(o.owner) .. " |cffbbbbbb· hace " .. ns.FormatDuration(ns.Now() - o.t) .. "|r")
    detail.steps:SetText("|cff40c0ffPedido de fabricación de Blizzard|r")
    detail.info:SetText(item.mine and "|cff999999Lo verán quienes saben hacerlo.|r"
      or "Cógelo en tu profesión: pestaña Pedidos › Hermandad (puede que ya esté hecho).")
    setWho(item.k, false, "Quién lo fabrica")
    if item.mine then
      setButton(detail.b1, "Borrar aviso", true, function()
        W.Confirm("¿Borrar este aviso de pedido? Dejará de salir a los demás.\n(En la mesa de pedidos del juego "
          .. "cancélalo tú allí.)", function() ns.Orders.Remove(o.id) end)
      end)
    else
      setButton(detail.b1, "Ocultar", true, function() ns.Orders.Dismiss(o.id) end)
    end
    setButton(detail.b2, not item.mine and "Susurrar" or nil, true, function() ns.SendTell(o.owner) end)
    setButton(detail.b3, nil)
    setButton(detail.x1, nil)
    setButton(detail.x2, nil)
    setButton(detail.x3, nil)
  end

  function page:RefreshDetail(item)
    detail.item = item
    local parts = { detail.icon, detail.title, detail.sub, detail.steps, detail.info, detail.whoLabel, detail.crafters,
      detail.b1, detail.b2, detail.b3, detail.x1, detail.x2, detail.x3 }
    for _, p in ipairs(parts) do p:SetShown(item ~= nil) end
    detail.empty:SetShown(item == nil)
    if not item then
      detail.empty:SetText(#list.items > 0 and "Pulsa una fila para ver el detalle." or "")
      return
    end
    local _, icon = ns.KeyInfo(item.k)
    detail.iconTex:SetTexture(icon)
    if item.kind == "offer" then showOffer(item)
    elseif item.kind == "craft" then showCraft(item)
    elseif item.kind == "need" then showNeed(item)
    elseif item.kind == "co" then showOrder(item)
    else showRequest(item) end
    detail:LayoutButtons()
  end

  -----------------------------------------------------------------------
  -- Filtrar, juntar y ordenar
  -----------------------------------------------------------------------
  local function chipMatch(chip, item)
    if chip == "craft" then return item.canServe or item.pending > 0 end
    if chip == "new" then return item.new end
    if chip == "mine" then return item.mine end
    if chip == "involved" then return item.pending > 0 or (item.claimed == true) end
    return true
  end

  local function passes(item, m)
    local t = TYPES[m.type] and TYPES[m.type].id
    if t and ns.UI.ItemCategory(item.k) ~= t then return false end
    if m.prof then
      local rec = Data.GetIndex()[item.k]
      if not (rec and rec.profs and rec.profs[m.prof]) then return false end
    end
    local slots, armor = m.slots, ARMOR[m.armor] and ARMOR[m.armor].id
    if slots or armor or m.myLevel then
      local kind, id = ns.ParseKey(item.k)
      if kind ~= "i" then return false end
      if slots then
        local _, label = ns.UI.GearGroup(item.k)
        if not (label and slots[label]) then return false end
      end
      if armor then
        local _, classID, subclassID = ns.ItemInstant(id)
        if classID ~= 4 or subclassID ~= armor then return false end
      end
      if m.myLevel then
        local _, _, _, _, minLevel = ns.KeyInfo(item.k)
        if minLevel and minLevel > ns.Dungeons.MyLevel() then return false end
      end
    end
    if m.tip and not (item.r and (item.r.g or item.r.pi)) then return false end
    if m.rush and not (item.r and item.r.pr) then return false end
    if state.search ~= "" then
      local text = (ns.KeyName(item.k) .. " " .. ns.ShortName(item.author)):lower()
      if not text:find(state.search, 1, true) then return false end
    end
    return true
  end

  local function sortItems(items, sort)
    table.sort(items, function(a, b)
      -- Lo de la hermandad y lo marcado como prioridad, siempre arriba.
      local pa, pb = (a.kind == "need" or a.priority) and 0 or 1, (b.kind == "need" or b.priority) and 0 or 1
      if pa ~= pb then return pa < pb end
      if sort == "new" then
        if a.t ~= b.t then return a.t > b.t end
      elseif sort == "rush" then
        local ra, rb = a.r and a.r.pr or 9, b.r and b.r.pr or 9
        if ra ~= rb then return ra < rb end
      elseif sort == "tip" then
        local ta, tb = a.r and a.r.g or 0, b.r and b.r.g or 0
        if ta ~= tb then return ta > tb end
      elseif sort == "karma" then
        if a.karma ~= b.karma then return a.karma > b.karma end
      else
        local ra, rb = ns.UI.MarketRank(a), ns.UI.MarketRank(b)
        if ra ~= rb then return ra < rb end
        local ua, ub = a.r and a.r.pr or 9, b.r and b.r.pr or 9
        if ua ~= ub then return ua < ub end
        if a.karma ~= b.karma then return a.karma > b.karma end
      end
      if a.t ~= b.t then return a.t > b.t end
      return a.id < b.id
    end)
  end

  -- El mismo objeto pedido por varios (y que nadie ha cogido) se junta en una fila.
  local function group(items)
    local byKey, out = {}, {}
    for _, it in ipairs(items) do
      if it.kind == "req" and not it.mine and it.pending == 0 and not it.priority and not it.ended then
        byKey[it.k] = byKey[it.k] or {}
        table.insert(byKey[it.k], it)
      end
    end
    local done = {}
    for _, it in ipairs(items) do
      local same = it.kind == "req" and byKey[it.k]
      if same and #same > 1 and not it.mine and it.pending == 0 and not it.priority and not it.ended then
        if not done[it.k] then
          done[it.k] = true
          local total = 0
          for _, c in ipairs(same) do total = total + (c.info.remaining or 0) end
          out[#out + 1] = { kind = "group", id = "g:" .. it.k, k = it.k, children = same, total = total,
            t = it.t, karma = it.karma, pending = 0 }
          if state.expanded[it.k] then
            for _, c in ipairs(same) do
              c.child = true
              out[#out + 1] = c
            end
          end
        end
      else
        out[#out + 1] = it
      end
    end
    return out
  end

  local function sideOf(item)
    return (item.kind == "offer" or item.kind == "craft") and "offer" or "want"
  end

  function page:Refresh()
    local g = ns.G()
    if not g then return end
    local m = settings()
    local all, stats = ns.UI.MarketCollect(page.seenAt)
    if state.ended then
      for _, it in ipairs(endedItems(g, ns.Me(), ns.Now())) do all[#all + 1] = it end
    end
    -- Números de los botones de arriba y de los filtros rápidos (en el lado que se ve).
    local counts = { want = 0, offer = 0 }
    local chipCounts = {}
    for _, it in ipairs(all) do
      local side = sideOf(it)
      if not it.ended then counts[side] = counts[side] + 1 end
      if side == state.side then
        for _, c in ipairs(CHIPS) do
          if chipMatch(c.id, it) then chipCounts[c.id] = (chipCounts[c.id] or 0) + 1 end
        end
      end
    end
    page.want:SetText(string.format("Se busca |cffffffff%d|r", counts.want))
    page.offer:SetText(string.format("Se ofrece |cffffffff%d|r", counts.offer))
    page.want:SetOn(state.side == "want")
    page.offer:SetOn(state.side == "offer")
    for _, c in ipairs(CHIPS) do
      local b = page.chips[c.id]
      b:SetText(c.label .. " |cffffffff" .. (chipCounts[c.id] or 0) .. "|r")
      b:SetOn(state.chip == c.id)
    end
    local active = (m.type ~= 1 or m.armor ~= 1 or m.slots ~= nil or m.prof or m.myLevel or m.tip or m.rush or state.ended)
    page.filtersButton:SetText(active and "Filtros » |cff40ff40•|r" or "Filtros »")
    page.filtersButton:SetOn(state.showFilters)
    page.sortButton:SetText(SORTS[m.sort] and SORTS[m.sort].label or SORTS[1].label)

    -- Filtros ▾
    if not state.showFilters then state.slotMenu = nil end
    fbox:SetShown(state.showFilters and not state.slotMenu)
    fbox.slotMenu:SetShown(state.showFilters and state.slotMenu == true)
    for i, b in ipairs(fbox.types) do b:SetOn(m.type == i) end
    for _, b in ipairs(fbox.profs) do b.tex:SetDesaturated(m.prof ~= nil and m.prof ~= b.pk) end
    local nSlots, oneLabel = 0, nil
    for i = 2, #SLOTS do
      if m.slots and m.slots[SLOTS[i].id] then
        nSlots = nSlots + 1
        oneLabel = SLOTS[i].label
      end
    end
    fbox.slot:SetText(not m.slots and "Ranuras: todas" or nSlots == 1 and oneLabel
      or string.format("Ranuras: %d", nSlots))
    for _, cb in ipairs(fbox.slotMenu.checks) do cb:SetChecked(not m.slots or m.slots[cb.slotId] == true) end
    fbox.armor:SetText(ARMOR[m.armor].label)
    fbox.level:SetChecked(m.myLevel and true or false)
    fbox.tip:SetChecked(m.tip and true or false)
    fbox.rush:SetChecked(m.rush and true or false)
    fbox.ended:SetChecked(state.ended and true or false)

    local items = {}
    for _, it in ipairs(all) do
      it.child = nil
      if sideOf(it) == state.side and chipMatch(state.chip, it) and passes(it, m) then items[#items + 1] = it end
    end
    sortItems(items, SORTS[m.sort] and SORTS[m.sort].id or "best")
    items = group(items)
    list:SetItems(items)

    -- Lo elegido: si ya no está en la lista, el primero.
    local selected
    for _, it in ipairs(items) do
      if it.id == state.selected then selected = it end
    end
    if not selected then
      for _, it in ipairs(items) do
        if it.kind ~= "group" then selected = it break end
      end
      if not selected and items[1] and items[1].kind == "group" then selected = items[1].children[1] end
    end
    state.selected = selected and selected.id
    list.selectedKey = state.selected
    list:Refresh()
    page:RefreshDetail(selected)

    -- Lista vacía: una frase y el botón que toca.
    local none = #items == 0
    page.empty:SetShown(none and not state.showFilters)
    page.emptyButton:SetShown(none and not state.showFilters)
    if none then
      local text, button, fn
      if #all == 0 then
        text, button, fn = "No hay nada en el Mercado ahora mismo.", "+ Pedir", function() ns.UI.OpenAsk("ask") end
      elseif state.chip == "craft" then
        text, button, fn = "Nadie pide nada que puedas hacer.", "+ Ofrecer", function() ns.UI.OpenAsk("offer") end
      elseif state.chip == "involved" then
        text, button, fn = "No tienes encargos pendientes.", "Ver lo que puedo hacer", function() page:SetChip("craft") end
      elseif state.chip == "mine" then
        if state.side == "offer" then
          text, button, fn = "No estás ofreciendo nada.", "+ Ofrecer", function() ns.UI.OpenAsk("offer") end
        else
          text, button, fn = "No tienes pedidos abiertos.", "+ Pedir", function() ns.UI.OpenAsk("ask") end
        end
      elseif state.side == "offer" then
        text, button, fn = "Nadie ofrece nada con estos filtros.", "+ Ofrecer", function() ns.UI.OpenAsk("offer") end
      else
        text, button, fn = "No hay nada con estos filtros.", "Quitar filtros", function()
          state.chip, state.search = nil, ""
          page.search:SetText("")
          fbox.clear:Click()
        end
      end
      page.empty:SetText(text)
      page.emptyButton:SetText(button)
      page.emptyButton:SetScript("OnClick", fn)
    end
  end

  function page:SetSide(side)
    state.side = side
    state.selected = nil
    page:Refresh()
  end

  -- Abre con un filtro rápido puesto (desde Inicio o los avisos).
  function page:SetChip(chip, side)
    state.chip = chip
    state.selected = nil
    if side then
      state.side = side
    elseif chip == "mine" or chip == "involved" then
      state.side = "want"
    end
    page:Refresh()
  end

  -- Elige algo concreto (un pedido por su id, una oferta "o:...", etc.).
  function page:SelectById(id)
    local g = ns.G()
    local r = g and g.requests[id]
    state.chip, state.search = nil, ""
    page.search:SetText("")
    if r then
      state.side = "want"
      if not Data.IsActiveState(Data.RequestInfo(r, ns.Now()).state) then state.ended = true end
      state.expanded[r.k] = true
    elseif type(id) == "string" and id:sub(1, 2) == "o:" then
      state.side = "offer"
    end
    state.selected = id
    page:Refresh()
    list:Select(state.selected)
  end

  -- Lo de antes: "Mis pedidos", "Mis encargos" e historial de la 0.29.
  ns.UI.FilterRequests = function(fid)
    local f = ns.UI.PageFrame("market")
    if not f then return end
    if fid == "ended" then
      state.ended = true
      f:SetChip(nil)
    else
      f:SetChip(fid == "craft" and "craft" or fid == "involved" and "involved" or fid == "mine" and "mine" or nil)
    end
  end

  -- "Nuevo": lo que ha llegado desde la última vez que miraste. Al entrar se toma la marca
  -- anterior y al salir se guarda la hora.
  page:HookScript("OnShow", function()
    local g = ns.G()
    page.seenAt = g and g.boardSeen or 0
  end)
  page:HookScript("OnHide", function()
    local g = ns.G()
    if g and page.seenAt then g.boardSeen = ns.Now() end
    page.seenAt = nil
    state.showFilters = false
  end)
end)
