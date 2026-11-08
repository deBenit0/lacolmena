local H = ...
-- Los botones "Pedir" (materiales) y "Ofrecer" (objeto) en la ventana de profesión aparecen
-- aunque la interfaz de Blizzard cree la ventana justo después de avisar de que se abre
-- (la ventana de profesión se carga bajo demanda la primera vez).
H.AddMember("Ana")
H.itemClass = { [4240] = { 1, 0 }, [2592] = { 7, 5 } }
local ana = H.Login("Ana", { bags = { [4240] = 2 } })
H.Advance(15)
local env = ana.env
local TAILORING = {
  name = "Sastrería", rank = 300, max = 300, selected = 1,
  rows = { { name = "Bolsa de lana", item = 4240, reagents = { { 2592, 3 } } } },
}

-- Crea las ventanas con los mismos nombres que la interfaz de Classic (Blizzard_TradeSkillUI).
local function createTradeSkillUI()
  env.TradeSkillFrame = env.CreateFrame("Frame", "TradeSkillFrame", env.UIParent)
  env.TradeSkillCreateButton = env.CreateFrame("Button", "TradeSkillCreateButton", env.TradeSkillFrame)
  env.TradeSkillInputBox = env.CreateFrame("EditBox", "TradeSkillInputBox", env.TradeSkillFrame)
  env.TradeSkillInputBox:SetText("1")
  env.TradeSkillSkillIcon = env.CreateFrame("Button", "TradeSkillSkillIcon", env.TradeSkillFrame)
  for i = 1, 8 do
    local slot = env.CreateFrame("Button", "TradeSkillReagent" .. i, env.TradeSkillFrame)
    slot:SetID(i)
    env["TradeSkillReagent" .. i] = slot
  end
end

-- 1) El aviso llega antes de que exista la ventana (el addon va primero).
H.OpenTradeSkill(ana, TAILORING) -- dispara TRADE_SKILL_SHOW sin ventana creada
H.ok(env.TradeSkillFrame == nil, "aún no existe la ventana")
-- 2) Blizzard la crea y la carga (ADDON_LOADED de Blizzard_TradeSkillUI).
createTradeSkillUI()
H.FireEvent(ana, "ADDON_LOADED", "Blizzard_TradeSkillUI")
H.Advance(1)
H.ok(env.TradeSkillReagent1.hdfHooked, "materiales enganchados aunque la ventana se creó después")
H.ok(env.TradeSkillSkillIcon.hdfOffer, "objeto enganchado aunque la ventana se creó después")

-- Pasar el ratón por el material: sale "Pedir"; por el objeto: sale "Ofrecer".
env.TradeSkillReagent1:GetScript("OnEnter")(env.TradeSkillReagent1)
H.ok(env.HDFProfReagentAsk and env.HDFProfReagentAsk:IsShown(), "botón Pedir visible sobre el material")
env.TradeSkillSkillIcon:GetScript("OnEnter")(env.TradeSkillSkillIcon)
H.ok(env.HDFProfOfferButton and env.HDFProfOfferButton:IsShown(), "botón Ofrecer visible sobre el objeto")
-- Pulsar el objeto (sin pasar el ratón antes) también lo muestra.
env.HDFProfOfferButton:Hide()
env.TradeSkillSkillIcon:GetScript("OnClick")(env.TradeSkillSkillIcon)
H.ok(env.HDFProfOfferButton:IsShown(), "al pulsar el objeto también sale Ofrecer")
env.HDFProfReagentAsk:Click()
H.ok(env.HDFProfRequestDialog:IsShown() and env.HDFProfRequestDialog.key == "i2592", "Pedir abre el material")
env.HDFProfRequestDialog:Hide()
env.HDFProfOfferButton:Show()
env.HDFProfOfferButton:Click()
H.ok(env.HDFProfOfferDialog:IsShown() and env.HDFProfOfferDialog.id == 4240, "Ofrecer abre la bolsa")
H.eq(env.HDFProfOfferDialog.qty:GetText(), "2", "con las que llevas")
env.HDFProfOfferDialog:Hide()

-- 3) Sin aviso de carga: basta con el reintento justo después de abrirla.
H.Reset()
H.AddMember("Bea")
local bea = H.Login("Bea")
H.Advance(15)
env = bea.env
H.OpenTradeSkill(bea, TAILORING)
createTradeSkillUI()
H.Advance(1)
H.ok(env.TradeSkillReagent1.hdfHooked and env.TradeSkillSkillIcon.hdfOffer, "enganchados con el reintento")

-- 4) No se engancha dos veces al abrir y cerrar.
local hooks = 0
local orig = env.TradeSkillReagent1.HookScript
env.TradeSkillReagent1.HookScript = function(self, ...) hooks = hooks + 1 return orig(self, ...) end
H.OpenTradeSkill(bea, TAILORING)
H.Advance(1)
H.eq(hooks, 0, "no se engancha dos veces")

H.eq(#H.errors, 0, "sin errores de Lua")
