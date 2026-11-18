-- Mercado › TABLÓN: lo que pide y ofrece la hermandad (lo tuyo va en Mis pedidos, Mis encargos y
-- Mis ofertas).
--   Arriba: iconos de profesión que se encienden y apagan (al entrar, las tuyas; sin profesiones,
--   todas), «Todas», buscador, «Conectados», «Con prisa» y «SOLO MATERIALES». Debajo, «Ver: Todo /
--   Lo que piden / Lo que ofrecen».
--   Cada fila: una etiqueta de color (PIDE, OFRECE, FABRICA, HERMANDAD o BLIZZARD) y UN botón. Lo
--   que puedes hacer o dar sale primero y con borde dorado. Pulsar la fila abre el detalle.
local _, ns = ...
local W, Data = ns.W, ns.Data

-- Profesiones del filtro (recolección: Minería, Herboristería y Desuello).
local PROFS = { 164, 165, 197, 171, 202, 333, 185, 186, 182, 393 }
local ROWS, ROW_H = 7, 48

local TAG = {
  req = { "PIDE", 0.85, 0.5, 0.2 },
  offer = { "OFRECE", 0.35, 0.6, 0.9 },
  craft = { "FABRICA", 0.35, 0.6, 0.9 },
  need = { "HERMANDAD", 0.9, 0.7, 0.2 },
  co = { "BLIZZARD", 0.25, 0.75, 0.9 },
}
local VIEW_SIDE = { { id = nil, label = "Todo" }, { id = "want", label = "Lo que piden" },
  { id = "offer", label = "Lo que ofrecen" } }

local function sideOf(it) return (it.kind == "offer" or it.kind == "craft") and "offer" or "want" end

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

-- Profesiones de un objeto: las que lo fabrican y la que lo recolecta.
local function profsOf(key)
  local out = {}
  local rec = Data.GetIndex()[key]
  for pk in pairs(rec and rec.profs or {}) do out[tonumber(pk) or pk] = true end
  local skill = ns.GatherSkillFor(key)
  if skill then out[skill] = true end
  return out
end

-- Mis profesiones (de fabricar y de recolectar).
local function myProfs()
  local c, set, any = ns.MyChar(), {}, false
  for pk in pairs(c and c.profs or {}) do
    set[tonumber(pk) or pk] = true
    any = true
  end
  for pk in pairs(c and c.gather or {}) do
    set[tonumber(pk) or pk] = true
    any = true
  end
  return set, any
end

-- Cuántos tengo en las bolsas del objeto de "key".
local function haveInBags(key)
  local kind, id = ns.ParseKey(key)
  if kind ~= "i" then return 0 end
  return ns.ItemCount(id)
end

-- Lo que puedo hacer con una fila: etiqueta del botón, color, si se puede, qué hace, la frase
-- pequeña («Sabes hacerlo», «Tienes N en tus bolsas») y si va con borde dorado.
local function action(it)
  if it.kind == "req" then
    local r, info = it.r, it.info
    if info.state ~= "open" or info.remaining <= 0 then return nil end
    local have = haveInBags(r.k)
    local craft = Data.ICanCraft(r.k) or Data.ICanGather(r.k)
    local hint = craft and "|cffffd100Sabes hacerlo|r"
      or have > 0 and string.format("|cff40ff40Tienes %d en tus bolsas|r", have) or nil
    local label = (not craft and have > 0) and "LO DOY" or "ME ENCARGO"
    return label, W.GREEN, true, function() W.AcceptRequest(r) end, hint, (craft or have > 0) and true or false
  elseif it.kind == "need" then
    local have = haveInBags(it.k)
    return "APORTAR", W.GREEN, true, function() ns.UI.ContributeNeed(it.need) end,
      have > 0 and string.format("|cff40ff40Tienes %d en tus bolsas|r", have) or nil, have > 0
  elseif it.kind == "offer" then
    local o = it.o
    if o.myClaim and o.myClaim > 0 then
      return "PEDIDO", W.BLUE, false, nil, string.format("|cff66ccffHas pedido %d|r", o.myClaim), false
    end
    return "LO QUIERO", W.BLUE, o.free > 0, function()
      if o.free <= 1 then
        local ok, err = ns.Offers.Claim(o.key, 1, ns.Now())
        if not ok and err then ns.Print(err) end
      else
        W.AskAmount(string.format("¿Cuántos quieres? (quedan %d)", o.free), 1, function(n)
          local ok, err = ns.Offers.Claim(o.key, n, ns.Now())
          if not ok and err then ns.Print(err) end
        end)
      end
    end, nil, false
  elseif it.kind == "craft" then
    return "PEDÍRSELO", W.BLUE, true, function()
      ns.UI.OpenRequestDialog({ k = it.k, pk = Data.SingleProfession(it.k), q = 1 })
    end, nil, false
  elseif it.kind == "co" then
    return nil, nil, nil, nil, it.canServe and "|cffffd100Sabes hacerlo: cógelo en tu profesión|r" or nil,
      it.canServe and true or false
  end
