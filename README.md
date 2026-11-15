# Stormhide

A compact circular HUD for Enhancement Shamans in **World of Warcraft: Forever**. **Work in progress:** not released yet.

Stormhide is built on [Catnip](https://github.com/DurtsGaming/Catnip), Durts' Feral Druid HUD for Forever, and reuses its engine: the resource circle, swing timer, cast bar, GCD, five-second rule, combo rings and cooldown box.

## Plan

1. **Skeleton:** mana circle, swing timer, cast bar, GCD, five-second rule and the cooldown box on a Shaman, with the Druid-only parts removed.
2. **Maelstrom Weapon:** its stacks on the five dots above the circle, lit up at 5.
3. **Rings:** Stormstrike, the shock cooldown, Flame Shock and Fire Nova.
4. **Later, if the API allows it in combat:** totems, a Windfury Weapon reminder and Lightning Shield charges.

## Installing (for now)

Clone or copy this repo into your Forever client's AddOns folder as `Stormhide`, so that `Stormhide.toc` sits directly inside `Interface/AddOns/Stormhide/`, then start the game and tick Stormhide in the AddOns list. `/stormhide` opens the settings.

## License

Stormhide is released under the [MIT License](LICENSE), as Catnip is. The bundled [LibEditMode](https://github.com/p3lim-wow/LibEditMode) library (in `libs/LibEditMode`) has its own license, in that folder.
