local H = ...
-- WoW Forever: la ventana de profesiones es la moderna (ProfessionsFrame) y las recetas se leen
-- con C_TradeSkillUI (no existen GetNumTradeSkills ni TradeSkillReagent1...). Imita la
-- estructura de la rama "forever" de la interfaz de Blizzard.
H.AddMember("Ana")
H.itemClass = { [2862] = { 7, 7 }, [2835] = { 7, 7 } }
local ana = H.Login("Ana", { bags = { [2862] = 3 } })
H.Advance(15)
local env, ns = ana.env, ana.ns

env.Enum = { CraftingReagentType = { Basic = 0, Modifying = 1 } }
local schematics = {
  [1001] = { recipeID = 1001, outputItemID = 2862, quantityMin = 1, reagentSlotSchematics = {
    { reagentType = 0, required = true, quantityRequired = 2, reagents = { { itemID = 2835 } } },
    { reagentType = 1, required = false, quantityRequired = 1, reagents = { { itemID = 999 } } }, -- opcional: no cuenta
  } },
  [1002] = { recipeID = 1002, quantityMin = 1, reagentSlotSchematics = { -- encantamiento: sin objeto
    { reagentType = 0, required = true, quantityRequired = 2, reagents = { { itemID = 10940 } } },
  } },
  [1003] = { recipeID = 1003, outputItemID = 3000, quantityMin = 1, reagentSlotSchematics = {} },
}
env.C_TradeSkillUI = {
  GetBaseProfessionInfo = function() return { professionID = 164, professionName = "Herrería", skillLevel = 120, maxSkillLevel = 150 } end,
  GetChildProfessionInfo = function() return { skillLevel = 0 } end,
  GetAllRecipeIDs = function() return { 1001, 1002, 1003 } end,
  GetRecipeInfo = function(id) return { recipeID = id, learned = id ~= 1003, name = "Receta " .. id } end,
  GetRecipeSchematic = function(id) return schematics[id] end,
  GetRecipeOutputItemData = function(id) return { itemID = schematics[id] and schematics[id].outputItemID } end,
  GetRecipeCooldown = function() return 0 end,
  IsTradeSkillLinked = function() return false end,
  IsTradeSkillGuild = function() return false end,
  IsNPCCrafting = function() return false end,
}

-- 1) Leer recetas con la API moderna.
H.FireEvent(ana, "TRADE_SKILL_LIST_UPDATE")
H.Advance(2)
local prof = ns.MyChar().profs[164]
H.ok(prof and prof.recipes["i2862"], "lee la receta de la barra (C_TradeSkillUI)")
H.ok(prof.recipes["e1002"], "los encantamientos se guardan como hechizo")
H.ok(not prof.recipes["i3000"], "no guarda recetas sin aprender")
H.eq(prof.r, 120, "nivel de la profesión")
local info = ns.Data.GetInfo(ns.Data.InfoKey(164, "i2862"))
H.ok(info and info.v[1].r[2835] == 2 and not info.v[1].r[999], "materiales básicos, sin los opcionales")
-- Viendo las recetas de otro jugador no se guarda nada.
env.C_TradeSkillUI.IsTradeSkillLinked = function() return true end
env.C_TradeSkillUI.GetAllRecipeIDs = function() return { 1003 } end
env.C_TradeSkillUI.GetRecipeInfo = function(id) return { recipeID = id, learned = true } end
H.FireEvent(ana, "TRADE_SKILL_LIST_UPDATE")
H.Advance(2)
H.ok(not prof.recipes["i3000"], "con las recetas de otro (enlazadas) no se guarda nada")
env.C_TradeSkillUI.IsTradeSkillLinked = function() return false end

-- 2) Ventana moderna: casillas recicladas y Init al elegir receta.
env.ProfessionsFrame = env.CreateFrame("Frame", "ProfessionsFrame", env.UIParent)
local page = env.CreateFrame("Frame", nil, env.ProfessionsFrame)
env.ProfessionsFrame.CraftingPage = page
page.CreateMultipleInputBox = env.CreateFrame("EditBox", nil, page)
page.CreateMultipleInputBox.GetValue = function() return 3 end
local form = env.CreateFrame("Frame", nil, page)
page.SchematicForm = form
form.OutputIcon = env.CreateFrame("Button", nil, form)
local active = {}
form.reagentSlotPool = { EnumerateActive = function()
  local i = 0
  return function() i = i + 1 return active[i] end
end }
local function newSlot(schematic)
  local slot = env.CreateFrame("Frame", nil, form)
  slot.GetReagentSlotSchematic = function() return schematic end
  return slot
end
function form:GetRecipeInfo() return self.currentRecipeInfo end
function form:Init(recipeInfo)
  self.currentRecipeInfo = recipeInfo
  active = {}
  for _, s in ipairs(schematics[recipeInfo.recipeID].reagentSlotSchematics) do active[#active + 1] = newSlot(s) end
end
H.FireEvent(ana, "ADDON_LOADED", "Blizzard_Professions")
H.ok(form.hdfHooked, "se engancha al formulario de recetas")
form:Init({ recipeID = 1001, name = "Barra" })
H.ok(active[1].hdfAsk and active[1].hdfAsk:IsShown(), "botón Pedir en el material básico")
H.ok(not (active[2].hdfAsk and active[2].hdfAsk:IsShown()), "sin botón en el material opcional")
H.ok(form.hdfOffer and form.hdfOffer:IsShown(), "botón Ofrecer junto al objeto")
active[1].hdfAsk:Click()
local rd = env.HDFProfRequestDialog
H.ok(rd:IsShown() and rd.key == "i2835", "Pedir abre el material")
H.eq(rd.qty:GetText(), "6", "cantidad: 2 por vez x 3 veces")
rd:Hide()
form.hdfOffer:Click()
local od = env.HDFProfOfferDialog
H.ok(od:IsShown() and od.id == 2862, "Ofrecer abre la barra")
H.eq(od.qty:GetText(), "3", "con las que llevas")
od:Hide()
-- Elegir otra receta (encantamiento): los botones se recolocan.
form:Init({ recipeID = 1002, name = "Encantamiento" })
H.ok(active[1].hdfAsk:IsShown(), "Pedir en el material del encantamiento")
H.ok(not form.hdfOffer:IsShown(), "un encantamiento no se puede ofrecer")
-- "Pedir en la hermandad" con varios materiales.
form:Init({ recipeID = 1001, name = "Barra" })
env.ProfessionsFrame:Show()
ns.Missing.OnClick()
H.ok(env.HDFProfMissingDialog and env.HDFProfMissingDialog:IsShown(), "Pedir en la hermandad abre la lista de lo que falta")

-- 3) Autocomprobación con la ventana de Forever.
local results = ns.Diag.Run()
local byLabel = {}
for _, r in ipairs(results) do byLabel[r.label] = r end
H.eq(byLabel["Ventana de profesión"].status, true, "comprobación: ventana moderna encontrada")
H.eq(byLabel["Botón \"Pedir\" en los materiales"].status, true, "comprobación: Pedir enganchado")
H.eq(byLabel["Recetas leídas (Forever)"].status, true, "comprobación: recetas leídas")

H.eq(#H.errors, 0, "sin errores de Lua")
