-- What we know about spell timing: whether a spell is on cooldown, and the GCD. Loads early so
-- every module can use it (the GCD pie, the cooldown rings, the cooldown box).
--
-- In combat a cooldown's start and duration are secret; only the isActive/isOnGCD flags are
-- readable. The cooldown box, rings and GCD pie hand Blizzard duration objects, which count down
-- exactly.
local addonName, ns = ...

-- Forever reports the GCD on Classic's GCD spell; retail's 61304 doesn't exist here (EllesmereUI's
-- Forever fix, PR #2240).
ns.GCD_SPELL = 29515

-- Is the GCD running? Readable in combat; secret or missing counts as not running.
function ns.GcdRunning()
    local info = C_Spell.GetSpellCooldown(ns.GCD_SPELL)
    local active = info and info.isActive
    return active == true
end

-- Is the ability on a real cooldown (not just the GCD)? Returns (onCooldown, sure): when sure is
-- false we couldn't tell and kept `previous`, and a timer shouldn't be restarted from this read.
-- Verified in and out of combat (2026-10-10, docs/api-research.md): isOnGCD is true while only the
-- GCD covers the spell, false for an on-GCD spell on its own cooldown, nil for an off-GCD spell, so
-- "isActive and isOnGCD ~= true" is a real cooldown, at once. (Until then, after a 2026-10-01
-- suspicion that isOnGCD turned true for Enrage on another spell's GCD, which the probe didn't
-- see, a GCD made the answer unsure and the cooldown box re-checked 1.6s later.)
function ns.CooldownState(spellID, previous)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info then
        return false, true
    end
    local active, onGCD = info.isActive, info.isOnGCD
    if ns.IsSecret(active) or ns.IsSecret(onGCD) then
        return previous, false
    end
    if active == nil then -- older field set: fall back to the numbers, readable out of combat
        local duration = info.duration
        if duration == nil or ns.IsSecret(duration) then
            return previous, false
        end
        return duration > 1.5, true
    end
    return active and onGCD ~= true, true
end
