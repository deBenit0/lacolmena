-- Mercado › Mis pedidos (se monta en el paso 5 del plan del Mercado nuevo).
local _, ns = ...
local W = ns.W

ns.UI.MarketView("mine", function(view, M)
  view.empty = W.Text(view, "GameFontDisable", "CENTER")
  view.empty:SetPoint("CENTER")
  view.empty:SetText("Mis pedidos: en construcción.")
  function view:Refresh(data) end
end)
