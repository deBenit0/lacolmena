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

---------------------------------------------------------------------------
-- Contra reembolso seguro
-- El buzón de Classic solo deja marcar "Contra reembolso" cuando ya hay objetos adjuntos;
-- sin objetos vuelve a "Enviar dinero" (y la cantidad se REGALARÍA). Por eso el addon no pone
-- la cantidad al preparar el correo: la recuerda y la pone cuando el juego actualiza el buzón
-- con objetos dentro, siempre en modo reembolso. Si se quitan los objetos, la vuelve a quitar.
---------------------------------------------------------------------------
local cod -- { to = destinatario, amount = cobre }

local function hasAttachments()
  for i = 1, ATTACHMENTS_MAX_SEND or 12 do
    if HasSendMailItem and HasSendMailItem(i) then return true end
  end
  return false
end

local function currentMoney()
  return (MoneyInputFrame_GetCopper and SendMailMoney and MoneyInputFrame_GetCopper(SendMailMoney)) or 0
end

local function applyCOD()
  if not cod or not SendMailCODButton or not SendMailMoney or not MoneyInputFrame_SetCopper then return end
  -- Si ha cambiado el destinatario, ya no es nuestro correo.
  local to = SendMailNameEditBox and SendMailNameEditBox:GetText() or ""
  if to:lower() ~= ns.ShortName(cod.to):lower() and to:lower() ~= cod.to:lower() then
    cod = nil
    return
  end
  if hasAttachments() and SendMailCODButton:IsEnabled() then
    if not SendMailCODButton:GetChecked() and SendMailRadioButton_OnClick then SendMailRadioButton_OnClick(2) end
    if SendMailCODButton:GetChecked() and currentMoney() ~= cod.amount then
      MoneyInputFrame_SetCopper(SendMailMoney, cod.amount)
    end
  elseif currentMoney() == cod.amount then
    -- Sin objetos el juego vuelve a "Enviar dinero": nunca dejar ahí nuestra cantidad.
    MoneyInputFrame_SetCopper(SendMailMoney, 0)
  end
end
Mail.ApplyCOD = applyCOD

function Mail.SetPendingCOD(to, amount)
  if not amount or amount <= 0 then
    cod = nil
    return
  end
  cod = { to = to, amount = amount }
  ns.Print("pon los objetos en el correo: se marcará \"Contra reembolso\" de %s y se le cobrará al recogerlo.",
    ns.FormatMoney(amount))
  applyCOD()
end

function Mail.PendingCOD() return cod end

if SendMailFrame_Update then
  hooksecurefunc("SendMailFrame_Update", function() ns.SafeCall(applyCOD) end)
end
-- Al adjuntar o quitar objetos el juego avisa con este evento (y actualiza el buzón).
ns.On("MAIL_SEND_INFO_UPDATE", function() ns.After(0, applyCOD) end)
ns.On("MAIL_SEND_SUCCESS", function() cod = nil end)
ns.On("MAIL_CLOSED", function() cod = nil end)

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
  Mail.SetPendingCOD(r.a, r.g and math.floor(r.g * amount / r.q) or 0)
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
  Mail.SetPendingCOD(who, (price or 0) * amount)
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
