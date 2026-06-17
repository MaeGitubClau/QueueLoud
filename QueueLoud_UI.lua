-- QueueLoud_UI.lua  — Settings panel

local function MakeLabel(parent, text, x, y)
    local l = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l:SetPoint("TOPLEFT", x, y)
    l:SetText(text)
    return l
end

local function MakeCheckbox(parent, label, x, y, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.text:SetText(label)
    cb:SetChecked(getter())
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)
    return cb
end

local function MakeSlider(parent, label, minVal, maxVal, step, x, y, w, getter, setter, fmtFn)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(w or 200)
    s:SetHeight(20)
    s:SetMinMaxValues(minVal, maxVal)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetValue(getter())

    _G[s:GetName() .. "Low"]:SetText(tostring(minVal))
    _G[s:GetName() .. "High"]:SetText(tostring(maxVal))
    _G[s:GetName() .. "Text"]:SetText(label)

    local valLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valLabel:SetPoint("TOP", s, "BOTTOM", 0, -2)

    local function Update(v)
        s:SetValue(v)
        valLabel:SetText(fmtFn and fmtFn(v) or tostring(v))
        setter(v)
    end

    s:SetScript("OnValueChanged", function(_, v) Update(v) end)
    valLabel:SetText(fmtFn and fmtFn(getter()) or tostring(getter()))
    return s, valLabel
end

local function MakeButton(parent, label, x, y, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(w or 120, h or 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

-- ── Sound Picker ─────────────────────────────────────────────────────────────

local soundIndex = 1

local function FindSoundIndex()
    for i, s in ipairs(QL.SOUNDS) do
        if s.key == QueueLoudDB.soundChoice then
            return i
        end
    end
    return 1
end

-- ── Build the panel ──────────────────────────────────────────────────────────

local panel = CreateFrame("Frame", "QueueLoudPanel", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(340, 420)
panel:SetPoint("CENTER")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
panel:SetClampedToScreen(true)
panel:Hide()

panel.TitleText:SetText("QueueLoud Settings")

-- Enable toggle
MakeLabel(panel, " ", 20, -30) -- spacer
local enabledCB = MakeCheckbox(panel,
    "Enable QueueLoud",
    20, -38,
    function() return QueueLoudDB.enabled end,
    function(v) QueueLoudDB.enabled = v end
)

-- Volume slider
MakeLabel(panel, "Boost Volume", 20, -72)
MakeSlider(panel, "", 0, 100, 1, 20, -82, 280,
    function() return math.floor(QueueLoudDB.boostVolume * 100) end,
    function(v) QueueLoudDB.boostVolume = v / 100 end,
    function(v) return v .. "%" end
)

-- Restore delay slider
MakeLabel(panel, "Restore Delay (seconds)", 20, -132)
MakeSlider(panel, "", 5, 120, 5, 20, -142, 280,
    function() return QueueLoudDB.restoreDelay end,
    function(v) QueueLoudDB.restoreDelay = v end,
    function(v) return v .. "s" end
)

-- Persistent checkbox
local persistCB = MakeCheckbox(panel,
    "Persistent Alerts (keep repeating until dismissed)",
    20, -196,
    function() return QueueLoudDB.persistent end,
    function(v) QueueLoudDB.persistent = v end
)

-- Alert interval slider
MakeLabel(panel, "Alert Interval (seconds)", 20, -222)
MakeSlider(panel, "", 1, 30, 1, 20, -232, 280,
    function() return QueueLoudDB.alertInterval end,
    function(v) QueueLoudDB.alertInterval = v end,
    function(v) return v .. "s" end
)

-- Screen flash checkbox
local flashCB = MakeCheckbox(panel,
    "Screen Flash + Warning Text",
    20, -284,
    function() return QueueLoudDB.screenFlash end,
    function(v) QueueLoudDB.screenFlash = v end
)

-- Sound picker label
MakeLabel(panel, "Alert Sound:", 20, -312)
local soundLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
soundLabel:SetPoint("TOPLEFT", 110, -312)

local function UpdateSoundLabel()
    soundLabel:SetText("|cffffff00" .. QL.SOUNDS[soundIndex].label .. "|r")
end

local prevBtn = MakeButton(panel, "◀", 20, -330, 30, 22, function()
    soundIndex = soundIndex - 1
    if soundIndex < 1 then soundIndex = #QL.SOUNDS end
    QueueLoudDB.soundChoice = QL.SOUNDS[soundIndex].key
    UpdateSoundLabel()
end)

local nextBtn = MakeButton(panel, "▶", 56, -330, 30, 22, function()
    soundIndex = soundIndex + 1
    if soundIndex > #QL.SOUNDS then soundIndex = 1 end
    QueueLoudDB.soundChoice = QL.SOUNDS[soundIndex].key
    UpdateSoundLabel()
end)

local soundNameLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
soundNameLabel:SetPoint("TOPLEFT", 92, -334)
soundNameLabel:SetWidth(220)

local function RefreshSoundName()
    soundNameLabel:SetText("|cffffff00" .. QL.SOUNDS[soundIndex].label .. "|r")
end

-- Test / Dismiss buttons
local testBtn = MakeButton(panel, "▶ Test Queue Pop", 20, -366, 140, 26, function()
    QL:StartAlerts()
end)

local dismissBtn = MakeButton(panel, "✕ Dismiss Alert", 170, -366, 140, 26, function()
    QL:StopAlerts()
end)
dismissBtn:Hide()

-- ── Public API ───────────────────────────────────────────────────────────────

QL_UI = {}

function QL_UI:Toggle()
    if panel:IsShown() then
        panel:Hide()
    else
        -- Re-sync state when opening
        soundIndex = FindSoundIndex()
        RefreshSoundName()
        enabledCB:SetChecked(QueueLoudDB.enabled)
        persistCB:SetChecked(QueueLoudDB.persistent)
        flashCB:SetChecked(QueueLoudDB.screenFlash)
        panel:Show()
    end
end

function QL_UI:SetDismissVisible(show)
    if show then
        dismissBtn:Show()
    else
        dismissBtn:Hide()
    end
end

-- Init sound label after QL.SOUNDS is available
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    soundIndex = FindSoundIndex()
    RefreshSoundName()
end)
