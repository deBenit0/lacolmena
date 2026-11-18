-- Mercado › Mis encargos (se monta en el paso 6 del plan del Mercado nuevo).
local _, ns = ...
local W = ns.W

ns.UI.MarketView("jobs", function(view, M)
  view.empty = W.Text(view, "GameFontDisable", "CENTER")
  view.empty:SetPoint("CENTER")
  view.empty:SetText("Mis encargos: en construcción.")
  function view:Refresh(data) end
end)
