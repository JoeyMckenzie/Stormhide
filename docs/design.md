# Stormhide design

The working spec for Stormhide, a circular HUD for **Enhancement Shaman** on WoW Forever. Stormhide started as a copy of [Catnip](https://github.com/DurtsGaming/Catnip) (a Feral Druid HUD); Catnip's spec, with the history behind the engine pieces kept here (resource circle, swing ring, cast bar, GCD pie, five-second rule, mana prediction, combo rings, cooldown box, settings window), is `docs/design.md` at commit `0ea2f9c` (`git show 0ea2f9c:docs/design.md`). [design.pdf](design.pdf) and [layout-sketch.svg](layout-sketch.svg) are Catnip's originals, kept until Stormhide has its own.

## Concept

A compact, circular Enhancement Shaman HUD. From the centre out: the mana circle (with the GCD pie over it and the five-second-rule ring on its border), the swing timer ring (the cast bar takes its place while casting), then five dots along an arc above, each with a ring slot that can show a short cooldown. A separate box shows non-rotational cooldowns.

What shapes it, from the Forever guides (Icy Veins and Wowhead, Nov 2026):

- **Two-handed only.** Forever Enhancement has no dual wield, so there is one swing timer. Casting Lightning Bolt with fewer than 5 Maelstrom Weapon stacks resets the swing.
- **Mana is the only resource**, so the five-second rule and mana prediction matter.
- **Rotation at max level:** keep a fire totem down, Flame Shock (shares the shock cooldown with Earth Shock), Rage of the Farseer (3 min), Stormstrike every 6s, Lightning Bolt at 5 Maelstrom Weapon stacks, Earth Shock, Fire Nova (6s cooldown, needs a fire totem).
- **Maelstrom Weapon isn't tracked by Blizzard's Cooldown Manager**, which makes its stacks on the five dots Stormhide's main draw, built like Catnip's Lacerate stacks (one AuraContainer per dot, `SetApplicationBar`; see api-research.md, "Aura stacks").

Only what can be tested at the owner's current level gets built (level 7 as of 2026-11-14: Lightning Bolt, Earth Shock, Rockbiter Weapon, Healing Wave, Stoneskin and Earthbind Totem; Lightning Shield at 8, Flame Shock and fire totems at 10, Stormstrike at 25, Windfury Weapon at 30).

## Elements

1. **Mana circle.** Fills from the bottom with the Forever mana bar's gradient, the mana as a percentage (or value) in the middle. Other power types (a vehicle) get a flat grey fill.
2. **Five dots** above the circle, along its arc. Until Maelstrom Weapon exists they are **empty outlines, always shown** (owner, 2026-11-14), so the rings around them have somewhere to sit and the layout shows where Maelstrom will go. Listed in the settings as "Maelstrom Dots" (Opacity).
3. **Combo rings.** A ring slot around each dot ("Combo ring 1" to "Combo ring 5", each with a Shows dropdown, a Segments choice and Opacity), as in Catnip. The first Shaman ring:
   - **Earth Shock cooldown**, slot 3 by default: six segments (1s each over the 6s shock cooldown), earthy amber from dark umber to pale sand clockwise from 12 o'clock (`ring_earth_shock_circular`/`_angular`; a first guess, not sampled from the icon). Starts full when the cooldown starts and empties clockwise, timed by the game's own cooldown (exact in combat). `/stormhide es [seconds]` previews it. Flame Shock shares the cooldown, so from level 10 the ring should also run after a Flame Shock (unverified).
4. **Swing timer.** A ring around the circle that appears full on each swing and empties clockwise from 12 o'clock, over a soft black glow, with `elapsed / total` text below it (hidden when the swing is ready or while casting). Color, bar opacity and background opacity settings.
5. **Cast bar.** Takes the swing ring's place while casting: gold, filling counter-clockwise from 12 o'clock (channels blue, draining clockwise), with the cast time and spell name below. Blizzard's player cast bar can be hidden (General → Blizzard UI).
6. **GCD pie.** A faint white pie over the mana circle, timed exactly by the game's GCD (spell 29515's duration object). Catnip paced it to the swing outside Cat Form (a Bear design); Stormhide uses the exact GCD (owner, 2026-11-14).
7. **Five-second rule.** A deep indigo ring over the circle's border: a mana spend fills it, then it opens at 12 o'clock and drains down both sides over 5s. Only casts with a mana cost count.
8. **Mana cost prediction.** While a cast with a mana cost runs, the fill drops by the cost over a darker band; on a cancel it climbs back over a glowing band in 0.5s.
9. **Cooldown box.** Unchanged from Catnip: a separate box of icons for abilities the player picks, grey with a countdown on cooldown, coloured with running dashes while their buff is up.

