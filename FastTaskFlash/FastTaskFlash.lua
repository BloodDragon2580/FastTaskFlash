-- FastTaskFlash.lua
local addonName, addon = ...

-- Fallback für InterfaceOptions_AddCategory (Retail 10+ mit neuer Settings-API)
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
if not InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory = function(frame)
        local category, layout = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name)
        category.ID = frame.name
        Settings.RegisterAddOnCategory(category)
        return category
    end
end

-- Default-Einstellungen
local defaults = {
    sound = true,
}

-- Frame für alles
local f = CreateFrame("Frame", "FastTaskFlashFrame")

-- Registriere Events
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_BN_WHISPER")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PARTY_INVITE_REQUEST")
f:RegisterEvent("GUILD_INVITE_REQUEST")
f:RegisterEvent("LFG_PROPOSAL_SHOW")
f:RegisterEvent("UPDATE_PENDING_MAIL")

-- Notify-Funktion: Flash + optional Sound
local function FastTaskNotify()
    FlashClientIcon()
    if FastTaskFlashDB.sound then
        PlaySound(SOUNDKIT.RAID_WARNING, "SFX")
    end
end

-- Event-Handler
f:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- 1) SavedVariables initialisieren
        FastTaskFlashDB = FastTaskFlashDB or {}
        for k, v in pairs(defaults) do
            if FastTaskFlashDB[k] == nil then
                FastTaskFlashDB[k] = v
            end
        end

        -- 2) Options-Panel anlegen
        local panel = CreateFrame("Frame", "FastTaskFlashOptionsPanel", InterfaceOptionsFramePanelContainer)
        panel.name = "FastTask Flash & Alert"

        -- Titel
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("FastTask Flash & Alert")

        -- Checkbox: Warn-Ton an/aus
        local cb = CreateFrame("CheckButton", "FastTaskFlashSoundCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
        cb.Text:SetText("Warn-Ton aktivieren")
        cb:SetChecked(FastTaskFlashDB.sound)
        cb:SetScript("OnClick", function(self)
            FastTaskFlashDB.sound = self:GetChecked()
        end)

        panel:Hide()

        -- 3) Options-Panel registrieren (oder Fallback)
        InterfaceOptions_AddCategory(panel)

    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        FastTaskNotify()

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, sub, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
        if destGUID == UnitGUID("player") and (sub=="SWING_DAMAGE" or sub=="SPELL_DAMAGE" or sub=="RANGE_DAMAGE") then
            FastTaskNotify()
        end

    else
        -- PARTY_INVITE_REQUEST, GUILD_INVITE_REQUEST, LFG_PROPOSAL_SHOW, UPDATE_PENDING_MAIL
        FastTaskNotify()
    end
end)
