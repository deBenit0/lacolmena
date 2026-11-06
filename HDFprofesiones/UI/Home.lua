-- Página "Inicio": lo primero que se ve al abrir el addon. Explica cómo funciona y lleva a
-- cada sección.
local _, ns = ...
local W = ns.W

local HELP = table.concat({
  "|cffffd100Pedidos|r: pide lo que necesitas a quien sabe fabricarlo o recolectarlo, y acepta los "
    .. "encargos de los demás.",
  "   |cffffffff· Tablón|r: los pedidos de la gente en este momento. Los pedidos van a toda la "
    .. "hermandad y |cffffffffse lo queda el primero que lo acepta|r, diciendo cuándo lo tendrá (ya, antes "
    .. "de 2 horas u hoy; puede pedir más tiempo una vez). Si no lo entrega a tiempo, vuelve al tablón. "
    .. "Mándalo por correo y el pedido "
    .. "|cff40ff40se completa solo|r al enviarlo.",
  "   |cffffffff· Pedir materiales|r: busca el material, elige cuántos, qué prisa tienes y si das "
    .. "propina. También desde tu ventana de profesión: pasa el ratón por un material y pulsa |cffffffffPedir|r.",
  "   |cffffffff· Mis cosas|r: tus profesiones, los avisos y el |cffff8040modo demostración|r "
    .. "(pedidos de ejemplo para probar).",
  "|cffffd100Karma|r: +1 por cada pedido que entregas y -1 por cada uno que recibes. "
    .. "A quien más ayuda le atienden antes.",
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
