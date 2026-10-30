# Obsidian Quality of Life

Small fixes for HELLDIVERS (2015), each one an option. It's a client mod, so it only changes your own game.

| Option | What it does | Starts |
|---|---|---|
| Skip intro | No logos or intro video at launch. | Off |
| Skip login screen | Straight to the ship, still online. Keyboard and mouse become player 1's controls. | Off |
| Skip war briefs | No war recap when you log in after a long time. | Off |
| Skip planet scanning | No planet discovery animation after a liberation or a new sector. | Off |
| Widescreen fixes | No black bars on screens wider than 16:9. | On |
| Expedite mission end | Faster gives each results screen about a second, and Instant goes straight to the last screen. Your rewards are saved either way. | Off |

## How to Use

Obsidian Quality of Life comes with [Obsidian](https://github.com/Alomare/ObsidianModManager), in the Obsidian Kit folder, switched on. It updates from this repository.

Select it in the Mods tab to change the options, and deploy to apply the mod.

## Releasing

Set `version` in `obsidian.json`, commit, then push a tag with the same version:

```
git tag v1.1.1
git push origin v1.1.1
```

The Release workflow packs the mod into a `.zip` and publishes it, and Obsidian offers it as an update.

## License

[MIT](LICENSE)
