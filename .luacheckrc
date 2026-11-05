-- Análisis estático del addon (luacheck). Lista de funciones y variables del juego que usamos.
std = "lua51"
max_line_length = 160
unused_args = false
exclude_files = { "tests/**" }

globals = { "HDFProfesiones", "HDFProfesionesDB", "StaticPopupDialogs", "UISpecialFrames" }

read_globals = {
  -- Lua de WoW
  "wipe", "tinsert", "hooksecurefunc", "geterrorhandler", "time",
  -- Marcos e interfaz
  "CreateFrame", "UIParent", "GameTooltip", "DEFAULT_CHAT_FRAME", "BackdropTemplateMixin",
  "FauxScrollFrame_Update", "FauxScrollFrame_GetOffset", "FauxScrollFrame_SetOffset", "FauxScrollFrame_OnVerticalScroll",
  "StaticPopup_Show", "GuildFrame", "CommunitiesFrame", "FriendsFrame", "ChatFrame_SendTell", "ChatEdit_InsertLink",
  "GetCurrentKeyBoardFocus", "GetCursorInfo", "ClearCursor", "PlaySound", "SOUNDKIT",
  "ACCEPT", "CANCEL", "YES", "NO", "ITEM_QUALITY_COLORS", "RAID_CLASS_COLORS", "CUSTOM_CLASS_COLORS",
  "GetCoinTextureString",
  -- Sistema
  "C_Timer", "C_ChatInfo", "C_Item", "C_Spell", "C_Container", "C_GuildInfo", "Enum",
  "GetTime", "GetServerTime", "GetNormalizedRealmName", "GetRealmName",
  -- Unidad y hermandad
  "UnitName", "UnitLevel", "UnitClass", "UnitAffectingCombat", "InCombatLockdown", "IsInInstance",
  "IsInGuild", "GetGuildInfo", "GetNumGuildMembers", "GetGuildRosterInfo", "GetGuildRosterLastOnline", "GuildRoster",
  -- Objetos y hechizos
  "GetItemInfo", "GetItemIcon", "GetItemCount", "GetSpellInfo",
  "GetContainerNumSlots", "GetContainerItemInfo", "BANK_CONTAINER", "NUM_BAG_SLOTS", "NUM_BANKBAGSLOTS",
  -- Profesiones
  "GetNumTradeSkills", "GetTradeSkillLine", "IsTradeSkillLinked", "GetTradeSkillInfo", "GetTradeSkillItemLink",
  "GetTradeSkillNumMade", "GetTradeSkillNumReagents", "GetTradeSkillReagentInfo", "GetTradeSkillReagentItemLink",
  "GetTradeSkillCooldown", "GetNumCrafts", "GetCraftDisplaySkillLine", "GetCraftInfo", "GetCraftItemLink",
  "GetCraftRecipeLink", "GetCraftNumReagents", "GetCraftReagentInfo", "GetCraftReagentItemLink",
  "GetNumSkillLines", "GetSkillLineInfo",
  -- Correo
  "SendMail", "GetSendMailItem", "GetSendMailItemLink", "ATTACHMENTS_MAX_SEND", "MailFrame",
  "MailFrameTab_OnClick", "SendMailNameEditBox", "SendMailSubjectEditBox",
  -- Ventanas de profesión
  "TradeSkillFrame", "TradeSkillCreateButton", "TradeSkillInputBox", "GetTradeSkillSelectionIndex",
  "CraftFrame", "CraftCreateButton", "GetCraftSelectionIndex",
}
