-- Página "Mercado" (0.35): cuatro pestañas y dos botones para crear.
--   TABLÓN (lo de todos) · MIS PEDIDOS (lo que pides) · MIS ENCARGOS (lo que haces para otros)
--   · MIS OFERTAS (lo que ofreces), y a la derecha «+ PEDIR» (verde) y «+ OFRECER» (azul).
-- Cada pestaña está en su archivo (MarketBoard, MarketMine, MarketJobs, MarketOffers) y se
-- registra con ns.UI.MarketView(id, build): build(view, M) monta su contenido en "view" y
-- define view:Refresh(data) y, si quiere, view:Select(id).
local _, ns = ...
local W, Data = ns.W, ns.Data

local M = {}
ns.UI.Market = M
M.HEADER_H = 34
M.BODY_W, M.BODY_H = ns.UI.CONTENT_W, ns.UI.CONTENT_H - M.HEADER_H

M.VIEWS = {
  { id = "board", label = "TABLÓN", width = 116,
    tip = "Lo que pide y ofrece la hermandad. El número: lo que tú puedes hacer o dar." },
  { id = "mine", label = "MIS PEDIDOS", width = 132,
    tip = "Lo que has pedido tú. El número: lo que espera algo de ti (te lo han enviado o caduca)." },
  { id = "jobs", label = "MIS ENCARGOS", width = 140,
    tip = "Lo que te has encargado de hacer para otros. El número: lo que te queda por enviar." },
  { id = "offers", label = "MIS OFERTAS", width = 132,
    tip = "Lo que ofreces tú. El número: lo que alguien quiere y tienes que mandarle." },
}

local builders = {}
function ns.UI.MarketView(id, build) builders[id] = build end

function M.Settings()
  local s = ns.db.settings
  s.market = s.market or {}
  return s.market
end

-- ¿Le queda poco (menos de un día) a algo que caduca en "at"?
function M.Soon(at, now) return at and at - now < 86400 end

-- Cuándo caduca algo, en corto ("caduca en 2 d"); en rojo si queda menos de un día.
function M.ExpiresText(at, now)
  if not at then return nil end
  local left = at - now
  if left <= 0 then return "|cffff4040caducado|r" end
  return (left < 86400 and "|cffff4040" or "|cffbbbbbb") .. "caduca en " .. ns.FormatDuration(left) .. "|r"
end

-- Pedidos ya terminados en los que estuve (los míos o los que hice): el historial.
function M.EndedItems(g, me, now)
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

-- ¿Me han enviado algo de este pedido mío que aún no he dado por recibido?
function M.SentToMe(r)
  for _, cm in pairs(r.c or {}) do
    if (cm.s or 0) > (cm.d or 0) then return true end
  end
  return false
end

-- Lo que espera algo de mí en cada pestaña. En Mis pedidos cuentan también los ya completos
-- por correo que aún no he dado por recibidos.
function M.Counts(items, stats, now)
  local c = { board = stats and stats.servable or 0, mine = 0, jobs = 0, offers = 0 }
  local g, me = ns.G(), ns.Me()
  for _, r in pairs(g and g.requests or {}) do
    if r.a == me and not r.x then
      local info = Data.RequestInfo(r, now)
      if M.SentToMe(r) or (info.state == "open" and M.Soon(info.expires, now)) then c.mine = c.mine + 1 end
    end
  end
  for _, it in ipairs(items or {}) do
    if it.kind == "req" and it.mine then
      -- (contados arriba)
    elseif it.kind == "req" and it.pending > 0 then
      c.jobs = c.jobs + 1
    elseif it.kind == "offer" and it.mine and it.pending > 0 then
      c.offers = c.offers + 1
    end
  end
  return c
end

-- Para las pestañas de la ventana y la tira pequeña.
function ns.UI.MarketCounts()
  if not ns.G() or not ns.UI.MarketCollect then return { board = 0, mine = 0, jobs = 0, offers = 0 } end
  local g = ns.G()
  local items, stats = ns.UI.MarketCollect(g.boardSeen)
  return M.Counts(items, stats, ns.Now())
end

