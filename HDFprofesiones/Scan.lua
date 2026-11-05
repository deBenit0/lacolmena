-- Escaneo de mis profesiones, cooldowns, nivel y banco.
-- Las recetas se leen al abrir la ventana de cada profesión. Nunca se borran recetas
-- (no se pueden olvidar): si hay filtros puestos, simplemente se leen menos esa vez.
local _, ns = ...
local Data = ns.Data
local Scan = {}
ns.Scan = Scan

local floor = math.floor

local function mineChanged()
  ns.Coalesce("publishMine", 3, function()
    if ns.Sync then ns.Sync.PublishMine() end
  end)
  ns.Fire("DATA_CHANGED", "mine")
end
Scan.MineChanged = mineChanged

local function itemIdFromLink(link)
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function profRecord(c, pk)
  local prof = c.profs[pk]
  if not prof then
    prof = { recipes = {}, cd = {} }
    c.profs[pk] = prof
  end
  prof.recipes = prof.recipes or {}
  prof.cd = prof.cd or {}
  return prof
end

-- getRow(i) devuelve { key, made, reagents = { [objeto] = n }, cooldown } o nil.
local function scanRows(pk, rank, maxRank, numRows, getRow)
  local c = ns.MyChar()
  if not c or not pk then return end
  local prof = profRecord(c, pk)
  local changed = false
  if rank and prof.r ~= rank then prof.r, changed = rank, true end
  if maxRank and prof.m ~= maxRank then prof.m, changed = maxRank, true end
  local now = ns.Now()
  for i = 1, numRows do
    local row = getRow(i)
    if row and row.key then
      if not prof.recipes[row.key] then
        prof.recipes[row.key] = true
        changed = true
      end
      local ik = Data.InfoKey(pk, row.key)
      if row.reagents then Data.AddInfoVariant(ik, row.made, row.reagents) end
      if row.cooldown and row.cooldown > 0 then
        local finish = now + floor(row.cooldown)
        local old = prof.cd[row.key]
        if not old or math.abs(old - finish) > 120 then
          prof.cd[row.key] = finish
          changed = true
        end
        Data.MarkCooldown(ik)
      elseif prof.cd[row.key] then
        prof.cd[row.key] = nil
        changed = true
      end
    end
  end
  prof.t = now
  if changed then mineChanged() end
end

---------------------------------------------------------------------------
-- Ventana de profesión clásica
---------------------------------------------------------------------------
local function tradeSkillRow(i)
  local name, kind = GetTradeSkillInfo(i)
  if not name or kind == "header" or kind == "subheader" then return nil end
  local key = ns.KeyFromLink(GetTradeSkillItemLink(i))
  if not key then return nil end
  local row = { key = key, made = (GetTradeSkillNumMade and GetTradeSkillNumMade(i)) or 1 }
  local count = (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i)) or 0
  local reagents, complete = {}, count > 0
  for r = 1, count do
    local _, _, needed = GetTradeSkillReagentInfo(i, r)
    local id = itemIdFromLink(GetTradeSkillReagentItemLink(i, r))
    if id and needed then
      reagents[id] = (reagents[id] or 0) + needed
    else
      complete = false -- el objeto aún no está en caché: ya se leerá en otra actualización
    end
  end
  if complete then row.reagents = reagents end
  if GetTradeSkillCooldown then row.cooldown = GetTradeSkillCooldown(i) end
  return row
end

function Scan.TradeSkill()
  if not GetNumTradeSkills or not GetTradeSkillLine then return end
  if IsTradeSkillLinked and IsTradeSkillLinked() then return end -- receta de otro jugador
  local name, rank, maxRank = GetTradeSkillLine()
  if not name or name == "" or name == "UNKNOWN" then return end
  scanRows(ns.ProfessionKey(name), rank, maxRank, GetNumTradeSkills() or 0, tradeSkillRow)
end

---------------------------------------------------------------------------
-- Ventana de encantamiento (en Classic usa otra interfaz)
---------------------------------------------------------------------------
local function craftRow(i)
  local name, _, kind = GetCraftInfo(i)
  if not name or kind == "header" then return nil end
  local key = ns.KeyFromLink(GetCraftItemLink and GetCraftItemLink(i))
  if not key and GetCraftRecipeLink then key = ns.KeyFromLink(GetCraftRecipeLink(i)) end
  if not key then return nil end
  local row = { key = key, made = 1 }
  local count = (GetCraftNumReagents and GetCraftNumReagents(i)) or 0
  local reagents, complete = {}, count > 0
  for r = 1, count do
    local _, _, needed = GetCraftReagentInfo(i, r)
    local id = itemIdFromLink(GetCraftReagentItemLink and GetCraftReagentItemLink(i, r))
    if id and needed then
      reagents[id] = (reagents[id] or 0) + needed
    else
      complete = false
    end
  end
  if complete then row.reagents = reagents end
  return row
