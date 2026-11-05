-- "Pedir lo que me falta": botón en la ventana de profesión que pide a la hermandad los
-- materiales que faltan para fabricar la receta elegida (bolsas + banco), con la cantidad exacta.
local _, ns = ...
local Data = ns.Data
local Missing = {}
ns.Missing = Missing

local function itemIdFromLink(link)
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- Materiales de la receta elegida: lista de { id, need } o nil si no hay ninguna elegida.
local function selectedReagents()
  if CraftFrame and CraftFrame:IsShown() and GetCraftSelectionIndex then
    local i = GetCraftSelectionIndex()
    if not i or i == 0 then return nil end
    local list = {}
    for r = 1, (GetCraftNumReagents(i) or 0) do
      local _, _, count = GetCraftReagentInfo(i, r)
      local id = itemIdFromLink(GetCraftReagentItemLink(i, r))
      if id and count then list[#list + 1] = { id = id, need = count } end
    end
    return list, 1
  end
  if GetTradeSkillSelectionIndex then
    local i = GetTradeSkillSelectionIndex()
    if not i or i == 0 then return nil end
    local list = {}
    for r = 1, (GetTradeSkillNumReagents(i) or 0) do
      local _, _, count = GetTradeSkillReagentInfo(i, r)
      local id = itemIdFromLink(GetTradeSkillReagentItemLink(i, r))
      if id and count then list[#list + 1] = { id = id, need = count } end
    end
    -- cuántas veces quiere fabricarla (la caja de cantidad de la ventana)
    local times = TradeSkillInputBox and tonumber(TradeSkillInputBox:GetText()) or 1
    return list, math.max(1, times or 1)
  end
end

-- Lo que falta: { { id, missing } }, ya descontando lo que tengo (bolsas + banco).
function Missing.Compute(reagents, times)
  local out = {}
  for _, re in ipairs(reagents or {}) do
    local missing = re.need * times - ns.Scan.Have(re.id)
    if missing > 0 then out[#out + 1] = { id = re.id, missing = missing } end
  end
  return out
end

-- Crea las peticiones (sin repetir las que ya tengo abiertas). Devuelve creadas, omitidas.
function Missing.Request(list)
  local now, created, skipped = ns.Now(), {}, {}
  for _, m in ipairs(list) do
    local key = "i" .. m.id
    if Data.MyActiveRequestFor(key, now) then
      skipped[#skipped + 1] = m
    else
      local r = ns.Sync.CreateRequest({ k = key, pk = Data.SingleProfession(key), q = m.missing })
      if r then created[#created + 1] = m else skipped[#skipped + 1] = m end
    end
  end
  return created, skipped
end

local function describe(list)
  local parts = {}
  for _, m in ipairs(list) do parts[#parts + 1] = m.missing .. "x " .. ns.KeyName("i" .. m.id) end
  return table.concat(parts, ", ")
end

function Missing.OnClick()
  if not ns.G() then
    ns.Print("no estás en ninguna hermandad.")
    return
  end
  local reagents, times = selectedReagents()
  if not reagents then
    ns.Print("elige primero una receta en la ventana de profesión.")
    return
  end
  local list = Missing.Compute(reagents, times)
  if #list == 0 then
    ns.Print("ya tienes todos los materiales (contando el banco).")
    return
  end
  ns.W.Confirm("¿Pedir a la hermandad lo que te falta?\n\n" .. describe(list), function()
    local created, skipped = Missing.Request(list)
    if #created > 0 then ns.Print("pedido a la hermandad: %s.", describe(created)) end
    if #skipped > 0 then
      ns.Print("no se ha pedido (ya lo tenías pedido o tienes %d abiertas): %s.", Data.MAX_OPEN, describe(skipped))
    end
  end)
end

-- Botón encima del de "Crear" (o arriba a la derecha si no lo encuentra).
local buttons = {}
local function addButton(frame, createButton)
  if not frame or buttons[frame] then return end
  local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  b:SetSize(160, 22)
  b:SetText("Pedir en la hermandad")
  if createButton then
    b:SetPoint("BOTTOMRIGHT", createButton, "TOPRIGHT", 0, 4)
  else
    b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -40)
  end
  b:SetScript("OnClick", function() ns.SafeCall(Missing.OnClick) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(ns.TITLE)
    GameTooltip:AddLine("Pide a la hermandad los materiales que te faltan para la receta elegida.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  buttons[frame] = b
end

ns.On("TRADE_SKILL_SHOW", function() addButton(TradeSkillFrame, TradeSkillCreateButton) end)
ns.On("CRAFT_SHOW", function() addButton(CraftFrame, CraftCreateButton) end)
