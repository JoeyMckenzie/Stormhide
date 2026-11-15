-- Five-second rule: mana only regenerates once 5 seconds have passed since mana was last spent.
-- A deep indigo ring over the resource circle's border shows it: a mana spend fills it, then it opens at 12 o'clock and the two ends
-- retreat down both sides, meeting at 6 o'clock as the 5 seconds run out. Empty while
-- regenerating (including during a cast, since mana is only spent when it lands).
--
-- Only casts that really spend mana count: not ones with no mana cost (skinning). Our casts' spell
-- IDs and spell costs are readable in combat and the timer is our own clock.
local addonName, ns = ...
local L = ns.L
local CreateFrame = ns.Profiled("FiveSecondRule") -- timed by /stormhide perf (Profiler.lua)

local RULE = 5
-- Deep indigo, well darker than the mana fill's bright azure; the texture adds tube shading.
local COLOR = { 0.12, 0.14, 0.55 }
local MANA = Enum.PowerType.Mana

local SIZE = ns.RESOURCE_SIZE + 6 -- matches the border in Resource.lua, which the ring covers

-- Each side of the ring is a clip frame showing only its half. Inside it, a half-ring texture
-- (ring_mana_half, the left half) rotates around the ring's centre: starting on the far side,
-- where it's clipped away, it swings in from 6 o'clock until it fills its half at 12 o'clock.
-- The ring drains by running that backwards.
local holder = CreateFrame("Frame", nil, ns.hud)
holder:SetSize(SIZE, SIZE)
holder:SetPoint("CENTER")
holder:SetFrameLevel(ns.hud:GetFrameLevel() + 4) -- over the GCD shading, under the resource number

local function CreateSide(point)
    local clip = CreateFrame("Frame", nil, holder)
    clip:SetPoint("TOP" .. point)
    clip:SetPoint("BOTTOM" .. point)
    clip:SetWidth(SIZE / 2)
    clip:SetClipsChildren(true)
    local arc = clip:CreateTexture(nil, "ARTWORK")
    arc:SetTexture(ns.MEDIA .. "ring_mana_half")
    arc:SetSize(SIZE, SIZE)
    arc:SetPoint("CENTER", holder)
    arc:SetVertexColor(COLOR[1], COLOR[2], COLOR[3])
    return arc
end

local rightArc = CreateSide("RIGHT")
local leftArc = CreateSide("LEFT")

-- fill 0-1 -> each arc has swept `angle` (0 to pi) up its side. SetRotation turns
-- counter-clockwise: the left half turned by +angle enters the right side from the bottom, and
-- turned by pi - angle (a right half turned clockwise) enters the left side from the bottom.
local function SetFill(fill)
    local angle = math.pi * fill
    rightArc:SetRotation(angle)
    leftArc:SetRotation(math.pi - angle)
end

local lastSpend -- GetTime() of the last mana spend

-- Preview mode (below): a made-up spend every SAMPLE_EVERY seconds.
local SAMPLE_EVERY = RULE + 1.5
local sampling, sampleSpend = false, nil

local function Progress()
    if sampling then
        if not sampleSpend then
            return 1
        end
        if GetTime() - sampleSpend >= SAMPLE_EVERY then
            sampleSpend = GetTime()
        end
        return math.min((GetTime() - sampleSpend) / RULE, 1)
    end
    if not lastSpend then
        return 1
    end
    return math.min((GetTime() - lastSpend) / RULE, 1)
end

-- The ring's fill: full right after a spend, empty once regenerating. Driven each frame only while
-- it has something to draw (after a spend, or the looping sample); once empty it stops until
-- the next spend wakes it (/stormhide perf, 2026-10-10: it ran every frame, forever).
local driver = CreateFrame("Frame")

local function Update()
    local progress = Progress()
    SetFill(1 - progress)
    if progress >= 1 and not (sampling and sampleSpend) then
        driver:Hide()
    end
end

driver:SetScript("OnUpdate", Update)
Update()

local function Wake()
    driver:Show()
end

-- Settings (Elements.lua): Opacity is the holder's alpha (nothing else sets it). No hit shape: it
-- lies on the resource circle's border, so it's picked from the list.
ns.RegisterElement({
    id = "resource.fsr",
    zone = "resource",
    name = L["Five-Second Ring"],
    hidden = true, -- not offered in the settings for now (Elements.lua)
    glyph = { kind = "ring", color = { 0.35, 0.31, 0.78 } },
    options = {
        { key = "opacity", type = "slider", label = L["Opacity"], min = 0, max = 100, step = 5, format = "%.0f%%", default = 100 },
    },
    apply = function(get)
        holder:SetAlpha(get("opacity") / 100)
    end,
    sample = function(state)
        sampling = state ~= nil
        sampleSpend = sampling and GetTime() or nil
        Wake() -- draws the sample, or puts back the real state
    end,
})

-- Whether a spell has a mana cost (skinning, for one, has none). If it can't be read, assume so.
local function CostsMana(spellID)
    if ns.IsSecret(spellID) or not (C_Spell and C_Spell.GetSpellPowerCost) then
        return true
    end
    local ok, result = pcall(function()
        for _, cost in ipairs(C_Spell.GetSpellPowerCost(spellID) or {}) do
            if cost.type == MANA and (ns.IsSecret(cost.cost) or cost.cost > 0) then
                return true
            end
        end
        return false
    end)
    return not ok or result
end

local function Spent(spellID, at, reason)
    lastSpend = math.max(lastSpend or 0, at)
    Wake()
    local name = not ns.IsSecret(spellID) and C_Spell.GetSpellName(spellID) or spellID
    ns.Debug("5s rule:", name, "spent mana, ring reset (" .. reason .. ")")
end

local function OnSucceeded(spellID)
    if CostsMana(spellID) then
        Spent(spellID, GetTime(), "costs mana")
    end
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(_, _, ...)
    OnSucceeded((select(3, ...))) -- unit, castGUID, spellID
end)
