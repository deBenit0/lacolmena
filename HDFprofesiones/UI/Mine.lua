-- Página "Opciones" (18/11, rehecha):
--   Tu personaje (lo principal): nombre, profesiones, principal, rol, no disponible y no molestar.
--   Avisos en tu chat: 4 casillas. Otros: mis pedidos en el chat y el minimapa.
--   Para arreglar fallos (abajo, en gris): comprobar el addon, copiar informe y estado y números.
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

-- Quitados de Opciones (18/11): letra de las listas, demostración y ayuda con el correo. Quien los
-- tuviera cambiados vuelve a lo normal.
ns.Listen("DB_READY", function()
  local s = ns.db.settings
  s.listFont, s.demo, s.mailOff = nil, nil, nil
  s.guildKey = nil -- «La J abre el addon» también se quitó (Hermandad): la J siempre abre el addon
end)

-- Avisos en el chat: 4 casillas, cada una enciende varios tipos de aviso.
local ALERT_GROUPS = {
  { id = "craft", label = "Pedidos que puedo hacer", types = { "craft" } },
  { id = "mine", label = "Novedades de mis pedidos", types = { "accepted", "expire" } },
  { id = "runs", label = "Quedadas y grupos", types = { "run", "signup", "group", "remind" } },
  { id = "other", label = "Lo demás", types = { "other" } },
}
local GROUP_OF = {}
for _, g in ipairs(ALERT_GROUPS) do
  for _, t in ipairs(g.types) do GROUP_OF[t] = g.id end
end
ns.UI.ALERT_GROUPS = ALERT_GROUPS

local function groupOn(g)
  for _, t in ipairs(g.types) do
    local ts = ns.Alerts.TypeSettings(t)
    if ts.on and ts.chat then return true end
  end
  return false
end

local function box(page, x, y, w, h, title)
  local b = W.Box(page, w, h)
  b:SetPoint("TOPLEFT", x, y)
  if title then
    b.title = W.Text(b, "GameFontNormalLarge")
    b.title:SetPoint("TOPLEFT", 12, -10)
    b.title:SetText(title)
  end
  return b
end

local function grey(parent, x, y, width)
  local t = W.Text(parent, "GameFontHighlightSmall")
  t:SetPoint("TOPLEFT", x, y)
  t:SetWidth(width)
  t:SetTextColor(0.6, 0.6, 0.6)
  return t
end

local function label(parent, x, y, text)
  local t = W.Text(parent, "GameFontNormalSmall")
  t:SetPoint("TOPLEFT", x, y)
  t:SetText(text)
  return t
end

