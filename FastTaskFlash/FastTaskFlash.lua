-- FastTaskFlash.lua
local addonName = ...

-- =========================
-- Settings / Options helper
-- =========================
local function AddToOptions(panel)
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
		Settings.RegisterAddOnCategory(category)
		return
	end

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end

local defaults = {
	sound = true,
	pvpQueue = true,
	directMessages = true,
	combat = true,
	requests = true,
}

FastTaskFlashDB = FastTaskFlashDB or {}

local f = CreateFrame("Frame")
local lastNotify = 0
local lastCombatNotify = 0
local flashTicker

local function StopFlashTicker()
	if flashTicker then
		flashTicker:Cancel()
		flashTicker = nil
	end
end

-- FlashClientIcon() can be very brief on newer Windows versions. Repeating it
-- makes the taskbar alert much easier to notice while WoW is minimized.
local function FlashTaskbar()
	StopFlashTicker()

	FlashClientIcon()
	if C_Timer and C_Timer.NewTicker then
		local flashes = 1
		flashTicker = C_Timer.NewTicker(0.8, function(ticker)
			flashes = flashes + 1
			FlashClientIcon()
			if flashes >= 8 then
				ticker:Cancel()
				flashTicker = nil
			end
		end)
	end
end

local function FastTaskNotify(throttle)
	throttle = throttle or 0.25
	local t = GetTime()
	if (t - lastNotify) < throttle then return end
	lastNotify = t

	FlashTaskbar()
	if FastTaskFlashDB.sound then
		PlaySound(SOUNDKIT.RAID_WARNING, "SFX")
	end
end

-- PvP queue state tracking. Notify only when a queue changes to "confirm"
-- (the battleground or arena is ready to enter).
local pvpQueueStates = {}

local function CheckPvPQueues()
	if not FastTaskFlashDB.pvpQueue or type(GetBattlefieldStatus) ~= "function" then
		return
	end

	local maxQueues = tonumber(MAX_BATTLEFIELD_QUEUES) or 3
	for index = 1, maxQueues do
		local status = GetBattlefieldStatus(index)
		local previous = pvpQueueStates[index]

		if status == "confirm" and previous ~= "confirm" then
			FastTaskNotify(0)
		end

		pvpQueueStates[index] = status
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

	local soundCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	soundCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
	soundCheckbox.Text:SetText("Warn-Ton aktivieren")
	soundCheckbox:SetChecked(FastTaskFlashDB.sound and true or false)
	soundCheckbox:SetScript("OnClick", function(selfBtn)
		FastTaskFlashDB.sound = selfBtn:GetChecked() and true or false
	end)

	local pvpCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	pvpCheckbox:SetPoint("TOPLEFT", soundCheckbox, "BOTTOMLEFT", 0, -8)
	pvpCheckbox.Text:SetText("Bei PvP-Warteschlangen blinken")
	pvpCheckbox:SetChecked(FastTaskFlashDB.pvpQueue and true or false)
	pvpCheckbox:SetScript("OnClick", function(selfBtn)
		FastTaskFlashDB.pvpQueue = selfBtn:GetChecked() and true or false
	end)

	local messageCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	messageCheckbox:SetPoint("TOPLEFT", pvpCheckbox, "BOTTOMLEFT", 0, -8)
	messageCheckbox.Text:SetText("Bei direkten Nachrichten blinken")
	messageCheckbox:SetChecked(FastTaskFlashDB.directMessages and true or false)
	messageCheckbox:SetScript("OnClick", function(selfBtn)
		FastTaskFlashDB.directMessages = selfBtn:GetChecked() and true or false
	end)

	local combatCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	combatCheckbox:SetPoint("TOPLEFT", messageCheckbox, "BOTTOMLEFT", 0, -8)
	combatCheckbox.Text:SetText("Bei Angriffen und Kampfbeginn blinken")
	combatCheckbox:SetChecked(FastTaskFlashDB.combat and true or false)
	combatCheckbox:SetScript("OnClick", function(selfBtn)
		FastTaskFlashDB.combat = selfBtn:GetChecked() and true or false
	end)

	local requestCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	requestCheckbox:SetPoint("TOPLEFT", combatCheckbox, "BOTTOMLEFT", 0, -8)
	requestCheckbox.Text:SetText("Bei Einladungen und direkten Anfragen blinken")
	requestCheckbox:SetChecked(FastTaskFlashDB.requests and true or false)
	requestCheckbox:SetScript("OnClick", function(selfBtn)
		FastTaskFlashDB.requests = selfBtn:GetChecked() and true or false
	end)

	local testButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	testButton:SetSize(180, 24)
	testButton:SetPoint("TOPLEFT", requestCheckbox, "BOTTOMLEFT", 4, -18)
	testButton:SetText("Taskleisten-Alarm testen")
	testButton:SetScript("OnClick", function()
		FastTaskNotify(0)
	end)

	local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", testButton, "BOTTOMLEFT", -4, -10)
	help:SetWidth(520)
	help:SetJustifyH("LEFT")
	help:SetText("Zum Testen WoW in den Fenstermodus setzen, den Testknopf anklicken und sofort zu einem anderen Fenster wechseln oder WoW minimieren.")

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
	-- Direct messages
	f:RegisterEvent("CHAT_MSG_WHISPER")
	f:RegisterEvent("CHAT_MSG_BN_WHISPER")

	-- Invitations, confirmations and requests that need the player's attention
	f:RegisterEvent("PARTY_INVITE_REQUEST")
	f:RegisterEvent("GUILD_INVITE_REQUEST")
	f:RegisterEvent("DUEL_REQUESTED")
	f:RegisterEvent("READY_CHECK")
	f:RegisterEvent("RESURRECT_REQUEST")
	f:RegisterEvent("CONFIRM_SUMMON")
	f:RegisterEvent("TRADE_SHOW")
	f:RegisterEvent("LFG_PROPOSAL_SHOW")
	f:RegisterEvent("LFG_ROLE_CHECK_SHOW")
	f:RegisterEvent("ROLE_POLL_BEGIN")
	f:RegisterEvent("UPDATE_PENDING_MAIL")
	f:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")

	-- Combat: entering combat catches aggro immediately; UNIT_COMBAT also catches
	-- blocked, absorbed, dodged or parried attacks before health necessarily drops.
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:RegisterUnitEvent("UNIT_COMBAT", "player")
	f:RegisterUnitEvent("UNIT_HEALTH", "player")
	lastHP = tonumber(tostring(UnitHealth("player")))

	CheckPvPQueues()
