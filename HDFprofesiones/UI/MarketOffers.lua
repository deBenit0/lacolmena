-- Mercado › MIS OFERTAS: lo que ofrezco yo (de mis bolsas o «te lo fabrico»).
--   Botón grande solo cuando hay algo que hacer: MANDÁRSELO si alguien lo quiere (con el buzón
--   abierto), RENOVAR si caduca en menos de 2 días. En pequeño, «editar · quitar · anunciar ·
--   ya lo he enviado».
local _, ns = ...
local W, Data = ns.W, ns.Data

local RENEW_BEFORE = 2 * 86400

local function priceText(g) return "Precio: " .. ns.UI.PriceText(g) end

-- «Ya lo he enviado»: apunta como entregado lo que le falta a quien lo quería.
local function markSent(o)
  local function amount(cl) return math.min(cl.left or 0, o.q or 0) end
  local function mark(cl)
    local n = ns.Offers.MarkSent(cl.name, o.id, ns.Now())
    if n > 0 then ns.Print("apuntado: %dx %s entregadas a %s.", n, ns.KeyLabel("i" .. o.id), ns.DisplayName(cl.name)) end
  end
  if #o.claims == 1 then
    local cl = o.claims[1]
    W.Confirm(string.format("¿Ya le has dado %dx %s a %s? Se apuntará como entregado.", amount(cl),
      ns.KeyName("i" .. o.id), ns.DisplayName(cl.name)), function() mark(cl) end)
  else
    local labels, shown = {}, {}
    for i = 1, math.min(4, #o.claims) do
      shown[i] = o.claims[i]
      labels[i] = string.format("%s (%d)", ns.DisplayName(o.claims[i].name), amount(o.claims[i]))
    end
    W.Choose("¿A quién se lo has dado?", ns.KeyName("i" .. o.id) .. " · se apuntará como entregado", labels,
      function(i) if shown[i] then mark(shown[i]) end end)
  end
end

local function fillOffer(it, now)
  local o = it.o
  local s = { title = ns.KeyLabel(it.k), qty = o.q }
  local expires = (o.t or 0) + ns.Offers.OFFER_TTL
  s.sub = "|cff66ccffDe tus bolsas|r |cff666666·|r " .. priceText(o.g) .. " |cff666666·|r " .. (ns.UI.Market.ExpiresText(expires, now) or "")
  local renew = function()
    local ok, err = ns.Offers.Renew(o.id, ns.Now())
    if not ok and err then ns.Print(err) end
  end
  if #o.claims > 0 then
    local names = {}
    for i = 1, math.min(2, #o.claims) do names[i] = ns.DisplayName(o.claims[i].name) .. " " .. o.claims[i].left end
    s.hint = "|cff66ccffLo quiere" .. (#o.claims > 1 and "n" or "") .. ": " .. table.concat(names, ", ")
      .. (#o.claims > 2 and "…" or "") .. "|r"
    s.gold = true
    local first = o.claims[1]
    local can = ns.Mail.CanPrepare()
    s.button = { label = "MANDÁRSELO", color = W.BLUE, can = can,
      fn = function() ns.Mail.PrepareOffer(first.name, o.id, first.left, o.g) end,
      tip = can and ("Prepara el correo para " .. ns.DisplayName(first.name) .. ". Se apunta solo al enviarlo.")
        or "Abre un buzón para mandárselo." }
  else
    s.hint = "|cff999999Nadie lo ha pedido todavía|r"
    if expires - now < RENEW_BEFORE then
      s.button = { label = "RENOVAR", color = W.BLUE, fn = renew, tip = "Vuelve a contar los 14 días." }
    end
  end
  s.small = {
    { label = "editar", fn = function() ns.UI.OpenOfferDialog(o.id, o.q, nil, { edit = true, price = o.g, note = o.nt }) end,
      tip = "Cambiar la cantidad, el precio o la nota." },
    { label = "quitar", fn = function() W.Confirm("¿Quitar esta oferta?", function() ns.Offers.Remove(o.id) end) end },
    { label = "anunciar", fn = function() ns.UI.Market.Announce("offer", o) end,
      tip = "Anunciarla en el chat de hermandad (para los que no tienen el addon)." },
  }
  if #o.claims > 0 then
    s.small[#s.small + 1] = { label = "ya lo he enviado", fn = function() markSent(o) end,
      tip = "Si se lo diste sin que el addon lo viera (en mano, desde otro personaje...)." }
  elseif s.button == nil then
    s.small[#s.small + 1] = { label = "renovar", fn = renew, tip = "Vuelve a contar los 14 días." }
  end
  return s
end

local function fillCraft(it, now)
  local grp = it.craft
  local my = ns.Offers.MyCrafts()[it.k] or {}
  local s = { title = ns.KeyLabel(it.k) }
  local expires = (grp.myT or 0) + ns.Offers.CRAFT_TTL
  s.sub = "|cff66ccffTe lo fabrico|r |cff666666·|r " .. priceText(my.g) .. " |cff666666·|r "
    .. (my.m and "pones tú los materiales" or "materiales de quien pide") .. " |cff666666·|r "
    .. (ns.UI.Market.ExpiresText(expires, now) or "")
  local others = #grp.crafters - 1
  s.hint = others > 0 and string.format("|cff999999También lo ofrece%s %d más|r", others > 1 and "n" or "", others)
    or "|cff999999Te lo pedirán desde el Tablón|r"
  local renew = function() ns.Offers.RenewCrafts(ns.Now()) end
  if expires - now < RENEW_BEFORE then
    s.button = { label = "RENOVAR", color = W.BLUE, fn = renew, tip = "Vuelve a contar los 30 días de todas tus recetas ofrecidas." }
  end
  s.small = {
    { label = "editar", fn = function()
      local kind, id = ns.ParseKey(it.k)
      if kind == "i" then
        ns.UI.OpenOfferDialog(id, nil, nil, { edit = true, craft = true, price = my.g, mats = my.m == 1, note = my.nt })
      else
        ns.UI.OpenAsk("craft")
      end
    end, tip = "Cambiar el precio, los materiales o la nota." },
    { label = "quitar", fn = function()
      W.Confirm("¿Dejar de ofrecer fabricarlo?", function() ns.Offers.RemoveCraft(it.k) end)
    end },
  }
  if not s.button then s.small[#s.small + 1] = { label = "renovar", fn = renew, tip = "Vuelve a contar los 30 días." } end
  return s
end

local function fill(it)
  local now = it.now or ns.Now()
  if it.kind == "craft" then return fillCraft(it, now) end
  return fillOffer(it, now)
end

ns.UI.MarketView("offers", function(view, M)
  view.title = W.Text(view, "GameFontNormal")
  view.title:SetPoint("TOPLEFT", 4, -8)
  view.title:SetText("Lo que ofreces tú")
  view.count = W.Text(view, "GameFontHighlightSmall", "RIGHT")
  view.count:SetPoint("TOPRIGHT", -4, -10)
  view.count:SetTextColor(0.7, 0.7, 0.7)
  M.CardList(view, 30, fill, "No ofreces nada. Pulsa «+ OFRECER»: algo de tus bolsas o fabricar algo.",
    { label = "+ OFRECER", fn = function() ns.UI.OpenOffer() end })

  function view:Refresh(data)
    if not data then return end
    view.data = data
    local items, want = {}, 0
    for _, it in ipairs(data.items) do
      if it.mine and (it.kind == "offer" or it.kind == "craft") then
        items[#items + 1] = it
        if it.kind == "offer" and #it.o.claims > 0 then want = want + 1 end
      end
    end
    table.sort(items, function(a, b)
      local wa = a.kind == "offer" and #a.o.claims > 0 and 0 or 1
      local wb = b.kind == "offer" and #b.o.claims > 0 and 0 or 1
      if wa ~= wb then return wa < wb end
      if a.kind ~= b.kind then return a.kind == "offer" end
      if a.t ~= b.t then return a.t > b.t end
      return a.id < b.id
    end)
    view:SetCards(items)
    view.count:SetText(string.format("%d ofertas · %d con alguien esperando", #items, want))
    ns.UI.MarketDetail.Refresh(items)
  end

  function view:Select(id)
    for _, it in ipairs(view.shown or {}) do
      if it.id == id then return ns.UI.MarketDetail.Show(it) end
    end
  end
end)
