-- Página "Inicio": lo primero que se ve al abrir el addon. Explica cómo funciona y lleva a
-- cada sección.
local _, ns = ...
local W = ns.W

local LOGO = "Interface\\AddOns\\HDFprofesiones\\Media\\norrisplay"

local HELP = table.concat({
  "|cffffd100Pedidos|r",
  "· |cffffffffTablón|r: lo que pide y ofrece la gente. Acepta un encargo (diciendo cuándo lo tendrás) o "
    .. "pulsa |cffffffffLo quiero|r en una oferta. Al enviarlo por correo |cff40ff40se completa solo|r.",
  "· |cffffffffEn tu profesión|r: ratón sobre un material → |cffffffffPedir|r; sobre lo que fabricas → "
    .. "|cffffffffOfrecer|r. También en |cffffffffPedir materiales|r.",
  "· |cffffffffPedidos de la hermandad|r |cffff9933[Hermandad]|r: los ponen los oficiales y se abastecen entre "
    .. "varios con |cffffffffAportar|r. En la pestaña Hermandad, además, el miembro de la semana.",
  "· |cffffffffMis cosas|r: tus profesiones, tu personaje principal, avisos y |cffff8040modo demostración|r.",
  " ",
  "|cffffd100Karma|r: +1 por cada pedido u oferta que das y -1 por cada uno que recibes (tus alts suman contigo).",
  "|cffffd100Mazmorras|r: propón una y la gente se apunta por rol; |cffffffffHacer grupo|r elige 1 tanque, "
    .. "1 sanador y 3 DPS.",
  "|cffffd100Eventos|r y |cffffd100Raids|r: próximamente.",
  "|cff999999Para que tus recetas salgan a los demás, abre una vez la ventana de cada profesión.|r",
}, "\n")

ns.UI.RegisterPage("home", function(page)
  page.motto = W.Text(page, "GameFontNormalHuge", "CENTER")
  page.motto:SetPoint("TOP", 0, -6)
  page.motto:SetTextColor(1, 0.45, 0.1)
  page.motto:SetText("\194\171" .. ns.MOTTO .. "\194\187")

  page.welcome = W.Text(page, "GameFontHighlight", "CENTER")
  page.welcome:SetPoint("TOP", page.motto, "BOTTOM", 0, -6)

  -- Anuncio de los oficiales (el más reciente).
  page.announce = W.Text(page, "GameFontHighlight")
  page.announce:SetPoint("TOPLEFT", 14, -62)
  page.announce:SetWidth(452)
  page.announce:SetJustifyH("LEFT")

  page.help = W.Text(page, "GameFontHighlightSmall")
  page.help:SetPoint("TOPLEFT", 14, -100)
  page.help:SetWidth(452)
  page.help:SetJustifyV("TOP")
  page.help:SetSpacing(2)
  page.help:SetText(HELP)

  -- Logo de NorrisPlay.
  page.logo = page:CreateTexture(nil, "ARTWORK")
  page.logo:SetSize(80, 160)
  page.logo:SetPoint("TOPRIGHT", -36, -70)
  page.logo:SetTexture(LOGO)
  page.logoPath = LOGO

  page.status = W.Text(page, "GameFontNormal", "CENTER")
  page.status:SetPoint("BOTTOM", 0, 44)
  page.status:SetWidth(580)

  page.goBoard = W.Button(page, "Ver el Tablón", 150, 24, function() ns.UI.ShowPage("board") end)
  page.goBoard:SetPoint("BOTTOMRIGHT", page, "BOTTOM", -4, 10)
  page.goAsk = W.Button(page, "Pedir materiales", 150, 24, function() ns.UI.ShowPage("materials") end)
  page.goAsk:SetPoint("BOTTOMLEFT", page, "BOTTOM", 4, 10)

  function page:Refresh()
    local me = ns.Me()
    page.welcome:SetText("Bienvenido, " .. (me and ns.ShortName(me) or "fundillero") .. ", al addon de "
      .. ns.TITLE .. ".")
    local inGuild = ns.G() ~= nil
    local an = inGuild and ns.Social.Announcement()
    page.announce:SetText(an and string.format("|cffff8040Anuncio de %s:|r %s", ns.ShortName(an.name), an.x) or "")
    page.goBoard:SetEnabled(inGuild)
    page.goAsk:SetEnabled(inGuild)
    if not inGuild then
      page.status:SetText("|cff999999No estás en ninguna hermandad.|r")
      return
    end
    local s = ns.UI.BoardStats()
    local parts = { string.format("Ahora mismo hay |cffffffff%d|r pedidos abiertos", s.open) }
    if s.new > 0 then parts[#parts + 1] = string.format("|cffffd100%d nuevos|r", s.new) end
    if s.servable > 0 then parts[#parts + 1] = string.format("|cff40ff40%d puedes hacerlos|r", s.servable) end
    if s.toSend > 0 then parts[#parts + 1] = string.format("|cff66ccfftienes %d encargos por enviar|r", s.toSend) end
    local best = ns.Social.MemberOfTheWeek(ns.Now())
    if best then
      parts[#parts + 1] = string.format("|cffffd100miembro de la semana: %s|r", ns.Social.Who(best.name))
    end
    local runs = 0
    for _, r in pairs(ns.Dungeons.Runs() or {}) do
      if ns.Dungeons.State(r, ns.Now()) == "open" then runs = runs + 1 end
    end
    if runs > 0 then parts[#parts + 1] = string.format("|cffffd100%d quedadas de mazmorra|r", runs) end
    page.status:SetText(table.concat(parts, ", ") .. ".")
  end
end)
