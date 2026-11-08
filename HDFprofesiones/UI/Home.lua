-- Página "Inicio": lo primero que se ve al abrir el addon. Resumen de lo tuyo (encargos por
-- terminar, pedidos abiertos y quedadas de mazmorra), botones a Mis pedidos, Mis encargos y
-- Opciones, y la explicación de cómo funciona (solo al pulsar "+info").
local _, ns = ...
local W, Data = ns.W, ns.Data

local LOGO = "Interface\\AddOns\\HDFprofesiones\\Media\\norrisplay"
local MAX_LINES = 3 -- filas de cada bloque del resumen

local HELP = table.concat({
  "|cffffd100Pedidos|r",
  "· |cffffffffTablón|r: lo que pide y ofrece la gente. Acepta un encargo (diciendo cuándo lo tendrás) o "
    .. "pulsa |cffffffffLo quiero|r en una oferta. Al enviarlo por correo |cff40ff40se completa solo|r.",
  "· |cffffffffEn tu profesión|r: ratón sobre un material → |cffffffffPedir|r; sobre lo que fabricas → "
    .. "|cffffffffOfrecer|r. También en |cffffffffPedir materiales|r.",
  "· |cffffffffPedidos de la hermandad|r |cffff9933[Hermandad]|r: los ponen los oficiales y se abastecen entre "
    .. "varios con |cffffffffAportar|r. En la pestaña Hermandad, además, el miembro de la semana.",
  "· |cffffffffMis pedidos|r y |cffffffffMis encargos|r (aquí, en Inicio): lo que has pedido y lo que te toca "
    .. "hacer. Tus pedidos se pueden borrar.",
  "· |cffffffffOpciones|r: tus profesiones, tu personaje principal, avisos, icono del minimapa y "
    .. "|cffff8040modo demostración|r.",
  " ",
  "|cffffd100Karma|r: +1 por cada pedido u oferta que das y -1 por cada uno que recibes (tus alts suman contigo).",
  "|cffffd100Mazmorras|r: propón una y la gente se apunta por rol; |cffffffffHacer grupo|r elige 1 tanque, "
    .. "1 sanador y 3 DPS. Cuando ya habéis ido, |cffffffffHECHO|r cierra la quedada.",
  "|cffffd100Eventos|r y |cffffd100Raids|r: próximamente.",
  "|cff999999Para que tus recetas salgan a los demás, abre una vez la ventana de cada profesión.|r",
}, "\n")

-- Lo que me queda por enviar de un pedido que acepté (0 si nada).
local function toSend(r, me, now)
  local cm = r.a ~= me and r.c and r.c[me]
  if not cm or not Data.CommitActive(cm, now, r) then return 0 end
  return math.max(0, (cm.n or 0) - Data.DeliveredOf(cm))
end