end

function Scan.Craft()
  if not GetNumCrafts or not GetCraftDisplaySkillLine then return end
  local name, rank, maxRank = GetCraftDisplaySkillLine()
  if not name then return end -- doma de bestias (cazadores): no es una profesión
  scanRows(ns.ProfessionKey(name), rank, maxRank, GetNumCrafts() or 0, craftRow)
end

---------------------------------------------------------------------------
-- Habilidades: nivel de cada profesión y profesiones abandonadas
---------------------------------------------------------------------------
function Scan.SkillLines()
  local c = ns.MyChar()
  if not c or not GetNumSkillLines or not GetSkillLineInfo then return end
  local present, allExpanded, changed = {}, true, false
  local total = GetNumSkillLines() or 0
  for i = 1, total do
    local name, isHeader, isExpanded, rank, _, _, maxRank = GetSkillLineInfo(i)
    if isHeader then
      if not isExpanded then allExpanded = false end
    elseif name then
      local pk = ns.ProfessionKey(name)
      if ns.PROFESSIONS[pk] then
        present[pk] = true
        local prof = c.profs[pk]
        if prof and rank and (prof.r ~= rank or prof.m ~= maxRank) then
          prof.r, prof.m = rank, maxRank
          changed = true
        end
      end
    end
  end
  -- Si algún grupo está plegado no vemos todas las habilidades: no borrar nada.
  if allExpanded and total > 0 then
    for pk in pairs(c.profs) do
      if type(pk) == "number" and not present[pk] then
        c.profs[pk] = nil
        changed = true
      end
    end
  end
  if changed then mineChanged() end
end

function Scan.Character()
  local c = ns.MyChar()
  if not c then return end
  local level = UnitLevel("player")
  local _, class = UnitClass("player")
  if c.level ~= level or c.class ~= class then
    c.level, c.class = level, class
    mineChanged()
  end
end

---------------------------------------------------------------------------
-- Banco (solo se puede leer con el banco abierto: guardamos una foto)
---------------------------------------------------------------------------
local function containerSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  return (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
end

local function containerItem(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.itemID, info.stackCount end
    return nil
  end
  if GetContainerItemInfo then
    local _, count, _, _, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
    return itemID or itemIdFromLink(link), count
  end
end

local bankOpen = false
function Scan.Bank()
  local c = ns.MyChar()
  if not bankOpen or not c then return end
  local bags = { BANK_CONTAINER or -1 }
  local firstBag = (NUM_BAG_SLOTS or 4) + 1
  for bag = firstBag, firstBag + (NUM_BANKBAGSLOTS or 6) - 1 do bags[#bags + 1] = bag end
  local counts = {}
  for _, bag in ipairs(bags) do
    for slot = 1, containerSlots(bag) do
      local id, count = containerItem(bag, slot)
      if id then counts[id] = (counts[id] or 0) + (count or 1) end
    end
  end
  c.bank = counts
  c.bankT = ns.Now()
  ns.Fire("DATA_CHANGED", "bank")
end

-- Cuántos tengo: bolsas (en directo) + banco (última foto).
function Scan.Have(itemID)
  local bags = ns.ItemCount(itemID)
  local c = ns.MyChar()
  local bank = (c and c.bank and c.bank[itemID]) or 0
  return bags + bank, bags, bank
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
ns.On("TRADE_SKILL_SHOW", function() ns.After(0.5, Scan.TradeSkill) end)
ns.On("TRADE_SKILL_UPDATE", function() ns.Coalesce("scanTrade", 1, Scan.TradeSkill) end)
ns.On("CRAFT_SHOW", function() ns.After(0.5, Scan.Craft) end)
ns.On("CRAFT_UPDATE", function() ns.Coalesce("scanCraft", 1, Scan.Craft) end)
ns.On("SKILL_LINES_CHANGED", function() ns.Coalesce("skillLines", 2, Scan.SkillLines) end)
ns.On("PLAYER_LEVEL_UP", function() ns.After(1, Scan.Character) end)
ns.On("BANKFRAME_OPENED", function()
  bankOpen = true
  ns.After(0.5, Scan.Bank)
end)
ns.On("BANKFRAME_CLOSED", function() bankOpen = false end)
ns.On("PLAYERBANKSLOTS_CHANGED", function() ns.Coalesce("bank", 1, Scan.Bank) end)
ns.On("BAG_UPDATE", function()
  if bankOpen then ns.Coalesce("bank", 1, Scan.Bank) end
end)
ns.On("BAG_UPDATE_DELAYED", function() ns.Fire("BAGS_CHANGED") end)
ns.Listen("LOGIN", function()
  Scan.Character()
  ns.After(5, Scan.SkillLines)
end)
