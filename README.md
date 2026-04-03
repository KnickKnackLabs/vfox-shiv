# vfox-shiv

mise backend plugin for [shiv](https://github.com/KnickKnackLabs/shiv) packages.

Declare shiv packages as tool dependencies in `mise.toml` with version pinning:

```toml
[tools]
"vfox-shiv:shimmer" = "0.1.0"
"vfox-shiv:notes" = "latest"
```

## How it works

The plugin delegates to shiv for the actual install. On first use, it bootstraps a pinned copy of shiv (via git clone), then calls `shiv install` with isolated paths so mise can manage versions independently.

The shiv-generated shim — the same bash script you get from `shiv install` — becomes the binary that mise activates on PATH. You get all of shiv's features (space-to-colon resolution, tab completions, task map caching) through mise's version management.

## Install

```bash
mise plugin install vfox-shiv https://github.com/KnickKnackLabs/vfox-shiv
```

Then in your `mise.toml`:

```toml
[tools]
"vfox-shiv:shimmer" = "0.1.0"
```

```bash
mise install
```

## Version resolution

- **Tags** are listed as versions (e.g., `v0.1.0` becomes `0.1.0`)
- **`latest`** tracks the default branch
- Branches and commits can be specified via mise's ref syntax

## Configuration

| Environment variable | Default | Description |
|---|---|---|
| `VFOX_SHIV_PATH` | `~/.local/share/mise/shiv-backend/shiv` | Path to the plugin's shiv clone |
| `VFOX_SHIV_REF` | `v0.1.0` | Pinned shiv version for the bootstrap |
| `VFOX_SHIV_REPO` | `https://github.com/KnickKnackLabs/shiv.git` | shiv repo URL |

The plugin reads package sources from `~/.config/shiv/sources/` (shared with your shiv installation) and falls back to the bundled `sources.json` in the shiv clone.

## License

MIT
