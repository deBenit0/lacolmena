-- Mercado › Mis ofertas (se monta en el paso 7 del plan del Mercado nuevo).
local _, ns = ...
local W = ns.W

ns.UI.MarketView("offers", function(view, M)
  view.empty = W.Text(view, "GameFontDisable", "CENTER")
  view.empty:SetPoint("CENTER")
  view.empty:SetText("Mis ofertas: en construcción.")
  function view:Refresh(data) end
end)
