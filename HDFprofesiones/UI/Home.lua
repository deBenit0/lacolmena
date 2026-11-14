-- Página "Inicio": lo primero que se ve al abrir el addon. Tres tarjetas (tus encargos, tus
-- pedidos y las quedadas), cada una con su número, lo primero de la lista y un botón que lleva
-- a su sitio ya filtrado. Encima, el anuncio de los oficiales; abajo, lo nuevo del Mercado.
-- La ayuda va en el «?» (al pasar el ratón).
local _, ns = ...
local W, Data = ns.W, ns.Data

local MAX_LINES = 4 -- líneas de cada tarjeta

local HELP = {
  { "Mercado", "Lo que se busca y lo que se ofrece. Pulsa una fila para ver el detalle: quién lo fabrica, "
    .. "aceptar el encargo, susurrar o preparar el correo. Al enviarlo por correo se completa solo." },
  { "+ Pedir y + Ofrecer", "Elige un objeto del catálogo o arrástralo desde tus bolsas al botón." },
  { "Grupos", "Propón una mazmorra hasta 7 días antes. Cada uno se apunta con los papeles que puede hacer "
    .. "y «Hacer grupo» elige 1 tanque, 1 sanador y 3 de daño." },
  { "Hermandad", "Miembro de la semana, karma, quién fabrica qué y, para oficiales, anuncios y pedidos de la hermandad." },
  { "Karma", "+1 por cada pedido u oferta que das y -1 por cada uno que recibes (tus alts suman contigo)." },
  { "Tus recetas", "Para que salgan a los demás, abre una vez la ventana de cada profesión." },
}

-- Lo que me queda por enviar de un pedido que acepté (0 si nada).
local function toSend(r, me, now)
  local cm = r.a ~= me and r.c and r.c[me]
  if not cm or not Data.CommitActive(cm, now, r) then return 0 end
  return math.max(0, (cm.n or 0) - Data.DeliveredOf(cm))
end

-- Abre el Mercado con un filtro rápido puesto.
local function openMarket(chip, side)
  local f = ns.UI.Open("market")
  if f and f.SetChip then f:SetChip(chip, side) end
end
ns.UI.OpenMarket = openMarket

