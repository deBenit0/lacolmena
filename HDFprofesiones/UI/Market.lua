-- Página "Mercado": tres pestañas y un botón para pedir. Aquí no se ofrece nada: la gente
-- pide y quien puede hacerlo acepta el encargo.
--   TABLÓN (lo de todos) · MIS PEDIDOS (lo que pides) · MIS ENCARGOS (lo que haces para otros),
--   y a la derecha «+ PEDIR» (verde).
-- Cada pestaña está en su archivo (MarketBoard, MarketMine, MarketJobs) y se
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
    tip = "Lo que pide la hermandad. El número: lo que tú puedes hacer o dar." },
  { id = "mine", label = "MIS PEDIDOS", width = 132,
    tip = "Lo que has pedido tú. El número: lo que espera algo de ti (te lo han enviado o caduca)." },
  { id = "jobs", label = "MIS ENCARGOS", width = 140,
    tip = "Lo que te has encargado de hacer para otros. El número: lo que te queda por enviar." },
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
  local c = { board = stats and stats.servable or 0, mine = 0, jobs = 0 }
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
    end
  end
  return c
end

-- Lista de tarjetas para Mis pedidos, Mis encargos y Mis ofertas. fill(it) devuelve lo que
-- se enseña: { title, sub, hint, money, qty, gold, grey,
--   button = { label, color, fn, can, tip }, small = { {label, fn, tip}, ... } (hasta 4) }.
-- Pulsar la tarjeta (no un botón) abre el detalle con todas las acciones.
M.ROWS, M.ROW_H = 7, 48
function M.CardList(view, top, fill, emptyText, emptyButton)
  local list = W.List(view, M.BODY_W, M.BODY_H - top, {
    rows = M.ROWS,
    rowHeight = M.ROW_H,
    card = true,
    keyOf = function(it) return it.id end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(36, 36)
      row.icon:SetPoint("LEFT", 8, 0)
      row.qty = row:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
      row.qty:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)
      row.title = W.ListText(row, "GameFontHighlight")
      row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
      row.title:SetWidth(300)
      row.title:SetWordWrap(false)
      row.sub = W.ListText(row, "GameFontHighlightSmall")
      row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -6)
      row.sub:SetWidth(330)
      row.sub:SetWordWrap(false)
      row.hint = W.ListText(row, "GameFontHighlightSmall")
      row.hint:SetPoint("TOPLEFT", row, "TOPLEFT", 400, -8)
      row.hint:SetWidth(220)
      row.hint:SetWordWrap(false)
      row.money = W.ListText(row, "GameFontNormalSmall")
      row.money:SetPoint("TOPLEFT", row.hint, "BOTTOMLEFT", 0, -5)
      row.money:SetWidth(220)
      row.money:SetWordWrap(false)
      row.button = W.Button(row, "", 140, 28)
      row.button:SetPoint("RIGHT", -8, 0)
      row.button:SetFontSize("normal")
      -- enlaces pequeños (editar · quitar · ...), debajo del texto de la derecha
      row.smalls = {}
      for i = 1, 4 do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(60, 14)
        b.text = W.Text(b, "GameFontNormalSmall")
        b.text:SetPoint("LEFT")
        b:SetScript("OnEnter", function(self)
          self.text:SetTextColor(1, 1, 1)
          if self.tipText then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.label)
            GameTooltip:AddLine(self.tipText, 1, 1, 1, true)
            GameTooltip:Show()
          end
        end)
        b:SetScript("OnLeave", function(self)
          self.text:SetTextColor(1, 0.82, 0)
          GameTooltip:Hide()
        end)
        b:Hide()
        row.smalls[i] = b
      end
      W.KeyTooltip(row, function(self) return self.item and self.item.k end)
    end,
    updateRow = function(row, it)
      local s = fill(it) or {}
      local _, icon = ns.KeyInfo(it.k)
      row.icon:SetTexture(icon)
      row.icon:SetDesaturated(s.grey and true or false)
      row.qty:SetText(s.qty and s.qty > 1 and tostring(s.qty) or "")
      row.title:SetText(s.title or ns.KeyLabel(it.k))
      row.sub:SetText(s.sub or "")
      row.hint:SetText(s.hint or "")
      row.money:SetText(s.money or "")
      local b = s.button
      if b and b.label then
        row.button:SetText(b.label)
        row.button:SetEnabled(b.can ~= false)
        row.button:SetScript("OnClick", b.fn)
        W.Tint(row.button, b.color)
        if b.tip then
          ns.UI.Tip(row.button, b.label, b.tip)
        else
          row.button:SetScript("OnEnter", nil)
        end
        row.button:Show()
      else
        row.button:Hide()
      end
      -- los enlaces pequeños, en fila; si hay, sustituyen a la línea del dinero
      local x = 0
      for i, sb in ipairs(row.smalls) do
        local d = s.small and s.small[i]
        if d then
          sb.text:SetText((i > 1 and "|cff777777·|r " or "") .. d.label)
          sb.text:SetTextColor(1, 0.82, 0)
          sb:SetWidth((sb.text:GetStringWidth() or 40) + 6)
          sb:ClearAllPoints()
          sb:SetPoint("TOPLEFT", row.hint, "BOTTOMLEFT", x, -4)
          x = x + sb:GetWidth() + 2
          sb.label, sb.tipText = d.label, d.tip
          sb:SetScript("OnClick", d.fn)
          sb:Show()
        else
          sb:Hide()
        end
      end
      if s.small and #s.small > 0 then row.money:SetText("") end
      row:SetSelected(s.gold and true or false)
      row:SetAlpha(s.grey and 0.55 or 1)
    end,
    onSelect = function(it) ns.UI.MarketDetail.Show(it) end,
  })
  list:SetPoint("TOPLEFT", 0, -top)
  view.list = list
  view.empty = W.Text(view, "GameFontNormal", "CENTER")
  view.empty:SetPoint("CENTER", list, "CENTER", 0, 14)
  view.empty:SetWidth(600)
  view.empty:SetTextColor(0.7, 0.7, 0.7)
  view.empty:SetText(emptyText)
  if emptyButton then
    view.emptyButton = W.Button(view, emptyButton.label, 170, 24, emptyButton.fn)
    view.emptyButton:SetPoint("TOP", view.empty, "BOTTOM", 0, -10)
  end
  function view:SetCards(items)
    view.shown = items
    list:SetItems(items)
    view.empty:SetShown(#items == 0)
    if view.emptyButton then view.emptyButton:SetShown(#items == 0) end
  end
  return list
end

-- «Anunciar» en el chat de hermandad: queda escrito y lo envía el jugador con Intro (el juego
-- bloquea a veces lo que manda el addon). kind: "request" o "need".
function M.Announce(kind, obj)
  local m = ns.Extras.AnnounceMacro(kind, obj)
  if m then W.ChatCommand(m, "anunciarlo en el chat de hermandad") else ns.Print("no estás en ninguna hermandad.") end
end

-- Con una sola persona, directamente; con varias, se elige (hasta 4).
function M.PickName(names, title, fn)
  local people = {}
  for i, n in ipairs(names) do people[i] = { name = n } end
  if #people == 0 then return end
  ns.UI.MarketDetail.PickPerson(people, title, function(p) fn(p.name) end)
end

-- Para las pestañas de la ventana y la tira pequeña.
function ns.UI.MarketCounts()
  if not ns.G() or not ns.UI.MarketCollect then return { board = 0, mine = 0, jobs = 0 } end
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

  -- Arrastrar un objeto a «+ PEDIR» lo deja ya elegido.
  local function cursorItem()
    if not GetCursorInfo then return nil end
    local kind, id = GetCursorInfo()
    if kind == "item" and id then
      if ClearCursor then ClearCursor() end
      return tonumber(id)
    end
  end
  page.addAsk = W.Tint(W.Button(page, "+ PEDIR", 150, 28, function()
    local id = cursorItem()
    if id then ns.UI.AskFor("i" .. id) else ns.UI.OpenAsk("ask") end
  end), W.GREEN)
  page.addAsk:SetPoint("TOPRIGHT", 0, -2)
  page.addAsk:SetScript("OnReceiveDrag", function()
    local id = cursorItem()
    if id then ns.UI.AskFor("i" .. id) end
  end)
  ns.UI.Tip(page.addAsk, "+ PEDIR", "Pide algo a la hermandad: búscalo, o arrastra aquí un objeto.")

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
  ns.UI.MarketGo = function(id) page:SetView(id) end

  -- Al abrir o cerrar el buzón cambian los botones de correo (PREPARAR CORREO, MANDÁRSELO).
  local function mailChanged()
    ns.After(0.2, function() if page:IsVisible() then page:Refresh() end end)
  end
  ns.On("MAIL_SHOW", mailChanged)
  ns.On("MAIL_CLOSED", mailChanged)

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
  --   side: ya no se usa (era para las ofertas)
  function page:SetChip(chip, side)
    local id = "board"
    if chip == "involved" then
      id = "jobs"
    elseif chip == "mine" then
      id = "mine"
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
