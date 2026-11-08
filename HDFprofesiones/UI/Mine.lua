-- Página "Opciones" (antes "Mis cosas"; se entra desde Inicio): mis profesiones publicadas, ajustes y estado de la sincronización.
local _, ns = ...
local W, Data, Guild = ns.W, ns.Data, ns.Guild

ns.UI.RegisterPage("mine", function(page)
  page.charText = W.Text(page, "GameFontNormal")
  page.charText:SetPoint("TOPLEFT", 8, -6)

  page.profText = W.Text(page, "GameFontHighlightSmall")
  page.profText:SetPoint("TOPLEFT", 8, -30)
  page.profText:SetSize(290, 150)
  page.profText:SetJustifyV("TOP")

  -- Personaje principal: los alts suman karma y ayudas con él. Por defecto, el de más nivel.
  local mainLabel = W.Text(page, "GameFontNormalSmall")
  mainLabel:SetPoint("TOPLEFT", 8, -190)
  mainLabel:SetText("Personaje principal:")
  page.mainButton = W.Button(page, "", 150, 22, function()
    local chars = ns.Social.MyChars()
    if #chars < 2 then
      ns.Print("solo conozco este personaje tuyo. Entra con tus alts (con el addon) y podrás elegir.")
      return
    end
    local current = ns.Social.MyMain()
    local nextIdx = 1
    for i, ch in ipairs(chars) do
      if ch.name == current then nextIdx = i % #chars + 1 end
    end
    ns.Social.SetMyMain(chars[nextIdx].name)
    page:Refresh()
  end)
  page.mainButton:SetPoint("LEFT", mainLabel, "RIGHT", 8, 0)
  page.hint = W.Text(page, "GameFontHighlightSmall")
  page.hint:SetPoint("TOPLEFT", 8, -214)
  page.hint:SetWidth(290)
  page.hint:SetTextColor(0.7, 0.7, 0.7)

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
  -- No molestar (1 h, 3 h, hasta mañana): los avisos se guardan y salen después juntos.
  page.quiet = W.Button(page, "", 140, 20, function()
    local opts = ns.Alerts.QUIET_OPTIONS
    local current = ns.Alerts.IsQuiet() and (ns.db.settings.dndOption or 1) or 1
    ns.Alerts.SetQuiet(current % #opts + 1, ns.Now())
    page:Refresh()
  end)
  page.quiet:SetPoint("TOPLEFT", 170, -290)

  page.chatPost = W.Check(page, "Escribir mis pedidos en el chat de hermandad", function(checked)
    ns.db.settings.chatPost = checked
  end)
  page.chatPost:SetPoint("TOPLEFT", 4, -314)

  page.demo = W.Check(page, "Modo demostración (jugadores de ejemplo, solo los ves tú)", function(checked)
    ns.Demo.Set(checked)
  end)
  page.demo:SetPoint("TOPLEFT", 4, -340)

  -- Para la prueba en el juego: autocomprobación e informe de errores.
  page.minimap = W.Check(page, "Icono en el minimapa", function(checked)
    ns.MinimapButton.SetShown(checked)
  end)
  page.minimap:SetPoint("TOPLEFT", 4, -366)

  page.check = W.Button(page, "Comprobar el addon", 140, 22, function() ns.Diag.Show() end)
  page.check:SetPoint("TOPLEFT", 8, -392)
  page.report = W.Button(page, "Copiar informe", 130, 22, function() ns.Diag.Show() end)
  page.report:SetPoint("LEFT", page.check, "RIGHT", 6, 0)
  page.errors = W.Text(page, "GameFontHighlightSmall")
  page.errors:SetPoint("LEFT", page.report, "RIGHT", 8, 0)
  page.errors:SetWidth(150)

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
    page.chatPost:SetChecked(ns.db.settings.chatPost ~= false)
    if ns.Alerts.IsQuiet() then
      page.quiet:SetText("No molestar: " .. ns.FormatDuration(ns.Alerts.QuietUntil() - ns.Now()))
    else
      page.quiet:SetText("No molestar: no")
    end
    page.demo:SetChecked(ns.db.settings.demo and true or false)
    page.minimap:SetChecked(ns.MinimapButton.IsShown())
    local main = ns.Social.MyMain()
    page.mainButton:SetText(ns.ShortName(main))
    local nChars = #ns.Social.MyChars()
    page.hint:SetText(main == me and (nChars > 1 and "Tus alts suman karma y ayudas contigo (pulsa para cambiar)."
      or "Tus alts suman karma y ayudas con tu principal.")
      or ("Este es un alt de " .. ns.ShortName(main) .. "."))
    local nErrors = #(ns.db.errors or {})
    page.errors:SetText(nErrors > 0 and string.format("|cffff8040Hay %d error%s guardado%s: pulsa Copiar informe.|r",
      nErrors, nErrors > 1 and "es" or "", nErrors > 1 and "s" or "") or "|cff999999Sin errores guardados.|r")

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
    local ranking, people = {}, {}
    for name in pairs(g.entries) do
      local person = ns.Social.MainOf(name)
      if not people[person] then
        people[person] = true
        ranking[#ranking + 1] = { name = person, k = Data.KarmaFor(person) }
      end
    end
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
    -- Mis estadísticas: esta semana, la anterior y en total.
    local st = ns.Extras.Stats(now)
    stats[#stats + 1] = " "
    stats[#stats + 1] = "|cffffd100Tus números|r |cff999999(esta semana / la anterior / total)|r"
    for _, s in ipairs(ns.Extras.STAT_NAMES) do
      local function v(t)
        local n = t[s.id] or 0
        return s.money and ns.FormatMoney(n) or tostring(n)
      end
      stats[#stats + 1] = string.format("%s: %s / %s / %s", s.label, v(st.this), v(st.last), v(st.total))
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
