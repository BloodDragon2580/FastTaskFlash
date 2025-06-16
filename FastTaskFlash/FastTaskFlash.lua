-- FastTaskFlash.lua
local addonName, addon = ...

local f = CreateFrame("Frame")

-- Registriere alle relevanten, existierenden Events
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_BN_WHISPER")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PARTY_INVITE_REQUEST")
f:RegisterEvent("GUILD_INVITE_REQUEST")
f:RegisterEvent("LFG_PROPOSAL_SHOW")      -- für Dungeons, Raids und PvP-Ready
f:RegisterEvent("UPDATE_PENDING_MAIL")

-- Kernfunktion: Flash + Sound
local function FastTaskNotify()
    FlashClientIcon()                       -- Taskleisten-Icon blinkt
    PlaySound(SOUNDKIT.RAID_WARNING, "SFX") -- Standard Raid-Warning-Ton
end

-- Event-Handler
f:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        FastTaskNotify()

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
        if destGUID == UnitGUID("player") and
           (subevent == "SWING_DAMAGE"
         or subevent == "SPELL_DAMAGE"
         or subevent == "RANGE_DAMAGE") then
            FastTaskNotify()
        end

    else
        -- PARTY_INVITE_REQUEST, GUILD_INVITE_REQUEST, LFG_PROPOSAL_SHOW, UPDATE_PENDING_MAIL
        FastTaskNotify()
    end
end)
