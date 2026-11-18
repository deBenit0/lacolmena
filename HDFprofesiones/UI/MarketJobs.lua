-- Mercado › MIS ENCARGOS: lo que me he encargado de hacer para otros.
--   Para quién, cuándo, propina y materiales (en rojo lo que falta). Un botón: PREPARAR CORREO
--   (con el buzón abierto) o QUEDAR (encantamientos: se hace en persona). En pequeño,
--   «susurrar · pedir lo que falta · más tiempo · soltar». Al final, los ya entregados en gris.
local _, ns = ...
local W, Data = ns.W, ns.Data

local MAX_ENDED = 10

local function payText(r)
  local parts = {}
  if r.g then parts[#parts + 1] = ns.FormatMoney(r.g) end
  if r.pi then
    local ids = {}
    for id in pairs(r.pi) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do parts[#parts + 1] = r.pi[id] .. "x " .. ns.KeyName("i" .. id) end
  end
  return #parts > 0 and ("Propina: " .. table.concat(parts, " + ")) or "|cff999999Sin propina|r"
end

-- «Pedir lo que falta»: un pedido por cada material que me falta, con la nota «para la hermandad».
local function askMissing(r, missing)
  local parts = {}
  for i, m in ipairs(missing) do parts[i] = m.n .. "x " .. ns.KeyName("i" .. m.id) end
  W.Confirm("¿Pedir a la hermandad lo que te falta? " .. table.concat(parts, ", "), function()
    local note = ns.CleanNote("para la hermandad: encargo de " .. ns.DisplayName(r.a))
    local n = 0
    for _, m in ipairs(missing) do
      if ns.Sync.CreateRequest({ k = "i" .. m.id, q = m.n, m = false, nt = note }) then n = n + 1 end
    end
    if n > 0 then ns.Print("pedido a la hermandad lo que te falta (%d %s).", n, n == 1 and "pedido" or "pedidos") end
  end)
end
ns.UI.AskMissing = askMissing

local function collectJobs(data)
  local live = {}
  for _, it in ipairs(data.items) do
    if it.kind == "req" and not it.mine and it.pending > 0 then live[#live + 1] = it end
  end
  table.sort(live, function(a, b)
    local ca, cb = a.r.c[a.me], b.r.c[b.me]
    local da, db = ca and ca.by or 0, cb and cb.by or 0
    if da ~= db then return da < db end -- lo que vence antes, arriba
    return a.id < b.id
  end)
  local ended = {}
  for _, it in ipairs(data.ended or {}) do
    if not it.mine then ended[#ended + 1] = it end
  end
  table.sort(ended, function(a, b) return (a.info.ended or a.t) > (b.info.ended or b.t) end)
  local nLive = #live
  for i = 1, math.min(MAX_ENDED, #ended) do live[#live + 1] = ended[i] end
  return live, nLive
end

local function fill(M)
  return function(it)
    local r, info, now, me = it.r, it.info, it.now or ns.Now(), it.me or ns.Me()
    local cm = r.c and r.c[me] or {}
    local s = { title = ns.KeyLabel(r.k), money = payText(r) }
    if it.ended then
      s.grey = true
      s.qty = r.q
      s.sub = "|cff999999para " .. ns.DisplayName(r.a) .. " · " .. (Data.STATE_LABEL[info.state] or info.state) .. "|r"
      return s
    end
    local pending = it.pending
    s.qty = pending
    local w = cm.w and Data.WHEN[cm.w]
    local parts = { "para " .. ns.AuthorText(r.a) }
    if w then parts[#parts + 1] = w.label:lower() end
    if cm.by then
      local left = cm.by - now
      parts[#parts + 1] = left > 0 and ((left < 3600 and "|cffff4040" or "|cffbbbbbb") .. "plazo " .. ns.FormatDuration(left) .. "|r")
        or "|cffff4040plazo pasado|r"
    end
    if #info.owners > 1 then parts[#parts + 1] = string.format("|cff999999haces %d de %d|r", pending, r.q) end
    s.sub = table.concat(parts, " |cff666666·|r ")
    s.hint = ns.UI.MaterialsStatus(r, pending)
    local missing = ns.UI.MissingMaterials(r, pending)
    local kind = ns.ParseKey(r.k)
    if r.demo then
      s.button = { label = "ENVIAR (EJEMPLO)", color = W.GREEN, fn = function() ns.Demo.SimulateMail(r) end }
    elseif kind == "e" then
      s.button = { label = "QUEDAR", color = W.GREEN, fn = function() ns.SendTell(r.a) end,
        tip = "Un encantamiento se hace en persona: susúrrale para quedar." }
    else
      local can = ns.Mail.CanPrepare()
      s.button = { label = "PREPARAR CORREO", color = W.GREEN, can = can, fn = function() ns.Mail.Prepare(r, pending) end,
        tip = can and "Pone el destinatario y el asunto: tú metes los objetos y envías. Se apunta solo."
          or "Abre un buzón para preparar el correo." }
    end
    local small = {}
    if kind ~= "e" then small[#small + 1] = { label = "susurrar", fn = function() ns.SendTell(r.a) end } end
    if type(missing) == "table" and #missing > 0 then
      small[#small + 1] = { label = "pedir lo que falta", fn = function() askMissing(r, missing) end,
        tip = "Pide a la hermandad los materiales que te faltan." }
    end
    if #Data.ExtendOptions(r, now) > 0 then
      small[#small + 1] = { label = "más tiempo", fn = function() W.ExtendRequest(r) end, tip = "Pedir un plazo más largo (solo una vez)." }
    end
    small[#small + 1] = { label = "soltar", fn = function()
      W.Confirm("¿Seguro que ya no lo vas a hacer? Vuelve al Tablón para otro.", function() ns.Sync.Release(r.id) end)
    end }
    s.small = small
    return s
  end
end

ns.UI.MarketView("jobs", function(view, M)
  view.title = W.Text(view, "GameFontNormal")
  view.title:SetPoint("TOPLEFT", 4, -8)
  view.title:SetText("Lo que haces para otros")
  view.count = W.Text(view, "GameFontHighlightSmall", "RIGHT")
  view.count:SetPoint("TOPRIGHT", -4, -10)
  view.count:SetTextColor(0.7, 0.7, 0.7)
  M.CardList(view, 30, fill(M), "No te has encargado de nada. En el Tablón, «ME ENCARGO».",
    { label = "Ir al Tablón", fn = function() ns.UI.MarketGo("board") end })

  function view:Refresh(data)
    if not data then return end
    view.data = data
    data.ended = data.ended or M.EndedItems(data.g, data.me, data.now)
    local items, live = collectJobs(data)
    view:SetCards(items)
    view.count:SetText(string.format("%d por enviar", live))
    ns.UI.MarketDetail.Refresh(items)
  end

  function view:Select(id)
    for _, it in ipairs(view.shown or {}) do
      if it.id == id then return ns.UI.MarketDetail.Show(it) end
    end
  end
end)