end
ns.UI.MarketAction = action

-- Línea de abajo de la fila: quién y cuándo, y quién lo hace.
local function subText(it, now)
  local parts = { ns.AuthorText(it.author), ns.FormatDuration(now - (it.t or now)) }
  if it.kind == "req" then
    local info = it.info
    if #info.owners > 0 then
      local names = {}
      for i = 1, math.min(2, #info.owners) do names[i] = ns.DisplayName(info.owners[i]) end
      parts[#parts + 1] = "|cff66ccfflo hace " .. table.concat(names, ", ") .. (#info.owners > 2 and "…" or "") .. "|r"
    end
    if it.r.pr then parts[#parts + 1] = "|cffff9933" .. Data.WHEN[it.r.pr].need:lower() .. "|r" end
  elseif it.kind == "craft" then
    local cr = it.craft.crafters
    parts = { "lo fabrica" .. (#cr > 1 and "n " or " ") .. ns.WhoColored(cr[1].name)
      .. (#cr > 1 and string.format(" y %d más", #cr - 1) or "") }
  elseif it.kind == "co" then
    parts[#parts + 1] = "se coge en tu profesión"
  end
  return table.concat(parts, " |cff666666·|r ")
end

-- Lo de la derecha: propina, precio o lo aportado.
local function moneyText(it)
  if it.kind == "req" then
    local p = payText(it.r)
    return p and ("Propina: " .. p) or "|cff999999Sin propina|r"
  elseif it.kind == "offer" then
    return "Precio: " .. ns.UI.PriceText(it.o.g)
  elseif it.kind == "craft" then
    local cheapest
    for _, c in ipairs(it.craft.crafters) do
      if not cheapest or (c.g or 0) < cheapest then cheapest = c.g or 0 end
    end
    return "Precio: " .. ns.UI.PriceText(cheapest)
  elseif it.kind == "need" then
    return string.format("Aportado %d de %d", it.need.given, it.need.q)
  end
  return ""
end

local function qtyOf(it)
  if it.kind == "req" then return it.info.remaining > 0 and it.info.remaining or it.r.q end
  if it.kind == "offer" then return it.o.free > 0 and it.o.free or it.o.q end
  if it.kind == "need" then return it.need.left end
end

ns.UI.MarketView("board", function(view, M)
  local state = { search = "", side = nil }
  local function settings() return M.Settings() end
  -- Profesiones encendidas: las guardadas o, la primera vez, las mías (sin ninguna, todas).
  local function enabled()
    local m = settings()
    if not m.profs then
      local mine, any = myProfs()
      if any then
        m.profs = mine
      else
        m.profs = {}
        for _, pk in ipairs(PROFS) do m.profs[pk] = true end
      end
    end
    return m.profs
  end
  local function allOn()
    local on = enabled()
    for _, pk in ipairs(PROFS) do
      if not on[pk] then return false end
    end
    return true
  end

  -- Fila de filtros
  view.profs = {}
  for i, pk in ipairs(PROFS) do
    local b = CreateFrame("Button", nil, view)
    b:SetSize(24, 24)
    b:SetPoint("TOPLEFT", (i - 1) * 27, -2)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexture(ns.ProfessionIcon(pk))
    b.ring = W.Border(b, W.COLORS.GOLD, "OVERLAY", -1, -1, -1, -1)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function()
      local on = enabled()
      on[pk] = (not on[pk]) or nil
      view:Refresh(view.data)
    end)
    ns.UI.Tip(b, ns.ProfessionName(pk), "Pulsa para encender o apagar sus pedidos y ofertas.")
    b.pk = pk
    view.profs[i] = b
  end
  local x = #PROFS * 27 + 2
  view.all = W.Chip(view, "Todas", 52, function()
    local m = settings()
    if allOn() then
      m.profs = nil
      enabled()
    else
      m.profs = {}
      for _, pk in ipairs(PROFS) do m.profs[pk] = true end
    end
    view:Refresh(view.data)
  end)
  view.all:SetPoint("TOPLEFT", x, -3)
  ns.UI.Tip(view.all, "Todas", "Enciende todas las profesiones. Otra vez: solo las tuyas.")
  x = x + 58
  view.search = W.Input(view, 128)
  view.search:SetPoint("TOPLEFT", x + 6, -4)
  view.search.hdfLink = true
  W.Placeholder(view.search, "Buscar…")
  view.search:HookScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    local name = text:match("|h%[(.-)%]|h")
    if name then
      self:SetText(name)
      return
    end
    state.search = text:lower()
    view:Refresh(view.data)
  end)
  x = x + 140
  local function toggle(key, label, width, tipText)
    local b = W.Chip(view, label, width, function()
      local m = settings()
      m[key] = (not m[key]) or nil
      view:Refresh(view.data)
    end)
    b:SetPoint("TOPLEFT", x, -3)
    ns.UI.Tip(b, label, tipText)
    x = x + width + 2
    return b
  end
  view.online = toggle("online", "Conectados", 86, "Solo lo de quien está conectado ahora.")
  view.rush = toggle("rush", "Con prisa", 74, "Solo los pedidos que corren prisa.")
  view.mats = toggle("onlyMats", "SOLO MATERIALES", M.BODY_W - x,
    "Solo materiales (minerales, hierbas, cueros, telas...).")

  -- Ver: Todo / Lo que piden / Lo que ofrecen
  local label = W.Text(view, "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", 2, -36)
  label:SetText("Ver:")
  view.sides = {}
  local sx = 30
  for i, s in ipairs(VIEW_SIDE) do
    local w = i == 1 and 70 or 116
    local b = W.Chip(view, s.label, w, function()
      state.side = s.id
      view:Refresh(view.data)
    end)
    b:SetPoint("TOPLEFT", sx, -31)
    sx = sx + w + 2
    view.sides[i] = b
  end
  view.count = W.Text(view, "GameFontHighlightSmall", "RIGHT")
  view.count:SetPoint("TOPRIGHT", -4, -36)
  view.count:SetTextColor(0.7, 0.7, 0.7)

  -- Lista
  local list = W.List(view, M.BODY_W, M.BODY_H - 58, {
    rows = ROWS,
    rowHeight = ROW_H,
    card = true,
    keyOf = function(it) return it.id end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(36, 36)
      row.icon:SetPoint("LEFT", 8, 0)
      row.qty = row:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
      row.qty:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)
      row.tag = CreateFrame("Frame", nil, row)
      row.tag:SetSize(70, 15)
      row.tag:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
      row.tag.bg = row.tag:CreateTexture(nil, "ARTWORK")
      row.tag.bg:SetAllPoints()
      row.tag.text = W.Text(row.tag, "GameFontHighlightSmall", "CENTER")
      row.tag.text:SetPoint("CENTER", 0, 0)
      row.tag.text:SetTextColor(0.08, 0.06, 0.04)
      row.title = W.ListText(row, "GameFontHighlight")
      row.title:SetPoint("LEFT", row.tag, "RIGHT", 6, 0)
      row.title:SetWidth(270)
      row.title:SetWordWrap(false)
      row.sub = W.ListText(row, "GameFontHighlightSmall")
      row.sub:SetPoint("TOPLEFT", row.tag, "BOTTOMLEFT", 0, -6)
      row.sub:SetWidth(330)
      row.sub:SetWordWrap(false)
      row.hint = W.ListText(row, "GameFontHighlightSmall")
      row.hint:SetPoint("TOPLEFT", row, "TOPLEFT", 440, -9)
      row.hint:SetWidth(180)
      row.hint:SetWordWrap(false)
      row.money = W.ListText(row, "GameFontNormalSmall")
      row.money:SetPoint("TOPLEFT", row.hint, "BOTTOMLEFT", 0, -5)
      row.money:SetWidth(180)
      row.money:SetWordWrap(false)
      row.button = W.Button(row, "", 122, 28)
      row.button:SetPoint("RIGHT", -8, 0)
      row.button:SetFontSize("normal")
      W.KeyTooltip(row, function(self) return self.item and self.item.k end)
    end,
    updateRow = function(row, it)
      local now = it.now or ns.Now()
      local _, icon = ns.KeyInfo(it.k)
      row.icon:SetTexture(icon)
      local q = qtyOf(it)
      row.qty:SetText(q and q > 1 and tostring(q) or "")
      local tag = TAG[it.kind] or TAG.req
      row.tag.bg:SetColorTexture(tag[2], tag[3], tag[4], 0.95)
      row.tag.text:SetText(tag[1])
      row.tag:SetWidth((row.tag.text:GetStringWidth() or 40) + 10)
      row.title:SetText(ns.KeyLabel(it.k))
      row.sub:SetText(subText(it, now))
      local label, color, can, fn, hint, gold = action(it)
      row.hint:SetText(hint or "")
      row.money:SetText(moneyText(it))
      local taken = it.kind == "req" and it.info.state ~= "open"
      if taken then
        -- ya cogido del todo: en gris, con quién lo hace
        row.hint:SetText("|cff66ccffLo hace " .. ns.DisplayName(it.info.owner or "?") .. "|r")
      end
      if label then
        row.button:SetText(label)
        row.button:SetEnabled(can and true or false)
        row.button:SetScript("OnClick", fn)
        W.Tint(row.button, color)
        row.button:Show()
      else
        row.button:Hide()
      end
      -- Lo que puedes hacer o dar: borde dorado. Lo ya cogido: apagado.
      row:SetSelected(gold and true or false)
      row:SetAlpha(taken and 0.55 or 1)
    end,
    onSelect = function(it) ns.UI.MarketDetail.Show(it) end,
  })
  list:SetPoint("TOPLEFT", 0, -58)
  view.list = list

  view.empty = W.Text(view, "GameFontNormal", "CENTER")
  view.empty:SetPoint("CENTER", list, "CENTER", 0, 14)
  view.empty:SetWidth(600)
  view.empty:SetTextColor(0.7, 0.7, 0.7)
  view.emptyButton = W.Button(view, "", 170, 24)
  view.emptyButton:SetPoint("TOP", view.empty, "BOTTOM", 0, -10)

  -- ¿Pasa los filtros? Devuelve si pasa y, si no, si es solo por la profesión.
  local function passes(it, m, on, everything)
    if it.mine then return false end
    if it.kind == "req" and it.pending > 0 then return false end -- lo hago yo: Mis encargos
    if state.side and sideOf(it) ~= state.side then return false end
    if m.rush and not (it.r and it.r.pr) then return false end
    if m.onlyMats and ns.UI.ItemCategory(it.k) ~= "mats" then return false end
    if m.online and not ns.Guild.IsOnline(it.author) then return false end
    if state.search ~= "" then
      local text = (ns.KeyName(it.k) .. " " .. ns.DisplayName(it.author)):lower()
      if not text:find(state.search, 1, true) then return false end
    end
    -- Por profesión: lo que no es de ninguna y lo que puedes dar (lo tienes) sale siempre.
    if not everything and not it.gold then
      local any = false
      for pk in pairs(profsOf(it.k)) do
        any = true
        if on[pk] then return true end
      end
      if any then return false, true end
    end
    return true
  end

  function view:Refresh(data)
    if not data then return end
    view.data = data
    local m = settings()
    local on = enabled()
    local everything = allOn()
    for _, b in ipairs(view.profs) do
      b.tex:SetDesaturated(not on[b.pk])
      b.tex:SetAlpha(on[b.pk] and 1 or 0.45)
      b.ring:SetShown(on[b.pk] == true)
    end
    view.all:SetOn(everything)
    view.online:SetOn(m.online == true)
    view.rush:SetOn(m.rush == true)
    view.mats:SetOn(m.onlyMats == true)
    for i, s in ipairs(VIEW_SIDE) do view.sides[i]:SetOn(state.side == s.id) end

    local items, hidden = {}, 0
    for _, it in ipairs(data.items) do
      local _, _, _, _, _, gold = action(it)
      it.gold = gold and true or false
      local ok, byProf = passes(it, m, on, everything)
      if ok then
        items[#items + 1] = it
      elseif byProf then
        hidden = hidden + 1
      end
    end
    table.sort(items, function(a, b)
      -- Lo de la hermandad y lo marcado como prioridad arriba; luego lo que puedes hacer o dar;
      -- lo abierto antes que lo ya cogido; con prisa; y lo más nuevo.
      local pa, pb = (a.kind == "need" or a.priority) and 0 or 1, (b.kind == "need" or b.priority) and 0 or 1
      if pa ~= pb then return pa < pb end
      if a.gold ~= b.gold then return a.gold end
      local oa = a.kind == "req" and a.info.state ~= "open" and 1 or 0
      local ob = b.kind == "req" and b.info.state ~= "open" and 1 or 0
      if oa ~= ob then return oa < ob end
      local ra, rb = a.r and a.r.pr or 9, b.r and b.r.pr or 9
      if ra ~= rb then return ra < rb end
      if a.t ~= b.t then return a.t > b.t end
      return a.id < b.id
    end)
    view.shown = items
    list:SetItems(items)
    view.count:SetText(hidden > 0 and string.format("%d más en otras profesiones (pulsa «Todas»)", hidden) or "")
    ns.UI.MarketDetail.Refresh(data.items)

    local none = #items == 0
    view.empty:SetShown(none)
    view.emptyButton:SetShown(none)
    if none then
      if hidden > 0 then
        view.empty:SetText("No hay nada de tus profesiones. Hay " .. hidden .. " de otras.")
        view.emptyButton:SetText("Ver todas")
        view.emptyButton:SetScript("OnClick", function() view.all:Click() end)
      else
        view.empty:SetText("No hay nada en el Tablón con estos filtros.")
        view.emptyButton:SetText("+ PEDIR")
        view.emptyButton:SetScript("OnClick", function() ns.UI.OpenAsk("ask") end)
      end
    end
  end

  -- Desde Inicio y los avisos (nombres de la 0.34).
  function view:SetQuick(chip, side)
    state.side = (side == "offer" or side == "want") and side or nil
  end

  function view:Select(id)
    for _, it in ipairs(view.data and view.data.items or {}) do
      if it.id == id then return ns.UI.MarketDetail.Show(it) end
    end
  end
end)