end

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

	if event == "UPDATE_BATTLEFIELD_STATUS" then
		CheckPvPQueues()
		return
	end

	if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
		if FastTaskFlashDB.directMessages then
			FastTaskNotify(0.15)
		end
		return
	end

	if event == "PLAYER_REGEN_DISABLED" then
		if FastTaskFlashDB.combat then
			lastCombatNotify = GetTime()
			FastTaskNotify(0)
		end
		return
	end

	if event == "UNIT_COMBAT" then
		if arg1 ~= "player" or not FastTaskFlashDB.combat then return end

		local combatEvent = ...
		local now = GetTime()
		-- Avoid constant sound/flash spam while still alerting for a new attack
		-- after the previous taskbar alert has had time to finish.
		if combatEvent and (now - lastCombatNotify) >= 6 then
			lastCombatNotify = now
			FastTaskNotify(0)
		end
		return
	end

	if event == "UNIT_HEALTH" then
		if arg1 ~= "player" then return end

		local hp = tonumber(tostring(UnitHealth("player")))
		if not hp then return end

		if hp <= 0 then
			lastHP = hp
			return
		end

		if type(lastHP) ~= "number" then
			lastHP = hp
			return
		end

		if hp < lastHP and FastTaskFlashDB.combat then
			local now = GetTime()
			if (now - lastCombatNotify) >= 6 then
				lastCombatNotify = now
				FastTaskNotify(0)
			end
		end

		lastHP = hp
		return
	end

	-- PARTY_INVITE_REQUEST, GUILD_INVITE_REQUEST, DUEL_REQUESTED,
	-- READY_CHECK, RESURRECT_REQUEST, CONFIRM_SUMMON, TRADE_SHOW,
	-- LFG_PROPOSAL_SHOW, LFG_ROLE_CHECK_SHOW, ROLE_POLL_BEGIN and mail.
	if FastTaskFlashDB.requests then
		FastTaskNotify(0.15)
	end
end)