ns.UI.RegisterPage("mine", function(page)
  -------------------------------------------------------------------------
  -- Tu personaje (lo principal)
  -------------------------------------------------------------------------
  local me = box(page, 0, -2, 440, 300)
  page.meBox = me
  page.charText = W.Text(me, "GameFontNormalLarge")
  page.charText:SetPoint("TOPLEFT", 14, -14)
  label(me, 14, -44, "Profesiones")
  page.profText = W.Text(me, "GameFontHighlightSmall")
  page.profText:SetPoint("TOPLEFT", 22, -60)
  page.profText:SetSize(406, 50)
  page.profText:SetJustifyV("TOP")
  page.profText:SetSpacing(3)
  local sep = me:CreateTexture(nil, "ARTWORK")
  sep:SetPoint("TOPLEFT", 12, -118)
  sep:SetSize(416, 1)
  sep:SetColorTexture(0.6, 0.45, 0.15, 0.5)

  local C1, C2, CW = 14, 228, 198
  -- Personaje principal: los alts suman karma y ayudas con él. Por defecto, el de más nivel.
  label(me, C1, -132, "Personaje principal")
  page.mainButton = W.Button(me, "", CW, 22, function()
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
  page.mainButton:SetPoint("TOPLEFT", C1 - 2, -148)
  page.hint = grey(me, C1, -176, CW)

  -- Rol de este personaje (para el recuento de la Hermandad): sale de los talentos o se elige.
  label(me, C2, -132, "Rol de este personaje")
  page.roleButton = W.Button(me, "", CW, 22, function() ns.UI.ChooseRoles() end)
  page.roleButton:SetPoint("TOPLEFT", C2 - 2, -148)
  ns.UI.Tip(page.roleButton, "Rol de este personaje", "Para contar en la Hermandad cuántos tanques, sanadores y DPS "
    .. "hay. «Auto» lo saca de tus talentos.")
  page.roleHint = grey(me, C2, -176, CW)

  label(me, C1, -214, "Estado")
  page.unavailable = W.Check(me, "No disponible", function(checked) ns.Sync.SetUnavailable(checked) end)
  page.unavailable:SetPoint("TOPLEFT", C1 - 4, -230)
  ns.UI.Tip(page.unavailable, "No disponible", "Sin avisos, y sales el último en «Quién lo fabrica».")
  grey(me, C1, -260, CW):SetText("Sin avisos y sales el último en los artesanos.")
  -- No molestar (1 h, 3 h, hasta mañana): los avisos se guardan y salen después juntos.
  page.quiet = W.Button(me, "", CW, 22, function()
    local opts = ns.Alerts.QUIET_OPTIONS
    local current = ns.Alerts.IsQuiet() and (ns.db.settings.dndOption or 1) or 1
    ns.Alerts.SetQuiet(current % #opts + 1, ns.Now())
    page:Refresh()
  end)
  page.quiet:SetPoint("TOPLEFT", C2 - 2, -232)
  ns.UI.Tip(page.quiet, "No molestar", "Los avisos se guardan y salen después, juntos.")
  grey(me, C2, -260, CW):SetText("1 h, 3 h o hasta mañana.")

  -------------------------------------------------------------------------
  -- Avisos en tu chat: 4 casillas
  -------------------------------------------------------------------------
  local al = box(page, 450, -2, 338, 172, "Avisos en tu chat")
  page.alertsBox = al
  grey(al, 12, -34, 314):SetText("Escríbeme en el chat cuando haya:")
  page.alertRows = {}
  for i, g in ipairs(ALERT_GROUPS) do
    local y = -50 - (i - 1) * 28
    local row = { id = g.id }
    row.mark = al:CreateTexture(nil, "BACKGROUND")
    row.mark:SetPoint("TOPLEFT", 6, y + 2)
    row.mark:SetSize(326, 28)
    row.mark:SetColorTexture(1, 0.82, 0, 0.2)
    row.mark:Hide()
    row.check = W.Check(al, g.label, function(checked)
      for _, t in ipairs(g.types) do
        local ts = ns.Alerts.TypeSettings(t)
        ts.chat = checked and true or false
        if checked then ts.on = true end
      end
      page:Refresh()
    end)
    row.check:SetPoint("TOPLEFT", 8, y)
    page.alertRows[g.id] = row
  end

  -------------------------------------------------------------------------
  -- Otros: dos casillas
  -------------------------------------------------------------------------
  local ot = box(page, 450, -182, 338, 120, "Otros")
  page.chatPost = W.Check(ot, "Escribir mis pedidos en el chat", function(checked) ns.db.settings.chatPost = checked end)
  page.chatPost:SetPoint("TOPLEFT", 8, -40)
  page.minimap = W.Check(ot, "Icono en el minimapa", function(checked) ns.MinimapButton.SetShown(checked) end)
  page.minimap:SetPoint("TOPLEFT", 8, -70)

  -------------------------------------------------------------------------
  -- Para arreglar fallos: aparte, abajo, en gris
  -------------------------------------------------------------------------
  local fx = box(page, 0, -312, 788, 108)
  page.fixBox = fx
  local fxTitle = W.Text(fx, "GameFontDisableSmall")
  fxTitle:SetPoint("TOPLEFT", 12, -10)
  fxTitle:SetText("Para arreglar fallos")
  local BW, X = 200, { 12, 294, 576 }
  page.check = W.Button(fx, "Comprobar el addon", BW, 22, function() ns.Diag.Show() end)
  page.check:SetPoint("TOPLEFT", X[1], -28)
  grey(fx, X[1] + 2, -56, 240):SetText("Mira si todo va bien.")
  page.report = W.Button(fx, "Copiar informe", BW, 22, function() ns.Diag.Show() end)
  page.report:SetPoint("TOPLEFT", X[2], -28)
  page.reportHint = grey(fx, X[2] + 2, -56, 270)
  page.reportHint:SetText("Sirve para compartir tu opinión o un fallo del addon: cópialo y pégalo donde nos lo mandes.")
  page.errors = W.Text(fx, "GameFontHighlightSmall")
  page.errors:SetPoint("TOPLEFT", X[2] + 2, -86)
  page.errors:SetWidth(270)
  page.statusButton = W.Button(fx, "Estado y números", BW, 22, function()
    page.statusBox:SetShown(not page.statusBox:IsShown())
    page:Refresh()
  end)
  page.statusButton:SetPoint("TOPLEFT", X[3], -28)
  grey(fx, X[3] + 2, -56, 200):SetText("Números del addon y de la hermandad.")
  for _, b in ipairs({ page.check, page.report, page.statusButton }) do
    if b.GetFontString and b:GetFontString() then b:GetFontString():SetTextColor(0.85, 0.75, 0.5) end
  end

  -- Estado y números (encima de todo menos la franja de abajo, hasta que se vuelve a pulsar).
  local sb = W.Box(page, 788, 300)
  sb:SetPoint("TOPLEFT", 0, -2)
  sb:SetFrameLevel(math.max(me:GetFrameLevel(), al:GetFrameLevel(), ot:GetFrameLevel()) + 10)
  sb.text = W.Text(sb, "GameFontHighlightSmall")
  sb.text:SetPoint("TOPLEFT", 14, -14)
  sb.text:SetSize(560, 276)
  sb.text:SetJustifyV("TOP")
  sb.close = W.Button(sb, "Cerrar", 90, 22, function()
    sb:Hide()
    page:Refresh()
  end)
  sb.close:SetPoint("BOTTOMRIGHT", -10, 10)
  sb:Hide()
  page.statusBox = sb

  -- Desde la rueda de un aviso: marca su casilla.
  function page:FocusAlert(id)
    page.statusBox:Hide()
    page.focus = GROUP_OF[id] or id
    page:Refresh()
  end

  function page:Refresh()
    local c, myName = ns.MyChar(), ns.Me()
    if not c then return end
    local now = ns.Now()
    page.charText:SetText(ns.ColoredName(myName, c.class) .. (c.level and ("  |cff999999nivel " .. c.level .. "|r") or ""))
    local profs = {}
    for pk, prof in pairs(c.profs) do profs[#profs + 1] = { pk = pk, prof = prof } end
    table.sort(profs, function(a, b) return ns.ProfessionName(a.pk) < ns.ProfessionName(b.pk) end)
    local lines = {}
    for _, p in ipairs(profs) do
      local count = 0
      for _ in pairs(p.prof.recipes or {}) do count = count + 1 end
      local line = string.format("|T%s:14|t |cffffd100%s|r  %s · %d receta%s", ns.ProfessionIcon(p.pk),
        ns.ProfessionName(p.pk), p.prof.r and string.format("%d/%d", p.prof.r, p.prof.m or 0) or "", count,
        count == 1 and "" or "s")
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
    page.mainButton:SetText(ns.DisplayName(main))
    local nChars = #ns.Social.MyChars()
    local D = ns.Dungeons
    if c.roleSet then
      page.roleButton:SetText(D.RoleLabel(c.roleSet))
      page.roleHint:SetText("Elegido por ti. Pulsa para cambiarlo.")
    else
      page.roleButton:SetText("Auto: " .. (D.RoleLabel(c.roleAuto) or "?"))
      page.roleHint:SetText(c.roleAuto and "Sale de tus talentos. Pulsa para elegirlo tú."
        or "Sin talentos todavía: pulsa para elegirlo.")
    end
    page.hint:SetText(main == myName and (nChars > 1 and "Tus alts suman karma y ayudas contigo. Pulsa para cambiar."
      or "Tus alts suman karma y ayudas con tu principal.")
      or ("Este es un alt de " .. ns.DisplayName(main) .. "."))

    for _, g in ipairs(ALERT_GROUPS) do
      local row = page.alertRows[g.id]
      row.check:SetChecked(groupOn(g))
      row.mark:SetShown(page.focus == g.id)
    end

    page.chatPost:SetChecked(ns.db.settings.chatPost ~= false)
    page.minimap:SetChecked(ns.MinimapButton.IsShown())
    local nErrors = #(ns.db.errors or {})
    page.errors:SetText(nErrors > 0 and string.format("|cffff8040Hay %d error%s guardado%s.|r",
      nErrors, nErrors > 1 and "es" or "", nErrors > 1 and "s" or "") or "")
    if page.statusBox:IsShown() then page.statusBox.text:SetText(statusText()) end
    page.statusButton:SetText(page.statusBox:IsShown() and "Ocultar estado" or "Estado y números")
  end

  page:HookScript("OnHide", function() page.focus = nil end)
end)
