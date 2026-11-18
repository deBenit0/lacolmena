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

-- Lo más largo que deja el juego: 128 letras (bytes); se corta sin partir una letra con tilde.
Tools.MOTD_MAX = 128
local function cutUtf8(s, max)
  local out, len = {}, 0
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if len + #ch > max then break end
    out[#out + 1] = ch
    len = len + #ch
  end
  return table.concat(out)
end

-- La macro para cambiarlo: "/gmotd texto" (en una línea; vacío lo borra).
function Tools.MOTDMacro(text)
  text = tostring(text or ""):gsub("[\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  text = cutUtf8(text, Tools.MOTD_MAX)
  local cmd = W.Slash("GUILD_MOTD", "/gmotd")
  return text ~= "" and (cmd .. " " .. text) or cmd
end

-- Las órdenes con nombre: /ginvite, /invite, /gpromote, /gdemote, /gremove.
function Tools.InviteMacro(name) return W.MacroLine("GUILD_INVITE", "/ginvite", name) end
function Tools.PartyMacro(name) return W.MacroLine("INVITE", "/invite", name) end
function Tools.PromoteMacro(name) return W.MacroLine("GUILD_PROMOTE", "/gpromote", name) end
function Tools.DemoteMacro(name) return W.MacroLine("GUILD_DEMOTE", "/gdemote", name) end
function Tools.RemoveMacro(name) return W.MacroLine("GUILD_UNINVITE", "/gremove", name) end
function Tools.LeaveMacro() return W.Slash("GUILD_LEAVE", "/gquit") end

-- La lista se vuelve a pedir cuando ya ha dado tiempo a pulsar Intro.
local function refreshSoon() ns.After(8, function() ns.Guild.RequestRoster() end) end

-- Ventana pequeña con una caja de texto (invitar y mensaje del día). Al aceptar, la orden queda
-- escrita en el chat para que pulses Intro (el juego no deja que la haga el addon).
-- opts: name, title, label, width, maxBytes, button, macro(text), done(text), none, what
local function inputDialog(opts)
  local f = W.Panel(opts.name, UIParent, 400, 130)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetPoint("CENTER", 0, 120)
  f:Hide()
  tinsert(UISpecialFrames, opts.name)
  local close = W.CloseButton(f)
  close:SetPoint("TOPRIGHT", -6, -6)
  f.title = W.Text(f, "GameFontNormal", "CENTER")
  f.title:SetPoint("TOP", 0, -16)
  f.title:SetWidth(360)
  f.title:SetText(opts.title)
  f.edit = W.Input(f, 340)
  f.edit:SetPoint("TOP", 0, -46)
  if opts.maxBytes then f.edit:SetMaxBytes(opts.maxBytes + 1) end
  f.hint = W.Text(f, "GameFontDisableSmall", "CENTER")
  f.hint:SetPoint("TOP", f.edit, "BOTTOM", 0, -6)
  f.hint:SetWidth(360)
  local function accept()
    if not f:IsShown() then return end
    local text = f.edit:GetText() or ""
    local cmd = opts.macro(text)
    if not cmd then
      if opts.none then ns.Print(opts.none) end
      return
    end
    f:Hide()
    W.ChatCommand(cmd, opts.what)
    if opts.done then opts.done(text) end
  end
  f.ok = W.Button(f, opts.button, 110, 22, accept)
  f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14)
  f.cancel = W.Button(f, CANCEL or "Cancelar", 110, 22, function() f:Hide() end)
  f.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14)
  f.edit:SetScript("OnEnterPressed", function() accept() end)
  f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
  return f
end

-- Cambiar el mensaje del día.
local motdWindow
function Tools.EditMOTD()
  if not Tools.CanEditMOTD() then
    ns.Print("tu rango no puede cambiar el mensaje del día.")
    return
  end
  if not motdWindow then
    motdWindow = inputDialog({
      name = "HDFProfMOTD", title = "Mensaje del día de la hermandad:", button = "Guardar",
      maxBytes = Tools.MOTD_MAX,
      macro = function(text) return Tools.MOTDMacro(text) end,
      what = "guardar el mensaje del día",
      done = function() refreshSoon() end,
    })
  end
  motdWindow.edit:SetText(Tools.MOTD())
  motdWindow.hint:SetText("Hasta " .. Tools.MOTD_MAX .. " letras.")
  motdWindow:Show()
  motdWindow.edit:SetFocus()
  return motdWindow
end

-- Invitar a la hermandad: se escribe el nombre del personaje (con apellido si lo tiene).
local inviteWindow
local function cleanName(text)
  return (tostring(text or ""):gsub("[\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s%s+", " "))
end
function Tools.ShowInvite()
  if not inviteWindow then
    inviteWindow = inputDialog({
      name = "HDFProfInvite", title = "¿A quién invitas a la hermandad?", button = "Invitar",
      macro = function(text)
        local name = cleanName(text)
        if name == "" then return nil end
        return Tools.InviteMacro(name)
      end,
      what = "invitar",
      done = function() refreshSoon() end,
      none = "escribe el nombre del personaje.",
    })
  end
  inviteWindow.edit:SetText("")
  inviteWindow.hint:SetText("Nombre del personaje (con apellido si lo tiene).")
  inviteWindow:Show()
  inviteWindow.edit:SetFocus()
  return inviteWindow
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

-- Salir: no hace falta confirmar aparte (hay que pulsar Intro en el chat).
function Tools.Leave()
  W.ChatCommand(Tools.LeaveMacro(), "SALIR de la hermandad (para volver, alguien tendrá que invitarte)")
  refreshSoon()
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
  -- Invitar al grupo: "/invite Nombre" con el botón seguro (f.partyName lo pone ShowMember).
  W.SecureMacro(f.party, function()
    if not f:IsShown() or not f.partyName then return nil end
    return Tools.PartyMacro(f.partyName)
  end, function()
    ns.Print("invitación al grupo enviada a %s.", f.partyName or "?")
  end)
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
  -- Ascender, degradar y expulsar: la orden queda escrita en el chat y pulsas Intro (eso ya
  -- es la confirmación).
  f.promote:SetScript("OnClick", function()
    W.ChatCommand(Tools.PromoteMacro(game), "ascender a " .. display)
    refreshSoon()
  end)
  f.demote:SetEnabled(not me and Tools.CanDemote())
  f.demote:SetScript("OnClick", function()
    W.ChatCommand(Tools.DemoteMacro(game), "degradar a " .. display)
    refreshSoon()
  end)
  f.remove:SetEnabled(not me and Tools.CanRemove())
  f.remove:SetScript("OnClick", function()
    f:Hide()
    W.ChatCommand(Tools.RemoveMacro(game), "EXPULSAR a " .. display .. " de la hermandad")
    refreshSoon()
  end)
  f.tell:SetEnabled(not me)
  f.tell:SetScript("OnClick", function() ns.SendTell(target) end)
  f.party:SetEnabled(not me and info.online)
  f.partyName = not me and (ns.TellName and ns.TellName(target) or game) or nil
  f.hint:SetText("Los botones apagados son los que tu rango no puede usar.")
  f:Show()
end
