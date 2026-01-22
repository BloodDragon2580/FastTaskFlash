-- FastTaskFlash.lua
local addonName = ...

-- =========================
-- Settings / Options helper
-- =========================
local function AddToOptions(panel)
	-- Retail: neue Settings-API
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
		Settings.RegisterAddOnCategory(category)
		return
	end

	-- Fallback (falls noch vorhanden)
	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end

-- Default-Einstellungen
local defaults = {
	sound = true,
}

-- SavedVars
FastTaskFlashDB = FastTaskFlashDB or {}

-- Frame (ohne globalen Namen -> weniger Ärger)
local f = CreateFrame("Frame")

-- Notify
local lastNotify = 0
local function FastTaskNotify(throttle)
	throttle = throttle or 0.25
	local t = GetTime()
	if (t - lastNotify) < throttle then return end
	lastNotify = t

	FlashClientIcon()
	if FastTaskFlashDB.sound then
		PlaySound(SOUNDKIT.RAID_WARNING, "SFX")
	end
end

-- HP tracking
local lastHP

local function CreateOptionsPanel()
	local panel = CreateFrame("Frame")
	panel.name = "FastTask Flash & Alert"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("FastTask Flash & Alert")

	local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
	cb.Text:SetText("Warn-Ton aktivieren")
	cb:SetChecked(FastTaskFlashDB.sound and true or false)
	cb:SetScript("OnClick", function(selfBtn)
		FastTaskFlashDB.sound = selfBtn:GetChecked() and true or false
	end)

	AddToOptions(panel)
end

local function InitSavedVars()
	FastTaskFlashDB = FastTaskFlashDB or {}
	for k, v in pairs(defaults) do
		if FastTaskFlashDB[k] == nil then
			FastTaskFlashDB[k] = v
		end
	end
end

local function RegisterRuntimeEvents()
	-- Social / UI stuff
	f:RegisterEvent("CHAT_MSG_WHISPER")
	f:RegisterEvent("CHAT_MSG_BN_WHISPER")
	f:RegisterEvent("PARTY_INVITE_REQUEST")
	f:RegisterEvent("GUILD_INVITE_REQUEST")
	f:RegisterEvent("LFG_PROPOSAL_SHOW")
	f:RegisterEvent("UPDATE_PENDING_MAIL")

	-- Damage-Erkennung ohne CombatLog
	f:RegisterUnitEvent("UNIT_HEALTH", "player")
	lastHP = tonumber(tostring(UnitHealth("player")))
end

-- Nur “sichere” Start-Events sofort
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event, arg1, ...)
	if event == "ADDON_LOADED" and arg1 == addonName then
		InitSavedVars()
		CreateOptionsPanel()
		return
	end

	if event == "PLAYER_LOGIN" then
		RegisterRuntimeEvents()
		return
	end

	if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
		FastTaskNotify(0.15)
		return
	end

	if event == "UNIT_HEALTH" then
		if arg1 ~= "player" then return end

		-- "secret value" safe machen: erst tostring(), dann tonumber()
		local hp = tonumber(tostring(UnitHealth("player")))
		if not hp then
			return
		end

		if hp <= 0 then
			lastHP = hp
			return
		end

		if type(lastHP) ~= "number" then
			lastHP = hp
			return
		end

		if hp < lastHP then
			-- HP drop -> vermutlich Schaden
			FastTaskNotify(0.35)
		end

		lastHP = hp
		return
	end

	-- PARTY_INVITE_REQUEST, GUILD_INVITE_REQUEST, LFG_PROPOSAL_SHOW, UPDATE_PENDING_MAIL
	FastTaskNotify(0.15)
end)
