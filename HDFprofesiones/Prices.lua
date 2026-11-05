-- Precios de la subasta: la venta (compra inmediata) más barata por unidad.
-- Fuentes, por orden: Auctionator o TSM si están instalados; si no, lo que el addon apunta
-- cada vez que miras la subasta (y una búsqueda propia si la tienes abierta al pedir).
local _, ns = ...
local Prices = {}
ns.Prices = Prices

Prices.DISCOUNT = 0.9 -- se ofrece un 10% menos que en la subasta

local function cache()
  ns.db.prices = ns.db.prices or {}
  return ns.db.prices
end

-- Precio por unidad en cobre, fuente y antigüedad en segundos (o nil si no se sabe).
function Prices.Get(itemID)
  if not itemID then return nil end
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.GetAuctionPriceByItemID then
    local ok, price = pcall(api.GetAuctionPriceByItemID, "HDFprofesiones", itemID)
    if ok and type(price) == "number" and price > 0 then return price, "Auctionator" end
  end
  if TSM_API and TSM_API.GetCustomPriceValue then
    local ok, price = pcall(TSM_API.GetCustomPriceValue, "dbminbuyout", "i:" .. itemID)
    if ok and type(price) == "number" and price > 0 then return price, "TSM" end
  end
  local entry = ns.db and cache()[itemID]
  if entry then return entry.p, "subasta", ns.Now() - entry.t end
end

-- Oferta sugerida para "qty" unidades (redondeada a platas), o nil.
function Prices.Suggest(itemID, qty)
  local unit = Prices.Get(itemID)
  if not unit then return nil end
  local offer = math.floor(unit * qty * Prices.DISCOUNT / 100) * 100
  return offer > 0 and offer or nil, unit
end

-- Apunta los precios de la página de resultados de la subasta que se está viendo.
function Prices.ScanPage()
  if not GetNumAuctionItems or not GetAuctionItemInfo or not ns.db then return end
  local now, best = ns.Now(), {}
  for i = 1, (GetNumAuctionItems("list") or 0) do
    local info = { GetAuctionItemInfo("list", i) }
    local count, buyout, itemID = info[3], info[10], info[17]
    if itemID and count and count > 0 and buyout and buyout > 0 then
      local unit = math.floor(buyout / count)
      if not best[itemID] or unit < best[itemID] then best[itemID] = unit end
    end
  end
  local prices = cache()
  for itemID, unit in pairs(best) do
    local old = prices[itemID]
    -- varias páginas de la misma búsqueda: quedarse con la más barata
    if old and now - old.t < 120 then unit = math.min(unit, old.p) end
    prices[itemID] = { p = unit, t = now }
  end
  if next(best) then ns.Fire("PRICES_CHANGED") end
end

-- Si la subasta está abierta, busca el objeto para tener su precio actual.
function Prices.Query(itemID)
  if not (AuctionFrame and AuctionFrame:IsShown() and QueryAuctionItems) then return false end
  if CanSendAuctionQuery and not CanSendAuctionQuery() then return false end
  local name = ns.KeyInfo("i" .. itemID)
  if not name then return false end
  pcall(QueryAuctionItems, name, nil, nil, 0, false, nil, false, true)
  return true
end

ns.On("AUCTION_ITEM_LIST_UPDATE", function() ns.Coalesce("auctionScan", 0.5, Prices.ScanPage) end)
