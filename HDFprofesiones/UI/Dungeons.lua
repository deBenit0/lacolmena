-- Página "Mazmorras": quedadas propuestas, apuntarse por rol y hacer el grupo.
local _, ns = ...
local W, D = ns.W, ns.Dungeons

local STATE_TEXT = { open = "|cff40ff40Abierta|r", cancelled = "|cff999999Cancelada|r", past = "|cff999999Pasada|r" }

local function whenText(r, now)
  if r.at <= now + 120 then
    return now > r.at + 120 and ("desde las " .. D.Clock(r.at)) or "ahora"
  end
  return "a las " .. D.Clock(r.at) .. " (en " .. ns.FormatDuration(r.at - now) .. ")"
end

local function personText(su, dg)
  local name = ns.ColoredName(su.name, su.class)
  local level = su.level and tostring(su.level) or "?"
  if su.level and su.level < dg.min then level = "|cffff4040" .. level .. "|r" end
  local text = name .. " (" .. level .. ")"
  if not su.online then text = "|cff888888" .. ns.ShortName(su.name) .. " (" .. (su.level or "?") .. ", desc.)|r" end
  return text
end

local function roleCounts(r)
  local t, h, dps = 0, 0, 0
  for _, su in ipairs(D.SignUps(r)) do
    if D.HasRole(su.roles, D.TANK) then t = t + 1 end
    if D.HasRole(su.roles, D.HEAL) then h = h + 1 end
    if D.HasRole(su.roles, D.DPS) then dps = dps + 1 end
  end
  return t, h, dps
end

---------------------------------------------------------------------------
-- Ventana "Proponer mazmorra"
---------------------------------------------------------------------------
local dialog

local function roleChecks(parent, x, y)
  local checks = {}
  for i, role in ipairs(D.ROLES) do
    local c = W.Check(parent, role.label)
    c:SetPoint("TOPLEFT", x + (i - 1) * 96, y)
    c.bit = role.bit
    checks[i] = c
  end
  return checks
end

-- Deja marcar solo los roles que puede hacer mi clase.
local function setupChecks(checks, mask)
  local allowed = D.RolesFor(D.MyClass())
  for _, c in ipairs(checks) do
    local can = D.HasRole(allowed, c.bit)
    c:SetEnabled(can)
    c.label:SetTextColor(can and 1 or 0.5, can and 1 or 0.5, can and 1 or 0.5)
    c:SetChecked(can and D.HasRole(mask or 0, c.bit) or false)
  end
end

local function checkedMask(checks)
  local mask = 0
  for _, c in ipairs(checks) do
    if c:GetChecked() then mask = mask + c.bit end
  end
  return mask
end

