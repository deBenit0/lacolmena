-- «¡Me ha llegado!» automático. Con el buzón abierto se miran las cartas (solo se escuchan
-- eventos: no se engancha ninguna función del buzón). Cuando una carta de quien se encargó de un
-- pedido mío pierde ese objeto y mis bolsas lo ganan, el pedido se da por recibido.
-- Solo cuenta lo que llega de esa persona y por correo: un objeto que ya tenía o que manda otro, no.
local _, ns = ...
local Inbox = {}
ns.Inbox = Inbox

local WAIT = 10 -- segundos que se espera a que el objeto aparezca en las bolsas

local snap, bags -- lo que había en el buzón (por remitente y objeto) y en las bolsas
local candidates = {} -- { {id, name, item, bag, at} }

local function lower(s) return (tostring(s or "")):lower() end

-- ¿Es "sender" (como lo da el buzón: «Xepe», «Xepe Barbabrote» o «Xepe-Reino») la persona "name"?
function Inbox.SenderIs(sender, name)
  local s = lower(sender)
  if s == "" then return false end
  if s == lower(name) then return true end
  local first = s:match("^([^%s%-]+)") or s
  return first == lower(ns.ShortName(name))
end

-- Lo que espero por correo: mis pedidos con algo enviado y sin recibir.
function Inbox.Waiting()
  local g, me, out = ns.G(), ns.Me(), {}
  if not g or not me then return out end
  for id, r in pairs(g.requests) do
    local kind, item = ns.ParseKey(r.k)
    if r.a == me and kind == "i" and not r.x then
      for name, cm in pairs(r.c or {}) do
        if (cm.s or 0) > (cm.d or 0) then out[#out + 1] = { id = id, name = name, item = item } end
      end
    end
  end
  return out
end

-- Lo que hay ahora en el buzón: [remitente en minúsculas][objeto] = cantidad.
function Inbox.Read()
  local out = {}
  if not GetInboxNumItems or not GetInboxHeaderInfo or not GetInboxItem then return out end
  local n = GetInboxNumItems() or 0
  for i = 1, n do
    local _, _, sender, _, _, _, _, hasItem = GetInboxHeaderInfo(i)
    if sender and hasItem then
      local who = lower(sender)
      for j = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
        local _, itemID, _, count = GetInboxItem(i, j)
        itemID = tonumber(itemID)
        if itemID then
          out[who] = out[who] or {}
          out[who][itemID] = (out[who][itemID] or 0) + (tonumber(count) or 1)
        end
      end
    end
  end
  return out
end

local function countFrom(mail, name, item)
  local n = 0
  for sender, items in pairs(mail or {}) do
    if items[item] and Inbox.SenderIs(sender, name) then n = n + items[item] end
  end
  return n
end

-- Los candidatos cuyo objeto ya está en mis bolsas: recibido.
-- Reparte lo que ha llegado entre sus pedidos (lo enviado antes, primero), sin pasar de lo enviado.
local function credit(name, item, amount)
  local g = ns.G()
  local list = {}
  for _, w in ipairs(Inbox.Waiting()) do
    if w.name == name and w.item == item then list[#list + 1] = g.requests[w.id] end
  end
  table.sort(list, function(a, b)
    local sa, sb = a.c[name].sv or 0, b.c[name].sv or 0
    if sa ~= sb then return sa < sb end
    return a.id < b.id
  end)
  for _, r in ipairs(list) do
    if amount <= 0 then break end
    local cm = r.c[name]
    local take = math.min(amount, (cm.s or 0) - (cm.d or 0))
    if take > 0 and ns.Sync.MarkArrived(r.id, name, take) then
      amount = amount - take
      ns.Print("te ha llegado %s de %s: apuntado como recibido.", ns.KeyLabel(r.k), ns.DisplayName(name))
    end
  end
end

local function settle(now)
  local keep = {}
  for _, c in ipairs(candidates) do
    local gained = ns.ItemCount(c.item) - c.bag
    if gained > 0 then
      credit(c.name, c.item, math.min(c.lost, gained))
    elseif now - c.at < WAIT then
      keep[#keep + 1] = c
    end
  end
  candidates = keep
end

-- Mira el buzón otra vez: lo que falta respecto a la última vez es lo que acabo de sacar.
function Inbox.Check(now)
  now = now or (GetTime and GetTime() or 0)
  local mail = Inbox.Read()
  if snap then
    local seen = {}
    for _, w in ipairs(Inbox.Waiting()) do
      local k = w.name .. "|" .. w.item
      if not seen[k] then
        seen[k] = true
        local before, after = countFrom(snap, w.name, w.item), countFrom(mail, w.name, w.item)
        if after < before then
          candidates[#candidates + 1] = { name = w.name, item = w.item, lost = before - after,
            bag = bags[w.item] or 0, at = now }
        end
      end
    end
  end
  snap = mail
  bags = {}
  for _, w in ipairs(Inbox.Waiting()) do bags[w.item] = ns.ItemCount(w.item) end
  settle(now)
end

function Inbox.Reset()
  snap, bags, candidates = nil, nil, {}
end

local open = false
ns.On("MAIL_SHOW", function()
  open = true
  Inbox.Reset()
  ns.After(0.5, function() if open then Inbox.Check() end end)
end)
ns.On("MAIL_INBOX_UPDATE", function() if open then Inbox.Check() end end)
ns.On("MAIL_CLOSED", function()
  open = false
  Inbox.Reset()
end)
ns.Listen("BAGS_CHANGED", function()
  if open and #candidates > 0 then settle(GetTime and GetTime() or 0) end
end)
