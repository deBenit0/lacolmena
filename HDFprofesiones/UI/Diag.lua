-- Autocomprobación y informe de errores: para la primera prueba en el juego.
-- "Comprobar el addon" revisa todo lo que depende del cliente (ventanas, botones y funciones
-- del juego) y "Copiar informe" junta eso, la versión y los errores guardados en un texto que
-- se copia con Ctrl+C para mandárselo a quien programa el addon.
local _, ns = ...
local W = ns.W
local Diag = {}
ns.Diag = Diag

local LOGO = "Interface\\AddOns\\HDFprofesiones\\Media\\norrisplay"

-- Cada comprobación devuelve: true (bien), false (falla) o nil (no se puede saber aún), y un texto.
local CHECKS = {
  { "Estás en una hermandad", function()
    if ns.G() then return true, ns.guildName or "" end
    return false, "el addon solo funciona dentro de una hermandad"
  end },
  { "Pestaña en la ventana de hermandad", function()
    local hosts = ns.UI.HostNames()
    if #hosts > 0 then return true, table.concat(hosts, ", ") end
    return nil, "abre la ventana de hermandad (J) y vuelve a comprobar"
  end },
  { "Mensajes entre jugadores", function()
    local ok = C_ChatInfo and C_ChatInfo.SendAddonMessage ~= nil
    if ok and C_ChatInfo.IsAddonMessagePrefixRegistered then
      ok = C_ChatInfo.IsAddonMessagePrefixRegistered(ns.PREFIX) and true or false
    end
    return ok, ok and "listo" or "el juego no deja enviar mensajes de addon"
  end },
  { "Otros con el addon conectados", function()
    local n = 0
    for _ in pairs(ns.Sync.peers) do n = n + 1 end
    if n > 0 then return true, n .. " vistos" end
    return nil, "aún no has visto a nadie más con el addon"
  end },
  { "Ventana de profesión", function()
    if not TradeSkillFrame then return nil, "abre una profesión y vuelve a comprobar" end
    local ok = TradeSkillReagent1 ~= nil and TradeSkillCreateButton ~= nil and GetTradeSkillReagentItemLink ~= nil
    return ok, ok and "materiales y botón Crear encontrados" or "no encuentro las casillas de materiales"
  end },
  { "Botón \"Pedir\" en los materiales", function()
    if not TradeSkillFrame then return nil, "abre una profesión y vuelve a comprobar" end
    local ok = TradeSkillReagent1 and TradeSkillReagent1.hdfHooked
    return ok and true or false, ok and "enganchado" or "no se ha podido enganchar"
  end },
  { "Ventana de encantamiento", function()
    if not CraftFrame then return nil, "si eres encantador, abre Encantamiento y vuelve a comprobar" end
    local ok = CraftReagent1 ~= nil and CraftCreateButton ~= nil
    return ok, ok and "compatible" or "no encuentro las casillas de materiales"
  end },
  { "Correo (se apunta solo al enviar)", function()
    local ok = SendMail ~= nil and GetSendMailItemLink ~= nil and GetSendMailItem ~= nil
    return ok, ok and "compatible" or "no puedo ver lo que se envía"
  end },
  { "Contra reembolso", function()
    if not SendMailNameEditBox then return nil, "abre el buzón y vuelve a comprobar" end
    local ok = (SendMailCODButton ~= nil and SendMailMoney ~= nil and MoneyInputFrame_SetCopper ~= nil)
      or SetSendMailCOD ~= nil
    return ok, ok and "el buzón lo tiene" or "no lo encuentro: la propina habrá que pagarla a mano"
  end },
  { "Invitar al grupo", function()
    local ok = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    return ok ~= nil, ok and "compatible" or "no se puede invitar desde el addon"
  end },
  { "Arrastrar objetos", function()
    local ok = GetCursorInfo ~= nil and ClearCursor ~= nil
    return ok, ok and "compatible" or "no; usa mayús+clic"
  end },
  { "Mayús+clic en objetos", function()
    local ok = ChatEdit_InsertLink ~= nil and GetCurrentKeyBoardFocus ~= nil
    return ok, ok and "compatible" or "no; usa arrastrar"
  end },
  { "Logo de NorrisPlay", function()
    local tex = UIParent:CreateTexture(nil, "BACKGROUND")
    local ok = tex:SetTexture(LOGO)
    tex:Hide()
    if ok == nil then return nil, "este cliente no dice si cargó la imagen: mira el Inicio" end
    return ok and true or false, ok and "cargado" or "no se carga la imagen"
  end },
  { "Hora del servidor", function()
    local ok = GetServerTime ~= nil and date ~= nil
    return ok, ok and (date and date("%H:%M") or "") or "no se puede leer la hora"
  end },
  { "Nivel y clase", function()
    local level = UnitLevel and UnitLevel("player")
    local class
    if UnitClass then class = select(2, UnitClass("player")) end
    local ok = level ~= nil and class ~= nil
    return ok, ok and (tostring(class) .. " " .. tostring(level)) or "no se puede leer"
  end },
  { "Datos de objetos", function()
    local ok = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    return ok ~= nil, ok and "compatible" or "no se pueden clasificar los objetos"
  end },
}

