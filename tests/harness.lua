-- Entorno simulado de WoW para probar el addon fuera del juego.
-- Cada "cliente" es un jugador con su propia copia del addon cargada en un entorno
-- aislado; una red simulada reparte los mensajes del canal de hermandad entre ellos.
local H = {}

H.ROOT = (arg and arg[0] and arg[0]:match("^(.*)/tests/[^/]+$")) or "."
H.ADDON_DIR = H.ROOT .. "/LaColmena"
H.EPOCH = 1767225600
H.SERVER_START = H.EPOCH + 300 * 86400 -- un día cualquiera de 2026

---------------------------------------------------------------------------
-- Reloj virtual y temporizadores compartidos
---------------------------------------------------------------------------
H.time = 0
local timers, timerSeq = {}, 0

local function addTimer(at, fn, owner)
  timerSeq = timerSeq + 1
  timers[#timers + 1] = { at = at, fn = fn, seq = timerSeq, owner = owner }
end

function H.Advance(seconds)
  local target = H.time + seconds
  while true do
    local bestIndex, best
    for i, t in ipairs(timers) do
      if t.at <= target and (not best or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then
        bestIndex, best = i, t
      end
    end
    if not best then break end
    table.remove(timers, bestIndex)
    if best.at > H.time then H.time = best.at end
    if not (best.owner and best.owner.dead) then best.fn() end
  end
  H.time = target
end

---------------------------------------------------------------------------
-- Errores y comprobaciones
---------------------------------------------------------------------------
H.errors = {}
H.failures = 0
H.passes = 0

function H.ok(value, msg)
  if value then
    H.passes = H.passes + 1
  else
    H.failures = H.failures + 1
    print("  FALLO: " .. tostring(msg))
    print(debug.traceback("", 2))
  end
  return value
end

local function deepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not deepEqual(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end
H.deepEqual = deepEqual

function H.eq(a, b, msg)
  return H.ok(deepEqual(a, b), (msg or "valores distintos") .. ": " .. H.dump(a) .. " ~= " .. H.dump(b))
end

function H.dump(v, depth)
  depth = depth or 0
  if type(v) == "string" then return string.format("%q", v) end
  if type(v) ~= "table" then return tostring(v) end
  if depth > 3 then return "{...}" end
  local parts = {}
  for k, x in pairs(v) do parts[#parts + 1] = "[" .. H.dump(k, depth + 1) .. "]=" .. H.dump(x, depth + 1) end
  table.sort(parts)
  return "{" .. table.concat(parts, ",") .. "}"
end

function H.copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = H.copy(x) end
  return t
end

---------------------------------------------------------------------------
-- Marcos simulados
---------------------------------------------------------------------------
-- Los métodos de WoW empiezan por mayúscula: si no están simulados, no hacen nada.
-- Los campos (minúscula) que no existen son nil, como en el juego.
local function isMethodName(k)
  return type(k) == "string" and k:match("^%u") ~= nil
end

local Dummy
Dummy = function()
  return setmetatable({}, {
    __index = function(_, k)
      if isMethodName(k) then return function() return Dummy() end end
    end,
  })
end
H.Dummy = Dummy

local Frame = {}
local frameMeta = {
  __index = function(_, k)
    local method = Frame[k]
    if method ~= nil then return method end
    if isMethodName(k) then return function() return Dummy() end end
  end,
}

local function newFrame(client, kind, name, parent)
  local f = setmetatable({
    _client = client, _kind = kind, _name = name, _parent = parent,
    _scripts = {}, _events = {}, _shown = true, _text = "", _checked = false, _enabled = true,
  }, frameMeta)
  if client then client.frames[#client.frames + 1] = f end
  return f
end

function Frame:SetScript(event, fn) self._scripts[event] = fn end
function Frame:GetScript(event) return self._scripts[event] end
function Frame:HookScript(event, fn)
  local old = self._scripts[event]
  self._scripts[event] = function(...)
    if old then old(...) end
    fn(...)
  end
end
function Frame:RegisterEvent(event) self._events[event] = true end
function Frame:UnregisterEvent(event) self._events[event] = nil end
function Frame:Show()
  local was = self._shown
  self._shown = true
  if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
end
function Frame:Hide()
  local was = self._shown
  self._shown = false
  if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self._shown end
function Frame:IsVisible()
  local f = self
  while f do
    if not f._shown then return false end
    f = f._parent
  end
  return true
end
function Frame:GetName() return self._name end
function Frame:GetParent() return self._parent end
function Frame:SetText(t) self._text = t == nil and "" or tostring(t) end
function Frame:GetText() return self._text end
function Frame:SetChecked(v) self._checked = v and true or false end
function Frame:GetChecked() return self._checked end
function Frame:HasFocus() return false end
function Frame:Enable() self._enabled = true end
function Frame:Disable() self._enabled = false end
function Frame:SetEnabled(v) self._enabled = v and true or false end
function Frame:IsEnabled() return self._enabled end
function Frame:GetFrameLevel() return 1 end
function Frame:CreateTexture() return newFrame(nil, "Texture", nil, self) end
function Frame:CreateFontString() return newFrame(nil, "FontString", nil, self) end
function Frame:Click()
  if self._enabled and self._scripts.OnClick then self._scripts.OnClick(self, "LeftButton") end
end

H.newFrame = newFrame

---------------------------------------------------------------------------
-- Red simulada (canal de hermandad)
---------------------------------------------------------------------------
H.clients = {}
H.roster = {} -- miembros de la hermandad: { name, class, level, rankIndex, online }
H.traffic = { messages = 0, bytes = 0, byType = {} }
H.LATENCY = 0.1

function H.AddMember(name, class, level)
  H.roster[#H.roster + 1] = { name = name, class = class or "WARRIOR", level = level or 60, rankIndex = 3, online = false }
end

local function member(name)
  for _, m in ipairs(H.roster) do
    if m.name == name then return m end
  end
end

function H.FireEvent(client, event, ...)
  if client.dead then return end
  for _, f in ipairs(client.frames) do
    if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
  end
end

local function deliver(sender, prefix, text, channel, target)
  assert(#text <= 255, "mensaje demasiado largo: " .. #text)
  assert(not text:find("\0", 1, true), "mensaje con byte nulo")
  H.traffic.messages = H.traffic.messages + 1
  H.traffic.bytes = H.traffic.bytes + #text
  -- tipo de mensaje (H, W, P, Q, R, I) contado en los mensajes completos y en el primer trozo
  local head = text:sub(1, 1)
  local kind
  if head == "S" then
    kind = text:sub(2, 2)
  elseif head == "F" then
    local i = 2
    while text:sub(i, i):match("[A-Zw-z#$]") do i = i + 1 end
    kind = text:sub(i + 1, i + 1)
  end
  if kind then H.traffic.byType[kind] = (H.traffic.byType[kind] or 0) + 1 end
  sender.sent = sender.sent + 1
  local from = sender.name .. "-Reino"
  for _, c in pairs(H.clients) do
    if not c.dead and c.online then
      local to = (channel == "GUILD") or (channel == "WHISPER" and target and (c.name == target or c.name .. "-Reino" == target))
      if to or c == sender then -- en WoW el remitente también recibe sus mensajes de hermandad
        if channel == "GUILD" or c ~= sender then
          addTimer(H.time + H.LATENCY, function() H.FireEvent(c, "CHAT_MSG_ADDON", prefix, text, channel, from) end, c)
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Clientes
---------------------------------------------------------------------------
local ADDON_FILES = {
  "Core.lua", "Codec.lua", "Comm.lua", "Data.lua", "Guild.lua", "Scan.lua", "Sync.lua", "Alerts.lua",
  "UI/Widgets.lua", "UI/Main.lua", "UI/Recipes.lua", "UI/Requests.lua", "UI/Mine.lua", "UI/Dialog.lua",
}

local function itemLink(id) return "|cff1eff00|Hitem:" .. id .. ":0:0:0|h[Objeto " .. id .. "]|h|r" end
local function enchantLink(id) return "|cffffd000|Henchant:" .. id .. "|h[Encantamiento " .. id .. "]|h|r" end
H.itemLink = itemLink

local function makeEnv(client)
  local env = {}
  local base = {
    -- Lua estándar
    string = string, table = table, math = math, pairs = pairs, ipairs = ipairs, type = type,
    tostring = tostring, tonumber = tonumber, select = select, pcall = pcall, xpcall = xpcall,
    error = error, setmetatable = setmetatable, getmetatable = getmetatable, next = next,
    rawget = rawget, rawset = rawset, unpack = unpack, print = print, assert = assert,
    -- extras de WoW
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    tinsert = table.insert,
    strsplit = nil,
    geterrorhandler = function()
      return function(err)
        H.errors[#H.errors + 1] = tostring(err)
        print("  ERROR LUA en " .. client.name .. ": " .. tostring(err))
      end
    end,
    hooksecurefunc = function(name, fn)
      local orig = env[name]
      env[name] = function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
      end
    end,
    -- tiempo
    GetTime = function() return H.time end,
    GetServerTime = function() return math.floor(H.SERVER_START + H.time) end,
    time = function() return math.floor(H.SERVER_START + H.time) end,
    C_Timer = {
      After = function(sec, fn) addTimer(H.time + sec, fn, client) end,
      NewTicker = function(sec, fn)
        local ticker = { cancelled = false }
        local function tick()
          if ticker.cancelled then return end
          fn()
          addTimer(H.time + sec, tick, client)
        end
        addTimer(H.time + sec, tick, client)
        function ticker:Cancel() self.cancelled = true end
        return ticker
      end,
    },
    -- marcos
    CreateFrame = function(kind, name, parent, template)
      local f = newFrame(client, kind, name, parent)
      if template and template:find("ScrollFrame") then f.ScrollBar = newFrame(client, "Slider", nil, f) end
      if name then env[name] = f end
      return f
    end,
    UIParent = newFrame(nil, "Frame", "UIParent"),
    GameTooltip = newFrame(nil, "GameTooltip", "GameTooltip"),
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) client.chat[#client.chat + 1] = msg end },
    BackdropTemplateMixin = {},
    UISpecialFrames = {},
    StaticPopupDialogs = {},
    StaticPopup_Show = function(which, text, _, data)
      local popup = newFrame(client, "Frame", "StaticPopup1", nil)
      popup.editBox = newFrame(client, "EditBox", nil, popup)
      client.popups[#client.popups + 1] = { which = which, text = text, data = data, popup = popup }
      return popup
    end,
    FauxScrollFrame_Update = function() end,
    FauxScrollFrame_GetOffset = function() return 0 end,
    FauxScrollFrame_SetOffset = function() end,
    FauxScrollFrame_OnVerticalScroll = function() end,
    ChatFrame_SendTell = function(name) client.whispers[#client.whispers + 1] = name end,
    ChatEdit_InsertLink = function() return false end,
    GetCurrentKeyBoardFocus = function() return client.focus end,
    GetCursorInfo = function() return nil end,
    ClearCursor = function() end,
    PlaySound = function(id) client.sounds[#client.sounds + 1] = id end,
    SOUNDKIT = { TELL_MESSAGE = 3081 },
    ITEM_QUALITY_COLORS = { [1] = { hex = "|cffffffff" }, [2] = { hex = "|cff1eff00" }, [3] = { hex = "|cff0070dd" } },
    RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } },
    ACCEPT = "Aceptar", CANCEL = "Cancelar", YES = "Sí", NO = "No",
    GetCoinTextureString = function(c) return c .. "c" end,
    -- unidad
    UnitName = function() return client.name end,
    UnitLevel = function() return client.level end,
    UnitClass = function() return "Clase", client.class end,
    UnitAffectingCombat = function() return client.inCombat end,
    InCombatLockdown = function() return client.inCombat end,
    IsInInstance = function() return client.inInstance, client.inInstance and "raid" or "none" end,
    GetNormalizedRealmName = function() return "Reino" end,
    GetRealmName = function() return "Reino" end,
    -- hermandad
    IsInGuild = function() return client.inGuild end,
    GetGuildInfo = function() if client.inGuild then return "Los hijos del Fundillo", "Miembro", 3, nil end end,
    GetNumGuildMembers = function() return #H.roster end,
    GetGuildRosterInfo = function(i)
      local m = H.roster[i]
      if not m then return nil end
      return m.name .. "-Reino", "Miembro", m.rankIndex, m.level, "Clase", "Zona", "", "", m.online, 0, m.class
    end,
    GetGuildRosterLastOnline = function(i)
      local m = H.roster[i]
      if m and not m.online then return 0, 0, 1, 2 end
      return 0, 0, 0, 0
    end,
    C_GuildInfo = {
      GuildRoster = function() addTimer(H.time + 0.5, function() H.FireEvent(client, "GUILD_ROSTER_UPDATE") end, client) end,
    },
    -- mensajes de addon
    C_ChatInfo = {
      RegisterAddonMessagePrefix = function() return true end,
      SendAddonMessage = function(prefix, text, channel, target)
        if not client.online then return false end
        deliver(client, prefix, text, channel, target)
        return true
      end,
    },
    -- objetos y hechizos
    GetItemInfo = function(id)
      id = tonumber(id)
      local gear = H.gear and H.gear[id]
      return "Objeto " .. id, itemLink(id), 2, gear and gear.ilvl or 40, gear and gear.minLevel or 0,
        "Tipo", "Subtipo", 20, gear and gear.equipLoc or "", "icono" .. id
    end,
    GetItemIcon = function(id) return "icono" .. tostring(id) end,
    GetSpellInfo = function(id)
      if H.spellNames and H.spellNames[id] then return H.spellNames[id], nil, "icono" end
      return "Hechizo " .. id, nil, "icono"
    end,
    GetItemCount = function(id) return client.bags[id] or 0 end,
    -- profesiones (ventana clásica)
    GetTradeSkillLine = function()
      local t = client.tradeskill
      if not t then return "UNKNOWN", 0, 0 end
      return t.name, t.rank, t.max
    end,
    GetNumTradeSkills = function() return client.tradeskill and #client.tradeskill.rows or 0 end,
    GetTradeSkillInfo = function(i)
      local row = client.tradeskill.rows[i]
      return row.name, row.kind or "optimal"
    end,
    GetTradeSkillItemLink = function(i)
      local row = client.tradeskill.rows[i]
      return row.item and itemLink(row.item) or nil
    end,
    GetTradeSkillNumMade = function(i) return client.tradeskill.rows[i].made or 1, client.tradeskill.rows[i].made or 1 end,
    GetTradeSkillNumReagents = function(i) return #(client.tradeskill.rows[i].reagents or {}) end,
    GetTradeSkillReagentInfo = function(i, r)
      local re = client.tradeskill.rows[i].reagents[r]
      return "Objeto " .. re[1], "icono", re[2], client.bags[re[1]] or 0
    end,
    GetTradeSkillReagentItemLink = function(i, r) return itemLink(client.tradeskill.rows[i].reagents[r][1]) end,
    GetTradeSkillCooldown = function(i) return client.tradeskill.rows[i].cooldown end,
    -- encantamiento (ventana "craft")
    GetCraftDisplaySkillLine = function()
      local t = client.craft
      if not t then return nil end
      return t.name, t.rank, t.max
    end,
    GetNumCrafts = function() return client.craft and #client.craft.rows or 0 end,
    GetCraftInfo = function(i)
      local row = client.craft.rows[i]
      return row.name, nil, row.kind or "optimal"
    end,
    GetCraftItemLink = function(i)
      local row = client.craft.rows[i]
      if row.enchant then return enchantLink(row.enchant) end
      return row.item and itemLink(row.item) or nil
    end,
    GetCraftNumReagents = function(i) return #(client.craft.rows[i].reagents or {}) end,
    GetCraftReagentInfo = function(i, r)
      local re = client.craft.rows[i].reagents[r]
      return "Objeto " .. re[1], "icono", re[2], 0
    end,
    GetCraftReagentItemLink = function(i, r) return itemLink(client.craft.rows[i].reagents[r][1]) end,
    -- habilidades
    GetNumSkillLines = function() return #client.skills end,
    GetSkillLineInfo = function(i)
      local s = client.skills[i]
      return s.name, s.header, s.expanded ~= false, s.rank, 0, 0, s.max
    end,
  }
  setmetatable(env, { __index = base })
  return env
end

-- Crea un jugador y carga el addon. savedDB = base de datos guardada de una sesión anterior.
function H.NewClient(name, opts)
  opts = opts or {}
  local client = {
    name = name, level = opts.level or 60, class = opts.class or "WARRIOR",
    inGuild = opts.inGuild ~= false, online = false, dead = false,
    frames = {}, chat = {}, sounds = {}, popups = {}, whispers = {},
    bags = opts.bags or {}, skills = opts.skills or {}, sent = 0,
  }
  client.env = makeEnv(client)
  client.ns = {}
  client.env.LaColmenaDB = opts.savedDB and H.copy(opts.savedDB) or nil
  for _, file in ipairs(ADDON_FILES) do
    local chunk = assert(loadfile(H.ADDON_DIR .. "/" .. file))
    setfenv(chunk, client.env)
    chunk("LaColmena", client.ns)
  end
  H.clients[name] = client
  return client
end

-- Conecta al jugador: eventos de carga del juego, en orden.
function H.Login(name, opts)
  local m = member(name)
  local client = H.NewClient(name, opts)
  client.online = true
  if m then m.online = true end
  H.FireEvent(client, "ADDON_LOADED", "LaColmena")
  H.FireEvent(client, "PLAYER_LOGIN")
  H.FireEvent(client, "PLAYER_ENTERING_WORLD")
  for _, c in pairs(H.clients) do
    if c.online and not c.dead then H.FireEvent(c, "GUILD_ROSTER_UPDATE") end
  end
  return client
end

-- Desconecta al jugador y devuelve su base de datos guardada.
function H.Logout(client)
  client.online = false
  client.dead = true
  local m = member(client.name)
  if m then m.online = false end
  H.clients[client.name] = nil
  for _, c in pairs(H.clients) do
    if c.online then H.FireEvent(c, "GUILD_ROSTER_UPDATE") end
  end
  return H.copy(client.env.LaColmenaDB)
end

-- Abre la ventana de profesión de un jugador.
function H.OpenTradeSkill(client, tradeskill)
  client.tradeskill = tradeskill
  H.FireEvent(client, "TRADE_SKILL_SHOW")
end

function H.OpenCraft(client, craft)
  client.craft = craft
  H.FireEvent(client, "CRAFT_SHOW")
end

function H.Reset()
  H.clients = {}
  H.roster = {}
  timers = {}
  H.time = 0
  H.traffic = { messages = 0, bytes = 0, byType = {} }
  H.gear = nil
  H.spellNames = nil
end

return H
