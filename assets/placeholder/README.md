# Placeholder art

Stand-in art for the map viewer (`specs/18-map-viewer.md`). These are ordinary committed
files, so replace them whenever real art exists.

## Map (`map/`)

| File | Used for |
|------|----------|
| `origin.svg` | ORIGIN nodes (homes) |
| `resource.svg` | RESOURCE nodes |
| `fort.svg` | FORT nodes |
| `neutral.svg` | NEUTRAL nodes |
| `waypoint.svg` | WAYPOINT nodes |
| `hidden_badge.svg` | Drawn beside a node hidden from some faction |

`map/map_art_set.tres` (a `MapArtSet`) wires these files to the viewer, together with
the faction palette, lane and edge colours.

**Replacing art:**
- **Same file name:** overwrite the SVG, or save a PNG with the same name and repoint
  the `.tres`. Godot re-imports it on the next editor focus or `--import`.
- **Different files:** open `map_art_set.tres` in the Inspector and drag your textures
  onto its fields. An empty field makes the viewer draw that shape in code instead.
- Node art is tinted with the owner's colour, so keep it light or greyscale.

`python tools/generate_placeholder_art.py` regenerates the default SVGs, overwriting
any edits to them.