## Preview mode

With `/stormhide` open on the Rotation tab (out of combat, outside Edit Mode), the HUD shows **one sample state** (owner, 2026-11-14; Catnip's Caster / Bear / Cat / Stealth buttons are gone): 80% mana, a 3.5s swing looping, the GCD pie sweeping every 2.5s, the five-second ring running, and every combo ring's sample draining in its slot. No cast is sampled, so the Cast Timer can be picked from the list but not on the HUD.

## Later

- **Maelstrom Weapon stacks on the dots** (talent; Stormhide's main feature): one AuraContainer per dot, as Catnip's Lacerate. Needs the buff's ID confirmed in-game (guides give 408498, which may be the talent rather than the buff).
- **Stormstrike** cooldown ring (17364, 6s), from level 25.
- **Flame Shock** (from level 10): its 12s DoT shares Earth Shock's cooldown; a DoT ring, or the shared shock ring. Its debuff would keep a cooldown-box icon lit past the cooldown, so it likely belongs in `COOLDOWN_ONLY` (Cooldowns.lua).
- **Fire Nova** (6s, needs a fire totem; ID unverified: 8349 or 408345) and **Rage of the Farseer** (3 min, ID unverified: 425336).
- **Totems and weapon imbues:** whether `GetTotemInfo` and `GetWeaponEnchantInfo` are readable in combat is unknown; probe before building.
- **Lightning Bolt's swing reset** below 5 Maelstrom stacks: whether `PLAYER_SWING` reports it is unverified.
- Delete Catnip's unused textures and their `make_textures.py` entries (a follow-up PR, owner, 2026-11-14).

## Status (as of 0.1.0)

How each piece works is in [architecture.md](architecture.md); the API facts behind it are in [api-research.md](api-research.md). "Verified in Catnip" means verified on a Druid; the same code on a Shaman still needs an in-game check.

| Feature | State |
|---------|-------|
| Mana circle and % number | Verified in Catnip; **untested** on a Shaman |
| Five empty dots | Built 2026-11-14, **untested** |
| Earth Shock cooldown ring (slot 3, `/stormhide es`) | Built 2026-11-14, **untested**; spell ID 8042 (Classic's rank 1) unverified |
| Combo ring slots (Shows, Segments, Opacity) | Verified in Catnip; **untested** with the Earth Shock ring |
| Swing timer and swing text | Verified in Catnip (Cat and Bear); **untested** with a two-hander |
| Cast bar and Blizzard cast bar hiding | Verified in Catnip; **untested** on a Shaman |
| GCD pie (exact GCD in every form) | The exact path verified in Catnip's Cat Form; **untested** on a Shaman |
| Five-second-rule ring | **untested** (Catnip never checked it in-game either) |
| Mana cost prediction | **untested** |
| Cooldown box | Verified in Catnip; **untested** on a Shaman |
| Preview mode with one sample state | Built 2026-11-14, **untested** |
| Settings window: Rotation tab without the preview strip or General zone (zones Above / Circle / Below), Shaman class icon and Lightning Bolt side tab icon | Built 2026-11-14, **untested** |
| Edit Mode (Blizzard's via LibEditMode, Stormhide's fallback) | Verified in Catnip; **untested** in Stormhide |
| Localization (enUS, zhCN) | zhCN lacks "Maelstrom Dots" and "Earth Shock Cooldown" |
