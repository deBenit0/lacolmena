-- Mercado: ventanita con el detalle de una fila (pedido, oferta, ofrezco fabricar, pedido de la
-- hermandad o pedido de Blizzard) y todas sus acciones. Se abre al pulsar una fila del Tablón o
-- una tarjeta de Mis pedidos, Mis encargos o Mis ofertas. Es el detalle del Mercado de la 0.34,
-- ahora aparte y con varios encargados por pedido.
local _, ns = ...
local W, Data = ns.W, ns.Data

local DETAIL_W, BODY_H = 340, 420
local D = {}
ns.UI.MarketDetail = D

-- Nombre de un enlace sin los corchetes (el color se queda).
local function noBrackets(text)
  return (tostring(text or ""):gsub("|h%[(.-)%]|h", "|h%1|h"))
end

local function payText(r)
  local parts = {}
  if r.g then parts[#parts + 1] = ns.FormatMoney(r.g) end
  if r.pi then
    local ids = {}
    for id in pairs(r.pi) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do parts[#parts + 1] = r.pi[id] .. "x " .. ns.KeyLabel("i" .. id) end
  end
  return #parts > 0 and table.concat(parts, " + ") or nil
end

-- Materiales que hacen falta para toda la petición (primera variante conocida).
local function neededMaterials(r)
  local rec = Data.GetIndex()[r.k]
  local profs = {}
  if r.pk then profs[#profs + 1] = r.pk end
  if rec then
    for pk in pairs(rec.profs) do
      if pk ~= r.pk then profs[#profs + 1] = pk end
    end
  end
  for _, pk in ipairs(profs) do
    local ik = Data.InfoKey(pk, r.k)
    local info = Data.GetInfo(ik)
    local var = info and info.v and info.v[1]
    if var then
      local times = math.ceil(r.q / math.max(1, var.m or 1))
      local ids, parts = {}, {}
      for id in pairs(var.r) do ids[#ids + 1] = id end
      table.sort(ids)
      for _, id in ipairs(ids) do parts[#parts + 1] = (var.r[id] * times) .. "x " .. ns.KeyName("i" .. id) end
      return table.concat(parts, ", ")
    end
    if rec then ns.Sync.AskInfo(ik) end
  end
end

-- Pasos de un pedido: pedido → aceptado → enviado → entregado. Devuelve el texto con el paso
-- en el que está encendido.
local STEPS = { "Pedido", "Aceptado", "Enviado", "Entregado" }
local function stepsText(r, info)
  local step = 1
  if info.state == "done" then
    step = 4
  elseif info.owner or info.pending > 0 then
    step = 2
    for _, c in ipairs(info.commits or {}) do
      if (c.mailed or 0) > 0 or (c.delivered or 0) > 0 then step = 3 end
    end
  end
  if info.state == "closed" or info.state == "expired" then
    return "|cff999999" .. (Data.STATE_LABEL[info.state] or info.state) .. "|r"
  end
  local parts = {}
  for i, label in ipairs(STEPS) do
    if i < step then
      parts[i] = "|cff40ff40" .. label .. "|r"
    elseif i == step then
      parts[i] = "|cffffffff[" .. label .. "]|r"
    else
      parts[i] = "|cff777777" .. label .. "|r"
    end
  end
  return table.concat(parts, " |cff999999›|r ")
end

-- Cuándo caduca algo, en corto ("caduca en 2 d"); en rojo si queda menos de un día.
local function expiresText(at, now)
  if not at then return nil end
  local left = at - now
  if left <= 0 then return "|cffff4040caducado|r" end
  local color = left < 86400 and "|cffff4040" or "|cffbbbbbb"
  return color .. "caduca en " .. ns.FormatDuration(left) .. "|r"
end

-- Con una sola persona, directamente; con varias, se elige ({ name = ... } cada una).
function D.PickPerson(people, title, fn)
  if #people == 1 then return fn(people[1]) end
  local labels = {}
  for i = 1, math.min(4, #people) do labels[i] = ns.DisplayName(people[i].name) end -- caben 4 botones
  W.Choose(title, nil, labels, function(i) if people[i] then fn(people[i]) end end)
end

local detail
local function build()
  detail = W.Panel("HDFProfMarketDetail", UIParent, DETAIL_W, BODY_H)
  detail:SetFrameStrata("HIGH")
  detail:SetToplevel(true)
  detail:SetClampedToScreen(true)
  detail:Hide()
  tinsert(UISpecialFrames, "HDFProfMarketDetail")
  detail.close = W.CloseButton(detail)
  detail.close:SetPoint("TOPRIGHT", 2, 2)
  -- Se cierra con la ventana del addon.
  if HDFProfPanel then HDFProfPanel:HookScript("OnHide", function() detail:Hide() end) end
  detail.icon = CreateFrame("Button", nil, detail)
  detail.icon:SetSize(40, 40)
  detail.icon:SetPoint("TOPLEFT", 10, -10)
  detail.iconTex = detail.icon:CreateTexture(nil, "ARTWORK")
  detail.iconTex:SetAllPoints()
  W.KeyTooltip(detail.icon, function() return detail.item and detail.item.k end)
  detail.title = W.Text(detail, "GameFontNormalLarge")
  detail.title:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 8, -2)
  detail.title:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.title:SetWordWrap(false)
  detail.sub = W.Text(detail, "GameFontHighlightSmall")
  detail.sub:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -4)
  detail.sub:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.sub:SetWordWrap(false)
  detail.steps = W.Text(detail, "GameFontHighlightSmall")
  detail.steps:SetPoint("TOPLEFT", 12, -58)
  detail.steps:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  -- Pedidos de la hermandad: barra dorada con lo aportado.
  detail.progress = W.Progress(detail, DETAIL_W - 24, 16)
  detail.progress:SetPoint("TOPLEFT", 12, -56)
  detail.progress:Hide()
  detail.infoHeader = W.Header(detail)
  detail.infoHeader:SetPoint("TOPLEFT", 8, -78)
  detail.infoHeader:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
  detail.infoHeader:Hide()
  detail.info = W.Text(detail, "GameFontHighlightSmall")
  detail.info:SetPoint("TOPLEFT", 12, -76)
  detail.info:SetSize(DETAIL_W - 24, 96)
  detail.info:SetJustifyV("TOP")
  detail.info:SetSpacing(1)
  detail.whoLabel = W.Header(detail)
  detail.whoLabel:SetPoint("TOPLEFT", 8, -170)
  detail.whoLabel:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
  detail.crafters = W.Crafters(detail, DETAIL_W - 16, 3, 26, true)
  detail.crafters:SetPoint("TOPLEFT", 8, -194)
  -- Materiales de la receta (cuántos tienes).
  detail.matsLabel = W.Header(detail)
  detail.matsLabel:Hide()
  local function reagents()
    detail.reagents = detail.reagents or ns.UI.ReagentsBlock(detail, DETAIL_W - 24)
    return detail.reagents
  end
  local LINE_H = 14

  -- b1 es la acción principal (grande, abajo); b2, b3, x1, x2 y x3, pequeñas, encima en filas de 3.
  detail.b1 = W.Button(detail, "", DETAIL_W - 16, 30)
  detail.b1:SetPoint("BOTTOMLEFT", 8, 8)
  detail.b1:SetFontSize("large")
  detail.b1:SetPrimary(true)
  detail.b1.upper = true
  detail.small = {}
  for _, key in ipairs({ "b2", "b3", "x1", "x2", "x3" }) do
    detail[key] = W.Button(detail, "", 104, 20)
    detail.small[#detail.small + 1] = detail[key]
  end
  -- Coloca las pequeñas que se ven, de izquierda a derecha y de abajo arriba.
  function detail:LayoutButtons()
    local n = 0
    for _, b in ipairs(self.small) do
      if b:IsShown() then
        local col, line = n % 3, math.floor(n / 3)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", self.b1, "TOPLEFT", col * 108, 3 + line * 22)
        n = n + 1
      end
    end
  end
  for _, b in ipairs({ detail.b1, detail.b2, detail.b3, detail.x1, detail.x2, detail.x3 }) do
    if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
    b:SetScript("OnEnter", function(self)
      if not self.tip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  detail.empty = W.Text(detail, "GameFontNormal", "CENTER")
  detail.empty:SetPoint("CENTER", 0, 20)
  detail.empty:SetWidth(DETAIL_W - 40)
  detail.empty:SetTextColor(0.6, 0.6, 0.6)

  local function setButton(b, text, enabled, onClick, tipText)
    if not text then
      b:Hide()
      return
    end
    b:SetText(b.upper and W.Upper(text) or text)
    b:SetEnabled(enabled and true or false)
    b:SetScript("OnClick", onClick)
    b.tip = tipText
    b:Show()
  end

  -- Materiales de la receta de "key" desde la altura y (los mismos del catálogo). prefer: la
  -- profesión que se prefiere si la hacen varias. Devuelve dónde sigue.
  local function showReagents(key, prefer, y)
    local rec = Data.GetIndex()[key]
    local pk = rec and next(rec.profs) and ((prefer and rec.profs[prefer] and prefer)
      or Data.SingleProfession(key) or next(rec.profs))
    if not pk then return y end
    detail.matsLabel:ClearAllPoints()
    detail.matsLabel:SetPoint("TOPLEFT", 8, y)
    detail.matsLabel:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
    local var, variants, h = reagents():Set(key, pk, 12, y - 24)
    local note
    if var and (var.m or 1) > 1 then
      note = string.format("(salen %d por vez)", var.m)
    elseif variants and variants > 1 then
      note = string.format("(hay %d recetas; se muestra una)", variants)
    end
    detail.matsLabel:SetText("Materiales", note)
    detail.matsLabel:Show()
    return y - 24 - h - 6
  end

  local function setWho(key, withGatherers, labelText)
    local rows = ns.UI.CrafterRows and ns.UI.CrafterRows(key, withGatherers) or {}
    detail.whoLabel:SetText(labelText, #rows == 0 and "|cffff8040nadie de la hermandad lo tiene publicado|r" or nil)
    detail.crafters:SetItems(rows)
    detail.whoLabel:Show()
    detail.crafters:Show()
  end

  -- Pedido normal.
  local function showRequest(item)
    local r, now, me = item.r, ns.Now(), ns.Me()
    local info = Data.RequestInfo(r, now)
    local _, _, link = ns.KeyInfo(r.k)
    detail.title:SetText(string.format("%dx %s", r.q, noBrackets(link or ns.KeyName(r.k))))
    local karma = ns.Social.AmOfficer() and (" |cffbbbbbb(karma " .. Data.KarmaText(r.a) .. ")|r") or ""
    detail.sub:SetText("pide " .. ns.AuthorText(r.a) .. karma .. " |cffbbbbbb· hace "
      .. ns.FormatDuration(now - (r.t or now)) .. "|r")
    detail.steps:SetText(stepsText(r, info))
    local lines = {}
    if info.moderated then lines[#lines + 1] = "|cffff8040Lo ha cerrado un oficial.|r" end
    if ns.Social.IsPriority(r.id) then lines[#lines + 1] = "|cffff80ffPrioridad de la hermandad.|r" end
    if Data.IsActiveState(info.state) then
      lines[#lines + 1] = string.format("Entregadas: %d de %d   %s", info.delivered, r.q, expiresText(info.expires, now) or "")
    end
    lines[#lines + 1] = r.m and "Materiales: |cff40ff40los pone quien pide|r" or "Materiales: |cffffd100los pone quien fabrica|r"
    local needed = neededMaterials(r)
    if needed then lines[#lines + 1] = "|cffbbbbbbHace falta: " .. needed .. "|r" end
    lines[#lines + 1] = "Propina: " .. (payText(r) or "|cffbbbbbbninguna|r")
    lines[#lines + 1] = "Prisa: " .. (r.pr and ("|cffff9933" .. Data.WHEN[r.pr].need .. "|r") or "sin prisa")
    if r.nt then lines[#lines + 1] = "Nota: |cffffffff" .. r.nt .. "|r" end
    for _, name in ipairs(info.owners) do
      local cm = r.c[name]
      local w = cm.w and Data.WHEN[cm.w]
      lines[#lines + 1] = "Lo hace: " .. ns.WhoColored(name)
        .. (#info.owners > 1 and string.format(" |cffffffff%d|r", cm.n - Data.DeliveredOf(cm)) or "")
        .. (w and (" (" .. w.label:lower() .. ")") or "")
        .. (cm.by and (", plazo " .. ns.FormatDuration(math.max(0, cm.by - now))) or "")
    end
    if #info.owners > 0 and info.state == "open" then
      lines[#lines + 1] = string.format("|cffffd100Quedan %d libres.|r", info.remaining)
    end
    if not item.mine then
      local mats = ns.UI.MaterialsStatus(r, item.pending > 0 and item.pending or info.remaining)
      if mats then lines[#lines + 1] = mats end
    end
    local mineCommit = r.c and r.c[me]
    if mineCommit and Data.CommitActive(mineCommit, now, r) then
      lines[#lines + 1] = string.format("|cff40ff40Envíale %d por correo a %s: se completa solo.|r",
        mineCommit.n - Data.DeliveredOf(mineCommit), ns.DisplayName(r.a))
    end
    if r.demo then lines[#lines + 1] = "|cffff8040Pedido de ejemplo: acéptalo y pulsa «Enviar (ejemplo)».|r" end
    detail.info:SetText(table.concat(lines, "\n"))
    setWho(r.k, true, "Quién lo fabrica")

    local active = Data.IsActiveState(info.state)
    local officer = ns.Social.AmOfficer() and active
    if r.a == me then
      -- Mi pedido: recibido en mano, renovar, borrar.
      local targets = {}
      for _, c in ipairs(info.commits) do
        if c.active then targets[#targets + 1] = c end
      end
      -- Se le pasó el plazo sin entregar del todo: aún se puede apuntar lo que llegue.
      if #targets == 0 and info.late then targets[1] = info.late end
      local function received(target)
        local left = math.max(1, (target.pending > 0) and target.pending or (r.q - info.delivered))
        local byMail = target.mailed or 0
        local text = byMail > 0
          and string.format("%s ya te ha enviado %d por correo (contado). ¿Cuántos MÁS te ha dado en mano?",
            ns.DisplayName(target.name), byMail)
          or string.format("¿Cuántos te ha dado %s en mano? (lo del correo se cuenta solo)", ns.DisplayName(target.name))
        W.AskAmount(text, left, function(n) ns.Sync.ConfirmDelivery(r.id, target.name, n) end)
      end
      setButton(detail.b1, "Recibido", (active or info.state == "expired") and #targets > 0, function()
        D.PickPerson(targets, "¿Quién te lo ha dado?", received)
      end, "Apunta lo que te han dado en mano. Lo del correo se cuenta solo.")
      setButton(detail.b2, "Renovar", active or info.state == "expired", function() ns.Sync.Renew(r.id) end,
        "Vuelve a contar los 7 días desde ahora.")
      setButton(detail.b3, "Borrar pedido", active or info.state == "expired", function()
        W.Confirm("¿Borrar este pedido? Desaparecerá del Mercado de todos.", function() ns.Sync.Close(r.id) end)
      end)
      setButton(detail.x1, active and "Anunciar" or nil, true, function()
        -- Lo escribe el jugador (Intro): el juego bloquea a veces el que manda el addon.
        local m = ns.Extras.AnnounceMacro("request", r)
        if m then W.ChatCommand(m, "anunciarlo en el chat de hermandad") else ns.Print("no estás en ninguna hermandad.") end
      end, "Anunciarlo en el chat de hermandad (para los que no tienen el addon).")
    else
      local myActive = mineCommit and Data.CommitActive(mineCommit, now, r)
      if myActive then
        setButton(detail.b1, "Más tiempo", #Data.ExtendOptions(r, now) > 0, function() W.ExtendRequest(r) end,
          "Pedir un plazo más largo (solo una vez).")
      else
        setButton(detail.b1, "Me encargo", info.state == "open", function() W.AcceptRequest(r) end,
          "Dices de cuántos te encargas y cuándo los tendrás; el resto sigue en el Tablón.")
      end
      if r.demo and myActive and mineCommit.n > Data.DeliveredOf(mineCommit) then
        setButton(detail.b2, "Enviar (ejemplo)", true, function() ns.Demo.SimulateMail(r) end)
      elseif myActive then
        local can = ns.Mail.CanPrepare()
        setButton(detail.b2, "Preparar correo", can, function() ns.Mail.Prepare(r, mineCommit.n - Data.DeliveredOf(mineCommit)) end,
          not can and "Abre el buzón para preparar el correo." or nil)
      else
        setButton(detail.b2, nil)
      end
      setButton(detail.b3, "Susurrar", true, function() ns.SendTell(r.a) end)
      setButton(detail.x1, myActive and "Soltar" or nil, true, function()
        W.Confirm("¿Seguro que ya no lo vas a hacer?", function() ns.Sync.Release(r.id) end)
      end, "Lo dejas y vuelve al Mercado para otro.")
    end
    if officer then
      local isPri = ns.Social.IsPriority(r.id)
      setButton(detail.x2, isPri and "Quitar prioridad" or "Prioridad", true,
        function() ns.Social.SetPriority(r.id, not isPri, ns.Now()) end, "Solo oficiales: lo pone arriba del todo.")
      setButton(detail.x3, r.a ~= me and "Cerrar (oficial)" or nil, true, function()
        W.Confirm("¿Cerrar este pedido de " .. ns.DisplayName(r.a) .. " como oficial?", function()
          ns.Social.ModClose(r.id, ns.Now())
        end)
      end)
    else
      setButton(detail.x2, nil)
      setButton(detail.x3, nil)
    end
    -- Mi pedido con encargado que no lo envía: quitárselo para que lo coja otro.
    if r.a == me and active and #info.owners > 0 then
      local people = {}
      for _, name in ipairs(info.owners) do people[#people + 1] = { name = name } end
      setButton(detail.x3, "Quitar encargado", true, function()
        D.PickPerson(people, "¿A quién le quitas el encargo?", function(p)
          W.Confirm(string.format("¿Quitarle el encargo a %s? Volverá al Mercado para que lo coja otro "
            .. "(lo que ya te haya enviado se queda contado).", ns.DisplayName(p.name)), function()
            ns.Sync.Reject(r.id, p.name)
          end)
        end)
      end, "Si no te lo envía, para que lo pueda aceptar otro.")
    end
  end

  -- Pedido de la hermandad (aportan varios).
  local function showNeed(item)
    local n = item.need
    local _, _, link = ns.KeyInfo(item.k)
    detail.title:SetText(string.format("%dx %s", n.q, noBrackets(link or ns.KeyName(item.k))))
    detail.sub:SetText("|cffff9933para la hermandad|r · lo pide " .. ns.AuthorText(n.owner))
    detail.steps:Hide()
    detail.progress:SetValue(n.given, n.q, string.format("aportado %d de %d · faltan %d", n.given, n.q, n.left))
    detail.progress:Show()
    local lines = {}
    for i = 1, math.min(3, #n.donors) do
      lines[#lines + 1] = ns.WhoColored(n.donors[i].name) .. "  |cffffffff" .. n.donors[i].n .. "|r"
    end
    if #n.donors > 3 then lines[#lines + 1] = string.format("|cffbbbbbby %d más|r", #n.donors - 3) end
    local have = ns.ItemCount(n.id)
    if have > 0 and not item.mine then lines[#lines + 1] = string.format("|cff40ff40Tienes %d.|r", have) end
    if #n.donors > 0 then
      detail.infoHeader:SetText("Aportan")
      detail.infoHeader:Show()
      detail.info:ClearAllPoints()
      detail.info:SetPoint("TOPLEFT", 12, -102)
      detail.info:SetHeight(64)
    end
    detail.info:SetText(table.concat(lines, "\n"))
    setWho(item.k, true, "Quién lo fabrica")
    if item.mine then
      setButton(detail.b1, "Quitar", true, function()
        W.Confirm("¿Quitar este pedido de la hermandad?", function() ns.Social.RemoveNeed(n.id) end)
      end)
    else
      setButton(detail.b1, "Aportar", true, function() ns.UI.ContributeNeed(n) end, "Se lo mandas por correo y se apunta solo.")
    end
    setButton(detail.b2, nil)
    setButton(detail.b3, nil)
    setButton(detail.x1, nil)
    setButton(detail.x2, nil)
    setButton(detail.x3, nil)
  end

  -- Pedido de fabricación de Blizzard: se coge en la ventana de profesión.
  local function showOrder(item)
    local o = item.order
    detail.title:SetText(ns.KeyLabel(item.k))
    detail.sub:SetText("pide " .. ns.AuthorText(o.owner) .. " |cffbbbbbb· hace " .. ns.FormatDuration(ns.Now() - o.t) .. "|r")
    detail.steps:SetText("|cff40c0ffPedido de fabricación de Blizzard|r")
    detail.info:SetText(item.mine and "|cff999999Lo verán quienes saben hacerlo.|r"
      or "Cógelo en tu profesión: pestaña Pedidos › Hermandad (puede que ya esté hecho).")
    setWho(item.k, false, "Quién lo fabrica")
    if item.mine then
      setButton(detail.b1, "Borrar aviso", true, function()
        W.Confirm("¿Borrar este aviso de pedido? Dejará de salir a los demás.\n(En la mesa de pedidos del juego "
          .. "cancélalo tú allí.)", function() ns.Orders.Remove(o.id) end)
      end)
    else
      setButton(detail.b1, "Ocultar", true, function() ns.Orders.Dismiss(o.id) end)
    end
    setButton(detail.b2, not item.mine and "Susurrar" or nil, true, function() ns.SendTell(o.owner) end)
    setButton(detail.b3, nil)
    setButton(detail.x1, nil)
    setButton(detail.x2, nil)
    setButton(detail.x3, nil)
  end

  function D.Fill(item)
    detail.item = item
    local parts = { detail.icon, detail.title, detail.sub, detail.steps, detail.info, detail.whoLabel, detail.crafters,
      detail.b1, detail.b2, detail.b3, detail.x1, detail.x2, detail.x3 }
    for _, p in ipairs(parts) do p:SetShown(item ~= nil) end
    detail.progress:Hide()
    detail.infoHeader:Hide()
    detail.matsLabel:Hide()
    if detail.reagents then detail.reagents:Hide() end
    detail.whoLabel:ClearAllPoints()
    detail.whoLabel:SetPoint("TOPLEFT", 8, -170)
    detail.whoLabel:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
    detail.info:ClearAllPoints()
    detail.info:SetPoint("TOPLEFT", 12, -76)
    detail.info:SetHeight(96)
    detail.empty:SetShown(item == nil)
    if not item then
      detail.empty:SetText("")
      return
    end
    local _, icon = ns.KeyInfo(item.k)
    detail.iconTex:SetTexture(icon)
    if item.kind == "need" then showNeed(item)
    elseif item.kind == "co" then showOrder(item)
    else showRequest(item) end
    detail:LayoutButtons()
  end

  detail.title:SetPoint("RIGHT", detail, "RIGHT", -30, 0)
end

-- Abre la ventanita con "item" (una fila de ns.UI.MarketCollect), pegada a la derecha del addon.
function D.Show(item)
  if not item then return end
  if not detail then build() end
  detail:ClearAllPoints()
  if HDFProfPanel and HDFProfPanel:IsShown() then
    detail:SetScale(HDFProfPanel:GetScale())
    detail:SetPoint("TOPLEFT", HDFProfPanel, "TOPRIGHT", 4, -40)
  else
    detail:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
  D.id = item.id
  detail:Show()
  D.Fill(item)
end

function D.Hide()
  if detail then detail:Hide() end
  D.id = nil
end

function D.IsShown() return detail ~= nil and detail:IsShown() end

-- Con los datos nuevos: vuelve a pintar lo que se ve (o se cierra si ya no está).
function D.Refresh(items)
  if not D.IsShown() then return end
  for _, it in ipairs(items or {}) do
    if it.id == D.id then return D.Fill(it) end
  end
  -- Un pedido abierto desde otra pestaña: sigue abierto con sus datos al día.
  local cur, g = detail.item, ns.G()
  local r = cur and cur.kind == "req" and g and g.requests[cur.id]
  if r then
    cur.r, cur.info, cur.now = r, Data.RequestInfo(r, ns.Now()), ns.Now()
    return D.Fill(cur)
  end
  D.Hide()
end
