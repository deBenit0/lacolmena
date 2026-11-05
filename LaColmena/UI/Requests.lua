-- Página "Peticiones": lo que necesita la hermandad y quién se encarga.
local _, ns = ...
local W, Data, Guild = ns.W, ns.Data, ns.Guild

local FILTERS = {
  { id = "active", label = "Ver: activas" },
  { id = "craft", label = "Ver: puedo hacerlas" },
  { id = "mine", label = "Ver: mías" },
  { id = "involved", label = "Ver: para mí / aceptadas" },
  { id = "ended", label = "Ver: terminadas" },
}

local STATE_COLOR = {
  open = "|cffffd100", accepted = "|cff66ccff", done = "|cff40ff40", closed = "|cff999999", expired = "|cff999999",
}

local function stateText(r, info)
  local color = STATE_COLOR[info.state] or "|cffffffff"
  local label = Data.STATE_LABEL[info.state] or info.state
  if info.state == "open" then
    label = string.format("%s %d/%d", label, info.delivered + info.pending, r.q)
  elseif info.state == "accepted" then
    label = string.format("%s, entregadas %d/%d", label, info.delivered, r.q)
  end
  return color .. label .. "|r"
end

local function payText(r)
  local parts = {}
  if r.g then parts[#parts + 1] = ns.FormatMoney(r.g) end
  if r.pi then
    local ids = {}
    for id in pairs(r.pi) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do parts[#parts + 1] = r.pi[id] .. "x " .. ns.KeyLabel("i" .. id) end
  end
  return #parts > 0 and table.concat(parts, " + ") or nil
end

local function matchesFilter(filter, r, info, me)
  local active = Data.IsActiveState(info.state)
  local myCommit = r.c and r.c[me]
  if filter == "active" then return active end
  if filter == "craft" then
    return info.state == "open" and r.a ~= me and (not r.to or r.to == me) and Data.ICanCraft(r.k)
  end
  if filter == "mine" then return r.a == me end
  if filter == "involved" then
    return active and (r.to == me or (myCommit and Data.CommitActive(myCommit, ns.Now())) or false)
  end
  if filter == "ended" then return not active end
  return true
end

-- Materiales que hacen falta para toda la petición (primera variante conocida).
local function neededMaterials(r)
  local rec = Data.GetIndex()[r.k]
  local profs = {}
  if r.pk then profs[#profs + 1] = r.pk end
  if rec then
    for pk in pairs(rec.profs) do
      if pk ~= r.pk then profs[#profs + 1] = pk end
    end
  end
  for _, pk in ipairs(profs) do
    local ik = Data.InfoKey(pk, r.k)
    local info = Data.GetInfo(ik)
    local var = info and info.v and info.v[1]
    if var then
      local times = math.ceil(r.q / math.max(1, var.m or 1))
      local ids, parts = {}, {}
      for id in pairs(var.r) do ids[#ids + 1] = id end
      table.sort(ids)
      for _, id in ipairs(ids) do parts[#parts + 1] = (var.r[id] * times) .. "x " .. ns.KeyName("i" .. id) end
      return table.concat(parts, ", ")
    end
    if rec then ns.Sync.AskInfo(ik) end
  end
end

ns.UI.RegisterPage("requests", function(page)
  local state = { filter = 1, id = nil }

  local filterButton = W.Button(page, FILTERS[1].label, 190, 22)
  filterButton:SetPoint("TOPLEFT", 4, -2)
  filterButton:SetScript("OnClick", function()
    state.filter = state.filter % #FILTERS + 1
    page:Refresh()
  end)

  local newButton = W.Button(page, "Nueva petición", 130, 22, function()
    ns.UI.OpenRequestDialog({})
  end)
  newButton:SetPoint("TOPRIGHT", -4, -2)

  local counter = W.Text(page, "GameFontHighlightSmall", "RIGHT")
  counter:SetPoint("RIGHT", newButton, "LEFT", -10, 0)

  local list = W.List(page, 280, 368, {
    rows = 10,
    rowHeight = 35,
    keyOf = function(item) return item.r.id end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(28, 28)
      row.icon:SetPoint("LEFT", 2, 0)
      row.title = W.Text(row, "GameFontHighlightSmall")
      row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -2)
      row.title:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row.title:SetWordWrap(false)
      row.sub = W.Text(row, "GameFontHighlightSmall")
      row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 2)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row.sub:SetWordWrap(false)
      W.KeyTooltip(row, function(self) return self.item and self.item.r.k end)
    end,
    updateRow = function(row, item)
      local r, info = item.r, item.info
      local _, icon = ns.KeyInfo(r.k)
      row.icon:SetTexture(icon)
      local title = string.format("%dx %s", r.q, ns.KeyLabel(r.k))
      if r.to == ns.Me() then title = "|cffff80ff[A ti]|r " .. title end
      row.title:SetText(title)
      local sub = ns.ShortName(r.a) .. " - " .. stateText(r, info)
      local pay = r.g and ns.FormatMoney(r.g)
      if pay then sub = sub .. " - " .. pay end
      row.sub:SetText(sub)
    end,
    onSelect = function(item)
      state.id = item.r.id
      page:RefreshDetail()
    end,
  })
  list:SetPoint("TOPLEFT", 0, -30)

  local detail = W.Box(page, 320, 368)
  detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0)

  detail.icon = CreateFrame("Button", nil, detail)
  detail.icon:SetSize(36, 36)
  detail.icon:SetPoint("TOPLEFT", 10, -10)
  detail.iconTex = detail.icon:CreateTexture(nil, "ARTWORK")
  detail.iconTex:SetAllPoints()
  W.KeyTooltip(detail.icon, function()
    local g = ns.G()
    local r = g and state.id and g.requests[state.id]
    return r and r.k
  end)
  detail.title = W.Text(detail, "GameFontNormal")
  detail.title:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 8, -2)
  detail.title:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.title:SetWordWrap(false)
  detail.sub = W.Text(detail, "GameFontHighlightSmall")
  detail.sub:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -4)
  detail.sub:SetPoint("RIGHT", detail, "RIGHT", -10, 0)

  detail.info = W.Text(detail, "GameFontHighlightSmall")
  detail.info:SetPoint("TOPLEFT", 12, -56)
  detail.info:SetSize(296, 140)
  detail.info:SetJustifyV("TOP")

  detail.commitsLabel = W.Text(detail, "GameFontNormalSmall")
  detail.commitsLabel:SetPoint("TOPLEFT", 12, -204)
  detail.commitsLabel:SetText("Quién se encarga")

  local commits = W.List(detail, 304, 112, {
    rows = 5,
    rowHeight = 20,
    keyOf = function(c) return c.name end,
    buildRow = function(row)
      row.text = W.Text(row, "GameFontHighlightSmall")
      row.text:SetPoint("LEFT", 4, 0)
      row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row.text:SetWordWrap(false)
    end,
    updateRow = function(row, c)
      local g = ns.G()
      local e = g and g.entries[c.name]
      local text = ns.ColoredName(c.name, e and e.c or (Guild.Info(c.name) or {}).class)
      text = text .. string.format(": %d", c.promised)
      if c.delivered > 0 then text = text .. string.format(" (entregadas %d)", c.delivered) end
      if c.active and c.deadline then
        text = text .. " |cffbbbbbb- quedan " .. ns.FormatDuration(c.deadline - ns.Now()) .. "|r"
      elseif not c.active and c.delivered < c.promised then
        text = text .. " |cff999999- soltada|r"
      end
      row.text:SetText(text)
    end,
    onSelect = function() page:RefreshButtons() end,
  })
  commits:SetPoint("TOPLEFT", 8, -218)

  detail.b1 = W.Button(detail, "", 98, 22)
  detail.b1:SetPoint("BOTTOMLEFT", 8, 8)
  detail.b2 = W.Button(detail, "", 98, 22)
  detail.b2:SetPoint("LEFT", detail.b1, "RIGHT", 4, 0)
  detail.b3 = W.Button(detail, "", 98, 22)
  detail.b3:SetPoint("LEFT", detail.b2, "RIGHT", 4, 0)

  detail.empty = W.Text(detail, "GameFontNormal", "CENTER")
  detail.empty:SetTextColor(0.6, 0.6, 0.6)
  detail.empty:SetPoint("CENTER")
  detail.empty:SetWidth(280)

  -- Referencias para depurar y para las pruebas.
  page.state, page.list, page.detail, page.commits, page.filterButton = state, list, detail, commits, filterButton

  local function current()
    local g = ns.G()
    return g and state.id and g.requests[state.id]
  end

  local function setButton(b, text, enabled, onClick)
    b:SetText(text)
    b:SetEnabled(enabled and true or false)
    b:SetScript("OnClick", onClick)
    b:Show()
  end

  function page:RefreshButtons()
    local r = current()
    if not r then return end
    local me, now = ns.Me(), ns.Now()
    local info = Data.RequestInfo(r, now)
    local active = Data.IsActiveState(info.state)
    if r.a == me then
      local selected = commits:Selected()
      local target = selected
      if not target then
        for _, c in ipairs(info.commits) do
          if c.active then
            if target then target = nil break end -- hay varios: que elija uno
            target = c
          end
        end
      end
      setButton(detail.b1, "Recibido", active and target ~= nil, function()
        local left = math.max(1, (target.pending > 0) and target.pending or (r.q - info.delivered))
        W.AskAmount(string.format("¿Cuántos has recibido de %s?", ns.ShortName(target.name)), left, function(n)
          ns.Sync.ConfirmDelivery(r.id, target.name, n)
        end)
      end)
      setButton(detail.b2, "Renovar", active or info.state == "expired", function() ns.Sync.Renew(r.id) end)
      setButton(detail.b3, "Cerrar", active, function()
        W.Confirm("¿Cerrar esta petición? Ya no se podrá aceptar.", function() ns.Sync.Close(r.id) end)
      end)
    else
      local mine = r.c and r.c[me]
      local canCommit = info.state == "open" and (not r.to or r.to == me)
      setButton(detail.b1, "Lo hago yo", canCommit, function()
        W.AskAmount(string.format("¿Cuántos vas a hacer? (faltan %d)", info.remaining), info.remaining, function(n)
          ns.Sync.Commit(r.id, n)
        end)
      end)
      setButton(detail.b2, "Soltar", mine and Data.CommitActive(mine, now), function()
        W.Confirm("¿Seguro que ya no lo vas a hacer?", function() ns.Sync.Release(r.id) end)
      end)
      setButton(detail.b3, "Susurrar", true, function()
        if ChatFrame_SendTell then ChatFrame_SendTell(r.a) end
      end)
    end
  end

  function page:RefreshDetail()
    local r = current()
    local regions = { detail.icon, detail.title, detail.sub, detail.info, detail.commitsLabel, commits, detail.b1, detail.b2, detail.b3 }
    for _, region in ipairs(regions) do region:SetShown(r ~= nil) end
    detail.empty:SetShown(r == nil)
    if not r then
      detail.empty:SetText(#list.items > 0 and "Elige una petición de la lista." or "No hay peticiones en esta vista.")
      return
    end
    local now = ns.Now()
    local info = Data.RequestInfo(r, now)
    local name, icon, link = ns.KeyInfo(r.k)
    detail.iconTex:SetTexture(icon)
    detail.title:SetText(string.format("%dx %s", r.q, link or name or ns.KeyName(r.k)))
    local authorEntry = ns.G().entries[r.a]
    detail.sub:SetText("Pide " .. ns.ColoredName(r.a, authorEntry and authorEntry.c or (Guild.Info(r.a) or {}).class)
      .. " |cffbbbbbbhace " .. ns.FormatDuration(now - (r.t or now)) .. "|r")

    local lines = {}
    lines[#lines + 1] = "Estado: " .. stateText(r, info)
    if Data.IsActiveState(info.state) then
      lines[#lines + 1] = string.format("Entregadas: %d de %d   Faltan por cubrir: %d", info.delivered, r.q, info.remaining)
      lines[#lines + 1] = "Caduca en " .. ns.FormatDuration(info.expires - now)
    end
    lines[#lines + 1] = r.m and "Materiales: |cff40ff40los pone quien pide|r" or "Materiales: |cffffd100los pone quien fabrica|r"
    local needed = neededMaterials(r)
    if needed then lines[#lines + 1] = "|cffbbbbbbHace falta: " .. needed .. "|r" end
    lines[#lines + 1] = "Paga: " .. (payText(r) or "|cffbbbbbbnada indicado|r")
    lines[#lines + 1] = "Para: " .. (r.to and ns.ShortName(r.to) or "cualquiera")
    local rec = Data.GetIndex()[r.k]
    if Data.ICanCraft(r.k) then
      lines[#lines + 1] = "|cff40ff40Sabes fabricarlo.|r"
    elseif rec then
      local names, online = {}, 0
      for _, cr in ipairs(rec.crafters) do
        if not names[cr.n] then
          names[cr.n] = true
          if Guild.IsOnline(cr.n) then online = online + 1 end
        end
      end
      local total = 0
      for _ in pairs(names) do total = total + 1 end
      lines[#lines + 1] = string.format("Lo saben hacer %d en la hermandad (%d en línea).", total, online)
    else
      lines[#lines + 1] = "|cffff8040Nadie de la hermandad lo tiene publicado.|r"
    end
    detail.info:SetText(table.concat(lines, "\n"))

    commits:SetItems(info.commits)
    detail.commitsLabel:SetText(#info.commits > 0 and "Quién se encarga" or "Quién se encarga: nadie todavía")
    page:RefreshButtons()
  end

  function page:Refresh()
    local g = ns.G()
    local me, now = ns.Me(), ns.Now()
    local filter = FILTERS[state.filter].id
    filterButton:SetText(FILTERS[state.filter].label)
    counter:SetText(string.format("Tus abiertas: %d/%d", Data.CountOpenBy(me, now), Data.MAX_OPEN))
    local items = {}
    for _, r in pairs(g.requests) do
      local info = Data.RequestInfo(r, now)
      if matchesFilter(filter, r, info, me) then
        items[#items + 1] = { r = r, info = info }
      end
    end
    table.sort(items, function(a, b)
      local aMe, bMe = a.r.to == me, b.r.to == me
      if aMe ~= bMe then return aMe end
      local aActive, bActive = Data.IsActiveState(a.info.state), Data.IsActiveState(b.info.state)
      if aActive ~= bActive then return aActive end
      if (a.r.t or 0) ~= (b.r.t or 0) then return (a.r.t or 0) > (b.r.t or 0) end
      return a.r.id < b.r.id
    end)
    list:SetItems(items)
    page:RefreshDetail()
  end

  -- Abre la página con una petición concreta elegida (desde un aviso, por ejemplo).
  function page:SelectById(id)
    local g = ns.G()
    local r = g and g.requests[id]
    if not r then return end
    local info = Data.RequestInfo(r, ns.Now())
    if not matchesFilter(FILTERS[state.filter].id, r, info, ns.Me()) then
      state.filter = Data.IsActiveState(info.state) and 1 or #FILTERS
    end
    state.id = id
    page:Refresh()
    list:Select(id)
    page:RefreshDetail()
  end
end)
