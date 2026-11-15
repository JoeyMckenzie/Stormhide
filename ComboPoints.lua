-- Five dots along the arc above the resource circle.
local addonName, ns = ...
local L = ns.L
local CreateFrame = ns.Profiled("ComboPoints") -- timed by /stormhide perf (Profiler.lua)

local COUNT = 5
local DOT_SIZE = 38
local ARC_RADIUS = 93 -- distance of the dot centres from the HUD centre
local ANGLES = { 150, 120, 90, 60, 30 } -- degrees, left to right; 90 is straight up

local group = CreateFrame("Frame", nil, ns.hud)
group:SetAllPoints()

ns.comboGroup = group
ns.COMBO_DOT_SIZE = DOT_SIZE
function ns.ComboDotOffset(i)
    local angle = math.rad(ANGLES[i])
    return ARC_RADIUS * math.cos(angle), ARC_RADIUS * math.sin(angle)
end

-- The real rings around the dots (CooldownRings.lua's arcs) live in comboLive; preview mode hides it while its stand-ins show in comboSample. Both at the group's
-- level, so frames placed in them keep the levels they had in the group.
local live = CreateFrame("Frame", nil, group)
live:SetAllPoints()
live:SetFrameLevel(group:GetFrameLevel())
ns.comboLive = live

local sampleHolder = CreateFrame("Frame", nil, group)
sampleHolder:SetAllPoints()
sampleHolder:SetFrameLevel(group:GetFrameLevel())
sampleHolder:Hide()
ns.comboSample = sampleHolder

-- A frame for a ring's layer in one of those holders, at the holder's level (for an opacity setting).
function ns.ComboRingGate(holder)
    local gate = CreateFrame("Frame", nil, holder)
    gate:SetAllPoints()
    gate:SetFrameLevel(holder:GetFrameLevel())
    return gate
end

-- Preview mode's hit for a ring around dot i: its band (ring_rip's, 47-63 of 128 on a canvas
-- DOT_SIZE + 8 across) from just inside the dot's edge, so the dot keeps its middle.
function ns.ComboRingHit(i, visible)
    local x, y = ns.ComboDotOffset(i)
    return { kind = "ring", x = x, y = y, inner = DOT_SIZE / 2 - 2, outer = (DOT_SIZE + 8) * 63 / 128 + 2,
        visible = visible }
end

local dots = {}
for i = 1, COUNT do
    local x, y = ns.ComboDotOffset(i)
    local dot = CreateFrame("Frame", nil, group)
    dot:SetSize(DOT_SIZE, DOT_SIZE)
    dot:SetPoint("CENTER", group, "CENTER", x, y)
    local border = dot:CreateTexture(nil, "OVERLAY")
    border:SetTexture(ns.MEDIA .. "ring_small")
    border:SetAllPoints()
    border:SetVertexColor(0, 0, 0)
    dots[i] = dot
end

-- Settings (Elements.lua). Opacity is each dot's alpha (the group's would fade the rings too).
-- Picked as one group by the dots' middles; the rings around them have their own elements.
local centres = {}
for i = 1, COUNT do
    centres[i] = { ns.ComboDotOffset(i) }
end

ns.RegisterElement({
    id = "combo.points",
    zone = "combo",
    name = L["Maelstrom Dots"],
    glyph = { kind = "dots", color = { 0.96, 0.77, 0.26 } },
    order = 0,
    hit = { kind = "circles", radius = DOT_SIZE / 2 - 2, centres = function() return centres end },
    options = {
        { key = "opacity", type = "slider", label = L["Opacity"], min = 0, max = 100, step = 5, format = "%.0f%%", default = 100 },
    },
    apply = function(get)
        for _, dot in ipairs(dots) do
            dot:SetAlpha(get("opacity") / 100)
        end
    end,
    sample = function(state)
        live:SetShown(state == nil)
        sampleHolder:SetShown(state ~= nil)
    end,
})