-- Ejecuta todas: lista de { label, status, detail }, y el número de bien, fallos y dudas.
function Diag.Run()
  local results, good, bad, unknown = {}, 0, 0, 0
  for _, check in ipairs(CHECKS) do
    local okCall, status, detail = pcall(check[2])
    if not okCall then status, detail = false, "error: " .. tostring(status) end
    if status == true then good = good + 1 elseif status == false then bad = bad + 1 else unknown = unknown + 1 end
    results[#results + 1] = { label = check[1], status = status, detail = detail or "" }
  end
  return results, good, bad, unknown
end

local function statusTag(status, color)
  if status == true then return color and "|cff40ff40[bien]|r" or "[bien]" end
  if status == false then return color and "|cffff4040[falla]|r" or "[FALLA]" end
  return color and "|cffffd100[?]|r" or "[?]"
end

-- Texto del informe (sin colores, para copiar y pegar).
function Diag.Report()
  local lines = {}
  local build, _, _, iface = "?", nil, nil, "?"
  if GetBuildInfo then build, _, _, iface = GetBuildInfo() end
  lines[#lines + 1] = string.format("%s v%s | juego %s (interfaz %s) | %s", ns.TITLE, ns.VERSION,
    tostring(build), tostring(iface), date and date("%Y-%m-%d %H:%M") or "")
  local class
  if UnitClass then class = select(2, UnitClass("player")) end
  lines[#lines + 1] = string.format("Personaje: %s (%s %s)", ns.Me() or "?", tostring(class),
    tostring(UnitLevel and UnitLevel("player")))
  lines[#lines + 1] = ""
  lines[#lines + 1] = "AUTOCOMPROBACIÓN"
  local results, good, bad, unknown = Diag.Run()
  for _, r in ipairs(results) do
    lines[#lines + 1] = statusTag(r.status) .. " " .. r.label .. ": " .. r.detail
  end
  lines[#lines + 1] = string.format("Total: %d bien, %d fallan, %d sin comprobar", good, bad, unknown)
  lines[#lines + 1] = ""
  local errors = ns.db and ns.db.errors or {}
  lines[#lines + 1] = string.format("ERRORES GUARDADOS (%d)", #errors)
  for i, e in ipairs(errors) do
    local when = (date and e.t and e.t > 0) and date("%d/%m %H:%M", e.t) or "?"
    lines[#lines + 1] = string.format("%d) [%s, v%s, x%d] %s", i, when, tostring(e.v), e.n or 1, tostring(e.m))
    if e.s then
      local n = 0
      for line in tostring(e.s):gmatch("[^\n]+") do
        n = n + 1
        if n <= 4 then lines[#lines + 1] = "     " .. line end
      end
    end
  end
  if #errors == 0 then lines[#lines + 1] = "(ninguno)" end
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Ventana del informe
---------------------------------------------------------------------------
local window

local function createWindow()
  window = W.Panel("HDFProfReport", UIParent, 560, 440)
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:SetPoint("CENTER", 0, 30)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:Hide()
  tinsert(UISpecialFrames, "HDFProfReport")
  window.title = W.Text(window, "GameFontNormal")
  window.title:SetPoint("TOP", 0, -16)
  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  -- Resultado de la autocomprobación, con colores.
  window.checks = W.Text(window, "GameFontHighlightSmall")
  window.checks:SetPoint("TOPLEFT", 22, -40)
  window.checks:SetWidth(516)
  window.checks:SetJustifyV("TOP")
  window.checks:SetSpacing(2)

  -- Informe para copiar.
  window.hint = W.Text(window, "GameFontNormalSmall")
  window.hint:SetPoint("TOPLEFT", 22, -272)
  window.hint:SetText("Informe: pulsa dentro, Ctrl+A y Ctrl+C, y pégalo donde te diga quien programa el addon.")
  local box = W.Box(window, 516, 112)
  box:SetPoint("TOPLEFT", 20, -288)
  local scroll = CreateFrame("ScrollFrame", "HDFProfReportScroll", box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", -26, 6)
  window.edit = CreateFrame("EditBox", nil, scroll)
  window.edit:SetMultiLine(true)
  window.edit:SetAutoFocus(false)
  window.edit:SetFontObject("GameFontHighlightSmall")
  window.edit:SetWidth(470)
  window.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  -- No se puede editar: si se toca, vuelve a poner el informe.
  window.edit:SetScript("OnTextChanged", function(self, userInput)
    if userInput and window.report and self:GetText() ~= window.report then self:SetText(window.report) end
  end)
  window.edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  scroll:SetScrollChild(window.edit)

  window.recheck = W.Button(window, "Comprobar otra vez", 140, 22, function() Diag.Show() end)
  window.recheck:SetPoint("BOTTOMLEFT", 20, 14)
  window.clear = W.Button(window, "Borrar errores", 120, 22, function()
    if ns.db then wipe(ns.db.errors) end
    Diag.Show()
  end)
  window.clear:SetPoint("LEFT", window.recheck, "RIGHT", 6, 0)
  window.select = W.Button(window, "Seleccionar informe", 150, 22, function()
    window.edit:SetFocus()
    window.edit:HighlightText()
  end)
  window.select:SetPoint("BOTTOMRIGHT", -20, 14)
end

function Diag.Show()
  if not window then createWindow() end
  local results, good, bad, unknown = Diag.Run()
  local lines = {}
  for _, r in ipairs(results) do
    lines[#lines + 1] = statusTag(r.status, true) .. " " .. r.label .. ": |cffbbbbbb" .. r.detail .. "|r"
  end
  window.checks:SetText(table.concat(lines, "\n"))
  local errors = ns.db and #ns.db.errors or 0
  window.title:SetText(string.format("Comprobación: %d bien, %d fallan, %d sin comprobar · %d errores guardados",
    good, bad, unknown, errors))
  window.report = Diag.Report()
  window.edit:SetText(window.report)
  window:Show()
  ns.Print("comprobación: %d bien, %d fallan, %d sin comprobar.", good, bad, unknown)
  return good, bad, unknown
end
