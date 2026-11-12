-- Pedidos en el chat de hermandad: para que lleguen aunque quien pide se haya desconectado.
--
-- Los addons no pueden guardar nada en el servidor, pero el chat de hermandad sí tiene historial
-- (el de la ventana de Comunidades). Al publicar un pedido, el addon escribe una línea normal en
-- el chat de hermandad con una marca al final:
--   [Los hijos del Fundillo] Pido 5x [Lingote de hierro] (propina 50 plata, lo necesita ya). (HDF1 <id> <datos>)
-- Al entrar al juego, el addon lee ese historial y recupera los pedidos que no conocía.
--
-- Verificado contra la rama "forever" de la interfaz de Blizzard: C_Club.GetGuildClubId,
-- GetStreams (streamType Enum.ClubStreamType.Guild = 1), GetMessageRanges, GetMessagesInRange,
-- RequestMoreMessagesBefore y el evento CLUB_MESSAGE_HISTORY_RECEIVED. El autor de cada línea lo
-- pone el servidor (author.name): nadie puede publicar un pedido en nombre de otro.
--
-- La copia que sale del chat lleva la versión del autor un punto por debajo de la original: en
-- cuanto alguien tenga la de verdad (y sus cambios: cerrado, aceptado...), gana esa.
local _, ns = ...
local Codec, Data = ns.Codec, ns.Data
local ChatLog = {}
ns.ChatLog = ChatLog

ChatLog.TAG = "HDF1"
ChatLog.PAGES = 3         -- páginas de historial que se piden al entrar
ChatLog.PAGE_SIZE = 100

local enc = Codec.EncodeUInt

local function money(copper)
  local gold, silver = math.floor(copper / 10000), math.floor((copper % 10000) / 100)
  if gold > 0 and silver > 0 then return gold .. " oro " .. silver .. " plata" end
  if gold > 0 then return gold .. " oro" end
  return math.max(1, silver) .. " plata"
end

-- Marca con los datos del pedido: "(HDF1 <sufijo del id> <tipo><número><cantidad><propina><prisa><materiales><profesión>)".
function ChatLog.Mark(r)
  local suffix = r.id:match(":(.+)$")
  if not suffix or not suffix:match("^[%w#$]+$") then return nil end
  local kind, num = r.k:match("^([ie])(%d+)$")
  if not kind then return nil end
  local pk = type(r.pk) == "number" and r.pk >= 0 and math.floor(r.pk) or 0
  local data = enc(kind == "e" and 1 or 0) .. enc(tonumber(num)) .. enc(r.q) .. enc(r.g or 0)
    .. enc(r.pr or 0) .. enc(r.m and 1 or 0) .. enc(pk)
  return "(" .. ChatLog.TAG .. " " .. suffix .. " " .. data .. ")"
end

