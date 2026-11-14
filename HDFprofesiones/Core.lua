-- Los hijos del Fundillo: addon de profesiones de la hermandad.
-- Núcleo: espacio de nombres, eventos, utilidades y base de datos guardada.
local ADDON, ns = ...

ns.VERSION = "0.34.1"
ns.PROTOCOL = 1
ns.PREFIX = "HDFprofesiones"
ns.TITLE = "Los hijos del Fundillo"
-- Los tiempos se guardan en segundos desde el 1-ene-2026 (UTC): así ocupan menos al enviarlos.
ns.EPOCH = 1767225600
ns.QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

HDFProfesiones = ns -- acceso global, útil para depurar con /dump

local floor, format = math.floor, string.format

---------------------------------------------------------------------------
-- Llamadas protegidas: un fallo en una parte no rompe las demás
---------------------------------------------------------------------------
-- Registro de errores para el informe ("Copiar informe" en Mis cosas). Antes de cargar la
-- base de datos se guardan en memoria; luego, en HDFProfesionesDB.errors (máximo 20).
ns.errorLog = {}
function ns.LogError(text, stack)
  text = tostring(text)
  local log = (ns.db and ns.db.errors) or ns.errorLog
  for _, e in ipairs(log) do
    if e.m == text then
      e.n = (e.n or 1) + 1
      e.t = time and time() or e.t
      return
    end
  end
  if #log >= 20 then table.remove(log, 1) end
  log[#log + 1] = { m = text, s = stack, t = time and time() or 0, v = ns.VERSION, n = 1 }
end

local function stackText()
  if not debugstack then return nil end
  local ok, st = pcall(debugstack, 3, 6, 0)
  return ok and st or nil
end

local shownErrors = {}
local function errorHandler(err)
  ns.LogError(err, stackText())
  -- Para la fase de pruebas: avisar en el chat aunque los errores de Lua estén desactivados.
  local text = tostring(err)
  if not shownErrors[text] and DEFAULT_CHAT_FRAME then
    shownErrors[text] = true
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5050" .. (ns.TITLE or "HDF") .. " (error, mándale una captura a quien lo programa):|r " .. text)
  end
  local handler = geterrorhandler and geterrorhandler()
  if handler then
    ns.inSafeError = true -- ya está apuntado: que el gestor general no lo cuente otra vez
    local ok, res = pcall(handler, err)
    ns.inSafeError = nil
    if ok then return res end
  end
  return err
end

-- Errores del addon que no pasan por SafeCall (p. ej. en un botón): también al informe.
-- Se encadena con el gestor que hubiera (el del juego u otro addon).
if geterrorhandler and seterrorhandler then
  local previous = geterrorhandler()
  seterrorhandler(function(msg, ...)
    if not ns.inSafeError and tostring(msg):find("HDFprofesiones", 1, true) then ns.LogError(msg, stackText()) end
    if previous then return previous(msg, ...) end
  end)
end

function ns.SafeCall(fn, ...)
  local n, args = select("#", ...), { ... }
  return xpcall(function() return fn(unpack(args, 1, n)) end, errorHandler)
end
local safeCall = ns.SafeCall

---------------------------------------------------------------------------
-- Eventos del juego y mensajes internos
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers, listeners = {}, {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = eventHandlers[event]
  if not list then return end
  for i = 1, #list do safeCall(list[i], ...) end
end)

-- Escucha un evento del juego. Si el evento no existe en este cliente, se ignora.
function ns.On(event, fn)
  local list = eventHandlers[event]
  if not list then
    if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return end
    list = {}
    eventHandlers[event] = list
  end
  list[#list + 1] = fn
end

-- Mensajes internos entre módulos (por ejemplo, "DATA_CHANGED").
function ns.Listen(message, fn)
  local list = listeners[message]
  if not list then
    list = {}
    listeners[message] = list
  end
  list[#list + 1] = fn
end

function ns.Fire(message, ...)
  local list = listeners[message]
  if not list then return end
  for i = 1, #list do safeCall(list[i], ...) end
end

---------------------------------------------------------------------------
-- Temporizadores
---------------------------------------------------------------------------
function ns.After(seconds, fn)
  C_Timer.After(seconds, function() safeCall(fn) end)
end

local coalescing = {}
-- Ejecuta fn una sola vez pasados "seconds", aunque se pida muchas veces mientras tanto.
function ns.Coalesce(key, seconds, fn)
  if coalescing[key] then return end
  coalescing[key] = true
  ns.After(seconds, function()
    coalescing[key] = nil
    fn()
  end)
end

function ns.Random(a, b)
  return a + math.random() * (b - a)
end

---------------------------------------------------------------------------
-- Tiempo y formatos
---------------------------------------------------------------------------
function ns.Now()
  local t = (GetServerTime and GetServerTime()) or time()
  return t - ns.EPOCH
end

function ns.FormatDuration(seconds)
  seconds = math.max(0, floor(seconds or 0))
  if seconds >= 2 * 86400 then return format("%d d", floor(seconds / 86400)) end
  if seconds >= 86400 then return format("1 d %d h", floor((seconds - 86400) / 3600)) end
  if seconds >= 3600 then return format("%d h", floor(seconds / 3600)) end
  if seconds >= 60 then return format("%d min", floor(seconds / 60)) end
  return "menos de 1 min"
end

-- Nota de un pedido u oferta («trueque», «precio a convenir», «escríbeme por Discord»...):
-- texto corto, sin códigos del juego (la barra | abre colores y enlaces) ni saltos de línea.
ns.NOTE_MAX = 80

-- Texto que llega de otro jugador (versión, clase, horas...): sin «|» (códigos de color, enlaces,
-- imágenes), sin saltos de línea y como mucho "max" letras. Si no es texto, nil.
function ns.CleanText(text, max)
  if type(text) ~= "string" then return nil end
  text = text:gsub("|", ""):gsub("[%c]", "")
  if #text > (max or 40) then text = text:sub(1, max or 40) end
  return text
end
function ns.CleanNote(text)
  if type(text) ~= "string" then return nil end
  text = text:gsub("|", ""):gsub("[%c]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  if #text > ns.NOTE_MAX then
    -- cortar sin partir una letra con tilde
    local out = ""
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
      if #out + #ch > ns.NOTE_MAX then break end
      out = out .. ch
    end
    text = out
  end
  return text
end

-- Dinero en palabras, para el chat («1 oro 50 plata», «50 plata»): sin iconos.
function ns.MoneyWords(copper)
  copper = floor(copper or 0)
  local gold, silver, cop = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
  local parts = {}
  if gold > 0 then parts[#parts + 1] = gold .. " oro" end
  if silver > 0 then parts[#parts + 1] = silver .. " plata" end
  if cop > 0 or #parts == 0 then parts[#parts + 1] = cop .. " cobre" end
  return table.concat(parts, " ")
end

function ns.FormatMoney(copper)
  copper = floor(copper or 0)
  if GetCoinTextureString then return GetCoinTextureString(copper) end
  local gold, silver, cop = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
  local parts = {}
  if gold > 0 then parts[#parts + 1] = gold .. " o" end
  if silver > 0 then parts[#parts + 1] = silver .. " p" end
  if cop > 0 or #parts == 0 then parts[#parts + 1] = cop .. " c" end
  return table.concat(parts, " ")
end

function ns.Print(msg, ...)
  if select("#", ...) > 0 then msg = format(msg, ...) end
  local chat = DEFAULT_CHAT_FRAME
  if chat then chat:AddMessage("|cffffd100" .. ns.TITLE .. ":|r " .. msg) end
end

---------------------------------------------------------------------------
-- Nombres de personaje ("Nombre-Reino")
---------------------------------------------------------------------------
local realmCache
function ns.Realm()
  if realmCache then return realmCache end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName()
  if not realm or realm == "" then
    realm = GetRealmName and GetRealmName()
    if realm then realm = realm:gsub("[%s%-]", "") end
  end
  if realm and realm ~= "" then realmCache = realm end
  return realm or ""
end

-- Apellidos de WoW Forever: cada personaje es «Nombre Apellido». El addon guarda a cada uno
-- como «Nombre-Reino» (como siempre) y se apunta aquí su nombre completo, que es el que hace
-- falta para el correo, susurrar e invitar.
--   ns.fullNames["Nombre-Reino"] = "Nombre Apellido"
ns.fullNames = {}

function ns.SurnameSeparator()
  local c = Constants and Constants.CharacterNameSeparatorConsts
  local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
  if type(sep) == "string" and sep ~= "" and sep ~= "-" then return sep end
  return " "
end

function ns.FullName(name)
  if type(name) ~= "string" or name == "" then return nil end
  local who, realm = name:match("^([^%-]+)%-(.+)$")
  who = who or name
  who = who:match("^%s*(.-)%s*$")
  if who == "" then return nil end
  realm = realm and realm:gsub("%s", "") or ns.Realm()
  -- Con apellido: se guarda el nombre completo y se usa el nombre de pila.
  local sep = ns.SurnameSeparator()
  local cut = who:find(sep, 1, true)
  local complete
  if cut and cut > 1 then
    complete = who
    who = who:sub(1, cut - 1)
  end
  local full = (realm ~= "") and (who .. "-" .. realm) or who
  if complete then ns.fullNames[full] = complete end
  return full
end

function ns.ShortName(full)
  if type(full) ~= "string" then return "?" end
  return full:match("^([^%-]+)") or full
end

-- Nombre para ENSEÑAR: siempre con apellido si se sabe («Exagono Exagonal»), sin el reino.
-- (ShortName sigue siendo el nombre de pila, para comparar y buscar.)
function ns.DisplayName(full)
  if type(full) ~= "string" or full == "" then return "?" end
  local base = full:match("^([^%-]+)") or full
  local sep = ns.SurnameSeparator()
  if base:find(sep, 1, true) then return base end
  -- dos en la hermandad con este nombre de pila: no se sabe de cuál es, mejor no adivinar el apellido
  if ns.Guild and ns.Guild.dupes and ns.Guild.dupes[full] then return base end
  local info = ns.Guild and ns.Guild.Find and ns.Guild.Find(full)
  local raw = info and type(info.raw) == "string" and (info.raw:match("^([^%-]+)") or info.raw)
  if raw and raw:find(sep, 1, true) then return raw end
  local known = ns.fullNames[full]
  if type(known) == "string" and known ~= "" then return known end
  return base
end

function ns.Me()
  if not ns.me then
    local name, surname = UnitName("player")
    local realm = ns.Realm()
    if name and name ~= "" and realm ~= "" then
      -- Si el juego lo da entero («Ana Smith»), antes se guardaba así: se recuerda para pasar sus datos.
      if name:find(ns.SurnameSeparator(), 1, true) then ns.meOld = name .. "-" .. realm end
      ns.me = ns.FullName(name .. "-" .. realm)
      -- Forever da el apellido aparte (otros juegos dan ahí el reino, pero nunca para "player").
      if type(surname) == "string" and surname ~= "" and not ns.fullNames[ns.me] then
        ns.fullNames[ns.me] = ns.ShortName(ns.me) .. ns.SurnameSeparator() .. surname
      end
    end
  end
  return ns.me
end

function ns.ClassColor(classFile)
  local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  local c = classFile and colors and colors[classFile]
  if c then return c.r, c.g, c.b end
  return 0.85, 0.85, 0.85
end

function ns.ColoredName(full, classFile)
  local r, g, b = ns.ClassColor(classFile)
  return format("|cff%02x%02x%02x%s|r", floor(r * 255), floor(g * 255), floor(b * 255), ns.DisplayName(full))
end

---------------------------------------------------------------------------
-- Objetos, hechizos y claves de receta
-- Una receta se identifica por lo que produce: "i<itemID>" (objeto) o
-- "e<spellID>" (encantamiento, que no es un objeto).
---------------------------------------------------------------------------
local function getItemInfo(id)
  local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if fn then return fn(id) end
end

local function getItemIcon(id)
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  if GetItemIcon then return GetItemIcon(id) end
end

function ns.SpellInfo(id)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(id)
    if type(info) == "table" then return info.name, info.iconID end
    if type(info) == "string" then return info end
    return nil
  end
  if GetSpellInfo then
    local name, _, icon = GetSpellInfo(id)
    return name, icon
  end
end

-- Datos básicos de un objeto sin esperar a que el juego lo tenga en caché:
-- hueco de equipo, clase y subclase.
function ns.ItemInstant(itemID)
  local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not fn then return nil end
  local _, _, _, equipLoc, _, classID, subclassID = fn(itemID)
  return equipLoc, classID, subclassID
end

function ns.ItemCount(itemID)
  local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
  return (fn and fn(itemID)) or 0
end

function ns.ParseKey(key)
  if type(key) ~= "string" then return nil end
  local kind, id = key:match("^([ie])(%d+)$")
  if kind then return kind, tonumber(id) end
end

function ns.KeyFromLink(link)
  if type(link) ~= "string" then return nil end
  local id = link:match("item:(%d+)")
  if id then return "i" .. id end
  id = link:match("enchant:(%d+)") or link:match("spell:(%d+)")
  if id then return "e" .. id end
end

-- ¿Puede usarlo mi personaje? (clase y nivel, reglas de Classic)
-- Armadura: tela (1), cuero (2), malla (3), placas (4); escudo (6).
local ARMOR_MAX = { WARRIOR = 4, PALADIN = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2, MAGE = 1, PRIEST = 1, WARLOCK = 1 }
local SHIELDS = { WARRIOR = true, PALADIN = true, SHAMAN = true }
-- Armas por subclase: 0 hacha 1M, 1 hacha 2M, 2 arco, 3 arma de fuego, 4 maza 1M, 5 maza 2M,
-- 6 arma de asta, 7 espada 1M, 8 espada 2M, 10 bastón, 13 puño, 15 daga, 16 arrojadiza,
-- 18 ballesta, 19 varita.
local function set(list)
  local t = {}
  for _, v in ipairs(list) do t[v] = true end
  return t
end
local WEAPONS = {
  WARRIOR = set({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }),
  PALADIN = set({ 0, 1, 4, 5, 6, 7, 8 }),
  HUNTER = set({ 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }),
  ROGUE = set({ 2, 3, 4, 7, 13, 15, 16, 18 }),
  PRIEST = set({ 4, 10, 15, 19 }),
  SHAMAN = set({ 0, 1, 4, 5, 10, 13, 15 }),
  MAGE = set({ 7, 10, 15, 19 }),
  WARLOCK = set({ 7, 10, 15, 19 }),
  DRUID = set({ 4, 5, 10, 13, 15 }),
}

function ns.CanUseItem(key, class, level, minLevel)
  local kind, id = ns.ParseKey(key)
  if kind ~= "i" then return true end -- encantamientos: para cualquiera
  if minLevel and minLevel > level then return false end
  local equipLoc, classID, subclassID = ns.ItemInstant(id)
  if classID == 4 then -- armadura
    if equipLoc == "INVTYPE_CLOAK" or subclassID == 0 then return true end -- capas, anillos, abalorios...
    if subclassID == 6 then return SHIELDS[class] or false end
    if subclassID and subclassID >= 1 and subclassID <= 4 then
      local max = ARMOR_MAX[class] or 1
      if level < 40 and max >= 3 then max = max - 1 end -- malla y placas, a partir del 40
      return subclassID <= max
    end
    -- reliquias: libros (paladín), ídolos (druida) y tótems (chamán)
    local relic = ({ [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" })[subclassID]
    return relic == class
  elseif classID == 2 then -- armas
    if subclassID == 14 or subclassID == 20 then return true end -- armas varias y cañas de pescar
    local allowed = WEAPONS[class]
    return allowed == nil or allowed[subclassID] or false
  end
  return true -- bolsas y lo demás
end

-- Devuelve nombre, icono, enlace, calidad, nivel mínimo y hueco de equipo.
-- El nombre puede ser nil si el juego aún no tiene el objeto en caché (se pide solo).
function ns.KeyInfo(key)
  local kind, id = ns.ParseKey(key)
  if kind == "i" then
    local name, link, quality, _, minLevel, _, _, _, equipLoc, icon = getItemInfo(id)
    if not name then
      if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
      return nil, getItemIcon(id) or ns.QUESTION_ICON
    end
    return name, icon or getItemIcon(id) or ns.QUESTION_ICON, link, quality, minLevel, equipLoc
  elseif kind == "e" then
    local name, icon = ns.SpellInfo(id)
    local link = name and ("|cffffd000|Henchant:" .. id .. "|h[" .. name .. "]|h|r") or nil
    return name, icon or ns.QUESTION_ICON, link
  end
  return nil, ns.QUESTION_ICON
end

-- ¿Se liga al recogerlo (o es de misión)? Entonces no se puede dar a nadie: quien lo fabrica
-- se lo queda. true/false; nil si el juego aún no tiene los datos del objeto.
function ns.IsSoulbound(key)
  local kind, id = ns.ParseKey(key)
  if kind ~= "i" then return false end
  local name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = getItemInfo(id)
  if not name then return nil end
  return bindType == 1 or bindType == 4
end

function ns.KeyName(key)
  local name = ns.KeyInfo(key)
  if name then return name end
  local kind, id = ns.ParseKey(key)
  return (kind == "e" and "Encantamiento " or "Objeto ") .. tostring(id or "?")
end

-- Nombre con color/enlace si está disponible.
function ns.KeyLabel(key)
  local name, _, link = ns.KeyInfo(key)
  return link or name or ns.KeyName(key)
end

function ns.KeyHyperlink(key)
  local kind, id = ns.ParseKey(key)
  if kind == "i" then return "item:" .. id end
  if kind == "e" then return "enchant:" .. id end
end

---------------------------------------------------------------------------
-- Profesiones: se identifican por número para que no dependan del idioma
---------------------------------------------------------------------------
ns.PROFESSIONS = {
  [171] = { name = "Alquimia", spells = { 2259 }, names = { "Alquimia", "Alchemy" } },
  [164] = { name = "Herrería", spells = { 2018 }, names = { "Herrería", "Blacksmithing" } },
  [333] = { name = "Encantamiento", spells = { 7411 }, names = { "Encantamiento", "Enchanting" } },
  [202] = { name = "Ingeniería", spells = { 4036 }, names = { "Ingeniería", "Engineering" } },
  [165] = { name = "Peletería", spells = { 2108 }, names = { "Peletería", "Leatherworking" } },
  [197] = { name = "Sastrería", spells = { 3908 }, names = { "Sastrería", "Tailoring" } },
  [185] = { name = "Cocina", spells = { 2550 }, names = { "Cocina", "Cooking" } },
  [129] = { name = "Primeros auxilios", spells = { 3273 }, names = { "Primeros auxilios", "First Aid" } },
  [186] = { name = "Minería", spells = { 2575, 2656 }, names = { "Minería", "Fundición", "Mining", "Smelting" } },
  [755] = { name = "Joyería", spells = { 25229 }, names = { "Joyería", "Jewelcrafting" } },
  [773] = { name = "Inscripción", spells = { 45357 }, names = { "Inscripción", "Inscription" } },
  [40] = { name = "Venenos", spells = { 2842 }, names = { "Venenos", "Poisons" } },
  [393] = { name = "Desuello", spells = { 8613 }, names = { "Desuello", "Skinning" }, gather = true },
  [182] = { name = "Herboristería", spells = { 2366 }, names = { "Herboristería", "Herbalism" }, gather = true },
}

-- Recolección: qué habilidad consigue cada tipo de material (subclase de "Objetos comerciables").
ns.GATHER_SKILLS = { [393] = true, [182] = true, [186] = true }
local GATHER_BY_SUBCLASS = { [6] = 393, [7] = 186, [9] = 182 }
local GATHER_BY_SUBTYPE = {
  ["cuero"] = 393, ["leather"] = 393,
  ["metal y piedra"] = 186, ["metal & stone"] = 186,
  ["hierba"] = 182, ["herb"] = 182,
}

-- Habilidad de recolección que consigue un objeto; false si no es recolectable;
-- nil si el juego aún no tiene el objeto en caché.
function ns.GatherSkillFor(key)
  local kind, id = ns.ParseKey(key)
  if kind ~= "i" then return false end
  local _, instClass, instSub = ns.ItemInstant(id)
  if instClass == 7 and GATHER_BY_SUBCLASS[instSub] then return GATHER_BY_SUBCLASS[instSub] end
  local name, _, _, _, _, _, subType, _, _, _, _, classID, subclassID = getItemInfo(id)
  if not name then
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return nil
  end
  if classID == 7 and GATHER_BY_SUBCLASS[subclassID] then return GATHER_BY_SUBCLASS[subclassID] end
  return (type(subType) == "string" and GATHER_BY_SUBTYPE[subType:lower()]) or false
end

local profByName
local function buildProfessionNames()
  profByName = {}
  for id, prof in pairs(ns.PROFESSIONS) do
    for _, name in ipairs(prof.names) do profByName[name:lower()] = id end
    for _, spell in ipairs(prof.spells) do
      local name = ns.SpellInfo(spell)
      if name then profByName[name:lower()] = id end
    end
  end
end

-- Número de profesión a partir de su nombre en el idioma del cliente (o el propio nombre si no se conoce).
function ns.ProfessionKey(name)
  if type(name) ~= "string" or name == "" then return nil end
  if not profByName then buildProfessionNames() end
  return profByName[name:lower()] or name
end

function ns.ProfessionName(key)
  local prof = ns.PROFESSIONS[key]
  return prof and prof.name or tostring(key)
end

---------------------------------------------------------------------------
-- Base de datos guardada (compartida por todos los personajes de la cuenta)
---------------------------------------------------------------------------
local DEFAULT_SETTINGS = { alerts = true, sound = true, hideLowGear = true, onlyUsable = true, chatPost = true }

ns.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  HDFProfesionesDB = HDFProfesionesDB or {}
  local db = HDFProfesionesDB
  db.schema = db.schema or 1
  db.settings = db.settings or {}
  for k, v in pairs(DEFAULT_SETTINGS) do
    if db.settings[k] == nil then db.settings[k] = v end
  end
  -- Ajustes de versiones anteriores que ya no valen.
  if (db.settingsVersion or 0) < 1 then
    db.settings.onlyMyReagents = false -- en la 0.6 venía marcado y dejaba la lista vacía
    db.settingsVersion = 1
  end
  db.chars = db.chars or {}   -- mis personajes: recetas escaneadas, banco...
  db.guilds = db.guilds or {} -- datos compartidos de cada hermandad
  db.info = db.info or {}     -- materiales de cada receta (datos fijos del juego)
  db.errors = db.errors or {} -- errores del addon (para el informe)
  ns.db = db
  for _, e in ipairs(ns.errorLog) do ns.LogError(e.m, e.s) end
  wipe(ns.errorLog)
  ns.Fire("DB_READY")
end)

-- Mi personaje actual dentro de la base de datos.
function ns.MyChar()
  local me = ns.Me()
  if not me or not ns.db then return nil end
  local c = ns.db.chars[me]
  if not c and ns.meOld and ns.meOld ~= me and ns.db.chars[ns.meOld] then
    -- antes se guardaba con el apellido: se pasa al nombre de pila
    c = ns.db.chars[ns.meOld]
    ns.db.chars[ns.meOld] = nil
    ns.db.chars[me] = c
  end
  if not c then
    c = { profs = {}, bank = {} }
    ns.db.chars[me] = c
  end
  c.profs = c.profs or {}
  return c
end

-- Hermandad actual: se identifica por nombre y reino.
function ns.UpdateGuildKey()
  local key
  if IsInGuild and IsInGuild() then
    local guildName, _, _, guildRealm = GetGuildInfo("player")
    if guildName and guildName ~= "" then
      local realm = (guildRealm and guildRealm ~= "") and guildRealm:gsub("[%s%-]", "") or ns.Realm()
      key = guildName .. "-" .. realm
      ns.guildName = guildName
    end
  elseif IsInGuild then
    ns.guildName = nil
  end
  if not key and IsInGuild and IsInGuild() then return end -- aún cargando: no cambiar nada
  if key ~= ns.guildKey then
    ns.guildKey = key
    ns.Fire("GUILD_CHANGED", key)
  end
end

-- Datos compartidos de la hermandad actual (nil si no estás en ninguna).
function ns.G()
  local key = ns.guildKey
  if not key or not ns.db then return nil end
  local g = ns.db.guilds[key]
  if not g then
    g = {}
    ns.db.guilds[key] = g
  end
  g.entries = g.entries or {}   -- fichas de fabricantes: ["Nombre-Reino"] = ficha
  g.requests = g.requests or {} -- peticiones: [id] = petición
  g.seen = g.seen or {}         -- última vez que vimos a cada personaje
  g.alerted = g.alerted or {}   -- peticiones de las que ya avisamos
  g.thanks = g.thanks or {}     -- encargos confirmados por mis personajes: [yo][fabricante] = n
  g.thanked = g.thanked or {}   -- [id de petición][fabricante] = true (para no contar dos veces)
  return g
end

ns.On("PLAYER_LOGIN", function()
  profByName = nil
  ns.me = nil
  ns.UpdateGuildKey()
  ns.Fire("LOGIN")
end)
ns.On("PLAYER_GUILD_UPDATE", function() ns.UpdateGuildKey() end)
ns.On("GUILD_ROSTER_UPDATE", function() ns.UpdateGuildKey() end)
