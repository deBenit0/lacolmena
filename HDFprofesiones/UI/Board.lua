-- Datos del Mercado (pedidos, pedidos de Blizzard y de la hermandad) y la ventana
-- "Lo que necesita la hermandad". La página que los enseña está en Market.lua.
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

-- ¿Puedo aceptar este pedido ahora? (no es mío, está abierto y queda algo sin coger)
local function canAccept(r, info, me)
  return r.a ~= me and info.state == "open" and info.remaining > 0
end

-- Lo que me queda por enviar de un pedido que acepté (0 si nada).
local function toSend(r, me, now)
  local cm = r.a ~= me and r.c and r.c[me]
  if not cm or not Data.CommitActive(cm, now, r) then return 0 end
  -- cerrado por el autor (o un oficial) o ya completo: no queda nada que enviar
  if r.x or not Data.IsActiveState(Data.RequestInfo(r, now).state) then return 0 end
  return math.max(0, (cm.n or 0) - Data.DeliveredOf(cm))
end

-- Lo que me falta para fabricar "amount" de un pedido: lista { {id, n} } (vacía si lo tengo
-- todo). nil si no lo fabrico yo; false si aún no sé la receta (hay que abrir la profesión);
-- "m" si los materiales los pone quien pide.
local function missingMaterials(r, amount)
  local c = ns.MyChar()
  for pk, prof in pairs(c and c.profs or {}) do
    if prof.recipes and prof.recipes[r.k] then
      if r.m then return "m" end
      local info = Data.GetInfo(Data.InfoKey(pk, r.k))
      local var = info and info.v and info.v[1]
      if not var then return false end
      local times = math.ceil(amount / math.max(1, var.m or 1))
      local ids = {}
      for mid in pairs(var.r) do ids[#ids + 1] = mid end
      table.sort(ids)
      local missing = {}
      for _, mid in ipairs(ids) do
        local need = var.r[mid] * times - ns.Scan.Have(mid)
        if need > 0 then missing[#missing + 1] = { id = mid, n = need } end
      end
      return missing
    end
  end
end
ns.UI.MissingMaterials = missingMaterials

-- ¿Tengo lo necesario para hacer "amount"? Texto para la fila, o nil si no lo hago yo.
local function materialsStatus(r, amount)
  local kind, id = ns.ParseKey(r.k)
  local missing = missingMaterials(r, amount)
  if missing == "m" then return "|cff40ff40Los materiales los pone quien pide.|r" end
  if missing == false then return "|cff999999Abre tu ventana de profesión para saber si tienes los materiales.|r" end
  if missing then
    if #missing == 0 then return "|cff40ff40Tienes los materiales para hacerlo ya.|r" end
    local parts = {}
    for i, m in ipairs(missing) do parts[i] = m.n .. "x " .. ns.KeyName("i" .. m.id) end
    return "|cffff4040Te faltan: " .. table.concat(parts, ", ") .. "|r"
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

-- Pedidos del tablón, y sus números (también los usa la página de inicio).
local function collect(seenAt)
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  local items = {}
  local stats = { open = 0, servable = 0, new = 0, toSend = 0, guild = 0 }
  if not g then return items, stats end
  for _, r in pairs(g.requests) do
    local info = Data.RequestInfo(r, now)
    local pending = toSend(r, me, now)
    local mine = r.a == me
    -- abiertos y ya cogidos (en el Tablón salen en gris con quién lo hace)
    local visible = Data.IsActiveState(info.state)
    if pending > 0 or visible then
      local item = {
        kind = "req", id = r.id, k = r.k, author = r.a, t = r.t or 0,
        r = r, info = info, me = me, now = now, mine = mine, pending = pending,
        canServe = Data.CanServe(r, now), acceptable = canAccept(r, info, me),
        karma = Data.KarmaFor(r.a), priority = ns.Social.IsPriority(r.id),
        new = not mine and pending == 0 and (r.t or 0) > (seenAt or 0),
      }
      if pending > 0 then stats.toSend = stats.toSend + 1 end
      if info.state == "open" and not mine then stats.open = stats.open + 1 end
      if item.canServe then stats.servable = stats.servable + 1 end
      if item.new and info.state == "open" then stats.new = stats.new + 1 end
      items[#items + 1] = item
    end
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
  if x.pending > 0 then return 0 end -- lo que tengo que enviar (mis encargos)
  if x.kind == "need" then return 1.2 end -- pedidos de la hermandad
  if x.mine then return 5 end
  if x.priority then return 1.5 end  -- marcadas por un oficial
  if x.canServe then return 2 end
  if x.new then return 3 end
  return 4
end

---------------------------------------------------------------------------
-- Ventana "Lo que necesita la hermandad" (la usan los oficiales desde Hermandad)
---------------------------------------------------------------------------
local needDialog

local function createNeedDialog()
  local d = W.Panel("HDFProfNeedDialog", UIParent, 404, 176)
  needDialog = d
  d:SetFrameStrata("DIALOG")
  d:SetToplevel(true)
  d:SetPoint("CENTER", 0, 60)
  d:Hide()
  tinsert(UISpecialFrames, "HDFProfNeedDialog")
  d.title = W.Text(d, "GameFontNormal")
  d.title:SetPoint("TOP", 0, -18)
  d.title:SetText("Lo que necesita la hermandad")
  local close = W.CloseButton(d)
  close:SetPoint("TOPRIGHT", -10, -10)

  -- Objeto: se elige arrastrándolo al cuadro o con mayús+clic en él con la caja de texto activa.
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
  d.itemName:SetPoint("RIGHT", d, "TOPRIGHT", -20, -60)
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

  function d:SetItem(id)
    self.id = id
    local name, icon, link = ns.KeyInfo("i" .. id)
    self.iconTex:SetTexture(icon or ns.QUESTION_ICON)
    self.itemName:SetText(link or name or ns.KeyName("i" .. id))
    self.itemName:Show()
    self.link:Hide()
    if (tonumber(self.qty:GetText()) or 0) < 1 then self.qty:SetText("20") end
  end

  d.info = W.Text(d, "GameFontHighlightSmall")
  d.info:SetPoint("BOTTOMLEFT", 24, 50)
  d.info:SetWidth(330)
  d.info:SetTextColor(0.7, 0.7, 0.7)
  d.info:SetText("Todos lo verán en Hermandad y podrán aportar por correo.")
  local publish = W.Button(d, "Añadir", 96, 22, function() d:Publish() end)
  publish:SetPoint("BOTTOMRIGHT", -22, 18)
  local cancel = W.Button(d, "Cancelar", 86, 22, function() d:Hide() end)
  cancel:SetPoint("RIGHT", publish, "LEFT", -6, 0)

  function d:Publish()
    local ok, err = ns.Social.AddNeed(self.id, tonumber(self.qty:GetText()), ns.Now())
    if not ok then
      ns.Print(err)
      return
    end
    self:Hide()
    ns.Print("añadido a lo que necesita la hermandad: %sx %s.", self.qty:GetText(), ns.KeyLabel("i" .. self.id))
  end
end

-- Abre la ventana para que un oficial añada lo que necesita la hermandad.
function ns.UI.OpenNeedDialog(id)
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  if not needDialog then createNeedDialog() end
  local d = needDialog
  d.id = nil
  d.link:SetText("")
  d.link:Show()
  d.itemName:Hide()
  d.qty:SetText("")
  d.iconTex:SetTexture(ns.QUESTION_ICON)
  if id then d:SetItem(id) end
  d:Show()
end

-- Para el Mercado: los datos y las piezas de texto.
ns.UI.MarketCollect = collect
ns.UI.MarketRank = rank
ns.UI.MaterialsStatus = materialsStatus
ns.UI.PriceText = priceText
