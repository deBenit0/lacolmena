-- Historial público de cada personaje: lo último que ha recibido (pedidos y ofertas) y lo que
-- ha aportado a la hermandad. Cada uno publica lo suyo en su ficha (e.hi). Lo que alguien ha
-- HECHO sale de lo que apuntan los que lo recibieron, así que nadie se lo puede inventar.
--   c.hist / e.hi = { { k = "p" pedido, "o" oferta o "a" aportación, i = "i<objeto>"/"e<encantamiento>",
--                       n = cantidad, w = el otro (quien lo hizo o a quien se aportó), t = cuándo }, ... }
-- (lo más nuevo primero)
local _, ns = ...
local History = {}
ns.History = History

History.MAX = 30 -- lo que guarda y publica cada personaje

local KINDS = { p = true, o = true, a = true }

local function valid(h)
  return type(h) == "table" and KINDS[h.k] and type(h.i) == "string" and h.i:match("^[ie]%d+$") ~= nil
    and type(h.n) == "number" and h.n > 0 and type(h.w) == "string" and h.w ~= "" and type(h.t) == "number"
end

local function copy(h)
  return { k = h.k, i = h.i, n = math.floor(h.n), w = h.w, t = h.t }
end

-- Apunta algo en mi historial.
function History.Add(kind, key, n, who, now)
  local c = ns.MyChar()
  if not c or not KINDS[kind] or not key or not who then return end
  local h = { k = kind, i = key, n = n or 1, w = who, t = now or ns.Now() }
  if not valid(h) then return end
  c.hist = c.hist or {}
  table.insert(c.hist, 1, h)
  while #c.hist > History.MAX do table.remove(c.hist) end
end

function History.BuildInto(e)
  local c = ns.MyChar()
  if not c or type(c.hist) ~= "table" then return end
  local out = {}
  for _, h in ipairs(c.hist) do
    if #out >= History.MAX then break end
    if valid(h) then out[#out + 1] = copy(h) end
  end
  if #out > 0 then e.hi = out end
end

function History.SanitizeInto(out, e)
  if type(e.hi) ~= "table" then return end
  local list = {}
  for _, h in ipairs(e.hi) do
    if #list >= History.MAX then break end
    if valid(h) then list[#list + 1] = copy(h) end
  end
  if #list > 0 then out.hi = list end
end

-- Historial de una persona (su principal y sus alts juntos), de lo más nuevo a lo más viejo:
--   got  = lo que ha recibido (pedidos y ofertas), con quién se lo hizo
--   gave = lo que ha hecho para otros (sale de las fichas de los demás) y lo que ha aportado
-- Cada línea: { kind, key, n, who (el otro), char (su personaje), t }
-- Lo que se hacen entre personajes de la misma persona no cuenta (como el karma).
function History.For(name)
  local got, gave = {}, {}
  local g = ns.G()
  if not g or not name then return got, gave end
  local mainOf = (ns.Social and ns.Social.MainOf) or function() return nil end
  local main = mainOf(name) or name
  local mine = { [name] = true }
  for ename in pairs(g.entries or {}) do
    if (mainOf(ename) or ename) == main then mine[ename] = true end
  end
  for ename, e in pairs(g.entries or {}) do
    if type(e.hi) == "table" then
      for _, h in ipairs(e.hi) do
        if valid(h) and not (mine[ename] and mine[h.w]) then
          if mine[ename] then
            local line = { kind = h.k, key = h.i, n = h.n, who = h.w, char = ename, t = h.t }
            if h.k == "a" then gave[#gave + 1] = line else got[#got + 1] = line end
          elseif mine[h.w] and h.k ~= "a" then
            gave[#gave + 1] = { kind = h.k, key = h.i, n = h.n, who = ename, char = h.w, t = h.t }
          end
        end
      end
    end
  end
  local function newest(a, b)
    if a.t ~= b.t then return a.t > b.t end
    return a.key < b.key
  end
  table.sort(got, newest)
  table.sort(gave, newest)
  return got, gave
end
