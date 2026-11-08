-- Carga en segundo plano los nombres de todos los objetos de la base de recetas, para que
-- el buscador los encuentre. En tandas pequeñas (20 cada medio segundo) y solo fuera de
-- combate; el juego los guarda en su caché, así que las siguientes veces ya están.
local _, ns = ...
local Codec = ns.Codec
local Preload = { total = 0, done = 0 }
ns.Preload = Preload

local BATCH, INTERVAL = 20, 0.5
local queue, pos, ticker

local function isCached(id)
  local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  return fn and fn(id) ~= nil
end

local function request(id)
  if C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, id)
  elseif GetItemInfo then
    GetItemInfo(id) -- en clientes antiguos, preguntar ya lo pide al servidor
  end
end

local function step()
  if InCombatLockdown and InCombatLockdown() then return end
  local sent = 0
  while pos <= #queue and sent < BATCH do
    local id = queue[pos]
    pos = pos + 1
    if not isCached(id) then
      request(id)
      sent = sent + 1
    end
  end
  Preload.done = pos - 1
  if pos > #queue and ticker then
    ticker:Cancel()
    ticker = nil
  end
end

function Preload.Start()
  if ticker or not ns.RECIPE_DB then return end
  local seen = {}
  queue, pos = {}, 1
  for _, d in pairs(ns.RECIPE_DB) do
    for _, id in ipairs(Codec.DecodeIDs(d.i) or {}) do
      if not seen[id] then
        seen[id] = true
        queue[#queue + 1] = id
      end
    end
  end
  table.sort(queue)
  Preload.total = #queue
  if #queue == 0 then return end
  ticker = C_Timer.NewTicker(INTERVAL, function() ns.SafeCall(step) end)
end

function Preload.Progress()
  return Preload.done, Preload.total
end

ns.Listen("LOGIN", function() ns.After(10, Preload.Start) end)
