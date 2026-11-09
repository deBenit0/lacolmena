-- Página "Agenda": quedadas de mazmorra (y, más adelante, eventos y raids). Arriba los filtros y
-- la semana; a la izquierda las tarjetas con los 5 huecos por papel; a la derecha, el detalle.
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
-- Tarjeta del grupo hecho (como la de grupos del juego): corona y nombre de quien lo lleva,
-- la mazmorra, el estado y 5 huecos redondos (tanque, sanador y 3 DPS) que se llenan con el
-- icono de la clase de cada uno.
---------------------------------------------------------------------------
local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local SLOT_ROLES = { "Tanque", "Sanador", "DPS", "DPS", "DPS" }

local function makeSlot(card, i)
  local slot = CreateFrame("Button", nil, card)
  slot:SetSize(31, 31)
  slot:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12 - (5 - i) * 33, -14)
  slot.bg = slot:CreateTexture(nil, "BACKGROUND")
  slot.bg:SetSize(20, 20)
  slot.bg:SetPoint("TOPLEFT", 7, -5)
  slot.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  slot.icon = slot:CreateTexture(nil, "ARTWORK")
  slot.icon:SetSize(20, 20)
  slot.icon:SetPoint("TOPLEFT", 7, -5)
  if slot.CreateMaskTexture then
    local mask = slot:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(slot.icon)
    slot.icon:AddMaskTexture(mask)
  end
  slot.ring = slot:CreateTexture(nil, "OVERLAY")
  slot.ring:SetSize(53, 53)
  slot.ring:SetPoint("TOPLEFT")
  slot.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  slot:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if self.name then
      GameTooltip:SetText(ns.ShortName(self.name), ns.ClassColor(self.class))
      local c = self.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[self.class]
      GameTooltip:AddLine(SLOT_ROLES[i] .. (c and (" · " .. c) or ""), 1, 1, 1)
      if self.inParty then GameTooltip:AddLine("Ya está en tu grupo", 0.25, 1, 0.25) end
    else
      GameTooltip:SetText(SLOT_ROLES[i])
      GameTooltip:AddLine("Hueco libre", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
  end)
  slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return slot
end

