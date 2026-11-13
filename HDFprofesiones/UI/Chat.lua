-- Página "Chat": el chat de la hermandad (y el de oficiales, si lo eres) dentro del addon.
-- Se guardan los últimos mensajes para verlos al abrir; abajo se escribe y Intro lo envía.
local _, ns = ...
local W = ns.W

local KEEP = 150 -- mensajes que se recuerdan

local CHANNELS = {
  GUILD = { label = "Hermandad", color = { 0.25, 1, 0.25 } },
  OFFICER = { label = "Oficiales", color = { 0.25, 0.75, 0.25 } },
}

local function log()
  local g = ns.G()
  if not g then return nil end
  g.chat = g.chat or {}
  return g.chat
end

local function amOfficer()
  -- El permiso del juego para ver el chat de oficiales; si no se puede saber, los rangos 0 y 1.
  local can = (C_GuildInfo and C_GuildInfo.CanViewOfficerNote) or CanViewOfficerNote
  if can then
    local ok, yes = pcall(can)
    if ok and yes ~= nil then return yes and true or false end
  end
  local info = ns.Guild and ns.Guild.Info(ns.Me())
  return info and (info.rank or 9) <= 1
end

-- Nombre con su apellido (WoW Forever) y sin el reino.
local function displayName(author)
  if type(author) ~= "string" then return "" end
  local name = author:gsub("%-[^%s]*$", "")
  if not name:find(" ", 1, true) and ns.TellName then
    local full = ns.TellName(ns.FullName and ns.FullName(author) or author)
    if full and full:find(" ", 1, true) then name = full end
  end
  return name
end

local function lineText(m)
  local c = CHANNELS[m.c] or CHANNELS.GUILD
  local time = date and date("%H:%M", m.t) or ""
  local r, g, b = ns.ClassColor(m.k)
  local who = string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
    displayName(m.a))
  local tag = m.c == "OFFICER" and "[Of.] " or ""
  return string.format("|cff888888%s|r |cff%02x%02x%02x%s|r%s: %s", time,
    math.floor(c.color[1] * 255), math.floor(c.color[2] * 255), math.floor(c.color[3] * 255), tag, who, m.m), c.color
end

local page

local function onMessage(channel)
  return function(text, author, ...)
    local l = log()
    if not l or type(text) ~= "string" or text == "" then return end
    local guid = select(10, ...)
    local class
    if guid and GetPlayerInfoByGUID then
      local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
      if ok then class = classFile end
    end
    local m = { c = channel, a = author, k = class, m = text, t = time() }
    l[#l + 1] = m
    while #l > KEEP do table.remove(l, 1) end
    if page and page:IsVisible() and (channel ~= "OFFICER" or amOfficer()) then
      page.messages:AddMessage((lineText(m)), 1, 1, 1)
    end
  end
end
ns.On("CHAT_MSG_GUILD", onMessage("GUILD"))
ns.On("CHAT_MSG_OFFICER", onMessage("OFFICER"))

ns.UI.RegisterPage("chat", function(f)
  page = f
  local channel = "GUILD"

  local box = W.Box(f, 788, 382)
  box:SetPoint("TOPLEFT", 0, 0)
  local messages = CreateFrame("ScrollingMessageFrame", nil, box)
  messages:SetPoint("TOPLEFT", 10, -8)
  messages:SetPoint("BOTTOMRIGHT", -10, 8)
  messages:SetFontObject(ChatFontNormal or GameFontHighlight)
  messages:SetJustifyH("LEFT")
  messages:SetFading(false)
  messages:SetMaxLines(KEEP + 20)
  if messages.SetIndentedWordWrap then messages:SetIndentedWordWrap(true) end
  messages:EnableMouseWheel(true)
  messages:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
  end)
  if messages.SetHyperlinksEnabled then messages:SetHyperlinksEnabled(true) end
  messages:SetScript("OnHyperlinkClick", function(_, link, text, button)
    if SetItemRef then pcall(SetItemRef, link, text, button) end
  end)
  f.messages = messages

  -- Abajo: a qué canal, la caja para escribir y Enviar.
  f.chips = {}
  local function setChannel(c)
    channel = c
    for _, chip in ipairs(f.chips) do chip:SetOn(chip.id == c) end
  end
  local x = 0
  for _, id in ipairs({ "GUILD", "OFFICER" }) do
    local chip = W.Chip(f, CHANNELS[id].label, 92, function() setChannel(id) end)
    chip:SetPoint("BOTTOMLEFT", x, 34)
    chip.id = id
    f.chips[#f.chips + 1] = chip
    x = x + 98
  end
  f.input = W.Input(f, 700)
  f.input:SetPoint("BOTTOMLEFT", 2, 4)
  f.input:SetMaxLetters(255)
  W.Placeholder(f.input, "Escribe a la hermandad y pulsa Intro...")
  local function send()
    local text = f.input:GetText() or ""
    if text:gsub("%s", "") == "" then return end
    local say = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if say then pcall(say, text, channel) end
    f.input:SetText("")
  end
  f.input:SetScript("OnEnterPressed", function(self)
    send()
    self:SetFocus() -- seguir escribiendo
  end)
  f.input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  f.send = W.Button(f, "Enviar", 76, 22, send)
  f.send:SetPoint("LEFT", f.input, "RIGHT", 8, 0)
  setChannel("GUILD")

  -- Al entrar en la página se pinta todo lo guardado; luego llegan los nuevos de uno en uno
  -- (así no salta al final si estás leyendo más arriba).
  local function rebuild()
    local officer = amOfficer()
    -- si estás leyendo más arriba, no se te mueve
    local atBottom = not messages.AtBottom or messages:AtBottom()
    local offset = messages.GetScrollOffset and messages:GetScrollOffset() or 0
    messages:Clear()
    -- Lo que guarda el juego (también lo de antes de conectarte); si no se puede, lo que
    -- ha apuntado el addon.
    local history = ns.ChatLog and ns.ChatLog.History and ns.ChatLog.History(officer)
    if history and #history > 0 then
      for _, m in ipairs(history) do messages:AddMessage((lineText(m)), 1, 1, 1) end
      if atBottom or not messages.SetScrollOffset then
        messages:ScrollToBottom()
      else
        messages:SetScrollOffset(offset)
      end
      return
    end
    for _, m in ipairs(log() or {}) do
      if m.c ~= "OFFICER" or officer then messages:AddMessage((lineText(m)), 1, 1, 1) end
    end
    messages:ScrollToBottom()
  end
  f:SetScript("OnShow", function()
    rebuild()
    -- pedir al juego los mensajes de antes, una vez por sesión (llegan un poco después y se repinta)
    if not f.askedHistory and ns.ChatLog and ns.ChatLog.ReadHistory then
      f.askedHistory = true
      pcall(ns.ChatLog.ReadHistory)
    end
  end)
  ns.Listen("CHAT_HISTORY", function()
    if f:IsVisible() then ns.Coalesce("chatHistory", 0.5, rebuild) end
  end)
  f.showOfficer = amOfficer

  function f:Refresh()
    local officer = amOfficer()
    self.chips[2]:SetShown(officer)
    if not officer and channel == "OFFICER" then setChannel("GUILD") end
  end
end)
