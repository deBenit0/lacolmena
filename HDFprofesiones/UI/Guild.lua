-- Página "Hermandad": miembro de la semana, karma con barras, quién fabrica qué (cada profesión
-- con quién la tiene y a qué nivel) y la zona de oficiales (anuncio, pedidos de la hermandad,
-- bienvenida e inactivos). Los pedidos de la hermandad se ven y se aportan en el Mercado.
local _, ns = ...
local W, S = ns.W, ns.Social

-- "Aportar" a un pedido de la hermandad: cuántos y se manda por correo al oficial (se apunta solo).
function ns.UI.ContributeNeed(item)
  local have = ns.ItemCount(item.id)
  W.AskAmount(string.format("¿Cuántos aportas? (faltan %d, tienes %d)", item.left, have),
    math.max(1, math.min(item.left, have)), function(n)
      if ns.Mail.CanPrepare() then
        ns.Mail.PrepareNeed(item.owner, item.id, n)
      else
        ns.Print("mándale %dx %s por correo a %s: la aportación se apunta sola al enviarlo.",
          n, ns.KeyLabel("i" .. item.id), ns.ShortName(item.owner))
      end
    end)
end

-- Profesiones que salen en «Quién fabrica qué», en este orden.
local WHO_PROFS = { 164, 165, 197, 171, 202, 333, 185, 129, 186, 393, 182 }

-- Todos los de la hermandad con una profesión, con su nivel (de más a menos) o, con byKarma, por
-- el karma de la persona (su principal) y luego por nivel.
local function countWith(pk)
  local g, n = ns.G(), 0
  for _, e in pairs(g and g.entries or {}) do
    if type(e.p) == "table" and e.p[pk] then n = n + 1 end
  end
  return n
end

