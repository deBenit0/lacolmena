-- Página "Tablón": lo que pide y lo que ofrece la gente en este momento.
-- - Pedidos: ver cada uno o aceptar el encargo sin más pasos. En lo que puedo hacer dice si
--   tengo los materiales.
-- - Ofertas: objetos concretos (bolsas, pociones...) que alguien da; "Lo quiero" y te los manda.
-- Arriba, lo que tengo que enviar. Se puede buscar y filtrar por tipo y categoría de objeto.
-- Lo nuevo desde la última visita sale marcado.
local _, ns = ...
local W, Data = ns.W, ns.Data

-- Filtros: qué se ve y qué categoría de objeto.
local SHOW = {
  { id = "all", label = "Ver: todo" },
  { id = "requests", label = "Ver: pedidos" },
  { id = "offers", label = "Ver: ofertas" },
}
local CATEGORIES = {
  { id = nil, label = "Categoría: todas" },
  { id = "mats", label = "Materiales" },
  { id = "cons", label = "Pociones y comida" },
  { id = "bags", label = "Bolsas" },
  { id = "gear", label = "Armas y armaduras" },
  { id = "other", label = "Otros" },
}

-- Categoría de un objeto por su clase en el juego.
local function category(key)
  local kind, id = ns.ParseKey(key)
  if kind ~= "i" then return "other" end
  local _, class = ns.ItemInstant(id)
  if class == 7 or class == 5 then return "mats" end
  if class == 0 then return "cons" end
  if class == 1 or class == 11 then return "bags" end
  if class == 2 or class == 4 then return "gear" end
  return "other"
end
ns.UI.ItemCategory = category

-- ¿Puedo aceptar este pedido ahora? (no es mío, está abierto y nadie lo ha cogido)
local function canAccept(r, info, me)
  return r.a ~= me and info.state == "open" and not info.owner and info.remaining > 0
end

local function urgencyText(r)
  if not r.pr then return nil end
  local color = r.pr == 1 and "|cffff4040" or "|cffff9933"
  return color .. Data.WHEN[r.pr].need .. "|r"
end

-- Lo que me queda por enviar de un pedido que acepté (0 si nada).
local function toSend(r, me, now)
  local cm = r.a ~= me and r.c and r.c[me]
  if not cm or not Data.CommitActive(cm, now, r) then return 0 end
  return math.max(0, (cm.n or 0) - Data.DeliveredOf(cm))
end

