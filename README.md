# Obsidian Patches

Small fixes for HELLDIVERS (2015), each one an option in Obsidian. Five of them can also be changed in game, in the pause menu under **Mods → Obsidian Patches**, and a change there goes back to Obsidian. As a client mod, it changes only the game it runs in, and it needs Obsidian API, which turns on with it.

| Option | What it does | Starts | In the pause menu |
|---|---|---|---|
| Widescreen fixes | No black bars on screens wider than 16:9, and the objective list, dialogue boxes and galaxy map panels at the real edges of the screen. | On | |
| Expedite mission end | Faster gives each results screen about a second, and Instant goes straight to the last screen. Rewards are saved either way. | Faster | Yes |
| Skip intro | No logos or intro video at launch. | On | |
| Skip login screen | Starts on the ship, still online, with keyboard and mouse as the player 1 controls. | On | |
| Skip war briefs | Hides the war recap shown at login after a long absence. | Off | |
| Skip planet scanning | No planet discovery animation after a liberation or a new sector. | On | |
| Dynamic solo pause | With a single player in the mission, the pause menu freezes the game, even in a public or friends-only lobby. | On | Yes |
| Aim cursor always visible | On PC, the cursor keeps the aiming look at all times. | Off | Yes |
| Toggle minimap | The map key opens the minimap and keeps it open until pressed again. | Off | Yes |
| Dynamic input switch | With a keyboard and a gamepad connected, both control the first Helldiver and the button prompts follow the last one used. The gamepad joins as a second Helldiver only when its join button is held for 1.5 seconds, and the prompt reads HOLD instead of PRESS. | Off | Yes |
| Weapon recoil animation fix | Brings back the recoil animation of the weapon in hand when a stratagem throw, or a weapon picked up from the ground, leaves it out. Covers the player, a second controller and bots run by this game. | On | |
| Sprint pose fix | Sprinting right after getting up from a dive shows the normal running pose, instead of an upper body stuck until the sprint starts over. | On | |

## How to Use

Obsidian Patches comes with [Obsidian](https://github.com/Alomare/ObsidianModManager), in the Obsidian Kit folder, switched on. It updates from this repository.

All twelve options are in Obsidian, in the details of Obsidian Patches, and take effect at the next launch. The five marked above are also in the game's pause menu, under **Mods**: a change there takes effect at once, and Obsidian saves it to the profile once the game is closed. The pause menu rows need Obsidian API 1.16.0 or newer.

## Releasing

Set `version` in `obsidian.json`, add a section for it to `CHANGELOG.md`, commit, then push a tag with the same version:

```
git tag v1.7.0
git push origin v1.7.0
```

The Release workflow packs the mod into a `.zip` and publishes it, and Obsidian offers it as an update.

## License

[MIT](LICENSE)