ns.UI.RegisterPage("market", function(page)
  page.views, page.tabs, page.badges = {}, {}, {}

  -- Pestañas
  local x = 0
  for _, v in ipairs(M.VIEWS) do
    local b = W.Tab(page, v.label, v.width, 28, function() page:SetView(v.id) end)
    b:SetPoint("TOPLEFT", x, -2)
    ns.UI.Tip(b, v.label, v.tip)
    local badge = ns.UI.Badge(b)
    badge:SetPoint("TOPRIGHT", 4, 6)
    page.tabs[v.id], page.badges[v.id] = b, badge
    x = x + v.width + 6
  end

  -- Arrastrar un objeto a «+ PEDIR» o «+ OFRECER» lo deja ya elegido.
  local function cursorItem()
    if not GetCursorInfo then return nil end
    local kind, id = GetCursorInfo()
    if kind == "item" and id then
      if ClearCursor then ClearCursor() end
      return tonumber(id)
    end
  end
  page.addOffer = W.Tint(W.Button(page, "+ OFRECER", 124, 28, function()
    local id = cursorItem()
    if id then ns.UI.OpenOfferDialog(id) else ns.UI.OpenAsk("offer") end
  end), W.BLUE)
  page.addOffer:SetPoint("TOPRIGHT", 0, -2)
  page.addOffer:SetScript("OnReceiveDrag", function()
    local id = cursorItem()
    if id then ns.UI.OpenOfferDialog(id) end
  end)
  page.addAsk = W.Tint(W.Button(page, "+ PEDIR", 124, 28, function()
    local id = cursorItem()
    if id then ns.UI.AskFor("i" .. id) else ns.UI.OpenAsk("ask") end
  end), W.GREEN)
  page.addAsk:SetPoint("RIGHT", page.addOffer, "LEFT", -6, 0)
  page.addAsk:SetScript("OnReceiveDrag", function()
    local id = cursorItem()
    if id then ns.UI.AskFor("i" .. id) end
  end)
  ns.UI.Tip(page.addAsk, "+ PEDIR", "Pide algo a la hermandad: búscalo, o arrastra aquí un objeto.")
  ns.UI.Tip(page.addOffer, "+ OFRECER", "Ofrece algo de tus bolsas, o fabricar algo de tus recetas.")

  -- Cuerpo: una vista por pestaña.
  for _, v in ipairs(M.VIEWS) do
    local f = CreateFrame("Frame", nil, page)
    f:SetPoint("TOPLEFT", 0, -M.HEADER_H)
    f:SetSize(M.BODY_W, M.BODY_H)
    f:Hide()
    if builders[v.id] and ns.SafeCall(builders[v.id], f, M) then page.views[v.id] = f end
  end

  function page:SetView(id)
    if not page.views[id] then id = "board" end
    M.Settings().tab = id
    page.current = id
    page:Refresh()
  end

  function page:Refresh()
    local g = ns.G()
    if not g then return end
    local now, me = ns.Now(), ns.Me()
    local items, stats = ns.UI.MarketCollect(page.seenAt)
    local counts = M.Counts(items, stats, now)
    page.current = page.views[page.current or M.Settings().tab] and (page.current or M.Settings().tab) or "board"
    for id, b in pairs(page.tabs) do
      b:SetOn(id == page.current)
      page.badges[id]:SetCount(counts[id])
    end
    for id, f in pairs(page.views) do f:SetShown(id == page.current) end
    local view = page.views[page.current]
    if view and view.Refresh then
      ns.SafeCall(view.Refresh, view, { g = g, me = me, now = now, items = items, stats = stats, counts = counts,
        seenAt = page.seenAt })
    end
  end

  -- Desde Inicio, los avisos y otras páginas (nombres de la 0.34).
  --   chip: "craft" (lo que puedes hacer) · "mine" (lo tuyo) · "involved" (lo que haces)
  --   side: "offer" (ofertas) o "want"
  function page:SetChip(chip, side)
    local id = "board"
    if chip == "involved" then
      id = "jobs"
    elseif chip == "mine" then
      id = side == "offer" and "offers" or "mine"
    end
    local view = page.views[id]
    if id == "board" and view and view.SetQuick then view:SetQuick(chip, side) end
    page:SetView(id)
  end

  -- Elige algo concreto (un pedido por su id, una oferta "o:...", etc.): va a su pestaña.
  function page:SelectById(id)
    local g, me = ns.G(), ns.Me()
    local r = g and g.requests[id]
    local view = "board"
    if r and r.a == me then
      view = "mine"
    elseif r and r.c and r.c[me] then
      view = "jobs"
    elseif type(id) == "string" and id:sub(1, 2) == "o:" then
      local owner = ns.Offers and ns.Offers.ParseKey(id:sub(3))
      if owner == me then view = "offers" end
    end
    page:SetView(view)
    local f = page.views[view]
    if f and f.Select then f:Select(id) end
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
  end)
end)