local function groupCard(parent)
  local card = W.Box(parent, 334, 64)
  if card.SetBackdropColor then
    card:SetBackdropColor(0.12, 0.09, 0.05, 0.95)
    card:SetBackdropBorderColor(0.75, 0.6, 0.25, 1)
  end
  card.crown = card:CreateTexture(nil, "ARTWORK")
  card.crown:SetSize(16, 16)
  card.crown:SetPoint("TOPLEFT", 8, -8)
  card.crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
  card.leader = W.Text(card, "GameFontNormalLarge")
  card.leader:SetPoint("LEFT", card.crown, "RIGHT", 4, 0)
  card.leader:SetWidth(130)
  card.leader:SetWordWrap(false)
  card.leader:SetTextColor(0.3, 0.75, 1)
  card.dungeon = W.Text(card, "GameFontHighlightSmall")
  card.dungeon:SetPoint("TOPLEFT", 28, -28)
  card.dungeon:SetWidth(130)
  card.dungeon:SetWordWrap(false)
  card.dungeon:SetTextColor(0.55, 0.8, 1)
  card.status = W.Text(card, "GameFontHighlightSmall")
  card.status:SetPoint("TOPLEFT", 28, -42)
  card.status:SetWidth(130)
  card.status:SetWordWrap(false)
  card.slots = {}
  for i = 1, 5 do card.slots[i] = makeSlot(card, i) end

  function card:Set(r)
    local D = ns.Dungeons
    local gp = r.gp or {}
    self.leader:SetText(ns.ShortName(r.a))
    self.dungeon:SetText(D.Dungeon(r.d).name)
    local missing = D.Missing(gp)
    if #missing == 0 then
      self.status:SetText("|cff40ff40Grupo completo|r")
    else
      self.status:SetText("|cffffd100Falta: " .. table.concat(missing, ", ") .. "|r")
    end
    local party = {}
    for p = 1, 4 do
      local name = UnitName and UnitName("party" .. p)
      if name then party[ns.ShortName(name):lower()] = true end
    end
    local names = { gp.t or false, gp.h or false }
    for k = 1, D.GROUP_SIZE.dps do names[#names + 1] = gp.d and gp.d[k] or false end
    for i, slot in ipairs(self.slots) do
      local name = names[i] or nil
      local su = name and r.s and r.s[name]
      slot.name = name
      slot.class = su and su.c
      slot.inParty = name and (name == ns.Me() or party[ns.ShortName(name):lower()]) or false
      local coords = slot.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[slot.class]
      if name and coords then
        slot.icon:SetTexture(CLASS_ICONS)
        slot.icon:SetTexCoord(unpack(coords))
      elseif name then
        slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      else
        slot.icon:SetTexture(nil)
      end
      slot.icon:SetShown(name ~= nil)
      slot.icon:SetDesaturated(name ~= nil and not slot.inParty and not (ns.Guild and ns.Guild.IsOnline(name)))
    end
  end
  return card
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

-- Horas fijas al proponer (nil = ahora).
local HOURS = { "now", 18, 20, 21, 22, 23 }

local function createDialog()
  dialog = W.Panel("HDFProfDungeonDialog", UIParent, 400, 290)
  dialog:SetFrameStrata("DIALOG")
  dialog:SetToplevel(true)
  dialog:SetPoint("CENTER", 0, 60)
  dialog:Hide()
  tinsert(UISpecialFrames, "HDFProfDungeonDialog")
  local title = W.Text(dialog, "GameFontNormal")
  title:SetPoint("TOP", 0, -18)
  title:SetText("Proponer quedada")
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

  -- Día (hoy y hasta 2 semanas) y hora: botones de horas fijas y -/+ de 15 en 15 minutos.
  local dayLabel = W.Text(dialog, "GameFontNormalSmall")
  dayLabel:SetPoint("TOPLEFT", 24, -102)
  dayLabel:SetText("Día")
  dialog.dayMinus = W.Button(dialog, "<", 24, 22, function() dialog:SetDay(dialog.day - 1) end)
  dialog.dayMinus:SetPoint("LEFT", dayLabel, "RIGHT", 44, 0)
  dialog.dayText = W.Text(dialog, "GameFontHighlight", "CENTER")
  dialog.dayText:SetWidth(110)
  dialog.dayText:SetPoint("LEFT", dialog.dayMinus, "RIGHT", 4, 0)
  dialog.dayPlus = W.Button(dialog, ">", 24, 22, function() dialog:SetDay(dialog.day + 1) end)
  dialog.dayPlus:SetPoint("LEFT", dialog.dayText, "RIGHT", 4, 0)
  local hLabel = W.Text(dialog, "GameFontNormalSmall")
  hLabel:SetPoint("TOPLEFT", 24, -130)
  hLabel:SetText("Hora")
  dialog.minus = W.Button(dialog, "-", 24, 22, function() dialog:StepTime(-1) end)
  dialog.minus:SetPoint("LEFT", hLabel, "RIGHT", 38, 0)
  dialog.timeText = W.Text(dialog, "GameFontHighlight", "CENTER")
  dialog.timeText:SetWidth(110)
  dialog.timeText:SetPoint("LEFT", dialog.minus, "RIGHT", 4, 0)
  dialog.plus = W.Button(dialog, "+", 24, 22, function() dialog:StepTime(1) end)
  dialog.plus:SetPoint("LEFT", dialog.timeText, "RIGHT", 4, 0)
  dialog.plus:SetScript("OnMouseWheel", nil)
  dialog.hours = {}
  for i, hv in ipairs(HOURS) do
    local h = type(hv) == "number" and hv or nil
    local b = W.Button(dialog, h and (h .. ":00") or "Ahora", 44, 20, function() dialog:SetHour(h) end)
    b:SetPoint("TOPLEFT", 84 + (i - 1) * 46, -152)
    b.hour = h
    dialog.hours[i] = b
  end
  dialog.MAX_DAYS = 13 -- hasta 2 semanas
  -- Medianoche de hoy (hora local) en tiempo del addon.
  local function todayStart()
    local now = ns.Now()
    local ok, t = pcall(date, "*t", now + ns.EPOCH)
    if not ok or type(t) ~= "table" then return now end
    return now - (t.hour * 3600 + t.min * 60 + t.sec)
  end
  -- El primer cuarto de hora que aún no ha pasado hoy (en minutos desde medianoche).
  local function firstFree()
    local now = ns.Now()
    return math.floor((now - todayStart()) / 900 + 1) * 15
  end
  -- minutes = nil: "ahora" (solo hoy).
  function dialog:SlotTime()
    if not self.minutes then return nil end
    return todayStart() + self.day * 86400 + self.minutes * 60
  end
  function dialog:Update()
    self.dayText:SetText(self.day == 0 and "Hoy" or D.DayText(todayStart() + self.day * 86400 + 43200, ns.Now()))
    local at = self:SlotTime()
    self.timeText:SetText(at and ("a las " .. D.Clock(at)) or "Ahora")
    self.dayMinus:SetEnabled(self.day > 0)
    self.dayPlus:SetEnabled(self.day < self.MAX_DAYS)
    self.minus:SetEnabled(self.minutes ~= nil and (self.day > 0 or self.minutes > firstFree() - 15))
    self.plus:SetEnabled(self.minutes == nil or self.minutes < 23 * 60 + 45)
    -- Horas fijas: las que ya han pasado hoy, apagadas; la elegida, encendida.
    for _, b in ipairs(self.hours) do
      local h = b.hour
      b:SetEnabled(h == nil or self.day > 0 or h * 60 >= firstFree())
      local on = (h == nil and self.minutes == nil) or (h ~= nil and self.minutes == h * 60)
      if on then b:LockHighlight() else b:UnlockHighlight() end
    end
  end
  -- h = nil: ahora (solo hoy).
  function dialog:SetHour(h)
    if h == nil then
      self.day, self.minutes = 0, nil
    else
      self.minutes = h * 60
    end
    self:Update()
  end
  function dialog:SetDay(day)
    self.day = math.max(0, math.min(self.MAX_DAYS, day))
    if self.day > 0 and not self.minutes then self.minutes = 21 * 60 end
    if self.day == 0 and self.minutes and self.minutes < firstFree() then self.minutes = nil end
    self:Update()
  end
  function dialog:StepTime(dir)
    if not self.minutes then
      if dir > 0 then self.minutes = firstFree() end
    else
      local m = self.minutes + dir * 15
      if self.day == 0 and m < firstFree() then
        self.minutes = nil
      else
        self.minutes = math.max(0, math.min(23 * 60 + 45, m))
      end
    end
    self:Update()
  end
  -- Compatibilidad con lo de antes: slot 0 = ahora.
  function dialog:SetSlot(slot)
    self.day, self.minutes = 0, nil
    if slot and slot > 0 then self.minutes = firstFree() + (slot - 1) * 15 end
    self:Update()
  end

  -- Mis roles (quien propone se apunta a la vez).
  local rLabel = W.Text(dialog, "GameFontNormalSmall")
  rLabel:SetPoint("TOPLEFT", 24, -192)
  rLabel:SetText("Voy de:")
  dialog.checks = roleChecks(dialog, 90, -186)
  local note = W.Text(dialog, "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 24, -216)
  note:SetText("Desmarca todo si solo la organizas y no vas.")

  dialog.chat = W.Check(dialog, "Avisar en el chat de hermandad")
  dialog.chat:SetPoint("BOTTOMLEFT", 20, 16)
  local publish = W.Button(dialog, "Proponer", 96, 22, function() dialog:Publish() end)
  publish:SetPoint("BOTTOMRIGHT", -22, 18)
  local cancel = W.Button(dialog, "Cancelar", 86, 22, function() dialog:Hide() end)
  cancel:SetPoint("RIGHT", publish, "LEFT", -6, 0)
  cancel:Hide() -- con la casilla del chat no cabe: se cierra con la X o con Esc

  function dialog:Publish()
    local r = ns.Sync.CreateRun({ d = self.d, at = self:SlotTime(), roles = checkedMask(self.checks) })
    if r then
      self:Hide()
      if self.chat:GetChecked() then ns.Extras.Announce("run", r, r.id) end
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
  dialog.chat:SetChecked(true)
  local allowed = D.RolesFor(D.MyClass())
  setupChecks(dialog.checks, D.HasRole(allowed, D.DPS) and D.DPS or allowed)
  dialog.menu:Hide()
  dialog:Show()
end

---------------------------------------------------------------------------
-- Página
---------------------------------------------------------------------------
local ROLE_ICONS = {
  "Interface\\Icons\\Ability_Defend", "Interface\\Icons\\Spell_Holy_FlashHeal", "Interface\\Icons\\INV_Sword_04",
}
local KINDS = {
  { id = "all", label = "Todo" },
  { id = "dungeons", label = "Mazmorras" },
  { id = "events", label = "Eventos · pronto", soon = true },
  { id = "raids", label = "Raids · pronto", soon = true },
}

-- Lo que le falta a una quedada: con el grupo hecho, lo que no se ha cubierto; antes, los
-- papeles que nadie de los apuntados puede hacer.
local function missingText(r)
  if r.gp then
    local m = D.Missing(r.gp)
    return #m == 0 and "|cff40ff40grupo hecho|r" or ("|cffffd100falta " .. table.concat(m, ", "):lower() .. "|r")
  end
  local t, h, dps = roleCounts(r)
  local need = {}
  if t == 0 then need[#need + 1] = "tanque" end
  if h == 0 then need[#need + 1] = "sanador" end
  if dps < D.GROUP_SIZE.dps then need[#need + 1] = (D.GROUP_SIZE.dps - dps) .. " de daño" end
  if #need == 0 then return "|cff40ff40hay gente para el grupo|r" end
  return "|cffffd100falta " .. table.concat(need, ", ") .. "|r"
end

-- Los 5 huecos de una tarjeta: icono del papel; con el grupo hecho, la clase de quien va.
-- Antes de hacerlo se encienden los papeles que alguien de los apuntados puede cubrir.
local function fillSlots(slots, r)
  local gp = r.gp
  local t, h, dps = roleCounts(r)
  local names = gp and { gp.t or false, gp.h or false, gp.d and gp.d[1] or false, gp.d and gp.d[2] or false,
    gp.d and gp.d[3] or false } or {}
  for i, slot in ipairs(slots) do
    local role = i == 1 and 1 or i == 2 and 2 or 3
    local name = names[i]
    local su = name and r.s and r.s[name]
    local coords = su and su.c and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[su.c]
    if coords then
      slot.icon:SetTexture(CLASS_ICONS)
      slot.icon:SetTexCoord(unpack(coords))
      slot.icon:SetDesaturated(false)
      slot.icon:SetAlpha(1)
    else
      slot.icon:SetTexture(ROLE_ICONS[role])
      slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      local covered = (role == 1 and t > 0) or (role == 2 and h > 0) or (role == 3 and dps >= i - 2)
      if gp then covered = name and true or false end
      slot.icon:SetDesaturated(not covered)
      slot.icon:SetAlpha(covered and 1 or 0.35)
    end
  end
end

-- Cuántos días han pasado esta semana desde el lunes (lunes = 0, domingo = 6).
local function weekdayOffset(now)
  local ok, t = pcall(date, "*t", now + ns.EPOCH)
  if not ok or type(t) ~= "table" then return 0 end
  return (t.wday + 5) % 7
end
local MAX_WEEK = 2 -- esta semana y las dos siguientes (para llegar a 2 semanas desde hoy)

ns.UI.RegisterPage("dungeons", function(page)
  local state = { id = nil, kind = "all", day = nil, week = 0 }

  -- Fila 1: tipos (eventos y raids, más adelante) y proponer.
  page.kinds = {}
  for i, k in ipairs(KINDS) do
    local b = W.Chip(page, k.label, k.soon and 124 or 96, function()
      state.kind = k.id
      page:Refresh()
    end)
    if i == 1 then b:SetPoint("TOPLEFT", 0, -2) else b:SetPoint("LEFT", page.kinds[i - 1], "RIGHT", 2, 0) end
    if k.soon then
      b:Disable()
      if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
      ns.UI.Tip(b, (k.label:gsub(" · pronto", "")), "Próximamente: entrarán aquí, en la misma Agenda.")
    end
    page.kinds[i] = b
  end
  page.propose = W.Button(page, "+ Proponer quedada", 160, 24, function() ns.UI.OpenDungeonDialog() end)
  page.propose:SetPoint("TOPRIGHT", 0, 0)

  -- Fila 2: la semana. Cada día con sus quedadas (puntos); al pulsarlo se ven solo las suyas.
  page.days = {}
  local ARROW_W = 20
  local DAY_W = (430 - 2 * (ARROW_W + 4) - 6 * 4) / 7
  page.prevWeek = W.Button(page, "<", ARROW_W, 40, function()
    state.week = math.max(0, state.week - 1)
    state.day, state.id = nil, nil
    page:Refresh()
  end)
  page.prevWeek:SetPoint("TOPLEFT", 0, -30)
  ns.UI.Tip(page.prevWeek, "Semana anterior")
  page.nextWeek = W.Button(page, ">", ARROW_W, 40, function()
    state.week = math.min(MAX_WEEK, state.week + 1)
    state.day, state.id = nil, nil
    page:Refresh()
  end)
  page.nextWeek:SetPoint("TOPLEFT", ARROW_W + 4 + 7 * DAY_W + 6 * 4 + 4, -30)
  ns.UI.Tip(page.nextWeek, "Semana siguiente", "Se pueden proponer quedadas hasta 2 semanas antes.")
  for i = 1, 7 do
    local b = CreateFrame("Button", nil, page, BackdropTemplateMixin and "BackdropTemplate" or nil)
    b:SetSize(DAY_W, 40)
    b:SetPoint("TOPLEFT", ARROW_W + 4 + (i - 1) * (DAY_W + 4), -30)
    if b.SetBackdrop then
      b:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      b:SetBackdropColor(0, 0, 0, 0.5)
    end
    b.name = W.Text(b, "GameFontHighlightSmall", "CENTER")
    b.name:SetPoint("TOP", 0, -5)
    b.num = W.Text(b, "GameFontNormal", "CENTER")
    b.num:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
    b.dots = W.Text(b, "GameFontNormalSmall", "CENTER")
    b.dots:SetPoint("BOTTOM", 0, 3)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnClick", function(self)
      state.day = (state.day ~= self.dayNumber) and self.dayNumber or nil
      state.id = nil
      page:Refresh()
    end)
    page.days[i] = b
  end

  -- Tarjetas de las quedadas.
  local list = W.List(page, 430, 368, {
    rows = 5,
    rowHeight = 70,
    keyOf = function(item) return item.r.id end,
    buildRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(40, 40)
      row.icon:SetPoint("LEFT", 4, 0)
      row.icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
      row.title = W.ListText(row, "GameFontHighlight")
      row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 4)
      row.title:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row.title:SetWordWrap(false)
      row.when = W.ListText(row, "GameFontNormalSmall")
      row.when:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
      row.when:SetPoint("RIGHT", row, "RIGHT", -172, 0)
      row.when:SetWordWrap(false)
      row.sub = W.ListText(row, "GameFontHighlightSmall")
      row.sub:SetPoint("TOPLEFT", row.when, "BOTTOMLEFT", 0, -3)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -172, 0)
      row.sub:SetWordWrap(false)
      row.slots = {}
      for i = 1, 5 do
        local slot = CreateFrame("Frame", nil, row)
        slot:SetSize(28, 28)
        slot:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4 - (5 - i) * 32, 6)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints()
        if slot.CreateMaskTexture then
          local mask = slot:CreateMaskTexture()
          mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
          mask:SetAllPoints(slot.icon)
          slot.icon:AddMaskTexture(mask)
        end
        row.slots[i] = slot
      end
    end,
    updateRow = function(row, item)
      local r, now = item.r, item.now
      local dg = D.Dungeon(r.d)
      row.icon:SetTexture(D.Icon(item.r.d))
      row.title:SetText(dg.name .. " |cff999999(" .. dg.min .. "-" .. dg.max .. ")|r")
      local when = r.at <= now + 120 and (now > r.at + 120 and ("desde las " .. D.Clock(r.at)) or "ahora")
        or (D.DayText(r.at, now) .. " · " .. D.Clock(r.at))
      row.when:SetText(when)
      local mine = r.s and r.s[item.me] and not r.s[item.me].o
      row.sub:SetText("propone " .. ns.WhoColored(r.a) .. " · " .. missingText(r)
        .. (mine and "  |cff66ccff(vas)|r" or ""))
      fillSlots(row.slots, r)
    end,
    onSelect = function(item)
      state.id = item.r.id
      page:RefreshDetail()
    end,
  })
  list:SetPoint("TOPLEFT", 0, -76)
  page.empty = W.Text(page, "GameFontNormal", "CENTER")
  page.empty:SetPoint("CENTER", list, "CENTER", 0, 20)
  page.empty:SetWidth(380)
  page.empty:SetTextColor(0.7, 0.7, 0.7)
  page.emptyButton = W.Button(page, "+ Proponer quedada", 160, 24, function() ns.UI.OpenDungeonDialog() end)
  page.emptyButton:SetPoint("TOP", page.empty, "BOTTOM", 0, -12)

  local detail = W.Box(page, 350, 414)
  detail:SetPoint("TOPLEFT", page, "TOPLEFT", 438, -30)
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
  detail.card = groupCard(detail)
  detail.card:SetPoint("TOPLEFT", 8, -162)

  detail.done = W.Button(detail, "HECHO", 84, 22)
  detail.done:SetPoint("TOPRIGHT", -10, -304)
  detail.done:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("HECHO")
    GameTooltip:AddLine("Ya habéis ido: cierra la quedada para todos.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  detail.done:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
    detail.card:SetShown(r ~= nil and r.gp ~= nil)
    detail.done:SetShown(r ~= nil and r.gp ~= nil and r.a == ns.Me())
    detail.empty:SetShown(r == nil)
    if not r then
      detail.empty:SetText(#list.items > 0 and "Pulsa una quedada para ver el detalle." or "")
      return
    end
    local me, now = ns.Me(), ns.Now()
    local dg = D.Dungeon(r.d)
    local st = D.State(r, now)
    local open = st == "open"
    detail.title:SetText(dg.name .. " |cff999999(" .. dg.min .. "-" .. dg.max .. ")|r")
    detail.sub:SetText("Propone " .. ns.WhoColored(r.a) .. " · " .. D.DayText(r.at, now) .. " · " .. whenText(r, now)
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

    -- Grupo hecho: la tarjeta con los 5 huecos y, debajo, suplentes y mi sitio.
    detail.group:ClearAllPoints()
    if r.gp then
      detail.card:Set(r)
      detail.group:SetPoint("TOPLEFT", 12, -230)
      local g = {}
      local bench = {}
      for _, name in ipairs(r.gp.b or {}) do bench[#bench + 1] = ns.ShortName(name) end
      -- En una sola línea: con muchos suplentes se pisaría con «Me apunto de».
      local more = #bench > 4 and (" y " .. (#bench - 4) .. " más") or ""
      for i = #bench, 5, -1 do bench[i] = nil end
      if #bench > 0 then g[#g + 1] = "|cffbbbbbbSuplentes: " .. table.concat(bench, ", ") .. more .. "|r" end
      local place = D.MyPlace(r)
      if place then g[#g + 1] = "|cff66ccffTú vas de " .. place .. ".|r" end
      detail.group:SetText(table.concat(g, "\n"))
    else
      detail.group:SetPoint("TOPLEFT", 12, -170)
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
    detail.done:SetEnabled(open)
    detail.done:SetScript("OnClick", function()
      W.Confirm("¿Ya habéis hecho la mazmorra? La quedada se cierra para todos.", function()
        ns.Sync.FinishRun(r.id)
      end)
    end)
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
    for i, k in ipairs(KINDS) do
      if not k.soon then page.kinds[i]:SetOn(state.kind == k.id) end
    end
    -- La semana: de lunes a domingo (0 = esta, 1 = la siguiente...), con un punto por quedada.
    local today = D.DayNumber(now)
    local offset = weekdayOffset(now)
    local perDay = {}
    local items = {}
    for _, r in pairs(D.Runs() or {}) do
      if D.State(r, now) == "open" then
        local day = math.max(today, D.DayNumber(r.at))
        perDay[day] = (perDay[day] or 0) + 1
        if not state.day or state.day == day then
          items[#items + 1] = { r = r, state = "open", me = me, now = now }
        end
      end
    end
    for i, b in ipairs(page.days) do
      local delta = (i - 1) - offset + 7 * state.week -- días desde hoy
      local at = now + delta * 86400
      local day = D.DayNumber(at)
      b.dayNumber = day
      local ok, t = pcall(date, "*t", at + ns.EPOCH)
      ok = ok and type(t) == "table"
      b.name:SetText(delta == 0 and "Hoy" or (ok and D.WEEKDAYS[t.wday] or ""))
      b.num:SetText(ok and tostring(t.day) or "")
      -- Los días que ya han pasado o que quedan lejos (más de 2 semanas), en gris.
      local usable = delta >= 0 and delta <= 13
      b:SetEnabled(usable)
      b:SetAlpha(usable and 1 or 0.4)
      local n = perDay[day] or 0
      b.dots:SetText(n > 0 and ("|cff40ff40" .. string.rep("•", math.min(n, 4)) .. "|r") or "")
      if b.SetBackdropBorderColor then
        if state.day == day then b:SetBackdropBorderColor(1, 0.82, 0, 1) else b:SetBackdropBorderColor(0.4, 0.35, 0.25, 1) end
      end
    end
    page.prevWeek:SetEnabled(state.week > 0)
    page.nextWeek:SetEnabled(state.week < MAX_WEEK)
    table.sort(items, function(x, y)
      if x.r.at ~= y.r.at then return x.r.at < y.r.at end
      return x.r.id < y.r.id
    end)
    list:SetItems(items)
    local found = false
    for _, it in ipairs(items) do if it.r.id == state.id then found = true end end
    if not found then state.id = items[1] and items[1].r.id or nil end
    list.selectedKey = state.id
    list:Refresh()
    local none = #items == 0
    page.empty:SetShown(none)
    page.emptyButton:SetShown(none)
    page.empty:SetText(state.day and "No hay quedadas ese día." or "No hay quedadas. ¡Propón una!")
    page:RefreshDetail()
  end

  -- Abre la Agenda en el día de una quedada (desde Inicio).
  function page:SelectDay(at)
    local now = ns.Now()
    state.day = D.DayNumber(math.max(at, now))
    state.week = math.max(0, math.min(MAX_WEEK,
      math.floor((state.day - D.DayNumber(now) + weekdayOffset(now)) / 7)))
    state.id = nil
    page:Refresh()
  end

  function page:SelectById(id)
    state.id = id
    state.day = nil
    page:Refresh()
    list:Select(id)
  end
end)
