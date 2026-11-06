-- Página "Inicio": lo primero que se ve al abrir el addon. Explica cómo funciona y lleva a
-- cada sección.
local _, ns = ...
local W = ns.W

local HELP = table.concat({
  "|cffffd100Pedidos|r: pide lo que necesitas a quien sabe fabricarlo o recolectarlo, y acepta los "
    .. "encargos de los demás.",
  "   |cffffffff· Tablón|r: los pedidos de la gente en este momento. Arriba, tus encargos por enviar "
    .. "y lo que puedes hacer (te dice si tienes los materiales). Pulsa |cffffffffAceptar encargo|r, "
    .. "mándalo por correo y el pedido |cff40ff40se completa solo|r al enviarlo.",
  "   |cffffffff· Pedir materiales|r: busca el material, elige cuántos y pídelo. También puedes pedir "
    .. "desde tu ventana de profesión: pasa el ratón por un material y pulsa |cffffffffPedir|r.",
  "   |cffffffff· Mis cosas|r: tus profesiones, los avisos y el |cffff8040modo demostración|r "
    .. "(pedidos de ejemplo para probar).",
  "|cffffd100Karma|r: sube cuando entregas y baja cuando recibes (1 punto por cada oro que vale en "
    .. "subasta). A quien más ayuda le atienden antes.",
  "|cffffd100Mazmorras|r y |cffffd100Eventos|r: próximamente.",
  "|cff999999Para que tus recetas salgan a los demás, abre una vez la ventana de cada profesión.|r",
}, "\n\n")

ns.UI.RegisterPage("home", function(page)
  page.motto = W.Text(page, "GameFontNormalHuge", "CENTER")
  page.motto:SetPoint("TOP", 0, -6)
  page.motto:SetTextColor(1, 0.45, 0.1)
  page.motto:SetText("\194\171" .. ns.MOTTO .. "\194\187")

  page.welcome = W.Text(page, "GameFontHighlight", "CENTER")
  page.welcome:SetPoint("TOP", page.motto, "BOTTOM", 0, -6)

  page.help = W.Text(page, "GameFontHighlightSmall")
  page.help:SetPoint("TOPLEFT", 14, -66)
  page.help:SetWidth(580)
  page.help:SetJustifyV("TOP")
  page.help:SetSpacing(2)
  page.help:SetText(HELP)

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
    page.status:SetText(table.concat(parts, ", ") .. ".")
  end
end)
