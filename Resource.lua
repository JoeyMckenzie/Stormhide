-- The big middle circle: mana, filling from the bottom, with the raw value in the middle.
local addonName, ns = ...
local L = ns.L
local CreateFrame = ns.Profiled("Resource") -- timed by /stormhide perf (Profiler.lua)

local SIZE = ns.RESOURCE_SIZE
-- Fill textures carry their own colour (the Forever mana bar's gradient; see make_textures.py), so
-- they're drawn untinted. Anything else (or a secret power type) gets a flat grey.
local POWER_TEXTURES = {
    [Enum.PowerType.Mana] = ns.MEDIA .. "fill_mana",
}
local FLAT_TEXTURE ="Interface\\Buttons\\WHITE8X8"
local DEFAULT_COLOR = { 0.7, 0.7, 0.7 }
local SMOOTH = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local hud = ns.hud

-- #2 soft circle as a dark backdrop
local backdrop = hud:CreateTexture(nil, "BACKGROUND")
backdrop:SetTexture(ns.MEDIA .. "circle_soft")
backdrop:SetSize(SIZE * 1.3, SIZE * 1.3)
backdrop:SetPoint("CENTER")
backdrop:SetVertexColor(0, 0, 0, 0.4) -- light enough for the GCD shading to show over the empty part

-- #1 circle: a square vertical bar, masked to a soft-edged circle so it fills from the bottom
local bar = CreateFrame("StatusBar", nil, hud)
bar:SetSize(SIZE, SIZE)
bar:SetPoint("CENTER")
bar:SetFrameLevel(hud:GetFrameLevel() + 2) -- leaves +1 for the mana prediction bands behind it
bar:SetOrientation("VERTICAL")
local mask = bar:CreateMaskTexture()
mask:SetTexture(ns.MEDIA .. "circle_feather", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
mask:SetAllPoints(bar)

-- Swaps the fill texture, only when it changes. If the StatusBar hands back a new texture object,
-- the mask goes on that one too.
local currentFile, maskedTexture
local fillOpacity = 1 -- the Resource circle's "Fill opacity" setting
local function SetFill(file, r, g, b)
    if file ~= currentFile then
        bar:SetStatusBarTexture(file)
        currentFile = file
        local texture = bar:GetStatusBarTexture()
        if texture ~= maskedTexture then
            texture:AddMaskTexture(mask)
            maskedTexture = texture
        end
        texture:SetAlpha(fillOpacity)
    end
    bar:SetStatusBarColor(r, g, b)
end
SetFill(FLAT_TEXTURE, unpack(DEFAULT_COLOR))

-- #3 ring as the border: the same size and band as the five-second-rule ring (FiveSecondRule.lua),
-- so the black shows exactly where the blue drains away
local border = bar:CreateTexture(nil, "OVERLAY")
border:SetTexture(ns.MEDIA .. "ring_thin")
border:SetSize(SIZE + 6, SIZE + 6)
border:SetPoint("CENTER")
border:SetVertexColor(0, 0, 0)

-- The number sits on its own higher layer, so the GCD shading (Gcd.lua) never dims it.
local textLayer = CreateFrame("Frame", nil, bar)
textLayer:SetAllPoints()
textLayer:SetFrameLevel(bar:GetFrameLevel() + 5)
local text = textLayer:CreateFontString(nil, "OVERLAY")
text:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE") -- until the saved font is applied (the element below)
text:SetPoint("CENTER")
text:SetTextColor(1, 1, 1, 1)

-- Mana shows as a percentage. Mana is secret in combat, so we can't divide it ourselves:
-- UnitPowerPercent works it out engine-side, and the ScaleTo100 curve makes it 0-100.
-- string.format accepts secrets, so it can add the "%".
local SCALE_TO_100 = CurveConstants and CurveConstants.ScaleTo100
local CAN_SHOW_PERCENT = UnitPowerPercent ~= nil and SCALE_TO_100 ~= nil
local manaFormat = "percent" -- the Resource number's "Mana as" option: "percent" or "value"

local function PowerText(powerType, power)
    if powerType == Enum.PowerType.Mana and CAN_SHOW_PERCENT and manaFormat == "percent" then
        return string.format("%d%%", UnitPowerPercent("player", powerType, false, SCALE_TO_100))
    end
    return power
end

-- Mana cost prediction (ManaPrediction.lua) lowers the fill by a spell's cost while it's cast.
-- Mana is secret in combat, so it can't subtract: it raises the bar's range by the cost instead
-- (offset to max + offset), which draws mana - cost. maxMana is a plain number it read earlier.
local offset, offsetMax = 0, nil
local IMMEDIATE = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate

local function SetRange(powerType)
    if offset > 0 and offsetMax and powerType == Enum.PowerType.Mana then
        bar:SetMinMaxValues(offset, offsetMax + offset)
    else
        bar:SetMinMaxValues(0, UnitPowerMax("player", powerType))
    end
end

-- The fill texture, whose top edge ManaPrediction.lua anchors its bands to.
function ns.ResourceFillTexture()
    return bar:GetStatusBarTexture()
end

-- snap: also jump the fill to the current value, skipping the smoothing (for when the range
-- returns to normal in the same moment the mana is spent, so the fill doesn't dip and recover).
local sample -- preview mode's sample { powerType, value, max } (below), shown instead of the real power
local SAMPLE_MANA = 0.8

-- Whether the circle shows preview mode's sample, not the real power (ManaPrediction.lua hides
-- its bands then).
function ns.IsResourceSampled()
    return sample ~= nil
end

function ns.SetResourceOffset(newOffset, maxMana, snap)
    offset, offsetMax = newOffset, maxMana
    if sample then
        return -- kept for when the preview ends
    end
    local powerType = UnitPowerType("player")
    SetRange(powerType)
    if snap then
        bar:SetValue(UnitPower("player", powerType), IMMEDIATE)
    end
end

-- The sample's number: mana in the Resource number's format, else the value.
local function SampleText()
    if sample.powerType == Enum.PowerType.Mana and manaFormat == "percent" then
        return string.format("%d%%", math.floor(sample.value / sample.max * 100 + 0.5))
    end
    return tostring(math.floor(sample.value))
end

local function Update()
    local powerType = sample and sample.powerType or UnitPowerType("player")
    local knownType = not ns.IsSecret(powerType)
    local file = knownType and POWER_TEXTURES[powerType]
    if file then
        SetFill(file, 1, 1, 1)
    else
        SetFill(FLAT_TEXTURE, unpack(DEFAULT_COLOR))
    end

    if sample then
        bar:SetMinMaxValues(0, sample.max)
        bar:SetValue(sample.value, SMOOTH)
        text:SetText(SampleText())
        if ns.onResourceUpdate then -- hides the mana prediction bands (ns.IsResourceSampled)
            ns.onResourceUpdate()
        end
        return
    end

    -- Current and max power may be secret in combat; StatusBar and FontString accept secrets as-is.
    local power = UnitPower("player", powerType)
    SetRange(powerType)
    bar:SetValue(power, SMOOTH)
    text:SetText(knownType and PowerText(powerType, power) or power)
    if ns.onResourceUpdate then -- ManaPrediction.lua
        ns.onResourceUpdate()
    end
end

ns.OnLoad(function()
    ns.Debug("mana as percent:", CAN_SHOW_PERCENT, "| UnitPowerPercent:", UnitPowerPercent ~= nil,
        "| CurveConstants.ScaleTo100:", SCALE_TO_100 ~= nil)
end)

-- Settings (Elements.lua). The circle: opacity of the fill, the dark background and the black
-- border, in percent. The hit circle (preview mode, Preview.lua) takes in the border.
local function PercentSlider(key, label, default)
    return { key = key, type = "slider", label = label, min = 0, max = 100, step = 5, format = "%.0f%%", default = default }
end
ns.RegisterElement({
    id = "resource.circle",
    zone = "resource",
    name = L["Resource Circle"],
    hidden = true, -- not offered in the settings for now (Elements.lua)
    glyph = { kind = "disc", color = { 0.96, 0.77, 0.26 } },
    hit = { kind = "circle", radius = SIZE / 2 + 3 },
    options = {
        PercentSlider("fillOpacity", L["Fill opacity"], 100),
        PercentSlider("backgroundOpacity", L["Background opacity"], 40),
        PercentSlider("borderOpacity", L["Border opacity"], 100),
    },
    apply = function(get)
        fillOpacity = get("fillOpacity") / 100
        bar:GetStatusBarTexture():SetAlpha(fillOpacity)
        backdrop:SetVertexColor(0, 0, 0, get("backgroundOpacity") / 100)
        border:SetVertexColor(0, 0, 0, get("borderOpacity") / 100)
    end,
    -- Preview mode: a fixed fill, or back to the real power (nil). Max mana is the real one when
    -- readable, so "Value" looks right.
    sample = function(state)
        local mana = Enum.PowerType.Mana
        if state then
            local max = UnitPowerMax("player", mana)
            if ns.IsSecret(max) or not max or max <= 0 then
                max = 5000
            end
            sample = { powerType = mana, value = math.floor(max * SAMPLE_MANA), max = max }
        else
            sample = nil
            SetRange(UnitPowerType("player")) -- puts back the mana prediction's offset, if any
        end
        Update()
    end,
})

-- The number's font, size and outline, and how mana shows. A raw mana
-- value is secret in combat too, but SetText takes it as-is.
local numberOptions = ns.TextOptions(20)
numberOptions[#numberOptions + 1] = { key = "manaFormat", type = "choice", label = L["Mana as"], default = "percent",
    values = { { value = "percent", text = L["Percent"] }, { value = "value", text = L["Value"] } } }
ns.RegisterElement({
    id = "resource.number",
    zone = "resource",
    name = L["Resource Value"],
    glyph = { kind = "text", color = { 1, 1, 1 } },
    hit = { kind = "text", region = text, anchor = textLayer, point = "CENTER", chars = 4 },
    options = numberOptions,
    apply = function(get)
        ns.ApplyFont(text, get("font"), get("size"), get("outline"))
        manaFormat = get("manaFormat")
        if UnitExists("player") then
            Update()
        end
    end,
})

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
events:SetScript("OnEvent", Update)