local function peopleWith(pk, byKarma)
  local g = ns.G()
  local rows = {}
  if not g then return rows end
  local karmaOf = {} -- una vez por persona (su principal)
  for name, e in pairs(g.entries) do
    local p = type(e.p) == "table" and e.p[pk]
    if p then
      local main = S.MainOf(name) or name
      if karmaOf[main] == nil then karmaOf[main] = ns.Data.KarmaFor(main) end
      local k = karmaOf[main]
      rows[#rows + 1] = { name = name, class = e.c or ns.ClassOf(name), pk = pk, r = p.r, unavailable = e.u,
        online = ns.Guild.IsOnline(name), seen = ns.Guild.LastSeen(name), k = k,
        karma = ns.Data.KarmaText(main), thanks = ns.Data.ThanksFor(name) }
      if byKarma then rows[#rows].extra = "|cffbbbbbbkarma " .. rows[#rows].karma .. "|r" end
    end
  end
  table.sort(rows, function(a, b)
    if byKarma and a.k ~= b.k then return a.k > b.k end
    if (a.r or 0) ~= (b.r or 0) then return (a.r or 0) > (b.r or 0) end
    return a.name < b.name
  end)
  return rows
end
ns.UI.PeopleWith = peopleWith

-- Cuántos personajes tienen alguna profesión de fabricar y cuántos de recolectar (cada personaje
-- aparte, como los roles). Cocina, primeros auxilios y pesca no cuentan.
local CRAFT_PROFS = { [164] = true, [165] = true, [197] = true, [171] = true, [202] = true, [333] = true,
  [755] = true, [773] = true }
local GATHER_PROFS = { [182] = true, [186] = true, [393] = true }
function ns.UI.TradeCounts(entries)
  local crafters, gatherers = 0, 0
  for _, e in pairs(entries or {}) do
    local craft, gather = false, false
    for pk in pairs(type(e.p) == "table" and e.p or {}) do
      if CRAFT_PROFS[pk] then craft = true end
      if GATHER_PROFS[pk] then gather = true end
    end
    for pk in pairs(type(e.ga) == "table" and e.ga or {}) do
      if GATHER_PROFS[tonumber(pk)] then gather = true end
    end
    if craft then crafters = crafters + 1 end
    if gather then gatherers = gatherers + 1 end
  end
  return crafters, gatherers
end

-- Karma de cada persona (su principal), de más a menos.
local function karmaRanking()
  local g = ns.G()
  local seen, out = {}, {}
  for name in pairs(g and g.entries or {}) do
    local main = S.MainOf(name) or name
    if not seen[main] then
      seen[main] = true
      local k = ns.Data.KarmaFor(main)
      if k ~= 0 then out[#out + 1] = { name = main, k = k } end
    end
  end
  table.sort(out, function(a, b)
    if a.k ~= b.k then return a.k > b.k end
    return a.name < b.name
  end)
  return out
end

-- Ventana para elegir el rol (o los roles) de este personaje. Con "force" no se puede cerrar
-- sin elegir: sale la primera vez que se abre la Hermandad.
local rolesFrame
function ns.UI.ChooseRoles(force)
  local D = ns.Dungeons
  local c = ns.MyChar()
  if not c then return end
  if not rolesFrame then
    local f = W.Panel("HDFProfRoles", UIParent, 380, 176)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetPoint("CENTER", 0, 80)
    f:Hide()
    f.title = W.Text(f, "GameFontNormalLarge", "CENTER")
    f.title:SetPoint("TOP", 0, -16)
    f.title:SetText("¿Qué rol haces con este personaje?")
    f.sub = W.Text(f, "GameFontHighlightSmall", "CENTER")
    f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
    f.sub:SetWidth(350)
    f.sub:SetText("Puedes marcar varios. Sirve para saber cuántos tanques, sanadores y DPS tiene la hermandad.")
    local ICONS = { [1] = "Interface\\Icons\\Ability_Defend", [2] = "Interface\\Icons\\Spell_Holy_FlashHeal",
      [4] = "Interface\\Icons\\INV_Sword_04" }
    f.buttons = {}
    for i, r in ipairs(D.ROLES) do
      local b = W.Chip(f, "      " .. r.label, 108, function()
        f.mask = D.HasRole(f.mask, r.bit) and (f.mask - r.bit) or (f.mask + r.bit)
        f:Update()
      end)
      b:SetHeight(30)
      b:SetPoint("TOPLEFT", 16 + (i - 1) * 118, -74)
      b.icon = b:CreateTexture(nil, "OVERLAY")
      b.icon:SetSize(20, 20)
      b.icon:SetPoint("LEFT", 8, 0)
      b.icon:SetTexture(ICONS[r.bit])
      b.bit = r.bit
      f.buttons[i] = b
    end
    f.ok = W.Button(f, "Aceptar", 110, 24, function()
      local me = ns.MyChar()
      if not me or f.mask == 0 then return end
      me.roleSet = f.mask
      f:Hide()
      ns.Sync.PublishMine()
      ns.Fire("DATA_CHANGED", "role")
    end)
    f.ok:SetPoint("BOTTOM", 0, 16)
    f.close = W.CloseButton(f)
    f.close:SetPoint("TOPRIGHT", -2, -2)
    function f:Update()
      local me = ns.MyChar()
      local allowed = D.CLASS_ROLES[(me and me.class) or D.MyClass()] or 7
      for _, b in ipairs(self.buttons) do
        local can = D.HasRole(allowed, b.bit)
        b:SetEnabled(can)
        b.icon:SetDesaturated(not can)
        b:SetOn(D.HasRole(self.mask, b.bit))
      end
      self.ok:SetEnabled(self.mask > 0)
    end
    rolesFrame = f
  end
  local allowed = D.CLASS_ROLES[c.class or D.MyClass()] or 7
  local mask = D.CleanRole(c.roleSet) or 0
  -- solo los roles que puede hacer su clase
  for _, r in ipairs(D.ROLES) do
    if D.HasRole(mask, r.bit) and not D.HasRole(allowed, r.bit) then mask = mask - r.bit end
  end
  rolesFrame.mask = mask
  rolesFrame.close:SetShown(not force)
  rolesFrame:Update()
  rolesFrame:Show()
end

ns.UI.RegisterPage("guild", function(page)
  -- La primera vez (sin rol elegido) hay que decir qué rol haces.
  page:HookScript("OnShow", function()
    local c = ns.MyChar()
    if c and not c.roleSet then ns.UI.ChooseRoles(true) end
  end)
  -- Columnas: karma (izquierda), «Quién fabrica qué» (centro) y oficiales (derecha, solo si lo eres).
  -- Si no eres oficial, «Quién fabrica qué» se queda también con el sitio de los oficiales.
  local COL1, COL2, COL3 = 0, 262, 604
  local WHO_W, WHO_W_WIDE, OFF_W = 334, 526, 184
  local state = { pk = nil }

  local function title(text, x, y)
    local fs = W.Text(page, "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
  end

  -- Columna 1: miembro de la semana, en grande, y el karma con barras.
  title("Miembro de la semana", COL1 + 4, -6)
  local weekBox = W.Box(page, 250, 84)
  weekBox:SetPoint("TOPLEFT", COL1, -24)
  weekBox.icon = weekBox:CreateTexture(nil, "ARTWORK")
  weekBox.icon:SetSize(44, 44)
  weekBox.icon:SetPoint("LEFT", 12, 0)
  weekBox.icon:SetTexture("Interface\\Icons\\INV_Crown_01")
  weekBox.name = W.Text(weekBox, "GameFontNormalLarge")
  weekBox.name:SetPoint("TOPLEFT", weekBox.icon, "TOPRIGHT", 10, -4)
  weekBox.name:SetPoint("RIGHT", -8, 0)
  weekBox.name:SetWordWrap(false)
  weekBox.sub = W.Text(weekBox, "GameFontHighlightSmall")
  weekBox.sub:SetPoint("TOPLEFT", weekBox.name, "BOTTOMLEFT", 0, -6)
  weekBox.sub:SetPoint("RIGHT", -8, 0)
  page.weekBox = weekBox

  title("Karma", COL1 + 4, -118)
  local karmaHint = W.Text(page, "GameFontDisableSmall")
  karmaHint:SetPoint("TOPLEFT", COL1 + 60, -120)
  karmaHint:SetText("+1 por dar, -1 por recibir")
  page.bars = {}
  for i = 1, 6 do
    local bar = CreateFrame("Button", nil, page)
    bar:SetSize(250, 28)
    bar:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    bar:SetScript("OnClick", function(self) if self.who then ns.UI.ShowHistory(self.who) end end)
    ns.UI.Tip(bar, "Historial", "Clic: lo que ha pedido, hecho y aportado.")
    bar:SetPoint("TOPLEFT", COL1, -136 - (i - 1) * 30)
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("LEFT", 0, 0)
    bar.fill:SetHeight(22)
    bar.fill:SetColorTexture(1, 0.82, 0, 0.25)
    bar.name = W.Text(bar, "GameFontHighlightSmall")
    bar.name:SetPoint("LEFT", 6, 0)
    bar.name:SetPoint("RIGHT", -40, 0)
    bar.name:SetWordWrap(false)
    bar.value = W.Text(bar, "GameFontNormal", "RIGHT")
    bar.value:SetPoint("RIGHT", -4, 0)
    page.bars[i] = bar
  end
  page.noKarma = W.Text(page, "GameFontHighlightSmall")
  page.noKarma:SetPoint("TOPLEFT", COL1 + 6, -140)
  page.noKarma:SetTextColor(0.6, 0.6, 0.6)
  page.noKarma:SetText("Aún nadie tiene karma.")

  -- Debajo del karma: cuántos tanques, sanadores y DPS hay (cada personaje, desde el nivel 10).
  title("Roles", COL1 + 4, -322)
  local rolesHint = W.Text(page, "GameFontDisableSmall")
  rolesHint:SetPoint("TOPLEFT", COL1 + 60, -324)
  rolesHint:SetText("desde nivel 10 · pulsa los tuyos")

  -- Pulsar tanque, sanador o DPS lo añade a los roles de este personaje (puede tener varios);
  -- pulsar uno que ya tiene lo quita. Sin ninguno, vuelve a «Auto» (talentos).
  local function setMyRole(role)
    local c = ns.MyChar()
    if not c then return end
    local D = ns.Dungeons
    local mask = D.CleanRole(c.roleSet) or 0
    if D.HasRole(mask, role) then
      mask = mask - role
    else
      local allowed = D.CLASS_ROLES[c.class or D.MyClass()] or 7
      if not D.HasRole(allowed, role) then
        ns.Print("tu clase no puede ser %s.", D.RoleLabel(role):lower())
        return
      end
      mask = mask + role
    end
    c.roleSet = mask > 0 and mask or nil
    ns.Sync.PublishMine()
    page:Refresh()
  end
  page.SetMyRole = function(_, role) setMyRole(role) end
  local ROLE_SLOTS = {
    { key = 1, icon = "Interface\\Icons\\Ability_Defend", tip = "Tanques" },
    { key = 2, icon = "Interface\\Icons\\Spell_Holy_FlashHeal", tip = "Sanadores" },
    { key = 4, icon = "Interface\\Icons\\INV_Sword_04", tip = "DPS" },
    { key = "unknown", icon = "Interface\\Icons\\INV_Misc_QuestionMark", tip = "Sin saber",
      text = "Sin el addon y de una clase que puede hacer varios roles (o sin talentos todavía)." },
    -- Segunda fila: oficios (de los que tienen el addon: las profesiones solo se saben por él).
    { key = "crafters", row = 2, icon = "Interface\\Icons\\Trade_BlackSmithing", tip = "Artesanos",
      text = "Personajes con alguna profesión de fabricar (herrería, alquimia, sastrería…). Solo cuenta a los que tienen el addon." },
    { key = "gatherers", row = 2, icon = "Interface\\Icons\\Trade_Herbalism", tip = "Recolectores",
      text = "Personajes con herboristería, minería o desuello. Solo cuenta a los que tienen el addon." },
  }
  page.roleSlots = {}
  for i, s in ipairs(ROLE_SLOTS) do
    local b = CreateFrame("Button", nil, page)
    local col = s.row == 2 and (s.key == "crafters" and 0 or 2) or (i - 1)
    b:SetSize(s.row == 2 and 120 or 58, 26)
    b:SetPoint("TOPLEFT", COL1 + 4 + col * 62, s.row == 2 and -374 or -342)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(24, 24)
    b.icon:SetPoint("LEFT", 0, 0)
    b.icon:SetTexture(s.icon)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = W.Text(b, "GameFontNormalLarge")
    b.count:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    if s.row == 2 then
      b.label = W.Text(b, "GameFontHighlightSmall")
      b.label:SetPoint("LEFT", b.count, "RIGHT", 5, 0)
      b.label:SetText(s.key == "crafters" and "artesanos" or "recolectores")
    end
    if s.key == "unknown" then b.count:SetTextColor(0.6, 0.6, 0.6) end
    if s.row == 2 then
      ns.UI.Tip(b, s.tip, s.text)
    else
      -- Aro dorado alrededor del icono en el rol de este personaje.
      b.ring = CreateFrame("Frame", nil, b)
      b.ring:SetSize(28, 28)
      b.ring:SetPoint("CENTER", b.icon, "CENTER")
      b.ringBorder = W.Border(b.ring, W.COLORS.GOLD, "OVERLAY")
      b.ring:Hide()
      if s.key ~= "unknown" then
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        local hl = b:GetHighlightTexture()
        if hl then
          hl:ClearAllPoints()
          hl:SetAllPoints(b.icon)
        end
        b:SetScript("OnClick", function() setMyRole(s.key) end)
      end
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.tip .. " (" .. tostring(self.count:GetText() or 0) .. ")")
        local c = ns.MyChar()
        if s.key == "unknown" then
          GameTooltip:AddLine(s.text, 1, 1, 1, true)
        elseif c and ns.Dungeons.HasRole(c.roleSet, s.key) then
          GameTooltip:AddLine("Es uno de los tuyos: lo has elegido tú. Pulsa otra vez para quitarlo.",
            0.25, 1, 0.25, true)
        elseif c and not c.roleSet and c.roleAuto == s.key then
          GameTooltip:AddLine("Es el tuyo: sale de tus talentos. Pulsa para fijarlo a mano.", 0.25, 1, 0.25, true)
        else
          GameTooltip:AddLine("Pulsa si este personaje también hace de " .. ns.Dungeons.RoleLabel(s.key):lower()
            .. " (puedes marcar varios). Otra vez: lo quita.", 1, 1, 1, true)
        end
        local names = page.roleNames and page.roleNames[s.key] or {}
        if #names > 0 then
          table.sort(names)
          GameTooltip:AddLine(" ")
          for i = 1, math.min(15, #names) do
            GameTooltip:AddLine(ns.WhoColored(names[i]), 1, 1, 1)
          end
          if #names > 15 then GameTooltip:AddLine(string.format("y %d más", #names - 15), 0.7, 0.7, 0.7) end
        end
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    b.key = s.key
    page.roleSlots[i] = b
  end

  -- Columna 2: quién fabrica qué.
  title("Quién fabrica qué", COL2 + 4, -6)
  page.profs = {}
  for i, pk in ipairs(WHO_PROFS) do
    local b = CreateFrame("Button", nil, page)
    b:SetSize(32, 32)
    b:SetPoint("TOPLEFT", COL2 + ((i - 1) % 7) * 38, -26 - math.floor((i - 1) / 7) * 38)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexture(ns.ProfessionIcon(pk))
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function()
      state.pk = pk
      page:Refresh()
    end)
    ns.UI.Tip(b, ns.ProfessionName(pk))
    b.pk = pk
    page.profs[i] = b
  end
  page.profTitle = W.Text(page, "GameFontNormalSmall")
  page.profTitle:SetPoint("TOPLEFT", COL2 + 4, -106)
  page.who = W.Crafters(page, WHO_W, 13, nil, nil, function(c) ns.UI.ShowHistory(c.name) end)
  page.who:SetPoint("TOPLEFT", COL2, -120)
  -- Ordenar por nivel (como siempre) o por karma; se recuerda.
  page.whoSort = W.Button(page, "", 128, 18, function()
    ns.db.settings.whoSort = (ns.db.settings.whoSort ~= "karma") and "karma" or nil
    page:Refresh()
  end)
  page.whoSort:SetFontSize("small")
  page.whoSort:SetPoint("BOTTOMRIGHT", page.who, "TOPRIGHT", 0, 1)
  ns.UI.Tip(page.whoSort, "Ordenar", "Por nivel de la profesión o por el karma de cada persona (el de su "
    .. "personaje principal).")
  page.noWho = W.Text(page, "GameFontHighlightSmall", "CENTER")
  page.noWho:SetPoint("CENTER", page.who, "CENTER")
  page.noWho:SetWidth(WHO_W - 40)
  page.noWho:SetTextColor(0.6, 0.6, 0.6)

  -- Columna 3: oficiales.
  -- Abajo a la derecha: la ventana de hermandad del juego (la J abre esta página).
  page.gameGuild = W.Button(page, "Ventana del juego", 140, 22, function() ns.UI.OpenGameGuild() end)
  page.gameGuild:SetPoint("BOTTOMRIGHT", 0, 2)
  ns.UI.Tip(page.gameGuild, "Ventana de hermandad del juego", "La de siempre: lista de miembros, rangos, noticias...")
  page.guildKey = W.Check(page, "Abrir con la J", function(checked) ns.UI.SetGuildKey(checked) end)
  page.guildKey:SetPoint("RIGHT", page.gameGuild, "LEFT", -150, 0)
  ns.UI.Tip(page.guildKey, "Abrir con la J", "Al abrir la ventana de hermandad del juego (la J), se abre "
    .. "también esta página a su lado, y se cierran juntas. Quítalo para que la J abra solo la del juego.")

  page.officerTitle = title("Oficiales", COL3 + 4, -6)
  page.announce = W.Input(page, OFF_W - 66)
  page.announce:SetPoint("TOPLEFT", COL3 + 8, -28)
  page.announce:SetMaxLetters(S.ANNOUNCE_MAX)
  W.Placeholder(page.announce, "Anuncio para el Inicio…")
  page.publish = W.Button(page, "Publicar", 60, 20, function()
    local ok, err = S.SetAnnouncement(page.announce:GetText(), ns.Now())
    if not ok then ns.Print(err) else ns.Print("anuncio publicado en el Inicio de todos.") end
  end)
  page.publish:SetPoint("LEFT", page.announce, "RIGHT", 4, 0)
  page.addNeed = W.Button(page, "+ Pedido de la hermandad", OFF_W, 22, function()
    ns.UI.OpenOfferDialog(nil, nil, "need")
  end)
  page.addNeed:SetPoint("TOPLEFT", COL3, -54)
  ns.UI.Tip(page.addNeed, "Pedido de la hermandad", "Frascos para la banda, materiales… Todos lo verán arriba del "
    .. "Mercado y podrán aportar por correo.")
  page.needs = W.Button(page, "", OFF_W, 22, function() ns.UI.OpenMarket(nil, "want") end)
  page.needs:SetPoint("TOPLEFT", COL3, -80)
  page.missing = W.Button(page, "", OFF_W, 22, function() ns.UI.ShowMissingRecipes() end)
  page.missing:SetPoint("TOPLEFT", COL3, -106)
  page.welcome = W.Check(page, "Bienvenida a los nuevos", function(checked)
    ns.QoL.WelcomeSettings().on = checked
  end)
  page.welcome:SetPoint("TOPLEFT", COL3, -134)
  ns.UI.Tip(page.welcome, "Bienvenida automática", "Saluda en el chat de hermandad a quien entra nuevo.")
  page.inactive = W.Text(page, "GameFontHighlightSmall")
  page.inactive:SetPoint("TOPLEFT", COL3 + 4, -164)
  page.inactive:SetWidth(OFF_W)
  page.inactive:SetJustifyV("TOP")
  page.inactive:SetSpacing(2)

  function page:Refresh()
    page.guildKey:SetChecked(ns.UI.GuildKeyOn())
    local now = ns.Now()
    local officer = S.AmOfficer()

    -- Miembro de la semana.
    local best = S.MemberOfTheWeek(now)
    if best then
      weekBox.name:SetText(ns.WhoColored(best.name))
      weekBox.sub:SetText(string.format("%d ayudas la semana pasada", best.n))
    else
      weekBox.name:SetText("|cff999999Nadie todavía|r")
      weekBox.sub:SetText("La semana pasada nadie ayudó (o aún no hay datos).")
    end

    -- Karma con barras.
    local ranking = karmaRanking()
    local top = ranking[1] and math.max(1, math.abs(ranking[1].k)) or 1
    for i, bar in ipairs(page.bars) do
      local e = ranking[i]
      bar:SetShown(e ~= nil)
      bar.who = e and e.name
      if e then
        bar.name:SetText(i .. ". " .. ns.WhoColored(e.name))
        bar.value:SetText(ns.Data.KarmaText(e.name))
        bar.fill:SetWidth(math.max(2, 250 * math.max(0, e.k) / top))
      end
    end
    page.noKarma:SetShown(#ranking == 0)

    -- Roles.
    local g = ns.G()
    local rc = ns.Dungeons.RoleCounts(g and g.entries, ns.Guild.roster)
    rc.crafters, rc.gatherers = ns.UI.TradeCounts(g and g.entries)
    page.roleNames = rc.names
    local c = ns.MyChar()
    local myRole = c and (c.roleSet or c.roleAuto)
    for _, b in ipairs(page.roleSlots) do
      b.count:SetText(rc[b.key] or 0)
      if b.ring then
        local mine = myRole ~= nil and type(b.key) == "number" and ns.Dungeons.HasRole(myRole, b.key)
        b.ring:SetShown(mine)
        -- elegido a mano: dorado; sacado de los talentos: más apagado
        if mine and c.roleSet then b.ringBorder:SetColor(1, 0.82, 0, 1) else b.ringBorder:SetColor(0.6, 0.5, 0.25, 1) end
      end
    end

    -- Quién fabrica qué: la profesión elegida (o la primera que tenga alguien).
    local counts = {}
    for _, pk in ipairs(WHO_PROFS) do counts[pk] = countWith(pk) end
    if not state.pk then
      for _, pk in ipairs(WHO_PROFS) do if counts[pk] > 0 then state.pk = pk break end end
      state.pk = state.pk or WHO_PROFS[1]
    end
    for _, b in ipairs(page.profs) do
      b.count:SetText(counts[b.pk] > 0 and tostring(counts[b.pk]) or "")
      b.tex:SetDesaturated(b.pk ~= state.pk)
    end
    local byKarma = ns.db.settings.whoSort == "karma"
    page.whoSort:SetText(byKarma and "Ordenar: karma" or "Ordenar: nivel")
    local rows = peopleWith(state.pk, byKarma)
    page.profTitle:SetText(ns.ProfessionName(state.pk) .. " |cffbbbbbb(" .. #rows .. ")|r")
    page.who:SetItems(rows)
    page.noWho:SetShown(#rows == 0)
    page.noWho:SetText("Nadie ha publicado " .. ns.ProfessionName(state.pk) .. ".\nCada uno debe abrir la ventana de su profesión una vez.")

    -- Oficiales.
    for _, f in ipairs({ page.officerTitle, page.announce, page.publish, page.addNeed, page.needs, page.missing,
      page.welcome, page.inactive }) do
      f:SetShown(officer)
    end
    page.who:SetWidth(officer and WHO_W or WHO_W_WIDE)
    page.noWho:SetWidth((officer and WHO_W or WHO_W_WIDE) - 40)
    if officer then
      local nNeeds = 0
      for _, n in ipairs(S.Needs(now)) do if n.left > 0 then nNeeds = nNeeds + 1 end end
      page.needs:SetText(string.format("Pedidos de la hermandad (%d)", nNeeds))
      page.missing:SetText(string.format("Nadie sabe hacerlo (%d)", #ns.Extras.MissingRecipes(now)))
      page.welcome:SetChecked(ns.QoL.WelcomeSettings().on and true or false)
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
      if #names > 0 then out[#out + 1] = "  " .. table.concat(names, ", ") .. (#noAddon > 8 and "…" or "") end
      page.inactive:SetText(table.concat(out, "\n"))
    end
  end
end)

-- Ventana del historial de una persona: lo que ha pedido (y quién se lo hizo) y lo que ha hecho
-- o aportado. Sale de las fichas de la hermandad (ver History.lua).
local historyWindow
local HISTORY_LINES = 60
local KIND_TEXT = { p = "pedido", o = "oferta", a = "aportación" }

local function historyLine(h, now, gave)
  local other = ns.ShortName(h.who)
  local text
  if h.kind == "a" then
    text = string.format("aportado a %s", other)
  elseif gave then
    text = string.format("para %s", other)
  else
    text = string.format("lo hizo %s", other)
  end
  return string.format("%dx %s\n   |cffbbbbbb%s (%s) · hace %s|r", h.n, ns.KeyLabel(h.key), text, KIND_TEXT[h.kind] or "",
    ns.FormatDuration(now - h.t))
end

function ns.UI.ShowHistory(name)
  if not name then return end
  if not historyWindow then
    local f = W.Panel("HDFProfHistory", UIParent, 640, 420)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetPoint("CENTER", 0, 40)
    f:Hide()
    tinsert(UISpecialFrames, "HDFProfHistory")
    f.title = W.Text(f, "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -16)
    local close = W.CloseButton(f)
    close:SetPoint("TOPRIGHT", -10, -10)
    f.cols = {}
    for i, label in ipairs({ "Ha pedido", "Ha hecho y aportado" }) do
      local x = 20 + (i - 1) * 310
      local head = W.Text(f, "GameFontNormal")
      head:SetPoint("TOPLEFT", x, -46)
      -- Con rueda o barra para bajar: caben las 30 de cada uno.
      local scroll = CreateFrame("ScrollFrame", "HDFProfHistoryScroll" .. i, f, "UIPanelScrollFrameTemplate")
      scroll:SetPoint("TOPLEFT", x, -66)
      scroll:SetSize(270, 300)
      local child = CreateFrame("Frame", nil, scroll)
      child:SetSize(270, 300)
      scroll:SetScrollChild(child)
      local text = W.Text(child, "GameFontHighlightSmall")
      text:SetPoint("TOPLEFT", 0, 0)
      text:SetWidth(266)
      text:SetJustifyH("LEFT")
      text:SetJustifyV("TOP")
      text:SetSpacing(2)
      f.cols[i] = { label = label, head = head, text = text, scroll = scroll, child = child }
    end
    f.hint = W.Text(f, "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", 20, 14)
    f.hint:SetWidth(600)
    f.hint:SetText("Lo hecho lo apunta quien lo recibe. Cada personaje guarda sus últimos 30. "
      .. "Solo lo de quien tiene la versión 0.33 o más nueva.")
    historyWindow = f
  end
  local f, now = historyWindow, ns.Now()
  local got, gave = ns.History.For(name)
  f.title:SetText("Historial de " .. ns.WhoColored(name))
  for i, list in ipairs({ got, gave }) do
    local col = f.cols[i]
    col.head:SetText(string.format("%s |cffbbbbbb(%d)|r", col.label, #list))
    local lines = {}
    for j = 1, math.min(#list, HISTORY_LINES) do lines[#lines + 1] = historyLine(list[j], now, i == 2) end
    if #list > HISTORY_LINES then lines[#lines + 1] = string.format("|cff999999y %d más...|r", #list - HISTORY_LINES) end
    col.text:SetText(#lines > 0 and table.concat(lines, "\n") or "|cff999999Nada todavía.|r")
    col.child:SetHeight(math.max(300, (col.text:GetStringHeight() or 0) + 8))
    col.scroll:SetVerticalScroll(0)
  end
  f:Show()
  return f
end

-- Ventana "Recetas que faltan".
local missingWindow
function ns.UI.ShowMissingRecipes()
  if not missingWindow then
    local f = W.Panel("HDFProfMissingRecipes", UIParent, 420, 330)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetPoint("CENTER", 0, 40)
    f:Hide()
    tinsert(UISpecialFrames, "HDFProfMissingRecipes")
    f.title = W.Text(f, "GameFontNormal")
    f.title:SetPoint("TOP", 0, -16)
    f.title:SetText("Lo que se pide y nadie sabe hacer")
    local close = W.CloseButton(f)
    close:SetPoint("TOPRIGHT", -10, -10)
    f.text = W.Text(f, "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", 20, -42)
    f.text:SetWidth(380)
    f.text:SetJustifyV("TOP")
    f.text:SetSpacing(3)
    f.hint = W.Text(f, "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", 20, 16)
    f.hint:SetWidth(380)
    f.hint:SetText("Si alguien aprende una de estas recetas, a quien lo pidió le llega un aviso.")
    missingWindow = f
  end
  local list = ns.Extras.MissingRecipes(ns.Now())
  local lines = {}
  for i = 1, math.min(15, #list) do
    local e = list[i]
    local who = ns.ShortName(e.askers[1]) .. (#e.askers > 1 and (" y " .. (#e.askers - 1) .. " más") or "")
    lines[#lines + 1] = string.format("%s  |cff999999(lo pide %s)|r", ns.KeyLabel(e.key), who)
  end
  if #list > 15 then lines[#lines + 1] = string.format("|cff999999y %d más...|r", #list - 15) end
  missingWindow.text:SetText(#lines > 0 and table.concat(lines, "\n")
    or "|cff40ff40Todo lo que se pide lo sabe hacer alguien de la hermandad.|r")
  missingWindow:Show()
  return missingWindow
end
