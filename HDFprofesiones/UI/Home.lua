-- Página "Inicio": lo primero que se ve al abrir el addon. Arriba el mensaje del día; luego
-- tres cajas (mis encargos, mis pedidos y grupos), cada una con su «Ver...»; lo que te espera en
-- el Mercado; la información de la hermandad; y abajo, el anuncio y el miembro de la semana.
-- La ayuda va en el «?» (al pasar el ratón).
local _, ns = ...
local W, Data = ns.W, ns.Data

local MAX_LINES = 2 -- líneas de cada tarjeta

local HELP = {
  { "Mercado", "Lo que pide la hermandad. Pulsa una fila para ver el detalle: quién lo fabrica, "
    .. "aceptar el encargo, susurrar o preparar el correo. Al enviarlo por correo se completa solo." },
  { "+ Pedir", "Elige un objeto del catálogo o arrástralo desde tus bolsas al botón." },
  { "Grupos", "Propón una mazmorra hasta 7 días antes. Cada uno se apunta con los papeles que puede hacer "
    .. "y quien la propuso pulsa «Elegir grupo»: elige 1 tanque, 1 sanador y 3 de daño." },
  { "Hermandad", "Miembro de la semana, roles y quién fabrica qué. Los oficiales ven además el karma, anuncios y pedidos de la hermandad." },
  { "Karma", "+1 por cada pedido que das y -1 por cada uno que recibes (tus alts suman contigo)." },
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

-- Una tarjeta: icono, título, número grande, dos líneas y el botón «Ver...» debajo.
local CARD_W, CARD_H = 254, 170
local function card(page, x, icon, title, buttonText)
  local c = W.Box(page, CARD_W, CARD_H)
  c:SetPoint("TOPLEFT", x, -36)
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
    row:SetSize(CARD_W - 24, 30)
    row:SetPoint("TOPLEFT", 12, -60 - (i - 1) * 34)
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
  c.empty:SetPoint("TOP", 0, -76)
  c.empty:SetWidth(CARD_W - 30)
  c.empty:SetTextColor(0.6, 0.6, 0.6)
  c.button = W.Button(c, buttonText, 200, 24)
  c.button:SetPoint("BOTTOM", 0, 10)
  -- lines = { { icono, texto }, ... }
  function c:Fill(count, lines, emptyText, onClick)
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
    self.button:SetScript("OnClick", onClick)
  end
  return c
end

-- Un texto con el ratón encima enseña el texto entero (cuando no cabe).
local function fullTextTip(frame, title, getText)
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function(self)
    local text = getText()
    if not text or text == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(title)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function guildInfoText()
  local get = _G.GetGuildInfoText
  if not get then return "" end
  local ok, text = pcall(get)
  return ok and type(text) == "string" and text or ""
end

ns.UI.RegisterPage("home", function(page)
  local PAGE_W = ns.UI.CONTENT_W or 788

  -- 1. Arriba: el mensaje del día de la hermandad.
  page.motdBox = W.Box(page, PAGE_W - 32, 28)
  page.motdBox:SetPoint("TOPLEFT", 0, 0)
  page.motd = W.Text(page.motdBox, "GameFontHighlight")
  page.motd:SetPoint("LEFT", 10, 0)
  page.motd:SetPoint("RIGHT", -10, 0)
  page.motd:SetWordWrap(false)
  fullTextTip(page.motdBox, "Mensaje del día", function() return ns.GuildTools and ns.GuildTools.MOTD() end)

  -- Ayuda: un «?» que la enseña al pasar el ratón.
  page.help = CreateFrame("Button", nil, page)
  page.help:SetSize(24, 24)
  page.help:SetPoint("TOPRIGHT", -2, -2)
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

  -- 2. Las tres cajas, cada una con su «Ver...».
  local gap = math.floor((PAGE_W - 3 * CARD_W) / 2)
  page.cards = {
    commits = card(page, 0, "Interface\\Icons\\Trade_BlackSmithing", "Mis encargos", "Ver encargos"),
    orders = card(page, CARD_W + gap, "Interface\\Icons\\INV_Misc_Note_01", "Mis pedidos", "Ver pedidos"),
    runs = card(page, 2 * (CARD_W + gap), "Interface\\Icons\\INV_Misc_Key_03", "Grupos", "Ver grupos"),
  }

  -- 3. Lo que te espera en el Mercado: pedidos que puedes hacer tú.
  page.wait = W.Box(page, PAGE_W, 56)
  page.wait:SetPoint("TOPLEFT", 0, -36 - CARD_H - 8)
  page.waitTitle = W.Text(page.wait, "GameFontNormal")
  page.waitTitle:SetPoint("TOPLEFT", 10, -8)
  page.waitTitle:SetText("Te espera en el Mercado")
  page.waitText = W.Text(page.wait, "GameFontHighlightSmall")
  page.waitText:SetPoint("TOPLEFT", 18, -30)
  page.waitText:SetPoint("RIGHT", page.wait, "RIGHT", -190, 0)
  page.waitText:SetWordWrap(false)
  page.waitButton = W.Button(page.wait, "ME ENCARGO", 160, 26)
  page.waitButton:SetPoint("RIGHT", -12, 0)
  if W.Tint then W.Tint(page.waitButton, W.GREEN) end

  -- 4. Debajo: la información de la hermandad (el texto largo).
  local infoTop = -36 - CARD_H - 8 - 56 - 8
  page.info = W.Box(page, PAGE_W, 448 + infoTop - 30)
  page.info:SetPoint("TOPLEFT", 0, infoTop)
  page.infoTitle = W.Text(page.info, "GameFontNormal")
  page.infoTitle:SetPoint("TOPLEFT", 10, -8)
  page.infoTitle:SetText("Información de la hermandad")
  page.infoText = W.Text(page.info, "GameFontHighlightSmall")
  page.infoText:SetPoint("TOPLEFT", 18, -28)
  page.infoText:SetPoint("BOTTOMRIGHT", -14, 8)
  page.infoText:SetJustifyH("LEFT")
  page.infoText:SetJustifyV("TOP")
  page.infoText:SetWordWrap(true)
  fullTextTip(page.info, "Información de la hermandad", guildInfoText)

  -- 5. Abajo: el anuncio de los oficiales y el miembro de la semana.
  page.status = W.Text(page, "GameFontNormal")
  page.status:SetPoint("BOTTOMLEFT", 6, 6)
  page.status:SetPoint("RIGHT", page, "RIGHT", -6, 0)
  page.status:SetWordWrap(false)

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
    page.cards.commits:Fill(#items, lines, "Nadie te ha encargado nada.", function() openMarket("involved") end)
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
    page.cards.orders:Fill(#mine, lines, "No tienes pedidos abiertos.", function() openMarket("mine") end)
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
    page.cards.runs:Fill(#runs, lines, "No hay grupos.", function()
      local f = ns.UI.Open("dungeons")
      if #runs > 0 and f and f.SelectDay then f:SelectDay(runs[1].at) end
    end)
  end

  -- Lo que puedo hacer yo de lo que piden (abierto y que puedo aceptar).
  local function fillWait()
    local items = {}
    local collect = ns.UI.MarketCollect
    local g = ns.G()
    if collect and g then
      for _, it in ipairs((collect(g.boardSeen))) do
        if it.kind == "req" and not it.mine and it.canServe and it.acceptable then items[#items + 1] = it end
      end
    end
    table.sort(items, function(a, b) return a.t > b.t end)
    local names = {}
    for i = 1, math.min(3, #items) do names[i] = ns.KeyLabel(items[i].k) end
    if #items == 0 then
      page.waitText:SetText("|cff999999Ahora no hay nada de tu profesión.|r")
      page.waitButton:Hide()
      return
    end
    local what = #items == 1 and "1 pedido de tu profesión" or (#items .. " pedidos de tu profesión")
    page.waitText:SetText(what .. "  |cff999999(" .. table.concat(names, ", ") .. (#items > 3 and "..." or "") .. ")|r")
    page.waitButton:Show()
    if #items == 1 then
      local r = items[1].r
      page.waitButton:SetText("ME ENCARGO")
      page.waitButton:SetScript("OnClick", function() W.AcceptRequest(r) end)
    else
      page.waitButton:SetText("VER LOS " .. #items)
      page.waitButton:SetScript("OnClick", function() openMarket("craft") end)
    end
  end

  local shown = { "motdBox", "help", "wait", "info", "status" }
  function page:Refresh()
    local inGuild = ns.G() ~= nil
    page.noGuild:SetShown(not inGuild)
    for _, c in pairs(page.cards) do c:SetShown(inGuild) end
    for _, k in ipairs(shown) do page[k]:SetShown(inGuild) end
    if not inGuild then return end

    local motd = ns.GuildTools and ns.GuildTools.MOTD() or ""
    page.motd:SetText("|cffffd100Mensaje del día:|r " .. (motd ~= "" and motd or "|cff888888(ninguno)|r"))
    local info = guildInfoText()
    page.infoText:SetText(info ~= "" and info or "|cff888888(sin información)|r")

    local g, me, now = ns.G(), ns.Me(), ns.Now()
    fillCommits(g, me, now)
    fillOrders(g, me, now)
    fillRuns(now)
    fillWait()

    local parts = {}
    local an = ns.Social.Announcement()
    if an then parts[#parts + 1] = string.format("|cffff8040Anuncio de %s:|r %s", ns.DisplayName(an.name), an.x) end
    local best = ns.Social.MemberOfTheWeek(now)
    if best then
      parts[#parts + 1] = string.format("|cffffd100Miembro de la semana: %s|r", ns.Social.Who(best.name))
    end
    page.status:SetText(table.concat(parts, "  ·  "))
  end
end)
