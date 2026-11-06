-- Página "Tablón": los pedidos de la gente en este momento, con un botón para ver cada uno y
-- otro para aceptar el encargo sin más pasos. Arriba, mis encargos por enviar; los pedidos
-- nuevos desde la última visita salen marcados, y en lo que puedo hacer dice si tengo los materiales.
local _, ns = ...
local W, Data = ns.W, ns.Data

-- ¿Puedo aceptar este pedido ahora? (no es mío, está abierto y no es para otra persona)
local function canAccept(r, info, me)
  return r.a ~= me and info.state == "open" and info.remaining > 0 and (not r.to or r.to == me)
end

local function accept(r)
  local info = Data.RequestInfo(r, ns.Now())
  W.AskAmount(string.format("¿Cuántos vas a hacer? (faltan %d)", info.remaining), info.remaining, function(n)
    ns.Sync.Commit(r.id, n)
  end)
end

-- Lo que me queda por enviar de un pedido que acepté (0 si nada).
local function toSend(r, me, now)
  local cm = r.a ~= me and r.c and r.c[me]
  if not cm or not Data.CommitActive(cm, now) then return 0 end
  return math.max(0, (cm.n or 0) - Data.DeliveredOf(cm))
end

-- ¿Tengo lo necesario para hacer "amount"? Texto para la fila, o nil si no lo hago yo.
local function materialsStatus(r, amount)
  local c = ns.MyChar()
  local kind, id = ns.ParseKey(r.k)
  for pk, prof in pairs(c and c.profs or {}) do
    if prof.recipes and prof.recipes[r.k] then
      if r.m then return "|cff40ff40Los materiales los pone quien pide.|r" end
      local info = Data.GetInfo(Data.InfoKey(pk, r.k))
      local var = info and info.v and info.v[1]
      if not var then return "|cff999999Abre tu ventana de profesión para saber si tienes los materiales.|r" end
      local times = math.ceil(amount / math.max(1, var.m or 1))
      local ids = {}
      for mid in pairs(var.r) do ids[#ids + 1] = mid end
      table.sort(ids)
      local missing = {}
      for _, mid in ipairs(ids) do
        local need = var.r[mid] * times - ns.Scan.Have(mid)
        if need > 0 then missing[#missing + 1] = need .. "x " .. ns.KeyName("i" .. mid) end
      end
      if #missing == 0 then return "|cff40ff40Tienes los materiales para hacerlo ya.|r" end
      return "|cffff9933Te faltan: " .. table.concat(missing, ", ") .. "|r"
    end
  end
  if kind == "i" and Data.ICanGather(r.k) then
    local have = ns.Scan.Have(id)
    if have >= amount then return string.format("|cff40ff40Ya tienes %d (lo recolectas tú).|r", have) end
    return string.format("|cffff9933Tienes %d de %d (lo recolectas tú).|r", have, amount)
  end
end

-- Pedidos del tablón y sus números (también los usa la página de inicio).
local function collect(seenAt)
  local g, me, now = ns.G(), ns.Me(), ns.Now()
  local items = {}
  local stats = { open = 0, servable = 0, new = 0, toSend = 0 }
  if not g then return items, stats end
  for _, r in pairs(g.requests) do
    local info = Data.RequestInfo(r, now)
    local pending = toSend(r, me, now)
    local visible = info.state == "open" and (not r.to or r.to == me or r.a == me)
    if pending > 0 or visible then
      local item = {
        r = r, info = info, me = me, now = now, mine = r.a == me, pending = pending,
        canServe = Data.CanServe(r, now), acceptable = canAccept(r, info, me),
        karma = Data.KarmaFor(r.a),
        new = r.a ~= me and pending == 0 and (r.t or 0) > (seenAt or 0),
      }
      if pending > 0 then stats.toSend = stats.toSend + 1 end
      if visible and not item.mine then stats.open = stats.open + 1 end
      if item.canServe then stats.servable = stats.servable + 1 end
      if item.new and visible then stats.new = stats.new + 1 end
      items[#items + 1] = item
    end
  end
  return items, stats
end

function ns.UI.BoardStats()
  local g = ns.G()
  local _, stats = collect(g and g.boardSeen)
  return stats
end

local function rank(x)
  if x.pending > 0 then return 0 end -- mis encargos por enviar
  if x.mine then return 5 end
  if x.r.to == x.me then return 1 end
  if x.canServe then return 2 end
  if x.new then return 3 end
  return 4
end

ns.UI.RegisterPage("board", function(page)
  local state = { onlyMine = false }

  page.summary = W.Text(page, "GameFontNormalSmall")
  page.summary:SetPoint("TOPLEFT", 6, -7)

  page.onlyMine = W.Check(page, "Solo lo que puedo hacer", function(checked)
    state.onlyMine = checked
    page:Refresh()
  end)
  page.onlyMine:SetPoint("TOPLEFT", 262, -1)

  page.history = W.Button(page, "Historial", 80, 22, function()
    ns.UI.Open("requests")
    ns.UI.FilterRequests("ended")
  end)
  page.history:SetPoint("TOPRIGHT", -2, -2)
  page.myRequests = W.Button(page, "Mis pedidos", 92, 22, function()
    ns.UI.Open("requests")
    ns.UI.FilterRequests("mine")
  end)
  page.myRequests:SetPoint("RIGHT", page.history, "LEFT", -4, 0)

  local list = W.List(page, 604, 366, {
    rows = 7,
    rowHeight = 50,
    keyOf = function(item) return item.r.id end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(36, 36)
      row.icon:SetPoint("LEFT", 4, 0)
      local function line(font, y)
        local fs = W.Text(row, font)
        fs:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, y)
        fs:SetPoint("RIGHT", row, "RIGHT", -214, 0)
        fs:SetWordWrap(false)
        return fs
      end
      row.title = line("GameFontHighlight", 4)
      row.sub = line("GameFontHighlightSmall", -12)
      row.mats = line("GameFontHighlightSmall", -26)
      row.accept = W.Button(row, "Aceptar encargo", 114, 22)
      row.accept:SetPoint("RIGHT", -2, 0)
      if row.accept.SetMotionScriptsWhileDisabled then row.accept:SetMotionScriptsWhileDisabled(true) end
      row.accept:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
      end)
      row.accept:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row.view = W.Button(row, "Ver pedido", 90, 22)
      row.view:SetPoint("RIGHT", row.accept, "LEFT", -4, 0)
      W.KeyTooltip(row, function(self) return self.item and self.item.r.k end)
    end,
    updateRow = function(row, item)
      local r, info = item.r, item.info
      local _, icon = ns.KeyInfo(r.k)
      row.icon:SetTexture(icon)
      local tags = ""
      if item.pending > 0 then tags = tags .. "|cff66ccff[Tu encargo]|r " end
      if item.new then tags = tags .. "|cffffd100¡Nuevo!|r " end
      if r.to == item.me and not item.mine then tags = tags .. "|cffff80ff[A ti]|r " end
      if item.mine then tags = tags .. "|cff999999[Tuyo]|r " end
      local title = tags .. string.format("%dx %s", r.q, ns.KeyLabel(r.k))
      if item.canServe and item.pending == 0 then title = title .. "  |cff40ff40(puedes hacerlo)|r" end
      row.title:SetText(title)

      local parts = { "Pide " .. ns.ShortName(r.a) .. " (" .. Data.KarmaText(r.a) .. ")" }
      parts[#parts + 1] = "hace " .. ns.FormatDuration(item.now - (r.t or item.now))
      if item.pending > 0 then
        parts[#parts + 1] = string.format("te comprometiste a %d, te quedan %d por enviar", r.c[item.me].n, item.pending)
      else
        parts[#parts + 1] = string.format("faltan %d de %d", info.remaining, r.q)
      end
      if r.g then parts[#parts + 1] = "paga " .. ns.FormatMoney(r.g) end
      row.sub:SetText(table.concat(parts, "  |cff666666·|r  "))

      local mats
      if not item.mine then
        mats = materialsStatus(r, item.pending > 0 and item.pending or info.remaining)
      end
      if not mats and r.m and not item.mine then mats = "|cffbbbbbbLos materiales los pone quien pide.|r" end
      row.mats:SetText(mats or "")

      row.view:SetScript("OnClick", function() ns.UI.Open("requests", r.id) end)
      row.accept.tip = nil
      if item.pending > 0 then
        -- Mi encargo: enviarlo directamente.
        if r.demo then
          row.accept:SetText("Enviar (ejemplo)")
          row.accept:SetEnabled(true)
          row.accept:SetScript("OnClick", function() ns.Demo.SimulateMail(r) end)
        else
          row.accept:SetText("Preparar correo")
          local can = ns.Mail.CanPrepare()
          row.accept:SetEnabled(can)
          if not can then row.accept.tip = "Abre el buzón para preparar el correo." end
          row.accept:SetScript("OnClick", function() ns.Mail.Prepare(r, item.pending) end)
        end
      else
        local cm = r.c and r.c[item.me]
        row.accept:SetText(cm and Data.CommitActive(cm, item.now) and "Aceptar más" or "Aceptar encargo")
        row.accept:SetEnabled(item.acceptable)
        row.accept:SetScript("OnClick", function() accept(r) end)
      end
    end,
    onSelect = function(item) ns.UI.Open("requests", item.r.id) end,
  })
  list:SetPoint("TOPLEFT", 0, -28)

  page.empty = W.Text(page, "GameFontNormal", "CENTER")
  page.empty:SetPoint("CENTER", list, "CENTER", 0, 20)
  page.empty:SetWidth(460)
  page.empty:SetTextColor(0.7, 0.7, 0.7)
  page.askButton = W.Button(page, "Pedir materiales", 140, 22, function() ns.UI.ShowPage("materials") end)
  page.askButton:SetPoint("TOP", page.empty, "BOTTOM", 0, -12)

  page.list = list

  function page:Refresh()
    local all, stats = collect(page.seenAt)
    local items = {}
    for _, item in ipairs(all) do
      if not state.onlyMine or item.canServe or item.pending > 0 then items[#items + 1] = item end
    end
    table.sort(items, function(a, b)
      local ra, rb = rank(a), rank(b)
      if ra ~= rb then return ra < rb end
      if a.karma ~= b.karma then return a.karma > b.karma end -- prioridad por karma
      if (a.r.t or 0) ~= (b.r.t or 0) then return (a.r.t or 0) > (b.r.t or 0) end
      return a.r.id < b.r.id
    end)
    list:SetItems(items)
    local text = string.format("Abiertos: |cffffffff%d|r   Puedes: |cff40ff40%d|r", stats.open, stats.servable)
    if stats.new > 0 then text = text .. string.format("   Nuevos: |cffffd100%d|r", stats.new) end
    page.summary:SetText(text)
    local none = #items == 0
    page.empty:SetShown(none)
    page.askButton:SetShown(none)
    if none then
      page.empty:SetText(state.onlyMine and "Ahora mismo no hay pedidos que puedas hacer."
        or "No hay pedidos abiertos ahora mismo.\n|cff999999(Para ver ejemplos, activa el modo demostración en Mis cosas.)|r")
    end
  end

  -- "Nuevo": lo que ha llegado desde la última vez que miraste el tablón. Al entrar se toma
  -- la marca anterior y al salir se guarda la hora.
  page:HookScript("OnShow", function()
    local g = ns.G()
    page.seenAt = g and g.boardSeen or 0
  end)
  local function leave()
    local g = ns.G()
    if g and page.seenAt then g.boardSeen = ns.Now() end
    page.seenAt = nil
  end
  page:HookScript("OnHide", leave)
end)