-- Una tarjeta: icono, título, número grande, unas líneas y un botón abajo.
local function card(page, x, icon, title)
  local c = W.Box(page, 250, 300)
  c:SetPoint("TOPLEFT", x, -34)
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(40, 40)
  c.icon:SetPoint("TOPLEFT", 12, -12)
  c.icon:SetTexture(icon)
  c.title = W.Text(c, "GameFontNormal")
  c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, -2)
  c.title:SetText(title)
  c.number = W.Text(c, "GameFontNormalHuge")
  c.number:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, -18)
  c.lines = {}
  for i = 1, MAX_LINES do
    local row = CreateFrame("Frame", nil, c)
    row:SetSize(226, 30)
    row:SetPoint("TOPLEFT", 12, -64 - (i - 1) * 34)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT")
    row.text = W.ListText(row, "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT")
    row.text:SetJustifyV("MIDDLE")
    row.text:SetHeight(30)
    c.lines[i] = row
  end
  c.empty = W.Text(c, "GameFontHighlightSmall", "CENTER")
  c.empty:SetPoint("TOP", 0, -100)
  c.empty:SetWidth(220)
  c.empty:SetTextColor(0.6, 0.6, 0.6)
  c.button = W.Button(c, "", 200, 24)
  c.button:SetPoint("BOTTOM", 0, 12)
  -- lines = { { icono, texto }, ... }
  function c:Fill(count, lines, emptyText, buttonText, onClick)
    self.number:SetText(count > 0 and tostring(count) or "|cff8888880|r")
    for i, row in ipairs(self.lines) do
      local l = lines[i]
      row:SetShown(l ~= nil)
      if l then
        row.icon:SetTexture(l[1] or ns.QUESTION_ICON)
        row.text:SetText(l[2])
      end
    end
    if #lines > MAX_LINES then
      local last = self.lines[MAX_LINES]
      last.text:SetText(last.text:GetText() .. string.format("  |cff999999(y %d más)|r", #lines - MAX_LINES))
    end
    self.empty:SetShown(#lines == 0)
    self.empty:SetText(emptyText or "")
    self.button:SetText(buttonText)
    self.button:SetScript("OnClick", onClick)
  end
  return c
end

ns.UI.RegisterPage("home", function(page)
  -- Anuncio de los oficiales (el más reciente).
  page.announce = W.Text(page, "GameFontHighlight")
  page.announce:SetPoint("TOPLEFT", 6, -6)
  page.announce:SetPoint("RIGHT", page, "RIGHT", -40, 0)
  page.announce:SetWordWrap(false)

  -- Ayuda: un «?» que la enseña al pasar el ratón.
  page.help = CreateFrame("Button", nil, page)
  page.help:SetSize(24, 24)
  page.help:SetPoint("TOPRIGHT", -4, -2)
  local q = page.help:CreateTexture(nil, "ARTWORK")
  q:SetAllPoints()
  q:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  page.help:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  page.help:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Cómo funciona")
    for _, h in ipairs(HELP) do
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(h[1], 1, 0.82, 0)
      GameTooltip:AddLine(h[2], 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  page.help:SetScript("OnLeave", function() GameTooltip:Hide() end)

  page.cards = {
    commits = card(page, 0, "Interface\\Icons\\Trade_BlackSmithing", "Tus encargos"),
    orders = card(page, 262, "Interface\\Icons\\INV_Misc_Note_01", "Tus pedidos"),
    runs = card(page, 524, "Interface\\Icons\\INV_Misc_Key_03", "Quedadas"),
  }

  -- Abajo: lo nuevo del Mercado. (El escudo de NorrisPlay va en la barra de arriba.)
  page.status = W.Text(page, "GameFontNormal")
  page.status:SetPoint("BOTTOMLEFT", 6, 14)
  page.status:SetPoint("RIGHT", page, "RIGHT", -170, 0)
  page.status:SetWordWrap(false)
  page.goMarket = W.Button(page, "Ver el Mercado", 130, 24, function() openMarket("craft") end)
  page.goMarket:SetPoint("BOTTOMRIGHT", -24, 8)

  page.noGuild = W.Text(page, "GameFontNormalLarge", "CENTER")
  page.noGuild:SetPoint("CENTER", 0, 20)
  page.noGuild:SetTextColor(0.6, 0.6, 0.6)
  page.noGuild:SetText("No estás en ninguna hermandad.\nEl addon funciona dentro de una.")

  local function fillCommits(g, me, now)
    local items = {}
    for _, r in pairs(g.requests) do
      local n = toSend(r, me, now)
      if n > 0 then items[#items + 1] = { r = r, n = n, by = r.c[me].by or 0 } end
    end
    table.sort(items, function(a, b) return a.by < b.by end)
    local lines = {}
    for _, it in ipairs(items) do
      local left = it.by > 0 and (it.by - now)
      local plazo = left and (left > 0 and ("quedan " .. ns.FormatDuration(left)) or "|cffff4040se acaba|r") or ""
      local _, icon = ns.KeyInfo(it.r.k)
      lines[#lines + 1] = { icon, string.format("%dx %s\n|cff999999para %s · %s|r", it.n, ns.KeyLabel(it.r.k),
        ns.DisplayName(it.r.a), plazo) }
    end
    page.cards.commits:Fill(#items, lines, "Nadie te ha encargado nada.\nMira lo que puedes hacer.",
      #items > 0 and "Mis encargos" or "Lo que puedo hacer",
      function() openMarket(#items > 0 and "involved" or "craft") end)
  end

  local function fillOrders(g, me, now)
    local mine = {}
    for _, r in pairs(g.requests) do
      local info = Data.RequestInfo(r, now)
      if r.a == me and Data.IsActiveState(info.state) then mine[#mine + 1] = { r = r, info = info } end
    end
    table.sort(mine, function(a, b) return (a.r.t or 0) > (b.r.t or 0) end)
    local lines = {}
    for _, it in ipairs(mine) do
      local who = it.info.owner and ("lo hace " .. ns.DisplayName(it.info.owner)) or "nadie lo ha cogido"
      local _, icon = ns.KeyInfo(it.r.k)
      lines[#lines + 1] = { icon, string.format("%dx %s\n|cff999999%s|r", it.r.q, ns.KeyLabel(it.r.k), who) }
    end
    page.cards.orders:Fill(#mine, lines, "No tienes pedidos abiertos.",
      #mine > 0 and "Mis pedidos" or "+ Pedir",
      function()
        if #mine > 0 then openMarket("mine") else ns.UI.Open("ask") end
      end)
  end

  local function fillRuns(now)
    local D = ns.Dungeons
    local runs = {}
    for _, r in pairs(D.Runs() or {}) do
      if D.State(r, now) == "open" then runs[#runs + 1] = r end
    end
    table.sort(runs, function(a, b) return a.at < b.at end)
    local lines = {}
    for _, r in ipairs(runs) do
      local when = r.at <= now + 120 and "ahora" or (D.DayText(r.at, now) .. " " .. D.Clock(r.at))
      local place = D.MyPlace(r)
      local extra = place and ("vas " .. (place == "en el grupo" and "" or "de ") .. place) or (r.gp and "grupo hecho" or (#D.SignUps(r) .. " apuntados"))
      lines[#lines + 1] = { D.Icon(r.d),
        string.format("%s\n|cff999999%s · %s|r", D.Dungeon(r.d).name, when, extra) }
    end
    page.cards.runs:Fill(#runs, lines, "No hay quedadas.\nPropón una.",
      #runs > 0 and "Ver grupos" or "+ Hacer grupo",
      function()
        local f = ns.UI.Open("dungeons")
        if #runs > 0 then
          if f and f.SelectDay then f:SelectDay(runs[1].at) end
        else
          ns.UI.OpenDungeonDialog()
        end
      end)
  end

  function page:Refresh()
    local inGuild = ns.G() ~= nil
    page.noGuild:SetShown(not inGuild)
    for _, c in pairs(page.cards) do c:SetShown(inGuild) end
    page.status:SetShown(inGuild)
    page.goMarket:SetShown(inGuild)
    local an = inGuild and ns.Social.Announcement()
    page.announce:SetText(an and string.format("|cffff8040Anuncio de %s:|r %s", ns.DisplayName(an.name), an.x) or "")
    if not inGuild then return end

    local g, me, now = ns.G(), ns.Me(), ns.Now()
    fillCommits(g, me, now)
    fillOrders(g, me, now)
    fillRuns(now)

    local s = ns.UI.BoardStats()
    local parts = {}
    if s.new > 0 then parts[#parts + 1] = string.format("|cffffd100%d nuevos en el Mercado|r", s.new) end
    if s.servable > 0 then parts[#parts + 1] = string.format("|cff40ff40%d puedes hacerlos|r", s.servable) end
    local best = ns.Social.MemberOfTheWeek(now)
    if best then
      parts[#parts + 1] = string.format("|cffffd100miembro de la semana: %s|r", ns.Social.Who(best.name))
    end
    page.status:SetText(table.concat(parts, "  ·  "))
  end
end)