function ChatLog.Text(r)
  local mark = ChatLog.Mark(r)
  if not mark then return nil end
  local name, _, link = ns.KeyInfo(r.k)
  local text = string.format("[%s] Pido %dx %s", ns.TITLE, r.q, link or ("[" .. (name or ns.KeyName(r.k)) .. "]"))
  local extra = {}
  if r.g then extra[#extra + 1] = "propina " .. money(r.g) end
  local w = r.pr and Data.WHEN[r.pr]
  if w then extra[#extra + 1] = w.need:lower() end
  if r.m then extra[#extra + 1] = "pongo los materiales" end
  if r.nt then extra[#extra + 1] = r.nt end
  if #extra > 0 then text = text .. " (" .. table.concat(extra, ", ") .. ")" end
  text = text .. ". "
  -- la marca siempre entera: si no cabe, se acorta el enlace a solo el nombre
  if #text + #mark > 255 then
    text = string.format("[%s] Pido %dx [%s]. ", ns.TITLE, r.q, name or ns.KeyName(r.k))
  end
  return text .. mark
end

-- Lee una línea del chat. Devuelve la petición (sin guardar) o nil si no es nuestra.
function ChatLog.Parse(text, author)
  if type(text) ~= "string" or type(author) ~= "string" or author == "" then return nil end
  local suffix, data = text:match("%(" .. ChatLog.TAG .. " ([%w#$]+) ([%w#$]+)%)%s*$")
  if not suffix then return nil end
  local t, pos = Codec.DecodeUInt(suffix, 1)
  if not t or not Codec.DecodeUInt(suffix, pos) then return nil end
  local vals, p = {}, 1
  for i = 1, 7 do
    vals[i], p = Codec.DecodeUInt(data, p)
    if not vals[i] then return nil end
  end
  if p ~= #data + 1 then return nil end
  -- El chat da el nombre con apellido y sin reino: se busca su ficha para que sea el mismo pedido.
  author = Data.CanonicalName(ns.FullName(author), true)
  local r = Data.SanitizeRequest({
    id = author .. ":" .. suffix, a = author, t = t, av = math.max(0, t - 1),
    k = (vals[1] == 1 and "e" or "i") .. vals[2], q = vals[3],
    g = vals[4] > 0 and vals[4] or nil, pr = vals[5] > 0 and vals[5] or nil,
    m = vals[6] == 1 or nil, pk = vals[7] > 0 and vals[7] or nil,
  })
  return r
end

-- Una línea del chat (del historial o en directo). Devuelve true si ha añadido un pedido nuevo.
function ChatLog.Consider(text, author, now)
  local g = ns.G()
  if not g then return false end
  local ok, r = pcall(ChatLog.Parse, text, author)
  if not ok or not r then return false end
  if r.a == ns.Me() then return false end
  if g.requests[r.id] or (g.gone and g.gone[r.id]) then return false end
  if not ns.Guild.Accepts(r.a) or Data.FromFuture(r, now) then return false end
  if now - r.t > Data.REQUEST_TTL then return false end
  local changed, old, merged = Data.ApplyRequest(r, now)
  if not changed then return false end
  ns.Fire("DATA_CHANGED", "request", r.id)
  ns.Fire("REQUEST_UPDATED", old, merged)
  return true
end

---------------------------------------------------------------------------
-- Escribir
---------------------------------------------------------------------------
function ChatLog.Enabled()
  return ns.db and ns.db.settings.chatPost ~= false
end

function ChatLog.Post(r)
  if not r or r.demo or not ChatLog.Enabled() then return false end
  local text = ChatLog.Text(r)
  return text and ns.Extras.SendGuild(text) or false
end

---------------------------------------------------------------------------
-- Leer el historial
---------------------------------------------------------------------------
local function secret(v)
  return issecretvalue and issecretvalue(v)
end

local function guildStream()
  if not (C_Club and C_Club.GetGuildClubId and C_Club.GetStreams) then return nil end
  local clubId = C_Club.GetGuildClubId()
  if not clubId then return nil end
  local guildType = Enum and Enum.ClubStreamType and Enum.ClubStreamType.Guild or 1
  for _, s in ipairs(C_Club.GetStreams(clubId) or {}) do
    if s.streamType == guildType then return clubId, s.streamId end
  end
end

ChatLog.found = 0  -- pedidos recuperados del historial en esta sesión (para la comprobación)
ChatLog.read = nil -- cuántas líneas se han leído, o nil si aún no se ha podido

function ChatLog.ReadDownloaded()
  local clubId, streamId = guildStream()
  if not clubId or not C_Club.GetMessageRanges then return false end
  local now, lines = ns.Now(), 0
  for _, range in ipairs(C_Club.GetMessageRanges(clubId, streamId) or {}) do
    local msgs = C_Club.GetMessagesInRange(clubId, streamId, range.oldestMessageId, range.newestMessageId) or {}
    for _, m in ipairs(msgs) do
      local text, author = m.content, m.author and m.author.name
      if not m.destroyed and not secret(text) and not secret(author) then
        lines = lines + 1
        if ChatLog.Consider(text, author, now) then ChatLog.found = ChatLog.found + 1 end
      end
    end
  end
  ChatLog.read = (ChatLog.read or 0) + lines
  return true
end

local pagesAsked = 0
local function oldestId(clubId, streamId)
  local ranges = C_Club.GetMessageRanges(clubId, streamId) or {}
  local first = ranges[1]
  return first and first.oldestMessageId
end

function ChatLog.ReadHistory()
  local clubId, streamId = guildStream()
  if not clubId then return false end
  pagesAsked = 1
  if C_Club.RequestMoreMessagesBefore then
    C_Club.RequestMoreMessagesBefore(clubId, streamId, nil, ChatLog.PAGE_SIZE)
  end
  ChatLog.ReadDownloaded() -- lo que ya esté descargado
  return true
end

ns.On("CLUB_MESSAGE_HISTORY_RECEIVED", function(clubId, streamId)
  ns.SafeCall(function()
    local gc, gs = guildStream()
    if not gc or clubId ~= gc or streamId ~= gs then return end
    ChatLog.ReadDownloaded()
    if pagesAsked > 0 and pagesAsked < ChatLog.PAGES then
      local oldest = oldestId(gc, gs)
      if oldest and not (C_Club.IsBeginningOfStream and C_Club.IsBeginningOfStream(gc, gs, oldest)) then
        pagesAsked = pagesAsked + 1
        C_Club.RequestMoreMessagesBefore(gc, gs, oldest, ChatLog.PAGE_SIZE)
      end
    end
  end)
end)

-- En directo: si el mensaje del addon no llega (versión vieja, mensajes perdidos), la línea del
-- chat sí.
ns.On("CHAT_MSG_GUILD", function(text, author)
  if secret(text) or secret(author) then return end
  ns.SafeCall(ChatLog.Consider, text, author, ns.Now())
end)
