-- Página "Opciones" (rueda dentada): tres grupos con icono.
--   Yo: personaje, profesiones leídas, principal, no disponible y no molestar.
--   Avisos: cada tipo de aviso con encendido, grande en el centro, sonido y también en el chat.
--   Otros: mis pedidos en el chat, minimapa, demostración, comprobar el addon, letra de las listas
--   y el estado.
local _, ns = ...
local W, Data, Guild = ns.W, ns.Data, ns.Guild

local function group(page, x, width, icon, title)
  local box = W.Box(page, width, 418)
  box:SetPoint("TOPLEFT", x, -2)
  box.icon = box:CreateTexture(nil, "ARTWORK")
  box.icon:SetSize(24, 24)
  box.icon:SetPoint("TOPLEFT", 10, -10)
  box.icon:SetTexture(icon)
  box.title = W.Text(box, "GameFontNormalLarge")
  box.title:SetPoint("LEFT", box.icon, "RIGHT", 8, 0)
  box.title:SetText(title)
  return box
end

-- El texto largo de antes (hermandad, tus números y diagnóstico): ahora en «Estado y números».
local function statusText()
  local c, me, g, now = ns.MyChar(), ns.Me(), ns.G(), ns.Now()
  local stats = {}
  if g then
    local crafters, online = 0, 0
    for name in pairs(g.entries) do
      crafters = crafters + 1
      if Guild.IsOnline(name) then online = online + 1 end
    end
    local active = 0
    for _, r in pairs(g.requests) do
      if Data.IsActiveState(Data.RequestInfo(r, now).state) then active = active + 1 end
    end
    stats[#stats + 1] = "|cffffd100" .. (ns.guildName or "Hermandad") .. "|r"
    stats[#stats + 1] = string.format("Fabricantes publicados: %d (%d en línea)", crafters, online)
    stats[#stats + 1] = string.format("Pedidos activos: %d", active)
    stats[#stats + 1] = string.format("Tus pedidos abiertos: %d/%d", Data.CountOpenBy(me, now), Data.MAX_OPEN)
    stats[#stats + 1] = string.format("Encargos que te han confirmado: %d", Data.ThanksFor(me))
    stats[#stats + 1] = "Tu karma: " .. Data.KarmaText(me)
    stats[#stats + 1] = " "
    local st = ns.Extras.Stats(now)
    stats[#stats + 1] = "|cffffd100Tus números|r |cff999999(esta semana / la anterior / total)|r"
    for _, s in ipairs(ns.Extras.STAT_NAMES) do
      local function v(t)
        local n = t[s.id] or 0
        return s.money and ns.FormatMoney(n) or tostring(n)
      end
      stats[#stats + 1] = string.format("%s: %s / %s / %s", s.label, v(st.this), v(st.last), v(st.total))
    end
    stats[#stats + 1] = " "
  end
  local peers = 0
  for _ in pairs(ns.Sync.peers) do peers = peers + 1 end
  stats[#stats + 1] = "|cffffd100Addon|r"
  stats[#stats + 1] = "Tu versión: " .. ns.VERSION
  if ns.Sync.newest then stats[#stats + 1] = "|cffff8040Hay una versión nueva: " .. ns.Sync.newest .. "|r" end
  stats[#stats + 1] = string.format("Compañeros con el addon vistos hoy: %d", peers)
  stats[#stats + 1] = "Sincronización: " .. (ns.Sync.IsStarted() and "activa" or "esperando a la hermandad...")
  local done, total = ns.Preload.Progress()
  if total > 0 and done < total then
    stats[#stats + 1] = string.format("Cargando nombres de objetos: %d de %d", done, total)
  end
  local queued = ns.Comm.Pending()
  if queued > 0 then stats[#stats + 1] = string.format("Mensajes por enviar: %d", queued) end
  local function yes(ok, good, bad)
    return ok and ("|cff40ff40" .. good .. "|r") or ("|cffff5050" .. bad .. "|r")
  end
  local hostNames = ns.UI.HostNames()
  local profCount = 0
  for _ in pairs(c and c.profs or {}) do profCount = profCount + 1 end
  local build = GetBuildInfo and select(4, GetBuildInfo())
  stats[#stats + 1] = " "
  stats[#stats + 1] = "|cffffd100Diagnóstico|r"
  stats[#stats + 1] = "Pestaña en: " .. yes(#hostNames > 0, table.concat(hostNames, ", "), "no encontrada")
  stats[#stats + 1] = "Ventana de profesión: " .. yes(GetNumTradeSkills ~= nil, "compatible", "no compatible")
    .. "  (" .. profCount .. " leídas)"
  stats[#stats + 1] = "Correo: " .. yes(SendMail ~= nil, "compatible", "no compatible")
  stats[#stats + 1] = "Interfaz del juego: " .. tostring(build or "?")
  return table.concat(stats, "\n")
end

ns.UI.RegisterPage("mine", function(page)
  -------------------------------------------------------------------------
  -- Yo
  -------------------------------------------------------------------------
  local me = group(page, 0, 250, "Interface\\Icons\\INV_Misc_Head_Human_01", "Yo")
  page.charText = W.Text(me, "GameFontHighlight")
  page.charText:SetPoint("TOPLEFT", 12, -44)
  page.profText = W.Text(me, "GameFontHighlightSmall")
  page.profText:SetPoint("TOPLEFT", 12, -66)
  page.profText:SetSize(226, 120)
  page.profText:SetJustifyV("TOP")
  page.profText:SetSpacing(2)

  -- Personaje principal: los alts suman karma y ayudas con él. Por defecto, el de más nivel.
  local mainLabel = W.Text(me, "GameFontNormalSmall")
  mainLabel:SetPoint("TOPLEFT", 12, -196)
  mainLabel:SetText("Personaje principal:")
  page.mainButton = W.Button(me, "", 110, 22, function()
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
  page.mainButton:SetPoint("LEFT", mainLabel, "RIGHT", 6, 0)
  page.hint = W.Text(me, "GameFontHighlightSmall")
  page.hint:SetPoint("TOPLEFT", 12, -222)
  page.hint:SetWidth(226)
  page.hint:SetTextColor(0.7, 0.7, 0.7)

  page.unavailable = W.Check(me, "No disponible", function(checked) ns.Sync.SetUnavailable(checked) end)
  page.unavailable:SetPoint("TOPLEFT", 8, -256)
  ns.UI.Tip(page.unavailable, "No disponible", "Sin avisos, y sales el último en «Quién lo fabrica».")
  -- No molestar (1 h, 3 h, hasta mañana): los avisos se guardan y salen después juntos.
  page.quiet = W.Button(me, "", 200, 22, function()
    local opts = ns.Alerts.QUIET_OPTIONS
    local current = ns.Alerts.IsQuiet() and (ns.db.settings.dndOption or 1) or 1
    ns.Alerts.SetQuiet(current % #opts + 1, ns.Now())
    page:Refresh()
  end)
  page.quiet:SetPoint("TOPLEFT", 12, -288)
  ns.UI.Tip(page.quiet, "No molestar", "Los avisos se guardan y salen después, juntos.")

  -- Rol de este personaje (para el recuento de la Hermandad): sale de los talentos y se puede
  -- elegir a mano. Cada pulsación pasa al siguiente rol que pueda hacer la clase, y vuelve a «Auto».
  local roleLabel = W.Text(me, "GameFontNormalSmall")
  roleLabel:SetPoint("TOPLEFT", 12, -334)
  roleLabel:SetText("Rol de este personaje:")
  page.roleButton = W.Button(me, "", 100, 22, function() ns.UI.ChooseRoles() end)
  page.roleButton:SetPoint("LEFT", roleLabel, "RIGHT", 6, 0)
  ns.UI.Tip(page.roleButton, "Rol de este personaje", "Para contar en la Hermandad cuántos tanques, sanadores y DPS "
    .. "hay. «Auto» lo saca de tus talentos.")
  page.roleHint = W.Text(me, "GameFontHighlightSmall")
  page.roleHint:SetPoint("TOPLEFT", 12, -358)
  page.roleHint:SetWidth(226)
  page.roleHint:SetTextColor(0.7, 0.7, 0.7)

  -------------------------------------------------------------------------
  -- Avisos
  -------------------------------------------------------------------------
  local al = group(page, 260, 330, "Interface\\Icons\\INV_Misc_Bell_01", "Avisos")
  page.alertsBox = al
  local COLS = { { key = "on", label = "Sí" }, { key = "big", label = "Grande" }, { key = "sound", label = "Sonido" },
    { key = "chat", label = "Chat" } }
  local X0 = 168
  for i, c in ipairs(COLS) do
    local h = W.Text(al, "GameFontNormalSmall", "CENTER")
    h:SetPoint("TOP", al, "TOPLEFT", X0 + (i - 1) * 40 + 12, -46)
    h:SetText(c.label)
  end
  page.alertRows = {}
  for i, t in ipairs(ns.Alerts.TYPES) do
    local y = -64 - (i - 1) * 30
    local row = { id = t.id }
    row.label = W.Text(al, "GameFontHighlightSmall")
    row.label:SetPoint("TOPLEFT", 12, y - 6)
    row.label:SetWidth(X0 - 16)
    row.label:SetText(t.label)
    row.mark = al:CreateTexture(nil, "BACKGROUND")
    row.mark:SetPoint("TOPLEFT", 6, y + 2)
    row.mark:SetSize(318, 28)
    row.mark:SetColorTexture(1, 0.82, 0, 0.2)
    row.mark:Hide()
    row.checks = {}
    for k, c in ipairs(COLS) do
      local cb = W.Check(al, "", function(checked)
        ns.Alerts.TypeSettings(t.id)[c.key] = checked
        page:Refresh()
      end)
      cb:SetPoint("TOPLEFT", X0 + (k - 1) * 40, y)
      cb.key = c.key
      row.checks[k] = cb
    end
    page.alertRows[t.id] = row
  end
  local legend = W.Text(al, "GameFontDisableSmall")
  legend:SetPoint("BOTTOMLEFT", 12, 44)
  legend:SetWidth(306)
  legend:SetJustifyV("BOTTOM")
  legend:SetText("Grande: en el centro de la pantalla (si no, un cartel arriba). Chat: también se escribe en tu "
    .. "chat. Cada aviso trae una rueda que lleva aquí.")
  page.test = W.Button(al, "Probar un aviso", 130, 22, function()
    ns.Alerts.Push({ type = "other", icon = "Interface\\Icons\\INV_Misc_Note_01",
      text = "Así se ve un aviso (" .. date("%H:%M:%S") .. ")" })
  end)
  page.test:SetPoint("BOTTOMLEFT", 10, 12)

  -------------------------------------------------------------------------
  -- Otros
  -------------------------------------------------------------------------
  local ot = group(page, 600, 188, "Interface\\Icons\\INV_Misc_Gear_01", "Otros")
  page.chatPost = W.Check(ot, "Escribir mis pedidos en el chat", function(checked) ns.db.settings.chatPost = checked end)
  page.chatPost:SetPoint("TOPLEFT", 8, -44)
  page.chatPost.label:SetWidth(150)
  page.minimap = W.Check(ot, "Icono en el minimapa", function(checked) ns.MinimapButton.SetShown(checked) end)
  page.minimap:SetPoint("TOPLEFT", 8, -80)
  page.demo = W.Check(ot, "Demostración", function(checked) ns.Demo.Set(checked) end)
  page.demo:SetPoint("TOPLEFT", 8, -106)
  ns.UI.Tip(page.demo, "Modo demostración", "Jugadores y pedidos de ejemplo. Solo los ves tú.")
  page.check = W.Button(ot, "Comprobar el addon", 166, 22, function() ns.Diag.Show() end)
  page.check:SetPoint("TOPLEFT", 10, -140)
  page.report = W.Button(ot, "Copiar informe", 166, 22, function() ns.Diag.Show() end)
  page.report:SetPoint("TOPLEFT", 10, -166)
  page.errors = W.Text(ot, "GameFontHighlightSmall")
  page.errors:SetPoint("TOPLEFT", 12, -194)
  page.errors:SetWidth(166)
  -- Letra de las listas: pequeña → normal → grande.
  local fontLabel = W.Text(ot, "GameFontNormalSmall")
  fontLabel:SetPoint("TOPLEFT", 12, -236)
  fontLabel:SetText("Letra de las listas:")
  page.fontButton = W.Button(ot, "", 166, 22, function()
    local sizes, current = W.FONT_SIZES, W.ListFontSize()
    for i, s in ipairs(sizes) do
      if s == current then W.SetListFont(sizes[i % #sizes + 1].id) break end
    end
    page:Refresh()
  end)
  page.fontButton:SetPoint("TOPLEFT", 10, -252)
  ns.UI.Tip(page.fontButton, "Letra de las listas", "Pequeña, normal o grande: Mercado, Agenda, Hermandad e Inicio.")
  page.statusButton = W.Button(ot, "Estado y números", 166, 22, function()
    page.statusBox:SetShown(not page.statusBox:IsShown())
    page:Refresh()
  end)
  page.statusButton:SetPoint("BOTTOMLEFT", 10, 12)

  -- Estado y números (encima de Avisos, hasta que se vuelve a pulsar).
  local sb = W.Box(page, 590, 418)
  sb:SetPoint("TOPLEFT", 0, -2)
  sb:SetFrameLevel(al:GetFrameLevel() + 10)
  sb.text = W.Text(sb, "GameFontHighlightSmall")
  sb.text:SetPoint("TOPLEFT", 14, -14)
  sb.text:SetSize(560, 360)
  sb.text:SetJustifyV("TOP")
  sb.close = W.Button(sb, "Cerrar", 90, 22, function()
    sb:Hide()
    page:Refresh()
  end)
  sb.close:SetPoint("BOTTOMRIGHT", -10, 10)
  sb:Hide()
  page.statusBox = sb

  -- Desde la rueda de un aviso: marca su fila.
  function page:FocusAlert(id)
    page.statusBox:Hide()
    page.focus = id
    page:Refresh()
  end

  function page:Refresh()
    local c, myName = ns.MyChar(), ns.Me()
    if not c then return end
    local now = ns.Now()
    page.charText:SetText(ns.ColoredName(myName, c.class) .. (c.level and (" |cffbbbbbbnivel " .. c.level .. "|r") or ""))
    local profs = {}
    for pk, prof in pairs(c.profs) do profs[#profs + 1] = { pk = pk, prof = prof } end
    table.sort(profs, function(a, b) return ns.ProfessionName(a.pk) < ns.ProfessionName(b.pk) end)
    local lines = {}
    for _, p in ipairs(profs) do
      local count = 0
      for _ in pairs(p.prof.recipes or {}) do count = count + 1 end
      local line = string.format("|T%s:14|t |cffffd100%s|r %s · %d recetas", ns.ProfessionIcon(p.pk), ns.ProfessionName(p.pk),
        p.prof.r and string.format("%d/%d", p.prof.r, p.prof.m or 0) or "", count)
      if count == 0 and not p.prof.t then line = line .. " |cffff8040(ábrela)|r" end
      lines[#lines + 1] = line
    end
    if #lines == 0 then lines[1] = "|cffbbbbbbAún no se ha leído ninguna profesión: abre su ventana una vez.|r" end
    page.profText:SetText(table.concat(lines, "\n"))
    page.unavailable:SetChecked(c.u and true or false)
    if ns.Alerts.IsQuiet() then
      page.quiet:SetText("No molestar: " .. ns.FormatDuration(ns.Alerts.QuietUntil() - now))
    else
      page.quiet:SetText("No molestar: no")
    end
    local main = ns.Social.MyMain()
    page.mainButton:SetText(ns.ShortName(main))
    local nChars = #ns.Social.MyChars()
    local D = ns.Dungeons
    if c.roleSet then
      page.roleButton:SetText(D.RoleLabel(c.roleSet))
      page.roleHint:SetText("Elegido por ti (puedes tener varios). Pulsa para cambiarlo.")
    else
      page.roleButton:SetText("Auto: " .. (D.RoleLabel(c.roleAuto) or "?"))
      page.roleHint:SetText(c.roleAuto and "Sale de tus talentos. Pulsa para elegirlo tú."
        or "Sin talentos todavía: pulsa para elegirlo.")
    end
    page.hint:SetText(main == myName and (nChars > 1 and "Tus alts suman karma y ayudas contigo (pulsa para cambiar)."
      or "Tus alts suman karma y ayudas con tu principal.")
      or ("Este es un alt de " .. ns.ShortName(main) .. "."))

    -- Avisos: un tipo apagado deja sus otras casillas en gris.
    for id, row in pairs(page.alertRows) do
      local ts = ns.Alerts.TypeSettings(id)
      for _, cb in ipairs(row.checks) do
        cb:SetChecked(ts[cb.key] and true or false)
        if cb.key ~= "on" then cb:SetEnabled(ts.on and true or false) end
      end
      row.label:SetTextColor(ts.on and 1 or 0.5, ts.on and 1 or 0.5, ts.on and 1 or 0.5)
      row.mark:SetShown(page.focus == id)
    end

    page.chatPost:SetChecked(ns.db.settings.chatPost ~= false)
    page.demo:SetChecked(ns.db.settings.demo and true or false)
    page.minimap:SetChecked(ns.MinimapButton.IsShown())
    page.fontButton:SetText(W.ListFontSize().label)
    local nErrors = #(ns.db.errors or {})
    page.errors:SetText(nErrors > 0 and string.format("|cffff8040Hay %d error%s guardado%s: pulsa Copiar informe.|r",
      nErrors, nErrors > 1 and "es" or "", nErrors > 1 and "s" or "") or "|cff999999Sin errores guardados.|r")
    if page.statusBox:IsShown() then page.statusBox.text:SetText(statusText()) end
    page.statusButton:SetText(page.statusBox:IsShown() and "Ocultar estado" or "Estado y números")
  end

  page:HookScript("OnHide", function() page.focus = nil end)
end)
