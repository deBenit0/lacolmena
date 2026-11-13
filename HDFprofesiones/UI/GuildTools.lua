-- Lo que antes solo estaba en la ventana de hermandad del juego, dentro del addon:
--   · ficha de cada miembro: nota pública y de oficial (verlas y cambiarlas), ascender, degradar,
--     expulsar, susurrar e invitar al grupo;
--   · mensaje del día, información de la hermandad, registro (quién entró, ascensos...),
--     rangos y permisos (la ventana del juego para eso) y salir de la hermandad.
-- Cada botón solo se enciende si tu rango tiene permiso para eso.
local _, ns = ...
local W = ns.W
local Tools = {}
ns.GuildTools = Tools

local function can(fn, ...)
  if type(fn) ~= "function" then return false end
  local ok, yes = pcall(fn, ...)
  return ok and yes and true or false
end
local function G(name) return _G[name] end

function Tools.CanViewOfficerNote()
  return can(C_GuildInfo and C_GuildInfo.CanViewOfficerNote) or can(G("CanViewOfficerNote"))
end
function Tools.CanEditPublicNote()
  return can(C_GuildInfo and C_GuildInfo.CanEditPublicNote) or can(G("CanEditPublicNote"))
end
function Tools.CanEditOfficerNote()
  return can(C_GuildInfo and C_GuildInfo.CanEditOfficerNote) or can(G("CanEditOfficerNote"))
end
function Tools.CanPromote() return can(G("CanGuildPromote")) end
function Tools.CanDemote() return can(G("CanGuildDemote")) end
function Tools.CanRemove() return can(G("CanGuildRemove")) end
function Tools.CanEditMOTD() return can(G("CanEditMOTD")) end
function Tools.CanEditInfo() return can(G("CanEditGuildInfo")) end
function Tools.IsLeader() return can(G("IsGuildLeader")) end

-- El nombre que entiende el juego para ese miembro (como sale en su lista).
local function rosterName(name)
  local info = ns.Guild.Info(name)
  return info and info.raw or ns.ShortName(name)
end

local function call(fn, ...)
  if type(fn) ~= "function" then
    ns.Print("este cliente del juego no deja hacer eso desde el addon: usa «Ventana del juego».")
    return false
  end
  local ok, err = pcall(fn, ...)
  if not ok then ns.Print("no se ha podido: %s", tostring(err)) end
  ns.After(1, function() ns.Guild.RequestRoster() end)
  return ok
end

---------------------------------------------------------------------------
-- Mensaje del día
---------------------------------------------------------------------------
function Tools.MOTD()
  local fn = G("GetGuildRosterMOTD")
  local ok, text = pcall(fn or function() return "" end)
  return ok and text or ""
end

function Tools.SetMOTD(text)
  local fn = (C_GuildInfo and C_GuildInfo.SetMOTD) or G("GuildSetMOTD")
  return call(fn, (text or ""):sub(1, 128))
end

---------------------------------------------------------------------------
-- Ventana con texto largo (información de la hermandad y registro)
---------------------------------------------------------------------------
local textWindow
local function openTextWindow(title, text, editable, onSave)
  if not textWindow then
    local f = W.Panel("HDFProfGuildText", UIParent, 460, 380)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetPoint("CENTER", 0, 40)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "HDFProfGuildText")
    f.title = W.Text(f, "GameFontNormal")
    f.title:SetPoint("TOP", 0, -16)
    local close = W.CloseButton(f)
    close:SetPoint("TOPRIGHT", -6, -6)
    local scroll = CreateFrame("ScrollFrame", "HDFProfGuildTextScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -44)
    scroll:SetPoint("BOTTOMRIGHT", -36, 48)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal or GameFontHighlight)
    edit:SetWidth(400)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)
    f.edit = edit
    f.save = W.Button(f, "Guardar", 96, 22, function()
      if f.onSave then f.onSave(f.edit:GetText() or "") end
      f:Hide()
    end)
    f.save:SetPoint("BOTTOMRIGHT", -18, 16)
    textWindow = f
  end
  local f = textWindow
  f.title:SetText(title)
  f.edit:SetText(text or "")
  f.edit:SetEnabled(editable and true or false)
  f.edit:SetCursorPosition(0)
  f.onSave = onSave
  f.save:SetShown(editable and true or false)
  f:Show()
