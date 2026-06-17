-- QueueLoud v2.0
-- Boosts volume, repeating alerts, screen flash, and TTS on queue pops

QL = QL or {}

-- Defaults (merged with saved on load)
local DEFAULTS = {
    enabled       = true,
    boostVolume   = 1.0,   -- 0.0–1.0
    restoreDelay  = 15,    -- seconds after queue pop to restore volume
    persistent    = true,  -- keep alerting until dismissed
    alertInterval = 5,     -- seconds between repeat alerts
    soundChoice   = "alarm1",
    screenFlash   = true,
}

-- ── Sounds ──────────────────────────────────────────────────────────────────

-- Each entry: key, label, fn (called each alert tick)
QL.SOUNDS = {
    { key = "default",    label = "Game Default"       },
    { key = "alarm1",     label = "Alarm 1"            },
    { key = "alarm2",     label = "Alarm 2"            },
    { key = "alarm3",     label = "Alarm 3"            },
    { key = "readycheck", label = "Ready Check"        },
    { key = "raidwarn",   label = "Raid Warning"       },
    { key = "horn",       label = "Air Horn"           },
    { key = "tts",        label = "Voice: ARENA!"      },
}

local SOUND_IDS = {
    default    = nil, -- game already plays its sound
    alarm1     = function() pcall(PlaySound, SOUNDKIT.ALARM_CLOCK_WARNING_1, "Master") end,
    alarm2     = function() pcall(PlaySound, SOUNDKIT.ALARM_CLOCK_WARNING_2, "Master") end,
    alarm3     = function() pcall(PlaySound, SOUNDKIT.ALARM_CLOCK_WARNING_3, "Master") end,
    readycheck = function() pcall(PlaySound, SOUNDKIT.READY_CHECK,            "Master") end,
    raidwarn   = function() pcall(PlaySound, SOUNDKIT.RAID_WARNING,           "Master") end,
    horn       = function() pcall(PlaySound, SOUNDKIT.PVP_THROUGH_QUEUE_ALERT_HORN, "Master") end,
    tts        = function() QL:SpeakArena() end,
}

function QL:PlayAlert()
    local fn = SOUND_IDS[QueueLoudDB.soundChoice]
    if fn then fn() end
end

function QL:SpeakArena()
    -- Try WoW's built-in TTS
    local ok = false
    if C_VoiceChat and C_VoiceChat.SpeakText then
        ok = pcall(function()
            C_VoiceChat.SpeakText(1, "Arena!", Enum.VoiceTTSSpeakType.LocalPlayer, 0, 1.0)
        end)
    end
    -- Fallback: big screen message
    if not ok then
        UIErrorsFrame:AddMessage("|cffff0000ARENA!|r", 1, 0, 0, 1, 3)
        RaidNotice_AddMessage(RaidWarningFrame, "ARENA!", {r=1,g=0.2,b=0.2}, 3)
    end
end

-- ── Volume ───────────────────────────────────────────────────────────────────

QL.originalMaster = nil
QL.originalSFX    = nil

local function GetVol(cvar)   return tonumber(GetCVar(cvar)) or 1.0 end
local function SetVol(cvar,v) SetCVar(cvar, v) end

function QL:BoostVolume()
    if not self.originalMaster then
        self.originalMaster = GetVol("Sound_MasterVolume")
        self.originalSFX    = GetVol("Sound_SFXVolume")
    end
    local v = QueueLoudDB.boostVolume
    SetVol("Sound_MasterVolume", v)
    SetVol("Sound_SFXVolume",    v)
end

function QL:RestoreVolume()
    if self.originalMaster then
        SetVol("Sound_MasterVolume", self.originalMaster)
        SetVol("Sound_SFXVolume",    self.originalSFX)
        self.originalMaster = nil
        self.originalSFX    = nil
    end
end

-- ── Persistent alert loop ────────────────────────────────────────────────────

QL.restoreTimer    = nil
QL.persistentTimer = nil
QL.alertActive     = false

function QL:StopAlerts()
    self.alertActive = false
    if self.persistentTimer then
        self.persistentTimer:Cancel()
        self.persistentTimer = nil
    end
    if self.restoreTimer then
        self.restoreTimer:Cancel()
        self.restoreTimer = nil
    end
    self:RestoreVolume()
    if QL_UI then QL_UI:SetDismissVisible(false) end
end

function QL:Tick()
    if not self.alertActive then return end
    self:BoostVolume()
    self:PlayAlert()
    if QueueLoudDB.screenFlash then
        UIErrorsFrame:AddMessage("|cffffff00▶ QUEUE POPPED ◀|r", 1, 1, 0, 1, 2)
        RaidNotice_AddMessage(RaidWarningFrame, "QUEUE POPPED!", {r=1,g=1,b=0}, 2)
    end
end

function QL:StartAlerts()
    if not QueueLoudDB.enabled then return end
    self.alertActive = true

    -- Cancel any running timers
    if self.persistentTimer then self.persistentTimer:Cancel() end
    if self.restoreTimer    then self.restoreTimer:Cancel()    end

    -- First immediate alert
    self:Tick()

    if QueueLoudDB.persistent then
        -- Repeating alert
        local interval = QueueLoudDB.alertInterval
        self.persistentTimer = C_Timer.NewTicker(interval, function()
            if self.alertActive then
                self:Tick()
            else
                self.persistentTimer:Cancel()
            end
        end)
    end

    -- Auto-restore volume after delay (even with persistent on)
    self.restoreTimer = C_Timer.NewTimer(QueueLoudDB.restoreDelay, function()
        self:RestoreVolume()
    end)

    if QL_UI then QL_UI:SetDismissVisible(true) end
end

-- ── Events ───────────────────────────────────────────────────────────────────

local f = CreateFrame("Frame")
f:RegisterEvent("PVPQUEUE_ANYWHERE_SHOW")
f:RegisterEvent("LFG_READY_CHECK")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "QueueLoud" then
        -- Merge saved vars with defaults
        QueueLoudDB = QueueLoudDB or {}
        for k, v in pairs(DEFAULTS) do
            if QueueLoudDB[k] == nil then QueueLoudDB[k] = v end
        end
        print("|cff00ff00QueueLoud:|r Loaded. |cffffff00/ql|r to open settings.")

    elseif event == "PLAYER_ENTERING_WORLD" then
        QL:StopAlerts()

    elseif event == "PVPQUEUE_ANYWHERE_SHOW" or event == "LFG_READY_CHECK" then
        QL:StartAlerts()
    end
end)

-- ── Slash ─────────────────────────────────────────────────────────────────────

SLASH_QUEUELOUD1 = "/ql"
SLASH_QUEUELOUD2 = "/queueloud"
SlashCmdList["QUEUELOUD"] = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "test" then
        QL:StartAlerts()
    elseif msg == "stop" or msg == "dismiss" then
        QL:StopAlerts()
    elseif msg == "status" then
        print(string.format("|cff00ff00QueueLoud:|r vol=%d%% delay=%ds interval=%ds sound=%s",
            math.floor(QueueLoudDB.boostVolume * 100),
            QueueLoudDB.restoreDelay,
            QueueLoudDB.alertInterval,
            QueueLoudDB.soundChoice))
    else
        if QL_UI then
            QL_UI:Toggle()
        end
    end
end