-- ¿Tengo lo necesario para hacer "amount"? Texto para la fila, o nil si no lo hago yo.
local function materialsStatus(r, amount)
  local c = ns.MyChar()
  local kind, id = ns.ParseKey(r.k)
  for pk, prof in pairs(c and c.profs or {}) do
    if prof.recipes and prof.recipes[r.k] then
      if r.m then return "|cff40ff40Los materiales los pone quien pide.|r" end
      local info = Data.GetInfo(Data.InfoKey(pk, r.k))
      local var = info and info.v and info.v[1]
      if not var then return "|cff999999Abre tu ventana de profesión para saber si tienes los materiales.|r" end
      local times = math.ceil(amount / math.max(1, var.m or 1))
      local ids = {}
      for mid in pairs(var.r) do ids[#ids + 1] = mid end
      table.sort(ids)
      local missing = {}
      for _, mid in ipairs(ids) do
        local need = var.r[mid] * times - ns.Scan.Have(mid)
        if need > 0 then missing[#missing + 1] = need .. "x " .. ns.KeyName("i" .. mid) end
      end
      if #missing == 0 then return "|cff40ff40Tienes los materiales para hacerlo ya.|r" end
      return "|cffff9933Te faltan: " .. table.concat(missing, ", ") .. "|r"
    end
  end
  if kind == "i" and Data.ICanGather(r.k) then
    local have = ns.Scan.Have(id)
    if have >= amount then return string.format("|cff40ff40Ya tienes %d (lo recolectas tú).|r", have) end
    return string.format("|cffff9933Tienes %d de %d (lo recolectas tú).|r", have, amount)
  end
end

local function priceText(copper)
  if not copper or copper <= 0 then return "|cff40ff40gratis|r" end
  return ns.FormatMoney(copper) .. " c/u"
end

-- Pedidos y ofertas del tablón, y sus números (también los usa la página de inicio).
local function collect(seenAt)
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  local items = {}
  local stats = { open = 0, servable = 0, new = 0, toSend = 0, offers = 0, guild = 0 }
  if not g then return items, stats end
  for _, r in pairs(g.requests) do
    local info = Data.RequestInfo(r, now)
    local pending = toSend(r, me, now)
    local mine = r.a == me
    local visible = info.state == "open" or (mine and Data.IsActiveState(info.state))
    if pending > 0 or visible then
      local item = {
        kind = "req", id = r.id, k = r.k, author = r.a, t = r.t or 0,
        r = r, info = info, me = me, now = now, mine = mine, pending = pending,
        canServe = Data.CanServe(r, now), acceptable = canAccept(r, info, me),
        karma = Data.KarmaFor(r.a), priority = ns.Social.IsPriority(r.id),
        new = not mine and pending == 0 and (r.t or 0) > (seenAt or 0),
      }
      if pending > 0 then stats.toSend = stats.toSend + 1 end
      if visible and not mine then stats.open = stats.open + 1 end
      if item.canServe then stats.servable = stats.servable + 1 end
      if item.new and visible then stats.new = stats.new + 1 end
      items[#items + 1] = item
    end
  end
  for _, o in ipairs(ns.Offers.List(now)) do
    local mine = o.owner == me
    local item = {
      kind = "offer", id = "o:" .. o.key, k = "i" .. o.id, author = o.owner, t = o.t or 0,
      o = o, me = me, now = now, mine = mine,
      pending = (mine and #o.claims > 0) and o.pending or 0, -- tengo que mandárselo a alguien
      claimed = o.myClaim > 0, karma = Data.KarmaFor(o.owner),
      new = not mine and (o.t or 0) > (seenAt or 0),
    }
    if not mine then stats.offers = stats.offers + 1 end
    if item.pending > 0 then stats.toSend = stats.toSend + 1 end
    if item.new then stats.new = stats.new + 1 end
    items[#items + 1] = item
  end
  -- Pedidos de fabricación de hermandad hechos en la mesa de Blizzard (los cogen allí).
  for _, o in ipairs(ns.Orders.List(now)) do
    local mine = o.owner == me
    local item = {
      kind = "co", id = "co:" .. o.id, k = o.key, author = o.owner, t = o.t, order = o,
      me = me, now = now, mine = mine, pending = 0, karma = Data.KarmaFor(o.owner),
      canServe = not mine and ns.Orders.CanMake(o), new = not mine and o.t > (seenAt or 0),
    }
    if item.canServe then stats.servable = stats.servable + 1 end
    if item.new then stats.new = stats.new + 1 end
    items[#items + 1] = item
  end
  -- Pedidos de la hermandad (los ponen los oficiales; aportan varios).
  for _, n in ipairs(ns.Social.Needs(now)) do
    if n.left > 0 then
      local mine = n.owner == me
      local item = {
        kind = "need", id = "n:" .. n.key, k = "i" .. n.id, author = n.owner, t = n.t or 0,
        need = n, me = me, now = now, mine = mine, pending = 0, karma = Data.KarmaFor(n.owner),
        new = not mine and (n.t or 0) > (seenAt or 0),
      }
      stats.guild = stats.guild + 1
      if item.new then stats.new = stats.new + 1 end
      items[#items + 1] = item
    end
  end
  return items, stats
end

function ns.UI.BoardStats()
  local g = ns.G()
  local _, stats = collect(g and g.boardSeen)
  return stats
end

local function rank(x)
  if x.pending > 0 then return 0 end -- lo que tengo que enviar (encargos y ofertas pedidas)
  if x.claimed then return 1 end     -- ofertas que he pedido
  if x.kind == "need" then return 1.2 end -- pedidos de la hermandad
  if x.mine then return 5 end
  if x.priority then return 1.5 end  -- marcadas por un oficial
  if x.canServe then return 2 end
  if x.new then return 3 end
  return 4
end

local function settings()
  local s = ns.db.settings
  s.board = s.board or { show = 1, cat = 1 }
  return s.board
end

---------------------------------------------------------------------------
-- Ventana "Ofrecer objeto"
---------------------------------------------------------------------------
local offerDialog
local PRICES = {
  { label = "Gratis", copper = 0 },
  { label = "50 plata", copper = 5000 },
  { label = "1 oro", copper = 10000 },
  { label = "5 oro", copper = 50000 },
}

local function markSelected(buttons, selected)
  for i, b in ipairs(buttons) do
    local fs = b.GetFontString and b:GetFontString()
    if i == selected then
      b:LockHighlight()
      if fs then fs:SetTextColor(1, 1, 1) end
    else
      b:UnlockHighlight()
      if fs then fs:SetTextColor(1, 0.82, 0) end
    end
  end
end

local function createOfferDialog()
  local d = W.Panel("HDFProfOfferDialog", UIParent, 380, 196)
  offerDialog = d
  d:SetFrameStrata("DIALOG")
  d:SetToplevel(true)
  d:SetPoint("CENTER", 0, 60)
  d:Hide()
  tinsert(UISpecialFrames, "HDFProfOfferDialog")
  d.title = W.Text(d, "GameFontNormal")
  d.title:SetPoint("TOP", 0, -18)
  d.title:SetText("Ofrecer a la hermandad")
  local close = CreateFrame("Button", nil, d, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  -- Objeto. Si no viene elegido (botón del Tablón), se elige arrastrándolo al cuadro o con
  -- mayús+clic en él con la caja de texto activa.
  d.itemButton = CreateFrame("Button", nil, d)
  d.itemButton:SetSize(32, 32)
  d.itemButton:SetPoint("TOPLEFT", 24, -44)
  d.iconTex = d.itemButton:CreateTexture(nil, "ARTWORK")
  d.iconTex:SetAllPoints()
  d.iconTex:SetTexture(ns.QUESTION_ICON)
  local function fromCursor()
    if not GetCursorInfo then return end
    local kind, id = GetCursorInfo()
    if kind == "item" and id then
      if ClearCursor then ClearCursor() end
      d:SetItem(tonumber(id))
    end
  end
  d.itemButton:SetScript("OnReceiveDrag", fromCursor)
  d.itemButton:SetScript("OnClick", fromCursor)
  W.KeyTooltip(d.itemButton, function() return d.id and ("i" .. d.id) end)
  d.itemName = W.Text(d, "GameFontHighlight")
  d.itemName:SetPoint("LEFT", d.itemButton, "RIGHT", 10, 0)
  d.itemName:SetPoint("RIGHT", d, "RIGHT", -20, 0)
  d.itemName:SetWordWrap(false)
  d.link = W.Input(d, 270)
  d.link.hdfLink = true
  d.link:SetPoint("LEFT", d.itemButton, "RIGHT", 12, 0)
  W.Placeholder(d.link, "Arrástralo aquí o mayús+clic en él")
  d.link:HookScript("OnTextChanged", function(self)
    local id = tonumber((self:GetText() or ""):match("item:(%d+)"))
    if id and id ~= d.id then d:SetItem(id) end
  end)

  -- Cantidad con - y +.
  local qtyLabel = W.Text(d, "GameFontNormalSmall")
  qtyLabel:SetPoint("TOPLEFT", 24, -94)
  qtyLabel:SetText("Cantidad")
  local function qtyValue() return math.max(1, tonumber(d.qty:GetText()) or 1) end
  d.minus = W.Button(d, "-", 24, 22, function() d.qty:SetText(tostring(math.max(1, qtyValue() - 1))) end)
  d.minus:SetPoint("LEFT", qtyLabel, "RIGHT", 14, 0)
  d.qty = W.Input(d, 50, true)
  d.qty:SetPoint("LEFT", d.minus, "RIGHT", 8, 0)
  d.qty:SetMaxLetters(4)
  d.qty:SetJustifyH("CENTER")
  d.plus = W.Button(d, "+", 24, 22, function() d.qty:SetText(tostring(math.min(Data.MAX_QTY, qtyValue() + 1))) end)
  d.plus:SetPoint("LEFT", d.qty, "RIGHT", 4, 0)
  d.have = W.Text(d, "GameFontHighlightSmall")
  d.have:SetPoint("LEFT", d.plus, "RIGHT", 10, 0)

  -- Precio: gratis salvo que se cambie en "Más opciones".
  d.moreButton = W.Button(d, "Más opciones", 110, 20)
  d.moreButton:SetPoint("TOPLEFT", 24, -124)
  d.summary = W.Text(d, "GameFontHighlightSmall")
  d.summary:SetPoint("LEFT", d.moreButton, "RIGHT", 10, 0)
  local more = CreateFrame("Frame", nil, d)
  more:SetAllPoints()
  d.more = more
  function d:SetExpanded(expanded)
    more:SetShown(expanded)
    self:SetHeight(expanded and 286 or 196)
    self.moreButton:SetText(expanded and "Menos opciones" or "Más opciones")
  end
  d.moreButton:SetScript("OnClick", function() d:SetExpanded(not more:IsShown()) end)

  local priceLabel = W.Text(more, "GameFontNormalSmall")
  priceLabel:SetPoint("TOPLEFT", 24, -154)
  priceLabel:SetText("Precio por unidad (se cobra con el correo)")
  d.prices = {}
  for i, p in ipairs(PRICES) do
    local b = W.Button(more, p.label, 76, 22)
    if i == 1 then b:SetPoint("TOPLEFT", 24, -170) else b:SetPoint("LEFT", d.prices[i - 1], "RIGHT", 4, 0) end
    b:SetScript("OnClick", function() d:SetPrice(p.copper) end)
    d.prices[i] = b
  end
  local other = W.Text(more, "GameFontHighlightSmall")
  other:SetPoint("TOPLEFT", 26, -204)
  other:SetText("u otro:")
  d.gold = W.Input(more, 50, true)
  d.gold:SetPoint("LEFT", other, "RIGHT", 12, 0)
  d.gold:SetMaxLetters(5)
  local goldLabel = W.Text(more, "GameFontHighlightSmall")
  goldLabel:SetPoint("LEFT", d.gold, "RIGHT", 4, 0)
  goldLabel:SetText("oro")
  d.silver = W.Input(more, 30, true)
  d.silver:SetPoint("LEFT", goldLabel, "RIGHT", 14, 0)
  d.silver:SetMaxLetters(2)
  local silverLabel = W.Text(more, "GameFontHighlightSmall")
  silverLabel:SetPoint("LEFT", d.silver, "RIGHT", 4, 0)
  silverLabel:SetText("plata")

  function d:Price()
    return (tonumber(self.gold:GetText()) or 0) * 10000 + (tonumber(self.silver:GetText()) or 0) * 100
  end
  function d:SetPrice(copper)
    self.setting = true
    local g, sv = math.floor(copper / 10000), math.floor(copper / 100) % 100
    self.gold:SetText(g > 0 and tostring(g) or "")
    self.silver:SetText(sv > 0 and tostring(sv) or "")
    self.setting = false
    self:MarkPrice()
  end
  function d:MarkPrice()
    local copper, selected = self:Price(), nil
    for i, p in ipairs(PRICES) do if p.copper == copper then selected = i end end
    markSelected(self.prices, selected)
    self.summary:SetText(copper > 0 and (ns.FormatMoney(copper) .. " c/u") or "|cff40ff40Gratis|r")
  end
  d.gold:HookScript("OnTextChanged", function() if not d.setting then d:MarkPrice() end end)
  d.silver:HookScript("OnTextChanged", function() if not d.setting then d:MarkPrice() end end)

  function d:SetItem(id)
    self.id = id
    local name, icon, link = ns.KeyInfo("i" .. id)
    self.iconTex:SetTexture(icon or ns.QUESTION_ICON)
    self.itemName:SetText(link or name or ns.KeyName("i" .. id))
    self.itemName:Show()
    self.link:Hide()
    local have = ns.ItemCount(id)
    self.have:SetText(string.format("|cffbbbbbbtienes %d|r", have))
    if (tonumber(self.qty:GetText()) or 0) < 1 then
      self.qty:SetText(tostring(self.mode == "need" and 20 or math.max(1, have)))
    end
  end

  d.info = W.Text(d, "GameFontHighlightSmall")
  d.info:SetPoint("BOTTOMLEFT", 24, 24)
  d.info:SetTextColor(0.7, 0.7, 0.7)
  d.info:SetText("Quien lo quiera te lo pide; se lo mandas por correo.")
  local publish = W.Button(d, "Ofrecer", 96, 22, function() d:Publish() end)
  d.publishButton = publish
  publish:SetPoint("BOTTOMRIGHT", -22, 18)
  local cancel = W.Button(d, "Cancelar", 86, 22, function() d:Hide() end)
  cancel:SetPoint("RIGHT", publish, "LEFT", -6, 0)

  function d:Publish()
    local ok, err
    if self.mode == "need" then
      ok, err = ns.Social.AddNeed(self.id, tonumber(self.qty:GetText()), ns.Now())
    else
      ok, err = ns.Offers.Create(self.id, tonumber(self.qty:GetText()), self:Price(), ns.Now())
    end
    if not ok then
      ns.Print(err)
      return
    end
    self:Hide()
    if self.mode == "need" then
      ns.Print("añadido a lo que necesita la hermandad: %sx %s.", self.qty:GetText(), ns.KeyLabel("i" .. self.id))
    else
      ns.Print("ofrecido en el Tablón: %sx %s.", self.qty:GetText(), ns.KeyLabel("i" .. self.id))
    end
  end
end

-- Abre la ventana de ofrecer. Con "id", el objeto ya viene elegido (desde la profesión).
-- mode = "need": la misma ventana para que un oficial añada lo que necesita la hermandad.
function ns.UI.OpenOfferDialog(id, qty, mode)
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  if not offerDialog then createOfferDialog() end
  local d = offerDialog
  d.id = nil
  d.link:SetText("")
  d.link:Show()
  d.itemName:Hide()
  d.qty:SetText(qty and tostring(qty) or "")
  d.have:SetText("")
  d.iconTex:SetTexture(ns.QUESTION_ICON)
  d:SetPrice(0)
  d:SetExpanded(false)
  d.mode = mode
  local need = mode == "need"
  d.title:SetText(need and "Lo que necesita la hermandad" or "Ofrecer a la hermandad")
  d.publishButton:SetText(need and "Añadir" or "Ofrecer")
  d.moreButton:SetShown(not need)
  d.summary:SetShown(not need)
  d.info:SetText(need and "Todos lo verán en Hermandad y podrán aportar por correo."
    or "Quien lo quiera te lo pide; se lo mandas por correo.")
  if id then d:SetItem(id) end
  if need and not id then d.qty:SetText("") end
  d:Show()
end

---------------------------------------------------------------------------
-- Página
---------------------------------------------------------------------------
ns.UI.RegisterPage("board", function(page)
  local state = { onlyMine = settings().onlyMine and true or false, search = "" }

  -- Fila 1: buscar y filtros. (Para ofrecer: desde tu ventana de profesión.)
  page.search = W.Input(page, 200)
  page.search:SetPoint("TOPLEFT", 10, -2)
  W.Placeholder(page.search, "Buscar...")
  page.search:HookScript("OnTextChanged", function(self)
    state.search = (self:GetText() or ""):lower()
    page:Refresh()
  end)
  page.showButton = W.Button(page, "", 116, 22, function()
    local f = settings()
    f.show = f.show % #SHOW + 1
    page:Refresh()
  end)
  page.showButton:SetPoint("LEFT", page.search, "RIGHT", 8, 0)
  page.catButton = W.Button(page, "", 150, 22, function()
    local f = settings()
    f.cat = f.cat % #CATEGORIES + 1
    page:Refresh()
  end)
  page.catButton:SetPoint("LEFT", page.showButton, "RIGHT", 4, 0)

  -- Fila 2: resumen, "solo lo que puedo hacer" y listas completas.
  page.summary = W.Text(page, "GameFontNormalSmall")
  page.summary:SetPoint("TOPLEFT", 6, -33)
  -- Solo lo de mis profesiones: lo que yo puedo hacer (o recolectar) y lo que tengo que enviar.
  -- Se recuerda.
  page.onlyMine = W.Check(page, "Solo mis profesiones", function(checked)
    state.onlyMine = checked
    settings().onlyMine = checked or nil
    page:Refresh()
  end)
  page.onlyMine:SetPoint("TOPLEFT", 262, -27)
  page.history = W.Button(page, "Historial", 80, 22, function()
    ns.UI.Open("requests")
    ns.UI.FilterRequests("ended")
  end)
  page.history:SetPoint("TOPRIGHT", -2, -28)
  page.myRequests = W.Button(page, "Mis pedidos", 92, 22, function()
    ns.UI.Open("requests")
    ns.UI.FilterRequests("mine")
  end)
  page.myRequests:SetPoint("RIGHT", page.history, "LEFT", -4, 0)

  local function updateRequestRow(row, item)
    local r, info = item.r, item.info
    local tags = ""
    if item.priority then tags = tags .. "|cffff80ff[Prioridad]|r " end
    if item.pending > 0 then tags = tags .. "|cff66ccff[Tu encargo]|r " end
    if item.new then tags = tags .. "|cffffd100¡Nuevo!|r " end
    if item.mine then tags = tags .. "|cff999999[Tuyo]|r " end
    local title = tags .. string.format("%dx %s", r.q, ns.KeyLabel(r.k))
    if item.canServe and item.pending == 0 then title = title .. "  |cff40ff40(puedes hacerlo)|r" end
    row.title:SetText(title)

    local parts = { "Pide " .. ns.Social.Who(r.a) .. " (" .. Data.KarmaText(r.a) .. ")" }
    parts[#parts + 1] = "hace " .. ns.FormatDuration(item.now - (r.t or item.now))
    if item.pending > 0 then
      local by = r.c[item.me].by
      local left = by and (by - item.now)
      local color = (left and left <= 15 * 60) and "|cffff4040" or "|cffffffff"
      parts[#parts + 1] = by and ("plazo: " .. color .. (left > 0 and ("quedan " .. ns.FormatDuration(left))
        or "se acaba") .. "|r") or "por enviar"
    elseif item.mine and info.owner then
      local cm = r.c[info.owner]
      parts[#parts + 1] = "lo hace " .. ns.Social.Who(info.owner)
        .. (cm.by and (" (plazo " .. ns.FormatDuration(math.max(0, cm.by - item.now)) .. ")") or "")
    else
      parts[#parts + 1] = "nadie lo ha cogido"
    end
    local urgency = urgencyText(r)
    if urgency then parts[#parts + 1] = urgency end
    if r.g then parts[#parts + 1] = "propina " .. ns.FormatMoney(r.g) end
    row.sub:SetText(table.concat(parts, "  |cff666666·|r  "))

    local mats
    if not item.mine then
      mats = materialsStatus(r, item.pending > 0 and item.pending or info.remaining)
    end
    if not mats and r.m and not item.mine then mats = "|cffbbbbbbLos materiales los pone quien pide.|r" end
    row.mats:SetText(mats or "")

    row.view:Show()
    if item.pending > 0 then
      -- Mi encargo: pedir más tiempo (una vez). Para ver el pedido, clic en la fila.
      row.view:SetText("Más tiempo")
      row.view:SetEnabled(#Data.ExtendOptions(r, item.now) > 0)
      row.view:SetScript("OnClick", function() W.ExtendRequest(r) end)
    else
      row.view:SetText("Ver pedido")
      row.view:SetEnabled(true)
      row.view:SetScript("OnClick", function() ns.UI.Open("requests", r.id) end)
    end
    if item.pending > 0 then
      -- Mi encargo: enviarlo directamente.
      if r.demo then
        row.accept:SetText("Enviar (ejemplo)")
        row.accept:SetEnabled(true)
        row.accept:SetScript("OnClick", function() ns.Demo.SimulateMail(r) end)
      else
        row.accept:SetText("Preparar correo")
        local can = ns.Mail.CanPrepare()
        row.accept:SetEnabled(can)
        if not can then row.accept.tip = "Abre el buzón para preparar el correo." end
        row.accept:SetScript("OnClick", function() ns.Mail.Prepare(r, item.pending) end)
      end
    else
      row.accept:SetText("Aceptar encargo")
      row.accept:SetEnabled(item.acceptable)
      row.accept:SetScript("OnClick", function() W.AcceptRequest(r) end)
    end
  end

  -- Pedido de fabricación de Blizzard: se coge en la ventana de profesión, no aquí.
  local function updateOrderRow(row, item)
    local o = item.order
    local tags = "|cff40c0ff[Pedido de Blizzard]|r "
    if item.new then tags = tags .. "|cffffd100¡Nuevo!|r " end
    if item.mine then tags = tags .. "|cff999999[Tuyo]|r " end
    local title = tags .. ns.KeyLabel(item.k)
    if item.canServe then title = title .. "  |cff40ff40(puedes hacerlo)|r" end
    row.title:SetText(title)
    row.sub:SetText(string.format("Lo pide %s en los pedidos de fabricación de la hermandad  |cff666666·|r  hace %s",
      ns.Social.Who(o.owner), ns.FormatDuration(item.now - o.t)))
    row.mats:SetText(item.mine and "|cff999999Lo verán quienes saben hacerlo.|r"
      or "|cffbbbbbbCógelo en tu profesión: pestaña Pedidos → Hermandad (puede que ya esté hecho).|r")
    row.view:Hide()
    row.accept:SetText("Ocultar")
    row.accept:SetEnabled(true)
    row.accept:SetScript("OnClick", function() ns.Orders.Dismiss(o.id) end)
  end

  -- Pedido de la hermandad: aportan varios, cada uno lo que pueda.
  local function updateNeedRow(row, item)
    local n = item.need
    local tags = "|cffff9933[Hermandad]|r "
    if item.new then tags = tags .. "|cffffd100¡Nuevo!|r " end
    row.title:SetText(tags .. string.format("%dx %s", n.q, ns.KeyLabel(item.k)))
    row.sub:SetText(string.format("Lo pide %s para la hermandad  |cff666666·|r  aportado |cffffffff%d|r de %d"
      .. "  |cff666666·|r  faltan %d", ns.ShortName(n.owner), n.given, n.q, n.left))
    local donors = {}
    for i = 1, math.min(3, #n.donors) do
      donors[#donors + 1] = ns.Social.Who(n.donors[i].name) .. " " .. n.donors[i].n
    end
    local have = ns.ItemCount(n.id)
    row.mats:SetText((#donors > 0 and ("|cffbbbbbbAportan: " .. table.concat(donors, ", ") .. "|r  ") or "")
      .. (have > 0 and not item.mine and string.format("|cff40ff40Tienes %d.|r", have) or ""))
    row.view:Hide()
    if item.mine then
      row.accept:SetText("Quitar")
      row.accept:SetEnabled(true)
      row.accept:SetScript("OnClick", function()
        W.Confirm("¿Quitar este pedido de la hermandad?", function() ns.Social.RemoveNeed(n.id) end)
      end)
    else
      row.accept:SetText("Aportar")
      row.accept:SetEnabled(true)
      row.accept:SetScript("OnClick", function() ns.UI.ContributeNeed(n) end)
    end
  end

  local function updateOfferRow(row, item)
    local o = item.o
    local tags = "|cff40c0ff[Oferta]|r "
    if item.new then tags = tags .. "|cffffd100¡Nuevo!|r " end
    if item.mine then tags = tags .. "|cff999999[Tuya]|r " end
    row.title:SetText(tags .. string.format("%dx %s", o.q, ns.KeyLabel(item.k)) .. "  (" .. priceText(o.g) .. ")")
    local parts = { "Ofrece " .. ns.Social.Who(o.owner) .. " (" .. Data.KarmaText(o.owner) .. ")" }
    parts[#parts + 1] = "hace " .. ns.FormatDuration(item.now - (o.t or item.now))
    parts[#parts + 1] = o.free > 0 and string.format("quedan %d libres", o.free) or "|cffff9933todo pedido|r"
    row.sub:SetText(table.concat(parts, "  |cff666666·|r  "))
    if item.mine then
      local who = {}
      for _, c in ipairs(o.claims) do who[#who + 1] = ns.ShortName(c.name) .. " " .. c.left end
      row.mats:SetText(#who > 0 and ("|cff66ccffLo quieren: " .. table.concat(who, ", ")
        .. ". Mándaselo por correo: se apunta solo.|r") or "|cff999999Nadie lo ha pedido todavía.|r")
    elseif item.claimed then
      row.mats:SetText(string.format("|cff66ccffHas pedido %d. %s te lo mandará por correo.|r", o.myClaim, ns.ShortName(o.owner)))
    else
      local have = ns.Scan.Have(o.id)
      row.mats:SetText(have > 0 and string.format("|cffbbbbbbTienes %d.|r", have) or "")
    end

    if item.mine then
      row.view:Show()
      row.view:SetText("Quitar oferta")
      row.view:SetEnabled(true)
      row.view:SetScript("OnClick", function()
        W.Confirm("¿Quitar esta oferta?", function() ns.Offers.Remove(o.id) end)
      end)
      local first = o.claims[1]
      if not first then
        -- Nadie la ha pedido aún: anunciarla en el chat de hermandad.
        row.accept:SetText("Anunciar")
        row.accept:SetEnabled(true)
        row.accept.tip = "Anunciarla en el chat de hermandad (para los que no tienen el addon)."
        row.accept:SetScript("OnClick", function()
          if ns.Extras.Announce("offer", o, o.key) then ns.Print("oferta anunciada en el chat de hermandad.") end
        end)
      else
        row.accept:SetText("Preparar correo")
        local can = ns.Mail.CanPrepare()
        row.accept:SetEnabled(can)
        if not can then row.accept.tip = "Abre el buzón para preparar el correo." end
        row.accept:SetScript("OnClick", function() ns.Mail.PrepareOffer(first.name, o.id, first.left, o.g) end)
      end
    elseif item.claimed then
      row.view:Hide()
      row.accept:SetText("Ya no lo quiero")
      row.accept:SetEnabled(true)
      row.accept:SetScript("OnClick", function() ns.Offers.Unclaim(o.key) end)
    else
      row.view:Hide()
      row.accept:SetText("Lo quiero")
      row.accept:SetEnabled(o.free > 0)
      row.accept:SetScript("OnClick", function()
        if o.free <= 1 then
          ns.Offers.Claim(o.key, 1, ns.Now())
        else
          W.AskAmount(string.format("¿Cuántos quieres? (quedan %d)", o.free), 1, function(n)
            local ok, err = ns.Offers.Claim(o.key, n, ns.Now())
            if not ok and err then ns.Print(err) end
          end)
        end
      end)
    end
  end

  local list = W.List(page, 604, 340, {
    rows = 6,
    rowHeight = 54,
    keyOf = function(item) return item.id end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(36, 36)
      row.icon:SetPoint("LEFT", 4, 0)
      local function line(font, y)
        local fs = W.Text(row, font)
        fs:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, y)
        fs:SetPoint("RIGHT", row, "RIGHT", -214, 0)
        fs:SetWordWrap(false)
        return fs
      end
      row.title = line("GameFontHighlight", 6)
      row.sub = line("GameFontHighlightSmall", -10)
      row.mats = line("GameFontHighlightSmall", -24)
      row.accept = W.Button(row, "Aceptar encargo", 114, 22)
      row.accept:SetPoint("RIGHT", -2, 0)
      if row.accept.SetMotionScriptsWhileDisabled then row.accept:SetMotionScriptsWhileDisabled(true) end
      row.accept:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
      end)
      row.accept:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row.view = W.Button(row, "Ver pedido", 90, 22)
      row.view:SetPoint("RIGHT", row.accept, "LEFT", -4, 0)
      W.KeyTooltip(row, function(self) return self.item and self.item.k end)
    end,
    updateRow = function(row, item)
      local _, icon = ns.KeyInfo(item.k)
      row.icon:SetTexture(icon)
      row.accept.tip = nil
      if item.kind == "offer" then
        updateOfferRow(row, item)
      elseif item.kind == "need" then
        updateNeedRow(row, item)
      elseif item.kind == "co" then
        updateOrderRow(row, item)
      else
        updateRequestRow(row, item)
      end
    end,
    onSelect = function(item)
      if item.kind == "req" then ns.UI.Open("requests", item.r.id) end
      if item.kind == "need" then ns.UI.ShowPage("guild") end
    end,
  })
  list:SetPoint("TOPLEFT", 0, -54)

  page.empty = W.Text(page, "GameFontNormal", "CENTER")
  page.empty:SetPoint("CENTER", list, "CENTER", 0, 20)
  page.empty:SetWidth(460)
  page.empty:SetTextColor(0.7, 0.7, 0.7)
  page.askButton = W.Button(page, "Pedir materiales", 140, 22, function() ns.UI.ShowPage("materials") end)
  page.askButton:SetPoint("TOP", page.empty, "BOTTOM", 0, -12)

  page.list, page.state = list, state

  -- ¿Pasa los filtros? (tipo, categoría, búsqueda y "solo lo que puedo hacer")
  local function passes(item, f)
    local show = SHOW[f.show].id
    if show == "requests" and item.kind == "offer" then return false end
    if show == "offers" and item.kind ~= "offer" then return false end
    local cat = CATEGORIES[f.cat].id
    if cat and category(item.k) ~= cat then return false end
    if state.search ~= "" then
      local text = (ns.KeyName(item.k) .. " " .. ns.ShortName(item.author)):lower()
      if not text:find(state.search, 1, true) then return false end
    end
    -- "Solo lo que puedo hacer": pedidos que puedo hacer y lo que tengo que enviar.
    if state.onlyMine and not item.canServe and item.pending == 0 then return false end
    return true
  end

  function page:Refresh()
    local f = settings()
    page.onlyMine:SetChecked(state.onlyMine)
    if not SHOW[f.show] then f.show = 1 end
    if not CATEGORIES[f.cat] then f.cat = 1 end
    page.showButton:SetText(SHOW[f.show].label)
    page.catButton:SetText(CATEGORIES[f.cat].label)
    local all, stats = collect(page.seenAt)
    local items = {}
    for _, item in ipairs(all) do
      if passes(item, f) then items[#items + 1] = item end
    end
    table.sort(items, function(a, b)
      local ra, rb = rank(a), rank(b)
      if ra ~= rb then return ra < rb end
      local pa, pb = a.r and a.r.pr or 9, b.r and b.r.pr or 9
      if pa ~= pb then return pa < pb end -- primero los que corren prisa
      if a.karma ~= b.karma then return a.karma > b.karma end -- luego por karma
      if a.t ~= b.t then return a.t > b.t end
      return a.id < b.id
    end)
    list:SetItems(items)
    local text = string.format("Pedidos: |cffffffff%d|r  Hermandad: |cffff9933%d|r  Ofertas: |cff40c0ff%d|r  Puedes: |cff40ff40%d|r",
      stats.open, stats.guild, stats.offers, stats.servable)
    if stats.new > 0 then text = text .. string.format("  Nuevos: |cffffd100%d|r", stats.new) end
    page.summary:SetText(text)
    local none = #items == 0
    page.empty:SetShown(none)
    page.askButton:SetShown(none)
    if none then
      local filtered = #all > 0
      page.empty:SetText(filtered and "No hay nada con estos filtros."
        or "No hay pedidos ni ofertas ahora mismo.\n|cff999999(Para ver ejemplos, activa el modo demostración en Mis cosas.)|r")
    end
  end

  -- "Nuevo": lo que ha llegado desde la última vez que miraste el tablón. Al entrar se toma
  -- la marca anterior y al salir se guarda la hora.
  page:HookScript("OnShow", function()
    local g = ns.G()
    page.seenAt = g and g.boardSeen or 0
  end)
  local function leave()
    local g = ns.G()
    if g and page.seenAt then g.boardSeen = ns.Now() end
    page.seenAt = nil
  end
  page:HookScript("OnHide", leave)
end)