end

function Tools.ShowInfo()
  local get = G("GetGuildInfoText")
  local ok, text = pcall(get or function() return "" end)
  local editable = Tools.CanEditInfo()
  openTextWindow("Información de la hermandad", ok and text or "", editable, function(newText)
    call(G("SetGuildInfoText"), newText)
  end)
end

-- Registro de la hermandad: quién entró, salió, fue ascendido...
local EVENT_TEXT = {
  invite = "%s invitó a %s",
  join = "%s entró en la hermandad",
  promote = "%s ascendió a %s a %s",
  demote = "%s degradó a %s a %s",
  remove = "%s expulsó a %s",
  quit = "%s dejó la hermandad",
}
function Tools.ShowLog()
  local query = G("QueryGuildEventLog")
  if query then pcall(query) end
  local function fill()
    local num = G("GetNumGuildEvents")
    local get = G("GetGuildEventInfo")
    local lines = {}
    local n = num and select(2, pcall(num)) or 0
    if type(n) ~= "number" then n = 0 end
    for i = n, math.max(1, n - 99), -1 do
      local ok, kind, p1, p2, rank, year, month, day, hour = pcall(get, i)
      if ok and kind then
        local fmt = EVENT_TEXT[kind] or (kind .. ": %s %s")
        local text = string.format(fmt, p1 or "?", p2 or "?", rank or "?")
        local ago = {}
        if (year or 0) > 0 then ago[#ago + 1] = year .. " a" end
        if (month or 0) > 0 then ago[#ago + 1] = month .. " m" end
        if (day or 0) > 0 then ago[#ago + 1] = day .. " d" end
        if (hour or 0) > 0 then ago[#ago + 1] = hour .. " h" end
        lines[#lines + 1] = text .. "  |cff888888(hace " .. (#ago > 0 and table.concat(ago, " ") or "un momento") .. ")|r"
      end
    end
    openTextWindow("Registro de la hermandad", #lines > 0 and table.concat(lines, "\n")
      or "Aún no ha llegado el registro: vuelve a pulsar en un momento.", false)
  end
  fill()
  ns.After(1, function() if textWindow and textWindow:IsShown() then fill() end end)
end

-- Rangos y permisos: la ventana del juego para eso (solo el líder).
function Tools.OpenRanks()
  if LoadAddOn then pcall(LoadAddOn, "Blizzard_GuildControlUI") end
  local frame = G("GuildControlUI") or G("GuildControlPopupFrame")
  if frame then
    frame:Show()
  else
    ns.Print("abre «Ventana del juego» y allí, Ajustes de la hermandad: este cliente no deja abrirlo desde el addon.")
  end
end

function Tools.Leave()
  W.Confirm("¿Seguro que quieres SALIR de la hermandad? Para volver, alguien tendrá que invitarte.", function()
    call(G("GuildLeave"))
  end)
end

---------------------------------------------------------------------------
-- Ficha de un miembro
---------------------------------------------------------------------------
local card
local function createCard()
  local f = W.Panel("HDFProfMemberCard", UIParent, 360, 300)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetPoint("CENTER", 0, 40)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "HDFProfMemberCard")
  local close = W.CloseButton(f)
  close:SetPoint("TOPRIGHT", -6, -6)
  f.name = W.Text(f, "GameFontNormalLarge")
  f.name:SetPoint("TOPLEFT", 20, -18)
  f.sub = W.Text(f, "GameFontHighlightSmall")
  f.sub:SetPoint("TOPLEFT", 20, -42)

  local function noteRow(label, y)
    local t = W.Text(f, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", 20, y)
    t:SetText(label)
    local input = W.Input(f, 250)
    input:SetPoint("TOPLEFT", 20, y - 14)
    input:SetMaxLetters(31)
    local save = W.Button(f, "Guardar", 60, 22)
    save:SetPoint("LEFT", input, "RIGHT", 6, 0)
    return t, input, save
  end
  f.noteLabel, f.note, f.noteSave = noteRow("Nota pública", -66)
  f.offLabel, f.offNote, f.offSave = noteRow("Nota de oficial", -112)

  f.promote = W.Button(f, "Ascender", 100, 22)
  f.promote:SetPoint("TOPLEFT", 20, -168)
  f.demote = W.Button(f, "Degradar", 100, 22)
  f.demote:SetPoint("LEFT", f.promote, "RIGHT", 6, 0)
  f.remove = W.Button(f, "Expulsar", 100, 22)
  f.remove:SetPoint("LEFT", f.demote, "RIGHT", 6, 0)
  f.tell = W.Button(f, "Susurrar", 100, 22)
  f.tell:SetPoint("TOPLEFT", 20, -200)
  f.party = W.Button(f, "Invitar al grupo", 120, 22)
  f.party:SetPoint("LEFT", f.tell, "RIGHT", 6, 0)
  f.hint = W.Text(f, "GameFontDisableSmall")
  f.hint:SetPoint("BOTTOMLEFT", 20, 16)
  f.hint:SetWidth(320)
  f.hint:SetJustifyH("LEFT")
  return f
end

function Tools.ShowMember(name)
  local info = ns.Guild.Info(name)
  if not info then return end
  if not card then card = createCard() end
  local f = card
  local game = rosterName(name)
  local display = (info.raw and info.raw:match("^([^%-]+)")) or ns.ShortName(name)
  f.name:SetText(display)
  local r, g, b = ns.ClassColor(info.class)
  f.name:SetTextColor(r, g, b)
  f.sub:SetText(string.format("Nivel %s · %s · %s%s", tostring(info.level or "?"), info.className or "",
    info.rankName or "", info.zone and info.zone ~= "" and (" · " .. info.zone) or ""))
  -- Notas
  f.note:SetText(info.note or "")
  local editPublic = Tools.CanEditPublicNote()
  f.note:SetEnabled(editPublic)
  f.noteSave:SetShown(editPublic)
  f.noteSave:SetScript("OnClick", function()
    f.note:ClearFocus()
    local cur = ns.Guild.Info(name)
    if cur and cur.index then call(G("GuildRosterSetPublicNote"), cur.index, f.note:GetText() or "") end
  end)
  local viewOff = Tools.CanViewOfficerNote()
  f.offLabel:SetShown(viewOff)
  f.offNote:SetShown(viewOff)
  f.offNote:SetText(viewOff and (info.officerNote or "") or "")
  local editOff = viewOff and Tools.CanEditOfficerNote()
  f.offNote:SetEnabled(editOff)
  f.offSave:SetShown(editOff)
  f.offSave:SetScript("OnClick", function()
    f.offNote:ClearFocus()
    local cur = ns.Guild.Info(name)
    if cur and cur.index then call(G("GuildRosterSetOfficerNote"), cur.index, f.offNote:GetText() or "") end
  end)
  -- Rango
  local me = name == ns.Me()
  f.promote:SetEnabled(not me and Tools.CanPromote())
  f.promote:SetScript("OnClick", function()
    W.Confirm("¿Ascender a " .. display .. "?", function() call((C_GuildInfo and C_GuildInfo.Promote) or G("GuildPromote"), game) end)
  end)
  f.demote:SetEnabled(not me and Tools.CanDemote())
  f.demote:SetScript("OnClick", function()
    W.Confirm("¿Degradar a " .. display .. "?", function() call((C_GuildInfo and C_GuildInfo.Demote) or G("GuildDemote"), game) end)
  end)
  f.remove:SetEnabled(not me and Tools.CanRemove())
  f.remove:SetScript("OnClick", function()
    W.Confirm("¿EXPULSAR a " .. display .. " de la hermandad?", function()
      call((C_GuildInfo and C_GuildInfo.Uninvite) or G("GuildUninvite"), game)
      f:Hide()
    end)
  end)
  f.tell:SetEnabled(not me)
  f.tell:SetScript("OnClick", function() ns.SendTell(name) end)
  f.party:SetEnabled(not me and info.online)
  f.party:SetScript("OnClick", function()
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or G("InviteUnit")
    if invite then pcall(invite, ns.TellName and ns.TellName(name) or game) end
  end)
  f.hint:SetText("Los botones apagados son los que tu rango no puede usar.")
  f:Show()
end
