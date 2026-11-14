-- Envío y recepción de mensajes ocultos del addon por el canal de hermandad.
-- Los mensajes largos se trocean; la cola respeta un ritmo prudente para no
-- chocar con los límites del servidor.
local _, ns = ...
local Codec = ns.Codec
local Comm = {}
ns.Comm = Comm

local MAX_LEN = 250   -- el juego admite 255 bytes por mensaje
local BUCKET_CAP = 8  -- ráfaga máxima
local BUCKET_RATE = 1 -- mensajes por segundo de media
local INBOX_TTL = 120 -- segundos que esperamos a que llegue un mensaje troceado
local MAX_PIECES = 400 -- trozos de un mensaje (unos 100 KB): más es que algo va mal
local MAX_OPEN_BOXES = 30 -- mensajes a medias de una misma persona
local RELAY_GAP_MIN, RELAY_GAP_MAX = 0.5, 2 -- espera entre reenvíos de datos ajenos
local nextRelayAt = 0

local queues = { {}, {} } -- [1] prioridad alta (control), [2] normal (datos)
local tokens = BUCKET_CAP
local lastPump
local counter = 0
local inbox = {}
local handlers = {}
Comm.stats = { sent = 0, received = 0 }

local THROTTLED, LOCKDOWN = {}, {}
if Enum and Enum.SendAddonMessageResult then
  local result = Enum.SendAddonMessageResult
  if result.AddonMessageThrottle then THROTTLED[result.AddonMessageThrottle] = true end
  if result.ChannelThrottle then THROTTLED[result.ChannelThrottle] = true end
  -- Cliente moderno (Forever): el juego bloquea un rato los mensajes de addons (p. ej. en
  -- algunos combates). No es un fallo del mensaje: hay que esperar y volver a intentarlo.
  if result.AddOnMessageLockdown then LOCKDOWN[result.AddOnMessageLockdown] = true end
end
Comm.LOCKDOWN_WAIT = 10
local pausedUntil = 0

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
  C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)
end

-- Registra la función que atiende un tipo de mensaje (una letra).
function Comm.Register(msgType, fn)
  handlers[msgType] = fn
end

-- Función que mira el principio de un mensaje troceado en cuanto llega su primer trozo.
local peekers = {}
function Comm.RegisterPeek(msgType, fn)
  peekers[msgType] = fn
end

function Comm.Pending()
  return #queues[1] + #queues[2]
end

-- Punto de corte que no parte un carácter UTF-8 por la mitad.
local function cutPoint(text, startPos, room)
  local e = startPos + room - 1
  if e >= #text then return #text end
  while e > startPos do
    local nextByte = string.byte(text, e + 1)
    if nextByte < 128 or nextByte >= 192 then break end
    e = e - 1
  end
  return e
end

