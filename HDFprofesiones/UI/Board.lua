-- Página "Tablón": lo primero que se ve al entrar en Pedidos. Los pedidos abiertos de la gente,
-- con un botón para ver cada uno y otro para aceptar el encargo sin más pasos.
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

ns.UI.RegisterPage("board", function(page)
  local state = { onlyMine = false }

  page.summary = W.Text(page, "GameFontNormal")
  page.summary:SetPoint("TOPLEFT", 6, -6)

  page.onlyMine = W.Check(page, "Solo los que puedo hacer", function(checked)
    state.onlyMine = checked
    page:Refresh()
  end)
  page.onlyMine:SetPoint("TOPRIGHT", -150, -1)

  local list = W.List(page, 604, 366, {
    rows = 8,
    rowHeight = 44,
    keyOf = function(item) return item.r.id end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(34, 34)
      row.icon:SetPoint("LEFT", 4, 0)
      row.title = W.Text(row, "GameFontHighlight")
      row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
      row.title:SetPoint("RIGHT", row, "RIGHT", -214, 0)
      row.title:SetWordWrap(false)
      row.sub = W.Text(row, "GameFontHighlightSmall")
      row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 2)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -214, 0)
      row.sub:SetWordWrap(false)
      row.accept = W.Button(row, "Aceptar encargo", 114, 22)
      row.accept:SetPoint("RIGHT", -2, 0)
      row.view = W.Button(row, "Ver pedido", 90, 22)
      row.view:SetPoint("RIGHT", row.accept, "LEFT", -4, 0)
      W.KeyTooltip(row, function(self) return self.item and self.item.r.k end)
    end,
    updateRow = function(row, item)
      local r, info = item.r, item.info
      local _, icon = ns.KeyInfo(r.k)
      row.icon:SetTexture(icon)
      local title = string.format("%dx %s", r.q, ns.KeyLabel(r.k))
      if r.to == item.me then title = "|cffff80ff[A ti]|r " .. title end
      if item.mine then title = "|cff999999[Tuyo]|r " .. title end
      if item.canServe then title = title .. "  |cff40ff40(puedes hacerlo)|r" end
      row.title:SetText(title)
      local parts = { "Pide " .. ns.ShortName(r.a) .. " (" .. Data.KarmaText(r.a) .. ")" }
      parts[#parts + 1] = "hace " .. ns.FormatDuration(item.now - (r.t or item.now))
      parts[#parts + 1] = string.format("faltan %d de %d", info.remaining, r.q)
      if r.g then parts[#parts + 1] = "paga " .. ns.FormatMoney(r.g) end
      if r.m then parts[#parts + 1] = "pone los materiales" end
      row.sub:SetText(table.concat(parts, "  |cff666666·|r  "))
      row.view:SetScript("OnClick", function() ns.UI.Open("requests", r.id) end)
      row.accept:SetEnabled(item.acceptable)
      row.accept:SetText(item.committed and "Aceptar más" or "Aceptar encargo")
      row.accept:SetScript("OnClick", function() accept(r) end)
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
    local g = ns.G()
    local me, now = ns.Me(), ns.Now()
    local items, open, servable = {}, 0, 0
    for _, r in pairs(g.requests) do
      local info = Data.RequestInfo(r, now)
      -- En el tablón: lo que aún está por hacer (abiertas) y no es para otra persona.
      if info.state == "open" and (not r.to or r.to == me or r.a == me) then
        local cm = r.c and r.c[me]
        local item = {
          r = r, info = info, me = me, now = now, mine = r.a == me,
          canServe = Data.CanServe(r, now), acceptable = canAccept(r, info, me),
          committed = cm and Data.CommitActive(cm, now) or false, karma = Data.KarmaFor(r.a),
        }
        if not item.mine then open = open + 1 end
        if item.canServe then servable = servable + 1 end
        if not state.onlyMine or item.canServe then items[#items + 1] = item end
      end
    end
    table.sort(items, function(a, b)
      local function rank(x)
        if x.mine then return 4 end
        if x.r.to == me then return 1 end
        if x.canServe then return 2 end
        return 3
      end
      local ra, rb = rank(a), rank(b)
      if ra ~= rb then return ra < rb end
      if a.karma ~= b.karma then return a.karma > b.karma end -- prioridad por karma
      if (a.r.t or 0) ~= (b.r.t or 0) then return (a.r.t or 0) > (b.r.t or 0) end
      return a.r.id < b.r.id
    end)
    list:SetItems(items)
    page.summary:SetText(string.format("Pedidos abiertos: |cffffffff%d|r   Puedes hacer: |cff40ff40%d|r", open, servable))
    local none = #items == 0
    page.empty:SetShown(none)
    page.askButton:SetShown(none)
    if none then
      page.empty:SetText(state.onlyMine and "Ahora mismo no hay pedidos que puedas hacer."
        or "No hay pedidos abiertos ahora mismo.\n|cff999999(Para ver ejemplos, activa el modo demostración en Mis cosas.)|r")
    end
  end
end)
