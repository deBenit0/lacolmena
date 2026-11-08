-- Página "Hermandad": necesidades de la hermandad (todos aportan por correo), miembro de la
-- semana y, para oficiales, el anuncio del Inicio y la lista de inactivos.
local _, ns = ...
local W, S = ns.W, ns.Social

ns.UI.RegisterPage("guild", function(page)
  -- Columna izquierda: necesidades.
  page.needsTitle = W.Text(page, "GameFontNormal")
  page.needsTitle:SetPoint("TOPLEFT", 6, -6)
  page.needsTitle:SetText("Lo que necesita la hermandad")
  page.addNeed = W.Button(page, "Añadir", 70, 20, function() ns.UI.OpenOfferDialog(nil, nil, "need") end)
  page.addNeed:SetPoint("TOPLEFT", 226, -2)

  local list = W.List(page, 300, 362, {
    rows = 6,
    rowHeight = 56,
    keyOf = function(item) return item.key end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(32, 32)
      row.icon:SetPoint("TOPLEFT", 2, -4)
      row.title = W.Text(row, "GameFontHighlightSmall")
      row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0)
      row.title:SetPoint("RIGHT", row, "RIGHT", -2, 0)
      row.title:SetWordWrap(false)
      row.progress = W.Text(row, "GameFontHighlightSmall")
      row.progress:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -14)
      row.sub = W.Text(row, "GameFontDisableSmall")
      row.sub:SetPoint("TOPLEFT", 2, -40)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -70, 0)
      row.sub:SetWordWrap(false)
      row.button = W.Button(row, "Aportar", 66, 20)
      row.button:SetPoint("BOTTOMRIGHT", -2, 2)
      W.KeyTooltip(row, function(self) return self.item and ("i" .. self.item.id) end)
    end,
    updateRow = function(row, item)
      local _, icon = ns.KeyInfo("i" .. item.id)
      row.icon:SetTexture(icon)
      row.title:SetText(string.format("%dx %s", item.q, ns.KeyLabel("i" .. item.id)))
      local done = item.left == 0
      row.progress:SetText(done and string.format("|cff40ff40¡Conseguido! %d/%d|r", item.given, item.q)
        or string.format("Aportado: |cffffffff%d|r de %d", item.given, item.q))
      local donors = {}
      for i = 1, math.min(3, #item.donors) do
        donors[#donors + 1] = S.Who(item.donors[i].name) .. " " .. item.donors[i].n
      end
      row.sub:SetText("Lo pide " .. ns.ShortName(item.owner)
        .. (#donors > 0 and (" · " .. table.concat(donors, ", ")) or ""))
      if item.owner == ns.Me() then
        row.button:SetText("Quitar")
        row.button:SetEnabled(true)
        row.button:SetScript("OnClick", function()
          W.Confirm("¿Quitar esta necesidad?", function() S.RemoveNeed(item.id) end)
        end)
      else
        row.button:SetText("Aportar")
        row.button:SetEnabled(not done)
        row.button:SetScript("OnClick", function()
          local have = ns.ItemCount(item.id)
          W.AskAmount(string.format("¿Cuántos aportas? (faltan %d, tienes %d)", item.left, have),
            math.max(1, math.min(item.left, have)), function(n)
              if ns.Mail.CanPrepare() then
                ns.Mail.PrepareNeed(item.owner, item.id, n)
              else
                ns.Print("mándale %dx %s por correo a %s: la donación se apunta sola al enviarlo.",
                  n, ns.KeyLabel("i" .. item.id), ns.ShortName(item.owner))
              end
            end)
        end)
      end
    end,
  })
  list:SetPoint("TOPLEFT", 0, -28)
  page.list = list
  page.emptyNeeds = W.Text(page, "GameFontHighlightSmall", "CENTER")
  page.emptyNeeds:SetPoint("CENTER", list, "CENTER")
  page.emptyNeeds:SetWidth(260)
  page.emptyNeeds:SetTextColor(0.7, 0.7, 0.7)

  -- Columna derecha: reconocimientos y herramientas de oficial.
  local x = 312
  page.weekTitle = W.Text(page, "GameFontNormal")
  page.weekTitle:SetPoint("TOPLEFT", x, -6)
  page.weekTitle:SetText("Miembro de la semana")
  page.week = W.Text(page, "GameFontHighlightSmall")
  page.week:SetPoint("TOPLEFT", x, -26)
  page.week:SetWidth(292)
  page.week:SetJustifyV("TOP")
  page.week:SetSpacing(2)

  page.officerTitle = W.Text(page, "GameFontNormal")
  page.officerTitle:SetPoint("TOPLEFT", x, -150)
  page.officerTitle:SetText("Oficiales")
  page.announce = W.Input(page, 210)
  page.announce:SetPoint("TOPLEFT", x + 4, -172)
  page.announce:SetMaxLetters(S.ANNOUNCE_MAX)
  W.Placeholder(page.announce, "Anuncio para el Inicio...")
  page.publish = W.Button(page, "Publicar", 76, 20, function()
    local ok, err = S.SetAnnouncement(page.announce:GetText(), ns.Now())
    if not ok then ns.Print(err) else ns.Print("anuncio publicado en el Inicio de todos.") end
  end)
  page.publish:SetPoint("LEFT", page.announce, "RIGHT", 4, 0)
  page.inactive = W.Text(page, "GameFontHighlightSmall")
  page.inactive:SetPoint("TOPLEFT", x, -198)
  page.inactive:SetWidth(292)
  page.inactive:SetJustifyV("TOP")
  page.inactive:SetSpacing(2)
  page.notOfficer = W.Text(page, "GameFontDisableSmall")
  page.notOfficer:SetPoint("TOPLEFT", x, -172)
  page.notOfficer:SetWidth(292)
  page.notOfficer:SetText("Los oficiales publican aquí el anuncio del Inicio, las necesidades de la hermandad "
    .. "y ven quién está inactivo. Desde cada pedido pueden marcarlo como prioridad o cerrarlo.")

  function page:Refresh()
    local now = ns.Now()
    local officer = S.AmOfficer()
    local needs = S.Needs(now)
    list:SetItems(needs)
    page.addNeed:SetShown(officer)
    page.emptyNeeds:SetShown(#needs == 0)
    page.emptyNeeds:SetText(officer and "No hay necesidades. Pulsa Añadir para pedir algo para la hermandad "
      .. "(frascos para la banda, materiales...)." or "Ahora mismo la hermandad no necesita nada.")

    local lines = {}
    local best = S.MemberOfTheWeek(now)
    if best then
      lines[#lines + 1] = string.format("|cffffd100%s|r: %d ayudas la semana pasada", S.Who(best.name), best.n)
    else
      lines[#lines + 1] = "|cff999999La semana pasada nadie ayudó (o aún no hay datos).|r"
    end
    lines[#lines + 1] = " "
    lines[#lines + 1] = "|cffffd100Esta semana|r |cff999999(pedidos enviados, ofertas y donaciones)|r"
    local ranking = S.Ranking("this", now)
    for i = 1, math.min(5, #ranking) do
      lines[#lines + 1] = string.format("%d. %s  %d", i, S.Who(ranking[i].name), ranking[i].n)
    end
    if #ranking == 0 then lines[#lines + 1] = "|cff999999Aún nadie.|r" end
    page.week:SetText(table.concat(lines, "\n"))

    page.announce:SetShown(officer)
    page.publish:SetShown(officer)
    page.inactive:SetShown(officer)
    page.notOfficer:SetShown(not officer)
    if officer then
      local c = ns.MyChar()
      if not page.announce:HasFocus() then page.announce:SetText(c and c.announce and c.announce.x or "") end
      local inactive, noAddon = S.Inactive(now)
      local out = { string.format("|cffffd100Inactivos (más de %d días): %d|r", S.INACTIVE_DAYS, #inactive) }
      for i = 1, math.min(6, #inactive) do
        out[#out + 1] = string.format("  %s  |cff999999%d días|r", ns.ShortName(inactive[i].name), inactive[i].days)
      end
      out[#out + 1] = string.format("|cffffd100Sin el addon: %d|r", #noAddon)
      local names = {}
      for i = 1, math.min(8, #noAddon) do names[#names + 1] = ns.ShortName(noAddon[i]) end
      if #names > 0 then out[#out + 1] = "  " .. table.concat(names, ", ") .. (#noAddon > 8 and "..." or "") end
      page.inactive:SetText(table.concat(out, "\n"))
    end
  end
end)
