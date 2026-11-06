-- Página "Mis cosas": mis profesiones publicadas, ajustes y estado de la sincronización.
local _, ns = ...
local W, Data, Guild = ns.W, ns.Data, ns.Guild

ns.UI.RegisterPage("mine", function(page)
  page.charText = W.Text(page, "GameFontNormal")
  page.charText:SetPoint("TOPLEFT", 8, -6)

  page.profText = W.Text(page, "GameFontHighlightSmall")
  page.profText:SetPoint("TOPLEFT", 8, -30)
  page.profText:SetSize(290, 150)
  page.profText:SetJustifyV("TOP")

  page.hint = W.Text(page, "GameFontHighlightSmall")
  page.hint:SetPoint("TOPLEFT", 8, -186)
  page.hint:SetWidth(290)
  page.hint:SetTextColor(0.7, 0.7, 0.7)
  page.hint:SetText("Abre la ventana de cada profesión (sin filtros) para publicar tus recetas. "
    .. "Los cooldowns se actualizan cada vez que la abres.")

  page.unavailable = W.Check(page, "No disponible (sin avisos; apareces el último)", function(checked)
    ns.Sync.SetUnavailable(checked)
  end)
  page.unavailable:SetPoint("TOPLEFT", 4, -236)

  page.alerts = W.Check(page, "Avisarme de peticiones que puedo hacer", function(checked)
    ns.db.settings.alerts = checked
  end)
  page.alerts:SetPoint("TOPLEFT", 4, -262)

  page.sound = W.Check(page, "Sonido en los avisos", function(checked)
    ns.db.settings.sound = checked
  end)
  page.sound:SetPoint("TOPLEFT", 4, -288)

  page.demo = W.Check(page, "Modo demostración (jugadores de ejemplo, solo los ves tú)", function(checked)
    ns.Demo.Set(checked)
  end)
  page.demo:SetPoint("TOPLEFT", 4, -314)

  page.statsTitle = W.Text(page, "GameFontNormal")
  page.statsTitle:SetPoint("TOPLEFT", 320, -6)
  page.statsTitle:SetText("Hermandad")

  page.stats = W.Text(page, "GameFontHighlightSmall")
  page.stats:SetPoint("TOPLEFT", 320, -30)
  page.stats:SetSize(280, 390)
  page.stats:SetJustifyV("TOP")

  function page:Refresh()
    local c, me, g, now = ns.MyChar(), ns.Me(), ns.G(), ns.Now()
    if not c then return end
    page.charText:SetText(ns.ColoredName(me, c.class) .. (c.level and (" - nivel " .. c.level) or ""))

    local profs = {}
    for pk, prof in pairs(c.profs) do profs[#profs + 1] = { pk = pk, prof = prof } end
    table.sort(profs, function(a, b) return ns.ProfessionName(a.pk) < ns.ProfessionName(b.pk) end)
    local lines = {}
    for _, p in ipairs(profs) do
      local count = 0
      for _ in pairs(p.prof.recipes or {}) do count = count + 1 end
      local line = string.format("|cffffd100%s|r %s - %d recetas", ns.ProfessionName(p.pk),
        p.prof.r and string.format("%d/%d", p.prof.r, p.prof.m or 0) or "", count)
      if p.prof.t then
        line = line .. " |cffbbbbbb(leída hace " .. ns.FormatDuration(now - p.prof.t) .. ")|r"
      elseif count == 0 then
        line = line .. " |cffff8040(abre su ventana)|r"
      end
      lines[#lines + 1] = line
    end
    if #lines == 0 then lines[1] = "|cffbbbbbbAún no se ha leído ninguna profesión.|r" end
    page.profText:SetText(table.concat(lines, "\n"))

    page.unavailable:SetChecked(c.u and true or false)
    page.alerts:SetChecked(ns.db.settings.alerts and true or false)
    page.sound:SetChecked(ns.db.settings.sound and true or false)
    page.demo:SetChecked(ns.db.settings.demo and true or false)

    local crafters, online = 0, 0
    for name in pairs(g.entries) do
      crafters = crafters + 1
      if Guild.IsOnline(name) then online = online + 1 end
    end
    local active = 0
    for _, r in pairs(g.requests) do
      if Data.IsActiveState(Data.RequestInfo(r, now).state) then active = active + 1 end
    end
    local peers = 0
    for _ in pairs(ns.Sync.peers) do peers = peers + 1 end

    local stats = {
      (ns.guildName or "?"),
      string.format("Fabricantes publicados: %d (%d en línea)", crafters, online),
      string.format("Peticiones activas: %d", active),
      string.format("Tus peticiones abiertas: %d/%d", Data.CountOpenBy(me, now), Data.MAX_OPEN),
      string.format("Encargos que te han confirmado: %d", Data.ThanksFor(me)),
      "Tu karma: " .. Data.KarmaText(me) .. " |cff999999(+1 por pedido entregado, -1 por pedido recibido)|r",
      " ",
      "|cffffd100Addon|r",
      "Tu versión: " .. ns.VERSION,
    }
    if ns.Sync.newest then
      stats[#stats + 1] = "|cffff8040Hay una versión nueva: " .. ns.Sync.newest .. "|r"
    end
    stats[#stats + 1] = string.format("Compañeros con el addon vistos hoy: %d", peers)
    -- Clasificación de karma (los 5 primeros).
    local ranking = {}
    for name in pairs(g.entries) do ranking[#ranking + 1] = { name = name, k = Data.KarmaFor(name) } end
    table.sort(ranking, function(a, b)
      if a.k ~= b.k then return a.k > b.k end
      return a.name < b.name
    end)
    stats[#stats + 1] = " "
    stats[#stats + 1] = "|cffffd100Más karma|r"
    for i = 1, math.min(5, #ranking) do
      local e = g.entries[ranking[i].name]
      stats[#stats + 1] = string.format("%d. %s  %s", i, ns.ColoredName(ranking[i].name, e and e.c), Data.KarmaText(ranking[i].name))
    end
    stats[#stats + 1] = "Sincronización: " .. (ns.Sync.IsStarted() and "activa" or "esperando a la hermandad...")
    local done, total = ns.Preload.Progress()
    if total > 0 and done < total then
      stats[#stats + 1] = string.format("Cargando nombres de objetos: %d de %d", done, total)
    end
    local queued = ns.Comm.Pending()
    if queued > 0 then stats[#stats + 1] = string.format("Mensajes por enviar: %d", queued) end

    -- Diagnóstico: qué ha encontrado el addon en este cliente (útil para resolver fallos).
    local function yes(ok, good, bad)
      return ok and ("|cff40ff40" .. good .. "|r") or ("|cffff5050" .. bad .. "|r")
    end
    local hostNames = ns.UI.HostNames()
    local profCount = 0
    for _ in pairs(c.profs) do profCount = profCount + 1 end
    local build = GetBuildInfo and select(4, GetBuildInfo())
    stats[#stats + 1] = " "
    stats[#stats + 1] = "|cffffd100Diagnóstico|r"
    stats[#stats + 1] = "Pestaña en: " .. yes(#hostNames > 0, table.concat(hostNames, ", "), "no encontrada")
    stats[#stats + 1] = "Ventana de profesión: " .. yes(GetNumTradeSkills ~= nil, "compatible", "no compatible")
      .. "  (" .. profCount .. " leídas)"
    stats[#stats + 1] = "Correo: " .. yes(SendMail ~= nil, "compatible", "no compatible")
    stats[#stats + 1] = "Interfaz del juego: " .. tostring(build or "?")
    page.stats:SetText(table.concat(stats, "\n"))
  end
end)
