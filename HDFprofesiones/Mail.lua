-- Entregas por correo: al enviar un correo con objetos a quien hizo una petición que
-- yo había aceptado, la entrega se apunta sola (y la petición se completa si ya está todo).
local _, ns = ...
local Data = ns.Data
local Mail = {}
ns.Mail = Mail

local pending -- correo enviado que espera la confirmación del servidor

local function attachedItems()
  local items = {}
  for i = 1, ATTACHMENTS_MAX_SEND or 12 do
    local link = GetSendMailItemLink and GetSendMailItemLink(i)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id then
      -- Según la versión: nombre, id, icono, cantidad...  o  nombre, icono, cantidad...
      local _, b, c, d = GetSendMailItem(i)
      local count = (b == id) and d or c
      items[id] = (items[id] or 0) + (tonumber(count) or 1)
    end
  end
  return items
end

function Mail.OnSendMail(recipient)
  if type(recipient) ~= "string" or recipient == "" then return end
  local items = attachedItems()
  if next(items) then pending = { to = ns.FullName(recipient), items = items } end
end

function Mail.OnSent()
  local mail = pending
  pending = nil
  if not mail or not ns.G() then return end
  local changed = Data.RegisterMail(mail.to, mail.items, ns.Now())
  for _, r in ipairs(changed) do
    local cm = r.c[ns.Me()]
    ns.Print("apuntado en la petición de %s: %d de %d %s enviadas por correo.",
      ns.ShortName(r.a), Data.DeliveredOf(cm), cm.n, ns.KeyLabel(r.k))
    ns.Sync.PushRequest(r.id, "high")
  end
  -- Lo que queda puede ser de mis ofertas.
  local offered = 0
  for _, d in ipairs(ns.Offers.RegisterMail(mail.to, mail.items, ns.Now())) do
    offered = offered + 1
    ns.Print("apuntado en tu oferta: %dx %s enviadas a %s.", d.n, ns.KeyLabel("i" .. d.id), ns.ShortName(d.who))
  end
  -- Y lo que quede, donaciones a lo que necesita la hermandad.
  local donated = ns.Social.RegisterMail(mail.to, mail.items, ns.Now())
  for _, d in ipairs(donated) do
    ns.Print("donación apuntada: %dx %s para la hermandad (a %s). ¡Gracias!", d.n, ns.KeyLabel("i" .. d.id), ns.ShortName(d.owner))
  end
  ns.Social.AddHelp(#changed + offered + #donated)
  if #changed > 0 then ns.Fire("DATA_CHANGED", "mail") end
end

-- Abre la pestaña de enviar del buzón con el destinatario y el asunto puestos.
function Mail.CanPrepare()
  return MailFrame ~= nil and MailFrame:IsShown() and SendMailNameEditBox ~= nil
end

function Mail.Prepare(r, amount)
  if not Mail.CanPrepare() then return false end
  if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2) end
  SendMailNameEditBox:SetText(ns.ShortName(r.a))
  if SendMailSubjectEditBox then
    SendMailSubjectEditBox:SetText(string.format("%dx %s", amount, ns.KeyName(r.k)))
  end
  -- Si la petición ofrece oro, el correo va contra reembolso: se le cobra al recogerlo.
  local cod = r.g and math.floor(r.g * amount / r.q) or 0
  if cod > 0 then
    if SendMailCODButton and SendMailMoney and MoneyInputFrame_SetCopper then
      SendMailCODButton:Click()
      MoneyInputFrame_SetCopper(SendMailMoney, cod)
    elseif SetSendMailCOD then
      SetSendMailCOD(cod)
    end
    ns.Print("correo contra reembolso de %s: se le cobrará al recogerlo.", ns.FormatMoney(cod))
  end
  return true
end

if SendMail then hooksecurefunc("SendMail", function(recipient) ns.SafeCall(Mail.OnSendMail, recipient) end) end
ns.On("MAIL_SEND_SUCCESS", Mail.OnSent)
ns.On("MAIL_FAILED", function() pending = nil end)

-- Lo mismo para una oferta mía: destinatario, asunto y, si tiene precio, contra reembolso.
function Mail.PrepareOffer(who, id, amount, price)
  if not Mail.CanPrepare() then return false end
  if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2) end
  SendMailNameEditBox:SetText(ns.ShortName(who))
  if SendMailSubjectEditBox then
    SendMailSubjectEditBox:SetText(string.format("%dx %s", amount, ns.KeyName("i" .. id)))
  end
  local cod = (price or 0) * amount
  if cod > 0 then
    if SendMailCODButton and SendMailMoney and MoneyInputFrame_SetCopper then
      SendMailCODButton:Click()
      MoneyInputFrame_SetCopper(SendMailMoney, cod)
    elseif SetSendMailCOD then
      SetSendMailCOD(cod)
    end
    ns.Print("correo contra reembolso de %s: se le cobrará al recogerlo.", ns.FormatMoney(cod))
  end
  ns.Print("pon %dx %s en el correo y envíalo: se apuntará solo.", amount, ns.KeyLabel("i" .. id))
  return true
end

-- Donar a una necesidad de la hermandad: destinatario (el oficial) y asunto.
function Mail.PrepareNeed(owner, id, amount)
  if not Mail.CanPrepare() then return false end
  if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2) end
  SendMailNameEditBox:SetText(ns.ShortName(owner))
  if SendMailSubjectEditBox then
    SendMailSubjectEditBox:SetText(string.format("Para la hermandad: %dx %s", amount, ns.KeyName("i" .. id)))
  end
  ns.Print("pon %dx %s en el correo y envíalo: la donación se apuntará sola.", amount, ns.KeyLabel("i" .. id))
  return true
end