local function createDialog()
  dialog = W.Panel("HDFProfDungeonDialog", UIParent, 400, 236)
  dialog:SetFrameStrata("DIALOG")
  dialog:SetToplevel(true)
  dialog:SetPoint("CENTER", 0, 60)
  dialog:Hide()
  tinsert(UISpecialFrames, "HDFProfDungeonDialog")
  local title = W.Text(dialog, "GameFontNormal")
  title:SetPoint("TOP", 0, -18)
  title:SetText("Proponer mazmorra")
  local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  -- Mazmorra: botón con menú desplegable.
  local dLabel = W.Text(dialog, "GameFontNormalSmall")
  dLabel:SetPoint("TOPLEFT", 24, -52)
  dLabel:SetText("Mazmorra")
  dialog.dungeonButton = W.Button(dialog, "", 260, 22)
  dialog.dungeonButton:SetPoint("LEFT", dLabel, "RIGHT", 12, 0)
  dialog.menu = W.Panel(nil, dialog, 290, #D.LIST * 16 + 16)
  dialog.menu:SetFrameStrata("FULLSCREEN_DIALOG")
  dialog.menu:SetPoint("TOPLEFT", dialog.dungeonButton, "BOTTOMLEFT", -4, 0)
  dialog.menu:Hide()
  dialog.menu.buttons = {}
  for i, dg in ipairs(D.LIST) do
    local b = CreateFrame("Button", nil, dialog.menu)
    b:SetSize(270, 16)
    b:SetPoint("TOPLEFT", 10, -8 - (i - 1) * 16)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.text = W.Text(b, "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", 2, 0)
    b.text:SetText(dg.name .. " |cff999999(" .. dg.min .. "-" .. dg.max .. ")|r"
      .. (dg.new and " |cff40c0ffnueva|r" or ""))
    b:SetScript("OnClick", function()
      dialog.menu:Hide()
      dialog:SetDungeon(dg.id)
    end)
    dialog.menu.buttons[i] = b
  end
  dialog.dungeonButton:SetScript("OnClick", function() dialog.menu:SetShown(not dialog.menu:IsShown()) end)
  function dialog:SetDungeon(d)
    self.d = d
    local dg = D.Dungeon(d)
    self.dungeonButton:SetText(dg.name .. " (" .. dg.min .. "-" .. dg.max .. ")")
    local level = D.MyLevel()
    self.levelNote:SetText(level < dg.min and string.format("|cffff4040Tu nivel (%d) no llega al recomendado.|r", level) or "")
  end
  dialog.levelNote = W.Text(dialog, "GameFontHighlightSmall")
  dialog.levelNote:SetPoint("TOPLEFT", 90, -76)

  -- Hora: ahora o en tramos de 15 minutos.
  local hLabel = W.Text(dialog, "GameFontNormalSmall")
  hLabel:SetPoint("TOPLEFT", 24, -102)
  hLabel:SetText("Hora")
  dialog.minus = W.Button(dialog, "-", 24, 22, function() dialog:SetSlot(dialog.slot - 1) end)
  dialog.minus:SetPoint("LEFT", hLabel, "RIGHT", 38, 0)
  dialog.timeText = W.Text(dialog, "GameFontHighlight", "CENTER")
  dialog.timeText:SetWidth(110)
  dialog.timeText:SetPoint("LEFT", dialog.minus, "RIGHT", 4, 0)
  dialog.plus = W.Button(dialog, "+", 24, 22, function() dialog:SetSlot(dialog.slot + 1) end)
  dialog.plus:SetPoint("LEFT", dialog.timeText, "RIGHT", 4, 0)
  -- slot 0 = ahora; 1, 2... = siguiente cuarto de hora, el siguiente...
  function dialog:SlotTime(slot)
    local now = ns.Now()
    if slot <= 0 then return nil end
    local base = (math.floor((now + ns.EPOCH) / 900) + 1) * 900 - ns.EPOCH
    return base + (slot - 1) * 900
  end
  function dialog:SetSlot(slot)
    self.slot = math.max(0, math.min(96, slot))
    local at = self:SlotTime(self.slot)
    self.timeText:SetText(at and ("a las " .. D.Clock(at)) or "Ahora")
    self.minus:SetEnabled(self.slot > 0)
  end

  -- Mis roles (quien propone se apunta a la vez).
  local rLabel = W.Text(dialog, "GameFontNormalSmall")
  rLabel:SetPoint("TOPLEFT", 24, -136)
  rLabel:SetText("Voy de:")
  dialog.checks = roleChecks(dialog, 90, -130)
  local note = W.Text(dialog, "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 24, -160)
  note:SetText("Desmarca todo si solo la organizas y no vas.")

  local publish = W.Button(dialog, "Proponer", 96, 22, function() dialog:Publish() end)
  publish:SetPoint("BOTTOMRIGHT", -22, 18)
  local cancel = W.Button(dialog, "Cancelar", 86, 22, function() dialog:Hide() end)
  cancel:SetPoint("RIGHT", publish, "LEFT", -6, 0)

  function dialog:Publish()
    local r = ns.Sync.CreateRun({ d = self.d, at = self:SlotTime(self.slot), roles = checkedMask(self.checks) })
    if r then
      self:Hide()
      ns.UI.Open("dungeons", r.id)
    end
  end
end

function ns.UI.OpenDungeonDialog()
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  if not dialog then createDialog() end
  dialog:SetDungeon(D.Recommended(D.MyLevel()))
  dialog:SetSlot(0)
  local allowed = D.RolesFor(D.MyClass())
  setupChecks(dialog.checks, D.HasRole(allowed, D.DPS) and D.DPS or allowed)
  dialog.menu:Hide()
  dialog:Show()
end

---------------------------------------------------------------------------
-- Página
---------------------------------------------------------------------------
ns.UI.RegisterPage("dungeons", function(page)
  local state = { id = nil }

  page.propose = W.Button(page, "Proponer mazmorra", 150, 22, function() ns.UI.OpenDungeonDialog() end)
  page.propose:SetPoint("TOPLEFT", 4, -2)
  page.summary = W.Text(page, "GameFontHighlightSmall")
  page.summary:SetPoint("LEFT", page.propose, "RIGHT", 10, 0)

  local list = W.List(page, 250, 388, {
    rows = 8,
    rowHeight = 46,
    keyOf = function(item) return item.r.id end,
    buildRow = function(row)
      row.title = W.Text(row, "GameFontHighlight")
      row.title:SetPoint("TOPLEFT", 4, -4)
      row.title:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row.title:SetWordWrap(false)
      row.sub = W.Text(row, "GameFontHighlightSmall")
      row.sub:SetPoint("TOPLEFT", 4, -20)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row.sub:SetWordWrap(false)
      row.roles = W.Text(row, "GameFontHighlightSmall")
      row.roles:SetPoint("TOPLEFT", 4, -32)
      row.roles:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row.roles:SetWordWrap(false)
    end,
    updateRow = function(row, item)
      local r, now = item.r, item.now
      local dg = D.Dungeon(r.d)
      local title = dg.name
      if item.state ~= "open" then title = "|cff999999" .. title .. "|r" end
      if r.gp then title = title .. "  |cff40ff40(grupo hecho)|r" end
      row.title:SetText(title)
      row.sub:SetText(whenText(r, now) .. " |cff666666·|r " .. ns.ShortName(r.a)
        .. (item.state ~= "open" and (" |cff666666·|r " .. STATE_TEXT[item.state]) or ""))
      local t, h, dps = roleCounts(r)
      local mine = r.s and r.s[item.me] and not r.s[item.me].o
      row.roles:SetText(string.format("|cffbbbbbbTanques %d · Sanadores %d · DPS %d|r%s", t, h, dps,
        mine and "  |cff66ccff(apuntado)|r" or ""))
    end,
    onSelect = function(item)
      state.id = item.r.id
      page:RefreshDetail()
    end,
  })
  list:SetPoint("TOPLEFT", 0, -28)

  local detail = W.Box(page, 350, 388)
  detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
  detail.title = W.Text(detail, "GameFontNormalLarge")
  detail.title:SetPoint("TOPLEFT", 12, -12)
  detail.title:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.title:SetWordWrap(false)
  detail.sub = W.Text(detail, "GameFontHighlightSmall")
  detail.sub:SetPoint("TOPLEFT", 12, -34)
  detail.sub:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.people = W.Text(detail, "GameFontHighlightSmall")
  detail.people:SetPoint("TOPLEFT", 12, -56)
  detail.people:SetWidth(326)
  detail.people:SetJustifyV("TOP")
  detail.people:SetSpacing(2)
  detail.group = W.Text(detail, "GameFontHighlightSmall")
  detail.group:SetPoint("TOPLEFT", 12, -170)
  detail.group:SetWidth(326)
  detail.group:SetJustifyV("TOP")
  detail.group:SetSpacing(2)

  local rolesLabel = W.Text(detail, "GameFontNormalSmall")
  rolesLabel:SetPoint("TOPLEFT", 12, -262)
  rolesLabel:SetText("Me apunto de:")
  detail.rolesLabel = rolesLabel
  detail.checks = roleChecks(detail, 10, -276)
  detail.join = W.Button(detail, "Apuntarme", 110, 22)
  detail.join:SetPoint("TOPLEFT", 12, -304)
  detail.leave = W.Button(detail, "Desapuntarme", 110, 22)
  detail.leave:SetPoint("LEFT", detail.join, "RIGHT", 4, 0)

  detail.make = W.Button(detail, "Hacer grupo", 104, 22)
  detail.make:SetPoint("BOTTOMLEFT", 8, 8)
  detail.invite = W.Button(detail, "Invitar al grupo", 120, 22)
  detail.invite:SetPoint("LEFT", detail.make, "RIGHT", 4, 0)
  detail.cancel = W.Button(detail, "Cancelar", 96, 22)
  detail.cancel:SetPoint("LEFT", detail.invite, "RIGHT", 4, 0)

  detail.empty = W.Text(detail, "GameFontNormal", "CENTER")
  detail.empty:SetPoint("CENTER")
  detail.empty:SetWidth(300)
  detail.empty:SetTextColor(0.7, 0.7, 0.7)

  page.list, page.detail, page.state = list, detail, state

  local function current()
    local all = D.Runs()
    return all and state.id and all[state.id]
  end

  function page:RefreshDetail()
    local r = current()
    local regions = { detail.title, detail.sub, detail.people, detail.group, detail.rolesLabel, detail.join,
      detail.leave, detail.make, detail.invite, detail.cancel }
    for _, region in ipairs(regions) do region:SetShown(r ~= nil) end
    for _, c in ipairs(detail.checks) do c:SetShown(r ~= nil) end
    detail.empty:SetShown(r == nil)
    if not r then
      detail.empty:SetText(#list.items > 0 and "Elige una quedada de la lista."
        or "No hay quedadas. Pulsa \"Proponer mazmorra\" para montar una.")
      return
    end
    local me, now = ns.Me(), ns.Now()
    local dg = D.Dungeon(r.d)
    local st = D.State(r, now)
    local open = st == "open"
    detail.title:SetText(dg.name .. " |cff999999(" .. dg.min .. "-" .. dg.max .. ")|r")
    detail.sub:SetText("Propone " .. ns.ShortName(r.a) .. " · " .. whenText(r, now)
      .. (open and "" or (" · " .. STATE_TEXT[st])))

    -- Apuntados por rol (alguien puede salir en varios).
    local signups = D.SignUps(r)
    local lines = {}
    for _, role in ipairs(D.ROLES) do
      local names = {}
      for _, su in ipairs(signups) do
        if D.HasRole(su.roles, role.bit) then names[#names + 1] = personText(su, dg) end
      end
      lines[#lines + 1] = string.format("|cffffd100%s (%d):|r %s", role.plural, #names,
        #names > 0 and table.concat(names, ", ") or "|cff888888nadie|r")
    end
    local low = 0
    for _, su in ipairs(signups) do if not su.levelOk then low = low + 1 end end
    if low > 0 then
      lines[#lines + 1] = string.format("|cffff4040%d no llega%s al nivel %d.|r", low, low > 1 and "n" or "", dg.min)
    end
    detail.people:SetText(table.concat(lines, "\n"))

    -- Grupo hecho.
    if r.gp then
      local function who(name)
        if not name then return "|cffff4040falta|r" end
        local su = r.s and r.s[name]
        return ns.ColoredName(name, su and su.c)
      end
      local dps = {}
      for i = 1, D.GROUP_SIZE.dps do dps[i] = who(r.gp.d and r.gp.d[i]) end
      local g = {
        "|cff40ff40Grupo:|r",
        "  Tanque: " .. who(r.gp.t),
        "  Sanador: " .. who(r.gp.h),
        "  DPS: " .. table.concat(dps, ", "),
      }
      local bench = {}
      for _, name in ipairs(r.gp.b or {}) do bench[#bench + 1] = ns.ShortName(name) end
      if #bench > 0 then g[#g + 1] = "|cffbbbbbbSuplentes: " .. table.concat(bench, ", ") .. "|r" end
      local place = D.MyPlace(r)
      if place then g[#g + 1] = "|cff66ccffTú vas de " .. place .. ".|r" end
      detail.group:SetText(table.concat(g, "\n"))
    else
      detail.group:SetText(open and "|cffbbbbbbAún no se ha hecho el grupo.|r" or "")
    end

    -- Apuntarme.
    local su = r.s and r.s[me]
    local joined = su and not su.o
    if not page.checksFor or page.checksFor ~= r.id then
      page.checksFor = r.id
      local allowed = D.RolesFor(D.MyClass())
      setupChecks(detail.checks, joined and su.r or (D.HasRole(allowed, D.DPS) and D.DPS or allowed))
    end
    for _, c in ipairs(detail.checks) do
      if not open then c:SetEnabled(false) end
    end
    detail.join:SetText(joined and "Cambiar roles" or "Apuntarme")
    detail.join:SetEnabled(open)
    detail.join:SetScript("OnClick", function() ns.Sync.SignUpRun(r.id, checkedMask(detail.checks)) end)
    detail.leave:SetEnabled(open and joined or false)
    detail.leave:SetScript("OnClick", function() ns.Sync.LeaveRun(r.id) end)

    -- Solo quien la propuso.
    local author = r.a == me
    detail.make:SetShown(author)
    detail.invite:SetShown(author)
    detail.cancel:SetShown(author)
    detail.make:SetEnabled(open and #signups > 0)
    detail.make:SetText(r.gp and "Rehacer grupo" or "Hacer grupo")
    detail.make:SetScript("OnClick", function() ns.Sync.MakeGroup(r.id) end)
    detail.invite:SetEnabled(open and r.gp ~= nil)
    detail.invite:SetScript("OnClick", function()
      local n = D.Invite(r)
      ns.Print("invitaciones enviadas: %d.", n)
    end)
    detail.cancel:SetEnabled(open)
    detail.cancel:SetScript("OnClick", function()
      W.Confirm("¿Cancelar esta quedada?", function() ns.Sync.CancelRun(r.id) end)
    end)
  end

  function page:Refresh()
    local me, now = ns.Me(), ns.Now()
    local items, open = {}, 0
    for _, r in pairs(D.Runs() or {}) do
      local st = D.State(r, now)
      if st == "open" then open = open + 1 end
      items[#items + 1] = { r = r, state = st, me = me, now = now }
    end
    table.sort(items, function(a, b)
      if (a.state == "open") ~= (b.state == "open") then return a.state == "open" end
      if a.r.at ~= b.r.at then
        if a.state == "open" then return a.r.at < b.r.at end
        return a.r.at > b.r.at
      end
      return a.r.id < b.r.id
    end)
    list:SetItems(items)
    if state.id and not (D.Runs() or {})[state.id] then state.id = nil end
    if not state.id and items[1] then state.id = items[1].r.id end
    list.selectedKey = state.id
    list:Refresh()
    page.summary:SetText(string.format("Quedadas abiertas: |cffffffff%d|r", open))
    page:RefreshDetail()
  end

  function page:SelectById(id)
    state.id = id
    page:Refresh()
    list:Select(id)
  end
end)
