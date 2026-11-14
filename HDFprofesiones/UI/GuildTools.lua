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

-- Encender o apagar una casilla de texto (con o sin SetEnabled en este cliente).
local function setEnabled(box, on)
  if box.SetEnabled then box:SetEnabled(on and true or false)
  elseif on then box:Enable() else box:Disable() end
end

-- El número de fila de alguien en la lista del juego, comprobado justo ahora (la lista se
-- reordena cuando alguien se conecta: con el número viejo la nota iría a otro).
local function rosterIndex(name, info)
  info = info or ns.Guild.Info(name)
  if not info or not GetGuildRosterInfo then return nil end
  if info.index and GetGuildRosterInfo(info.index) == info.raw then return info.index end
  for i = 1, (GetNumGuildMembers and GetNumGuildMembers()) or 0 do
    if GetGuildRosterInfo(i) == info.raw then return i end
  end
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
  setEnabled(f.edit, editable)
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
  textWindow.mode = "info"
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
  local num, get = G("GetNumGuildEvents"), G("GetGuildEventInfo")
  if not num or not get then
    openTextWindow("Registro de la hermandad", "Este cliente del juego no deja leer el registro desde el addon: "
      .. "míralo en «Ventana del juego».", false)
    return
  end
  if query then pcall(query) end
  local function fill()
    local lines = {}
    local n = select(2, pcall(num))
    if type(n) ~= "number" then n = 0 end
    for i = n, 1, -1 do
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
    textWindow.mode = "log"
  end
  fill()
  -- el juego lo manda un poco después: se repinta si sigue abierta la del registro
  ns.After(1, function() if textWindow and textWindow:IsShown() and textWindow.mode == "log" then fill() end end)
end

-- Rangos y permisos: la ventana del juego para eso (solo el líder). Nuestra ventana va en una
-- capa más alta que las del juego: la de rangos se abría DETRÁS y no se veía. Ahora se pone
-- delante, en el centro si no tiene sitio, y si aun así no sale, se dice.
function Tools.OpenRanks()
  if not Tools.IsLeader() then
    ns.Print("solo el líder de la hermandad puede cambiar los rangos y permisos.")
    return
  end
  local load = (C_AddOns and C_AddOns.LoadAddOn) or G("LoadAddOn")
  if G("GuildControlUI_LoadUI") then pcall(G("GuildControlUI_LoadUI")) end
  if load then pcall(load, "Blizzard_GuildControlUI") end
  local frame = G("GuildControlUI")
  local popup = G("GuildControlPopupFrame")
  local parent = popup and popup.GetParent and popup:GetParent()
  if not frame and popup and (not parent or parent == UIParent or parent:IsShown()) then frame = popup end
  if not frame then
    ns.Print("este cliente no deja abrir los rangos desde el addon: pulsa «Ventana del juego» y allí, Ajustes de la hermandad.")
    return
  end
  if frame.GetNumPoints and frame:GetNumPoints() == 0 then frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
  if frame.SetFrameStrata then frame:SetFrameStrata("DIALOG") end
  if frame.SetToplevel then frame:SetToplevel(true) end
  frame:Show()
  if frame.Raise then frame:Raise() end
  ns.After(0.3, function()
    if not (frame.IsVisible and frame:IsVisible()) then
      ns.Print("no se ha podido enseñar la ventana de rangos: pulsa «Ventana del juego» y allí, Ajustes de la hermandad.")
    end
  end)
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
  f:SetPoint("CENTER", 0, -90)
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
  f.sub:SetWidth(320)
  f.sub:SetJustifyH("LEFT")
  f.sub:SetWordWrap(false)

  local function noteRow(label, y)
    local t = W.Text(f, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", 20, y)
    t:SetText(label)
    local input = W.Input(f, 250)
    input:SetPoint("TOPLEFT", 20, y - 14)
    input:SetMaxLetters(31)
    local save = W.Button(f, "Guardar", 74, 22)
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
  f.party = W.Button(f, "Invitar al grupo", 140, 22)
  f.party:SetPoint("LEFT", f.tell, "RIGHT", 6, 0)
  f.hint = W.Text(f, "GameFontDisableSmall")
  f.hint:SetPoint("BOTTOMLEFT", 20, 16)
  f.hint:SetWidth(320)
  f.hint:SetJustifyH("LEFT")
  return f
end

-- info: la fila de la lista (para distinguir a dos que se llaman igual de nombre de pila).
function Tools.ShowMember(name, info)
  info = info or ns.Guild.Info(name)
  if not info then return end
  if not card then card = createCard() end
  local f = card
  local game = info.raw or rosterName(name)
  local display = (info.raw and info.raw:match("^([^%-]+)")) or ns.DisplayName(name)
  -- a quién susurrar o invitar: el nombre completo de su fila
  local target = info.raw and (info.raw:match("^([^%-]+)") or info.raw) or name
  if not target:find(ns.SurnameSeparator(), 1, true) then target = name end
  f.name:SetText(display)
  local r, g, b = ns.ClassColor(info.class)
  f.name:SetTextColor(r, g, b)
  f.sub:SetText(string.format("Nivel %s · %s · %s%s", tostring(info.level or "?"), info.className or "",
    info.rankName or "", info.zone and info.zone ~= "" and (" · " .. info.zone) or ""))
  -- Notas
  f.note:SetText(info.note or "")
  local editPublic = Tools.CanEditPublicNote()
  setEnabled(f.note, editPublic)
  f.noteSave:SetShown(editPublic)
  f.noteSave:SetScript("OnClick", function()
    f.note:ClearFocus()
    local index = rosterIndex(name, info)
    if index then call(G("GuildRosterSetPublicNote"), index, f.note:GetText() or "")
    else ns.Print("no encuentro a %s en la lista: vuelve a intentarlo en un momento.", display) end
  end)
  local viewOff = Tools.CanViewOfficerNote()
  f.offLabel:SetShown(viewOff)
  f.offNote:SetShown(viewOff)
  f.offNote:SetText(viewOff and (info.officerNote or "") or "")
  local editOff = viewOff and Tools.CanEditOfficerNote()
  setEnabled(f.offNote, editOff)
  f.offSave:SetShown(editOff)
  f.offSave:SetScript("OnClick", function()
    f.offNote:ClearFocus()
    local index = rosterIndex(name, info)
    if index then call(G("GuildRosterSetOfficerNote"), index, f.offNote:GetText() or "")
    else ns.Print("no encuentro a %s en la lista: vuelve a intentarlo en un momento.", display) end
  end)
  -- Rango
  local myRaw = ns.Guild.Info(ns.Me())
  local me = name == ns.Me() and (not myRaw or myRaw.raw == info.raw)
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
  f.tell:SetScript("OnClick", function() ns.SendTell(target) end)
  f.party:SetEnabled(not me and info.online)
  f.party:SetScript("OnClick", function()
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or G("InviteUnit")
    if invite then pcall(invite, ns.TellName and ns.TellName(target) or game) end
  end)
  f.hint:SetText("Los botones apagados son los que tu rango no puede usar.")
  f:Show()
end
