-- Datos del Mercado (pedidos, ofertas, pedidos de Blizzard y de la hermandad) y la ventana
-- "Ofrecer objeto". La página que los enseña está en Market.lua.
local _, ns = ...
local W, Data = ns.W, ns.Data

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
      ns.Print("ofrecido en el Mercado: %sx %s.", self.qty:GetText(), ns.KeyLabel("i" .. self.id))
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


-- Para el Mercado: los datos y las piezas de texto.
ns.UI.MarketCollect = collect
ns.UI.MarketRank = rank
ns.UI.MaterialsStatus = materialsStatus
ns.UI.PriceText = priceText
ns.UI.UrgencyText = urgencyText
ns.UI.CanAccept = canAccept
