-- Swing timer: a ring around the resource circle that appears full on each swing and empties
-- clockwise from 12 o'clock until the next auto-attack. Driven by the PLAYER_SWING event
-- (Midnight-era API). Below it, "elapsed / total" text while a swing counts down.
local addonName, ns = ...
local L = ns.L
local CreateFrame = ns.Profiled("Swing") -- timed by /stormhide perf (Profiler.lua)

local SIZE = ns.SWING_RING_SIZE
local GLOW_SCALE = 1.14 -- ring_glow's soft band sits just inside ring_bar's band (1.18 centres it; see tools/make_textures.py)
local COLOR = { 1, 1, 1 } -- the default of the "Color" setting (below)

local hud = ns.hud

-- #4 glow ring: the timer's black, feathered background (darkest along the band, fading out)
local glow = hud:CreateTexture(nil, "BACKGROUND", nil, -6)
glow:SetTexture(ns.MEDIA .. "ring_glow")
glow:SetSize(SIZE * GLOW_SCALE, SIZE * GLOW_SCALE)
glow:SetPoint("CENTER")
glow:SetVertexColor(0, 0, 0, 0.75)

-- #7 bar ring, drawn by a Cooldown frame's swipe, which starts full and empties clockwise from
-- 12 o'clock. SetCooldown rejects secrets from addon code, but PLAYER_SWING's duration is a plain
-- number (verified in-game).
local ring = CreateFrame("Cooldown", nil, hud)
ring:SetSize(SIZE, SIZE)
ring:SetPoint("CENTER")
ring:SetSwipeTexture(ns.MEDIA .. "ring_bar")
ring:SetDrawEdge(false)
ring:SetDrawBling(false)
ring:SetHideCountdownNumbers(true)
ns.swingRing = ring -- Cast.lua hides it (via alpha, so it keeps timing) while casting

-- The swipe colour's alpha is the "Bar opacity" setting (the frame's own alpha belongs to Cast.lua).
local ringOpacity = 1
local function SetRingColor(color)
    ring:SetSwipeColor(color[1], color[2], color[3], ringOpacity)
end

SetRingColor(COLOR)

-- Swing text: "0.0 / 2.5s" (elapsed / swing length) where the cast text goes; same font as the cast time. Hidden once the swing is ready, and while casting (the cast
-- text takes the spot). The frame is only shown while a swing is counting down.
local info = CreateFrame("Frame", nil, hud)
info:SetSize(1, 1)
info:SetPoint("TOP", hud, "CENTER", 0, -ns.TIME_TEXT_OFFSET)
info:Hide()

local timeText = info:CreateFontString(nil, "OVERLAY")
timeText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") -- until the saved font is applied
timeText:SetPoint("TOP")
timeText:SetTextColor(1, 1, 1)
-- Cast.lua's "Swing/Cast Timer" setting sizes it, and picks it on the HUD while no cast shows.
ns.swingInfo, ns.swingTimeText = info, timeText

local swingStart, swingDuration

-- Preview mode (Preview.lua): while sampling, a made-up swing loops on the ring and text, and real
-- swings are only noted, not drawn.
local SAMPLE_SWING = 3.5
local sampling = false
local sampleStart -- the looping sample swing's start, while it shows
local sampleLength -- and its length

-- The text shows tenths, so it's only rewritten when the shown tenth (or the swing's length)
-- changes, not every frame (/stormhide perf, 2026-10-10: it was the second-costliest thing in combat).
local shownTenth, shownDuration

info:SetScript("OnUpdate", function()
    local start, duration = swingStart, swingDuration
    if sampleStart then
        if GetTime() - sampleStart >= sampleLength then -- loop
            sampleStart = GetTime()
            ring:SetCooldown(sampleStart, sampleLength)
        end
        start, duration = sampleStart, sampleLength
    end
    local elapsed = GetTime() - start
    if elapsed >= duration then
        info:Hide() -- swing ready
        return
    end
    timeText:SetShown(not (ns.IsCasting and ns.IsCasting()))
    local tenth = math.floor(elapsed * 10 + 0.5) -- as %.1f rounds it
    if tenth ~= shownTenth or duration ~= shownDuration then
        shownTenth, shownDuration = tenth, duration
        timeText:SetText(string.format("%.1f / %.1fs", elapsed, duration))
    end
end)

local function OnSwing(duration, weaponSlot)
    if ns.IsSecret(duration) or not duration or duration <= 0 then
        if not sampling then
            ring:Clear()
            info:Hide()
        end
        return
    end
    local now = GetTime()
    swingStart, swingDuration = now, duration
    if not sampling then
        ring:SetCooldown(now, duration)
        info:Show()
    end
end

-- Registered for its preview sample (the swing loop); its setting is Cast.lua's "Swing/Cast Timer".
ns.RegisterElement({
    id = "text.swing",
    zone = "text",
    name = L["Swing Time"],
    hidden = true, -- offered as one setting with the cast text: "Swing/Cast Timer" (Cast.lua)
    -- nil puts back the real swing, if one is still running.
    sample = function(state)
        sampling = state ~= nil
        if sampling then
            sampleStart, sampleLength = GetTime(), SAMPLE_SWING
            ring:SetCooldown(sampleStart, sampleLength)
            info:Show()
            return
        end
        sampleStart = nil
        if not sampling and swingStart and GetTime() - swingStart < swingDuration then
            ring:SetCooldown(swingStart, swingDuration)
            info:Show()
        else
            ring:Clear()
            info:Hide()
        end
    end,
})

-- Settings (Elements.lua). The ring and its black glow behind, the setting in the glow's vertex
-- colour. Hidden under a cast (the cast bar is picked there).
local function Percent(key, label, default)
    return { key = key, type = "slider", label = label, min = 0, max = 100, step = 5, format = "%.0f%%", default = default }
end
local RING_OUTER = SIZE * 127 / 256 -- ring_bar's band: 20 of 256 pixels thick, out to 127
local RING_INNER = SIZE * 107 / 256
ns.SWING_BAND = { inner = RING_INNER, outer = RING_OUTER } -- Cast.lua's ring sits in the same band

ns.RegisterElement({
    id = "swing.ring",
    zone = "swing",
    name = L["Swing Timer"],
    order = 1, -- in the Ring group: Swing Timer, Cast Timer
    glyph = { kind = "ring", color = { 0.91, 0.89, 0.82 } },
    hit = { kind = "ring", inner = RING_INNER, outer = RING_OUTER,
        visible = function() return not (ns.CastBarShown and ns.CastBarShown()) end },
    options = {
        Percent("barOpacity", L["Bar opacity"], 100),
        Percent("glowOpacity", L["Background opacity"], 75),
        { key = "color", type = "color", label = L["Color"], default = COLOR },
    },
    apply = function(get)
        ringOpacity = get("barOpacity") / 100
        glow:SetVertexColor(0, 0, 0, get("glowOpacity") / 100)
        SetRingColor(get("color"))
    end,
})

local events = CreateFrame("Frame")
local hasSwingEvent = ns.TryRegisterEvent(events, "PLAYER_SWING")
events:SetScript("OnEvent", function(_, _, ...)
    OnSwing(...)
end)

ns.OnLoad(function()
    if not hasSwingEvent then
        ns.Print(L["The swing timer isn't supported in this version of the game."])
    end
    ns.Debug("swing event:", hasSwingEvent, "C_SwingTimer:", C_SwingTimer and "present" or "missing")
end)
