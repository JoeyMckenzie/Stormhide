-- Global cooldown "Harvey ball": a faint white pie over the resource circle that shrinks clockwise while
-- the GCD runs. Retail reports the GCD on dummy spell 61304; Forever doesn't have it and uses
-- Classic's GCD spell 29515 instead (found via EllesmereUI's Forever fix, PR #2240).
local addonName, ns = ...
local L = ns.L
local CreateFrame = ns.Profiled("Gcd") -- timed by /stormhide perf (Profiler.lua)

local REFERENCE_SPELL = ns.GCD_SPELL -- Forever's GCD spell (SpellTiming.lua)
local SHADE = { 1, 1, 1, 0.3 }

local ball = CreateFrame("Cooldown", nil, ns.hud, "CooldownFrameTemplate")
ball:ClearAllPoints() -- the template fills its parent (the whole HUD); size it to the circle instead
ball:SetSize(ns.RESOURCE_SIZE, ns.RESOURCE_SIZE)
ball:SetPoint("CENTER")
ball:SetFrameLevel(ns.hud:GetFrameLevel() + 3) -- over the resource fill, under its number
ball:SetSwipeTexture(ns.MEDIA .. "circle_feather") -- same soft edge as the resource fill
ball:SetSwipeColor(SHADE[1], SHADE[2], SHADE[3], SHADE[4])
ball:SetDrawEdge(false)
ball:SetDrawBling(false)
ball:SetHideCountdownNumbers(true)

local sampling = false

local function Update()
    if sampling then
        return
    end
    local ok, err = pcall(function()
        -- isActive stays readable in combat; gating on it avoids redrawing a finished GCD (as EllesmereUI does).
        local info = C_Spell.GetSpellCooldown(REFERENCE_SPELL)
        local active = info and info.isActive
        local duration = active and not ns.IsSecret(active) and C_Spell.GetSpellCooldownDuration(REFERENCE_SPELL)
        if duration then
            ball:SetCooldownFromDurationObject(duration)
        else
            ball:Clear()
        end
    end)
    if not ok then
        ns.Debug("GCD: duration object rejected:", err)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:SetScript("OnEvent", Update)

local SAMPLE_EVERY = 2.5
local SAMPLE_LENGTH = 1.5
local sampleDriver = CreateFrame("Frame")
sampleDriver:Hide()
local sampleStart = 0
sampleDriver:SetScript("OnUpdate", function()
    if GetTime() - sampleStart >= SAMPLE_EVERY then
        sampleStart = GetTime()
        ball:SetCooldown(sampleStart, SAMPLE_LENGTH)
    end
end)

ns.RegisterElement({
    id = "resource.gcd",
    zone = "resource",
    name = L["GCD Pie"],
    hidden = true, -- not offered in the settings for now (Elements.lua)
    glyph = { kind = "disc", color = { 0.43, 0.40, 0.36 } },
    options = {
        { key = "opacity", type = "slider", label = L["Opacity"], min = 0, max = 100, step = 5, format = "%.0f%%", default = 100 },
    },
    apply = function(get)
        ball:SetSwipeColor(SHADE[1], SHADE[2], SHADE[3], SHADE[4] * get("opacity") / 100)
    end,
    sample = function(state)
        sampling = state ~= nil
        if sampling then
            sampleStart = 0
            sampleDriver:Show()
        else
            sampleDriver:Hide()
            ball:Clear()
            Update()
        end
    end,
})

ns.OnLoad(function()
    ns.Debug("GCD reference spell:", C_Spell.GetSpellName(REFERENCE_SPELL), REFERENCE_SPELL)
end)