-- Encola un mensaje. Formato de cada trozo:
--   "S" + mensaje completo           (cabe en uno)
--   "F"/"M"/"L" + id + parte         (primero / intermedio / último)
-- isStale (opcional): se consulta justo antes de enviar; si devuelve true, el mensaje
-- se descarta (por ejemplo, porque otro jugador ya está enviando lo mismo).
function Comm.Send(msgType, payload, channel, target, priority, isStale)
  local text = msgType .. (payload or "")
  local queue = queues[priority == "high" and 1 or 2]
  if #text + 1 <= MAX_LEN then
    queue[#queue + 1] = { channel, target, "S" .. text, isStale = isStale }
    return
  end
  counter = counter % 4095 + 1
  local id = Codec.EncodeUInt(counter)
  local room = MAX_LEN - 1 - #id
  local pos = 1
  while pos <= #text do
    local e = cutPoint(text, pos, room)
    local head
    if pos == 1 then
      head = "F"
    elseif e >= #text then
      head = "L"
    else
      head = "M"
    end
    queue[#queue + 1] = {
      channel, target, head .. id .. string.sub(text, pos, e),
      mid = counter, isStale = pos == 1 and isStale or nil,
    }
    pos = e + 1
  end
end

-- Descarta el primer mensaje de la cola (con todos sus trozos).
local function dropFirst(queue)
  local mid = queue[1].mid
  table.remove(queue, 1)
  if mid then
    while queue[1] and queue[1].mid == mid do table.remove(queue, 1) end
  end
end

local function sendNow(item)
  local fn = C_ChatInfo and C_ChatInfo.SendAddonMessage
  if not fn then return true, nil end
  return pcall(fn, ns.PREFIX, item[3], item[1], item[2])
end

local function pump()
  local now = GetTime()
  if now < pausedUntil then return end
  if lastPump then tokens = math.min(BUCKET_CAP, tokens + (now - lastPump) * BUCKET_RATE) end
  lastPump = now
  while tokens >= 1 do
    local queue = (queues[1][1] and queues[1]) or (queues[2][1] and queues[2])
    if not queue then return end
    local item = queue[1]
    local staleOk, stale = true, false
    if item.isStale then
      -- Los reenvíos salen de uno en uno y espaciados al azar: así los demás ven
      -- a tiempo lo que ya se está enviando y no lo repiten.
      if now < nextRelayAt then return end
      staleOk, stale = pcall(item.isStale)
      if not (staleOk and stale) then nextRelayAt = now + RELAY_GAP_MIN + math.random() * (RELAY_GAP_MAX - RELAY_GAP_MIN) end
    end
    if item[1] == "GUILD" and not IsInGuild() then
      dropFirst(queue)
    elseif staleOk and stale then
      dropFirst(queue) -- ya lo ha enviado otro: no gastar mensajes
      Comm.stats.skipped = (Comm.stats.skipped or 0) + 1
    else
      local ok, result = sendNow(item)
      if ok and LOCKDOWN[result] then
        -- bloqueo temporal del juego: no se pierde nada, se reintenta en unos segundos
        pausedUntil = now + Comm.LOCKDOWN_WAIT
        Comm.stats.lockdowns = (Comm.stats.lockdowns or 0) + 1
        return
      end
      if ok and (result == false or THROTTLED[result]) then
        -- el servidor nos frena: reintentar más tarde
        item.tries = (item.tries or 0) + 1
        if item.tries > 5 then table.remove(queue, 1) end
        tokens = 0
        return
      end
      table.remove(queue, 1)
      if ok then Comm.stats.sent = Comm.stats.sent + 1 end
      tokens = tokens - 1
    end
  end
end
Comm.Pump = pump
C_Timer.NewTicker(0.2, function() ns.SafeCall(pump) end)

local function dispatch(sender, text, channel)
  local fn = handlers[string.sub(text, 1, 1)]
  if fn then
    Comm.stats.received = Comm.stats.received + 1
    ns.SafeCall(fn, sender, string.sub(text, 2), channel)
  end
end

function Comm.OnAddonMessage(prefix, text, channel, sender)
  if prefix ~= ns.PREFIX or type(text) ~= "string" or text == "" then return end
  if channel ~= "GUILD" and channel ~= "WHISPER" then return end
  sender = ns.FullName(sender)
  if not sender or sender == ns.Me() then return end
  if channel == "WHISPER" and not (ns.Guild and ns.Guild.IsMember(sender)) then return end
  if ns.Guild then ns.Guild.MarkSeen(sender) end

  local head = string.sub(text, 1, 1)
  if head == "S" then
    dispatch(sender, string.sub(text, 2), channel)
    return
  end
  if head ~= "F" and head ~= "M" and head ~= "L" then return end
  local id, pos = Codec.DecodeUInt(text, 2)
  if not id then return end
  local part = string.sub(text, pos)
  local box = inbox[sender]
  if not box then
    box = {}
    inbox[sender] = box
  end
  if head == "F" then
    if not box[id] then
      local open = 0
      for _ in pairs(box) do open = open + 1 end
      if open >= MAX_OPEN_BOXES then return end
    end
    box[id] = { part, t = GetTime() }
    -- Aviso temprano: ya se sabe qué está enviando aunque falten trozos.
    local peek = peekers[string.sub(part, 1, 1)]
    if peek then ns.SafeCall(peek, sender, string.sub(part, 2)) end
  else
    local pieces = box[id]
    if not pieces then return end
    if #pieces >= MAX_PIECES then
      box[id] = nil
      return
    end
    pieces[#pieces + 1] = part
    pieces.t = GetTime()
    if head == "L" then
      box[id] = nil
      dispatch(sender, table.concat(pieces), channel)
    end
  end
end
ns.On("CHAT_MSG_ADDON", Comm.OnAddonMessage)

-- Limpieza de mensajes troceados que nunca se completaron.
C_Timer.NewTicker(30, function()
  local limit = GetTime() - INBOX_TTL
  for sender, box in pairs(inbox) do
    for id, pieces in pairs(box) do
      if pieces.t < limit then box[id] = nil end
    end
    if next(box) == nil then inbox[sender] = nil end
  end
end)
