# Obsidian Quality of Life

Small fixes for HELLDIVERS (2015), each one a setting in the pause menu, under **Mods → Obsidian QoL**. Skip intro and Skip login screen take effect at the next launch; the others at once. As a client mod, it changes only the game it runs in, and it needs Obsidian API, which turns on with it.

| Setting | What it does | Starts |
|---|---|---|
| Skip intro | No logos or intro video at launch. | Off |
| Skip login screen | Starts on the ship, still online, with keyboard and mouse as the player 1 controls. | Off |
| Skip war briefs | Hides the war recap shown at login after a long absence. | Off |
| Skip planet scanning | No planet discovery animation after a liberation or a new sector. | Off |
| Expedite mission end | Faster gives each results screen about a second, and Instant goes straight to the last screen. Rewards are saved either way. | Off |
| Dynamic solo pause | With a single player in the mission, the pause menu freezes the game, even in a public or friends-only lobby. | On |
| Aim cursor always visible | On PC, the cursor keeps the aiming look at all times. | Off |
| Toggle minimap | The map key opens the minimap and keeps it open until pressed again. | Off |
| Widescreen fixes | No black bars on screens wider than 16:9. | On |

## How to Use

Obsidian Quality of Life comes with [Obsidian](https://github.com/Alomare/ObsidianModManager), in the Obsidian Kit folder, switched on. It updates from this repository.

The settings are in the game's pause menu, under **Mods**.

## Releasing

Set `version` in `obsidian.json`, commit, then push a tag with the same version:

```
git tag v1.1.1
git push origin v1.1.1
```

The Release workflow packs the mod into a `.zip` and publishes it, and Obsidian offers it as an update.

## License

[MIT](LICENSE)
