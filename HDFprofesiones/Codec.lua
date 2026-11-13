-- Codificación compacta para los mensajes del addon y los datos guardados.
-- Todo es determinista: la misma tabla produce siempre el mismo texto (claves ordenadas),
-- lo que permite comparar datos entre jugadores con un simple resumen (hash).
local _, ns = ...
local Codec = {}
ns.Codec = Codec

local floor, concat, sort = math.floor, table.concat, table.sort
local byte, sub, format = string.byte, string.sub, string.format

---------------------------------------------------------------------------
-- Enteros sin signo autodelimitados (base 32)
-- Todas las cifras menos la última usan el alfabeto de "continuación" y la
-- última, el "terminal". Así se pueden encadenar números sin separadores.
---------------------------------------------------------------------------
local TERMINAL = "0123456789abcdefghijklmnopqrstuv"
local CONTINUE = "ABCDEFGHIJKLMNOPQRSTUVWXYZwxyz#$"
local termChar, contChar, termVal, contVal = {}, {}, {}, {}
for i = 1, 32 do
  termChar[i - 1] = sub(TERMINAL, i, i)
  contChar[i - 1] = sub(CONTINUE, i, i)
  termVal[byte(TERMINAL, i)] = i - 1
  contVal[byte(CONTINUE, i)] = i - 1
end

function Codec.EncodeUInt(n)
  n = floor(n)
  if n < 0 then error("EncodeUInt: número negativo") end
  local digit = n % 32
  local out = termChar[digit]
  n = (n - digit) / 32
  while n > 0 do
    digit = n % 32
    out = contChar[digit] .. out
    n = (n - digit) / 32
  end
  return out
end

-- Devuelve el número y la posición siguiente, o nil si el texto no es válido.
function Codec.DecodeUInt(s, pos)
  local value, len = 0, #s
  while pos <= len do
    local b = byte(s, pos)
    local t = termVal[b]
    if t then return value * 32 + t, pos + 1 end
    local c = contVal[b]
    if not c then return nil end
    if value >= 2 ^ 43 then return nil end -- nadie manda números así: el mensaje está mal
    value = value * 32 + c
    pos = pos + 1
  end
  return nil
end

---------------------------------------------------------------------------
-- Listas de identificadores: ordenadas, sin repetidos y guardadas como diferencias
---------------------------------------------------------------------------
function Codec.EncodeIDs(ids)
  local sorted, seen = {}, {}
  for _, id in ipairs(ids) do
    if not seen[id] then
      seen[id] = true
      sorted[#sorted + 1] = id
    end
  end
  sort(sorted)
  local buf, prev = {}, 0
  for i = 1, #sorted do
    buf[i] = Codec.EncodeUInt(sorted[i] - prev)
    prev = sorted[i]
  end
  return concat(buf)
end

function Codec.DecodeIDs(s)
  local out, pos, prev = {}, 1, 0
  if type(s) ~= "string" then return out end
  while pos <= #s do
    local delta
    delta, pos = Codec.DecodeUInt(s, pos)
    if not delta then return nil end
    prev = prev + delta
    out[#out + 1] = prev
  end
  return out
end

---------------------------------------------------------------------------
-- Serialización de tablas
--   +n  entero >= 0        -n  entero negativo     .x;  decimal
--   'Ln texto de longitud L   !  verdadero  ~  falso   { clave valor ... }  tabla
---------------------------------------------------------------------------
local MAX_DEPTH = 24
local MAX_INT = 9007199254740992

local function sortedKeys(t)
  local nums, strs, bools = {}, {}, {}
  for k in pairs(t) do
    local kt = type(k)
    if kt == "number" then nums[#nums + 1] = k
    elseif kt == "string" then strs[#strs + 1] = k
    elseif kt == "boolean" then bools[#bools + 1] = k
    else error("Serialize: tipo de clave no admitido: " .. kt) end
  end
  sort(nums)
  sort(strs)
  if #bools == 2 then bools[1], bools[2] = false, true end
  for i = 1, #strs do nums[#nums + 1] = strs[i] end
  for i = 1, #bools do nums[#nums + 1] = bools[i] end
  return nums
end

local function write(v, buf, depth)
  local vt = type(v)
  if vt == "number" then
    if v ~= v or v == math.huge or v == -math.huge then error("Serialize: número no válido") end
    if v % 1 == 0 and v > -MAX_INT and v < MAX_INT then
      if v >= 0 then
        buf[#buf + 1] = "+" .. Codec.EncodeUInt(v)
      else
        buf[#buf + 1] = "-" .. Codec.EncodeUInt(-v)
      end
    else
      buf[#buf + 1] = "." .. format("%.17g", v) .. ";"
    end
  elseif vt == "string" then
    buf[#buf + 1] = "'" .. Codec.EncodeUInt(#v)
    buf[#buf + 1] = v
  elseif vt == "boolean" then
    buf[#buf + 1] = v and "!" or "~"
  elseif vt == "table" then
    if depth > MAX_DEPTH then error("Serialize: demasiada profundidad") end
    buf[#buf + 1] = "{"
    local keys = sortedKeys(v)
    for i = 1, #keys do
      local k = keys[i]
      write(k, buf, depth + 1)
      write(v[k], buf, depth + 1)
    end
    buf[#buf + 1] = "}"
  else
    error("Serialize: tipo no admitido: " .. vt)
  end
end

function Codec.Serialize(v)
  local buf = {}
  write(v, buf, 0)
  return concat(buf)
end

local function validNumber(n)
  return n and n == n and n ~= math.huge and n ~= -math.huge
end

local read
read = function(s, pos, depth)
  local tag = byte(s, pos)
  if tag == 43 then -- +
    return Codec.DecodeUInt(s, pos + 1)
  elseif tag == 45 then -- -
    local n, nxt = Codec.DecodeUInt(s, pos + 1)
    if not n then return nil end
    return -n, nxt
  elseif tag == 46 then -- .
    local e = s:find(";", pos + 1, true)
    if not e then return nil end
    local n = tonumber(sub(s, pos + 1, e - 1))
    if not validNumber(n) then return nil end
    return n, e + 1
  elseif tag == 39 then -- '
    local len, nxt = Codec.DecodeUInt(s, pos + 1)
    if not len or nxt + len - 1 > #s then return nil end
    return sub(s, nxt, nxt + len - 1), nxt + len
  elseif tag == 33 then -- !
    return true, pos + 1
  elseif tag == 126 then -- ~
    return false, pos + 1
  elseif tag == 123 then -- {
    if depth > MAX_DEPTH then return nil end
    local t = {}
    pos = pos + 1
    while true do
      local b = byte(s, pos)
      if not b then return nil end
      if b == 125 then return t, pos + 1 end -- }
      local k, v
      k, pos = read(s, pos, depth + 1)
      if pos == nil or k == nil then return nil end
      v, pos = read(s, pos, depth + 1)
      if pos == nil then return nil end
      t[k] = v
    end
  end
  return nil
end

-- Devuelve el valor o nil si el texto no es válido (nunca lanza errores).
function Codec.Deserialize(s)
  if type(s) ~= "string" or s == "" then return nil end
  local ok, v, pos = pcall(read, s, 1, 0)
  if not ok or pos ~= #s + 1 then return nil end
  return v
end

---------------------------------------------------------------------------
-- Resumen corto de un texto (djb2 de 32 bits), para comparar sin enviar todo
---------------------------------------------------------------------------
function Codec.Hash(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + byte(s, i)) % 4294967296
  end
  return Codec.EncodeUInt(h)
end
