-- Short cooldowns as segmented rings around the combo points, each in whichever combo ring slot
-- the player picks for it (ComboRings.lua). Each ring starts full when the cooldown starts and
-- empties clockwise from 12 o'clock over it, leaving nothing behind; when ready it's simply gone
-- (no flash). (Segments pulsed as they emptied until 2026-10-10.)
-- Each is a SegmentedArc.lua ring (a radial StatusBar) timed by SegmentedCooldown.lua (the game's
-- own cooldown), coloured from its spell's icon (make_textures.py). Its segments are Circular by
-- default or Angular, the player's pick (ComboRings.lua), both drawn into the art
-- (`art`_circular, `art`_angular), so a different segment count means regenerating those. The
-- timing runs whether or not the ring is in a slot.
local addonName, ns = ...
local L = ns.L

local RING_SIZE = ns.COMBO_DOT_SIZE + 8 -- the ring textures have ring_rip's band

local RINGS = {
    {
        key = "es",
        label = "Earth Shock",
        choice = L["Earth Shock Cooldown"],
        order = 1,
        dot = 3,
        art = "ring_earth_shock",
        color = { 0.80, 0.56, 0.24 },
        spells = { ns.SPELL.EARTH_SHOCK },
        defaultLength = 6,
        command = "es",
    },
}

for _, ring in ipairs(RINGS) do
    -- Made out of sight; ns.PlaceComboRing moves each into its slot.
    local function Arc()
        local arc = ns.CreateSegmentedArc({
            parent = UIParent,
            size = RING_SIZE,
            art = ring.art .. "_circular", -- ns.ShapeComboRingArc sets the shape picked
            from = math.pi / 2, -- 12 o'clock
            span = 2 * math.pi,
            clockwise = true,
            drain = true,
            noFlash = true,
        })
        ns.PlaceComboRing(arc.frame, nil)
        return arc
    end

    local arc = Arc()
    ns.CreateSegmentedCooldown({
        label = ring.label,
        spells = ring.spells,
        defaultLength = ring.defaultLength,
        command = ring.command, -- /stormhide <command> [seconds] (shows only while in a slot)
        arc = arc,
    })

    -- Preview mode's looping copy (ns.ArcSampler).
    local sampleArc = Arc()
    local StartSample, StopSample = ns.ArcSampler(sampleArc, ring.defaultLength)

    ns.AddComboRingSpell({
        key = ring.key,
        label = ring.choice,
        color = ring.color,
        order = ring.order,
        defaultSlot = ring.dot,
        shape = "circular", -- by default
        Place = function(slot)
            ns.ShapeComboRingArc(arc, ring.key, ring.art)
            ns.PlaceComboRing(arc.frame, slot and slot.gate, slot and slot.index)
        end,
        StartSample = function(slot)
            ns.ShapeComboRingArc(sampleArc, ring.key, ring.art)
            ns.PlaceComboRing(sampleArc.frame, slot.sampleGate, slot.index)
            StartSample()
        end,
        StopSample = StopSample,
    })
end