-- Un bloque del resumen: título con botón "Ver" a la derecha y unas líneas debajo.
local function block(page, y, title, onView)
  local b = {}
  b.title = W.Text(page, "GameFontNormal")
  b.title:SetPoint("TOPLEFT", 14, y)
  b.title:SetText(title)
  b.view = W.Button(page, "Ver", 56, 18, onView)
  b.view:SetPoint("TOPLEFT", 418, y + 2)
  b.text = W.Text(page, "GameFontHighlightSmall")
  b.text:SetPoint("TOPLEFT", 22, y - 18)
  b.text:SetWidth(452)
  b.text:SetJustifyV("TOP")
  b.text:SetSpacing(2)
  function b:SetShown(shown)
    self.title:SetShown(shown)
    self.view:SetShown(shown)
    self.text:SetShown(shown)
  end
  function b:SetLines(lines, empty)
    local out = {}
    for i = 1, math.min(MAX_LINES, #lines) do out[i] = lines[i] end
    if #out == 0 then out[1] = "|cff888888" .. empty .. "|r" end
    if #lines > MAX_LINES then
      out[#out] = out[#out] .. string.format("  |cff999999(y %d más)|r", #lines - MAX_LINES)
    end
    self.text:SetText(table.concat(out, "\n"))
  end
  return b
end

ns.UI.RegisterPage("home", function(page)
  page.motto = W.Text(page, "GameFontNormalHuge", "CENTER")
  page.motto:SetPoint("TOP", 0, -6)
  page.motto:SetTextColor(1, 0.45, 0.1)
  page.motto:SetText("\194\171" .. ns.MOTTO .. "\194\187")

  page.welcome = W.Text(page, "GameFontHighlight", "CENTER")
  page.welcome:SetPoint("TOP", page.motto, "BOTTOM", 0, -4)

  -- Anuncio de los oficiales (el más reciente).
  page.announce = W.Text(page, "GameFontHighlight")
  page.announce:SetPoint("TOPLEFT", 14, -52)
  page.announce:SetWidth(580)
  page.announce:SetJustifyH("LEFT")
  page.announce:SetWordWrap(false)

  -- Botones de Inicio.
  local function openRequests(filter)
    ns.UI.Open("requests")
    ns.UI.FilterRequests(filter)
  end
  page.myOrders = W.Button(page, "MIS PEDIDOS", 132, 24, function() openRequests("mine") end)
  page.myOrders:SetPoint("TOPLEFT", 10, -72)
  page.myCommits = W.Button(page, "MIS ENCARGOS", 132, 24, function() openRequests("involved") end)
  page.myCommits:SetPoint("LEFT", page.myOrders, "RIGHT", 6, 0)
  page.options = W.Button(page, "OPCIONES", 112, 24, function() ns.UI.ShowPage("mine") end)
  page.options:SetPoint("LEFT", page.myCommits, "RIGHT", 6, 0)
  page.info = W.Button(page, "+info", 64, 24)
  page.info:SetPoint("TOPRIGHT", -8, -72)

  -- Resumen.
  page.blocks = {
    commits = block(page, -110, "Tus encargos por terminar", function() openRequests("involved") end),
    orders = block(page, -180, "Pedidos abiertos", function() ns.UI.ShowPage("board") end),
    runs = block(page, -250, "Quedadas de mazmorra", function() ns.UI.ShowPage("dungeons") end),
  }

  -- Explicación (oculta hasta pulsar "+info").
  page.help = W.Text(page, "GameFontHighlightSmall")
  page.help:SetPoint("TOPLEFT", 14, -108)
  page.help:SetWidth(470)
  page.help:SetJustifyV("TOP")
  page.help:SetSpacing(2)
  page.help:SetText(HELP)
  page.help:Hide()
  page.info:SetScript("OnClick", function()
    page.showHelp = not page.showHelp
    page:Refresh()
  end)

  -- Logo de NorrisPlay.
  page.logo = page:CreateTexture(nil, "ARTWORK")
  page.logo:SetSize(80, 160)
  page.logo:SetPoint("TOPRIGHT", -24, -112)
  page.logo:SetTexture(LOGO)
  page.logoPath = LOGO

  page.status = W.Text(page, "GameFontNormal", "CENTER")
  page.status:SetPoint("BOTTOM", 0, 42)
  page.status:SetWidth(580)

  page.goBoard = W.Button(page, "Ver el Tablón", 150, 24, function() ns.UI.ShowPage("board") end)
  page.goBoard:SetPoint("BOTTOMRIGHT", page, "BOTTOM", -4, 10)
  page.goAsk = W.Button(page, "Pedir materiales", 150, 24, function() ns.UI.ShowPage("materials") end)
  page.goAsk:SetPoint("BOTTOMLEFT", page, "BOTTOM", 4, 10)

  local function fillCommits(g, me, now)
    local items = {}
    for _, r in pairs(g.requests) do
      local n = toSend(r, me, now)
      if n > 0 then items[#items + 1] = { r = r, n = n, by = r.c[me].by or 0 } end
    end
    table.sort(items, function(a, b) return a.by < b.by end)
    local lines = {}
    for _, it in ipairs(items) do
      local plazo = ""
      if it.by > 0 then
        local left = it.by - now
        plazo = left > 0 and ("quedan " .. ns.FormatDuration(left)) or "|cffff4040se acaba|r"
      end
      lines[#lines + 1] = string.format("%dx %s para %s  |cff999999%s|r", it.n, ns.KeyLabel(it.r.k),
        ns.ShortName(it.r.a), plazo)
    end
    page.blocks.commits.title:SetText(string.format("Tus encargos por terminar |cffffffff(%d)|r", #items))
    page.blocks.commits:SetLines(lines, "No tienes encargos pendientes.")
  end

  local function fillOrders(g, me, now)
    local open, mine = {}, 0
    for _, r in pairs(g.requests) do
      local info = Data.RequestInfo(r, now)
      if r.a == me and Data.IsActiveState(info.state) then mine = mine + 1 end
      if r.a ~= me and info.state == "open" then
        open[#open + 1] = { r = r, info = info, serve = Data.CanServe(r, now) and true or false }
      end
    end
    -- primero los que puedo hacer, luego los más nuevos
    table.sort(open, function(a, b)
      if a.serve ~= b.serve then return a.serve end
      return (a.r.t or 0) > (b.r.t or 0)
    end)
    local lines = {}
    for _, it in ipairs(open) do
      lines[#lines + 1] = string.format("%dx %s  |cff999999de %s|r%s", it.info.remaining, ns.KeyLabel(it.r.k),
        ns.ShortName(it.r.a), it.serve and "  |cff40ff40(puedes hacerlo)|r" or "")
    end
    page.blocks.orders.title:SetText(string.format("Pedidos abiertos |cffffffff(%d)|r%s", #open,
      mine > 0 and string.format("  |cff66ccff· tuyos activos: %d|r", mine) or ""))
    page.blocks.orders:SetLines(lines, "No hay pedidos abiertos ahora mismo.")
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
      local when = r.at <= now + 120 and "ahora" or ("a las " .. D.Clock(r.at))
      local place = D.MyPlace(r)
      local extra = place and ("  |cff66ccff(vas de " .. place .. ")|r") or (r.gp and "  |cff40ff40(grupo hecho)|r" or "")
      lines[#lines + 1] = string.format("%s  |cff999999%s · %d apuntados · de %s|r%s", D.Dungeon(r.d).name, when,
        #D.SignUps(r), ns.ShortName(r.a), extra)
    end
    page.blocks.runs.title:SetText(string.format("Quedadas de mazmorra |cffffffff(%d)|r", #runs))
    page.blocks.runs:SetLines(lines, "No hay quedadas. Propón una en Mazmorras.")
  end

  function page:Refresh()
    local me = ns.Me()
    page.welcome:SetText("Bienvenido, " .. (me and ns.ShortName(me) or "fundillero") .. ", al addon de "
      .. ns.TITLE .. ".")
    local inGuild = ns.G() ~= nil
    local an = inGuild and ns.Social.Announcement()
    page.announce:SetText(an and string.format("|cffff8040Anuncio de %s:|r %s", ns.ShortName(an.name), an.x) or "")
    page.goBoard:SetEnabled(inGuild)
    page.goAsk:SetEnabled(inGuild)
    page.myOrders:SetEnabled(inGuild)
    page.myCommits:SetEnabled(inGuild)
    page.options:SetEnabled(inGuild)

    -- Sin hermandad no hay resumen que enseñar: se ve la explicación.
    local help = page.showHelp or not inGuild
    page.help:SetShown(help)
    page.info:SetText(page.showHelp and "-info" or "+info")
    for _, b in pairs(page.blocks) do b:SetShown(not help) end
    if not inGuild then
      page.status:SetText("|cff999999No estás en ninguna hermandad.|r")
      return
    end

    local g, now = ns.G(), ns.Now()
    if not help then
      fillCommits(g, me, now)
      fillOrders(g, me, now)
      fillRuns(now)
    end

    local s = ns.UI.BoardStats()
    local parts = {}
    if s.new > 0 then parts[#parts + 1] = string.format("|cffffd100%d nuevos en el Tablón|r", s.new) end
    if s.servable > 0 then parts[#parts + 1] = string.format("|cff40ff40%d puedes hacerlos|r", s.servable) end
    local best = ns.Social.MemberOfTheWeek(now)
    if best then
      parts[#parts + 1] = string.format("|cffffd100miembro de la semana: %s|r", ns.Social.Who(best.name))
    end
    page.status:SetText(#parts > 0 and (table.concat(parts, ", ") .. ".") or "")
  end
end)
