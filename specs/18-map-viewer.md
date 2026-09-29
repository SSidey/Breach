---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Map Viewer (MapDef → drawn map)

## Purpose

The designer saves maps into Godot as `content/maps/<name>.tres` (specs/16, specs/17),
but nothing draws a `MapDef`, so a map can only be inspected as Inspector text. This
item adds a **map viewer**: a Godot scene that draws any designer map. The user chose to
build it before the layout schema (Decision 31), which renumbers that work to spec 19 and
structures to spec 20.

The viewer draws everything a `MapDef` holds today:
- nodes at their positions, with type art, owner colour, id and garrison count
- which nodes are hidden, and from whom
- lanes as paths, extra edges as dashed lines
- off-lane nodes

Tiles, roads and route geometry appear once spec 19 gives them schema. Placeholder art
is **committed, replaceable files** (the user's request): SVGs behind a `MapArtSet`
resource, with the same shapes drawn in code whenever a texture is missing.

Nothing here plays the map. `main.tscn` and the P-f-F-c slice are untouched.

## Components

- **`MapViewModel`** (new, `presentation/map_view_model.gd`): pure and headless. Static
  `build(map_def, view_as_faction_id := "")` returns:
  - **`markers`**: one per unique `NodeDef` across lanes and `off_lane_nodes`, with
    shared node instances deduplicated. Each marker carries id, position, node_type,
    owner, garrison, hidden_from, on_lane and hidden_badge.
  - **`lane_paths`**: per lane, its id and one or more runs of positions in node order.
  - **`edge_segments`**: position pairs, resolved by node id.
  - **`bounds`**: a `Rect2` covering the markers, snapped outward to whole 64 px cells
    (nodes sit at cell centres) and grown by one more cell. The default
    is a 10×6-cell rect when the map has no nodes.
  - **`faction_color(id, palette, neutral)`**: the faction's index in `MapDef.factions`,
    wrapped over the palette. An empty or unknown owner gets `neutral`.
  - **`node_at(point, radius)`**: the id of the nearest visible marker within `radius`,
    else "".

  **View-as** (Decision 28's semantics):
  - Empty `view_as` means the designer view: everything is shown, and a node hidden from
    anyone has `hidden_badge`.
  - With a faction set, nodes hidden from that faction are left out, along with every
    edge touching them. A lane path splits into separate runs at a hidden node rather
    than bridging over it.
- **`MapArtSet`** (new, `presentation/map_art_set.gd`, a Resource):
  - one exported texture per node type, plus `hidden_badge`
  - `faction_palette` (the designer's six colours), `neutral_color`, `lane_colors` and
    `edge_color`
  - `texture_for(node_type) -> Texture2D`, which returns null when the texture is unset
- **Placeholder art:**
  - `tools/generate_placeholder_art.py` (stdlib) writes `assets/placeholder/map/*.svg`:
    a circle for an origin, a diamond for a resource, a crenellated square for a fort,
    a hexagon for neutral, a dot for a waypoint, and an eye-slash badge. Shapes are light
    grey, so owner colour modulates them.
  - `assets/placeholder/map/map_art_set.tres` references the SVGs.
  - `assets/placeholder/README.md` explains how to replace the art.
- **`MapView`** (new, `presentation/map_view.gd`, a `@tool` Node2D): exports `map`,
  `art_set` and `view_as_faction_id`, and redraws whenever any of them changes, including
  in the editor viewport. Engine glue with a smoke test. It draws, in order:
  1. a faint grid
  2. dashed edges
  3. lane paths
  4. owner-tinted node art, or the code-drawn fallback
  5. labels
  6. hidden badges
- **`map_viewer.tscn` / `MapViewer`** (new, `presentation/`): engine glue.
  - Map picker over `res://content/maps/*.tres`, skipping files that aren't a `MapDef`.
  - "View as" picker: Designer (everything), plus each map faction.
  - `Camera2D` with drag-to-pan, wheel zoom and a Fit button.
  - Clicking a node shows its details.
  - `--map=<res path>` in the user args preselects a map.
- **Designer → viewer:**
  - `POST /api/maps/<name>/view` (serve.py / `DesignerRepo.view_map`) launches Godot on
    the viewer scene with `--map`, as a detached process. It's an error if Godot isn't
    configured or the `.tres` doesn't exist.
  - The designer gets a **View in Godot** button, which saves first if the map has
    unsaved changes.
- **Importer:** the "not imported yet" warning now names specs 19/20.

## Scenarios (Given/When/Then)

```
Scenario: Every node gets exactly one marker
  Given a map whose home node is shared by two lanes, plus one off-lane node
  When the view model is built
  Then each node id appears once, and only the off-lane node has on_lane false

Scenario: Lanes and edges resolve to positions
  Given a lane a,b,c and an edge b<->x
  When the view model is built
  Then the lane path runs through a, b, c's positions in order and the edge joins b and x

Scenario: Bounds frame the map
  Given nodes spanning (32,32)..(416,224)
  When the view model is built
  Then bounds is (-64,-64)..(512,320): whole cells around the nodes plus one cell, every
  edge on a cell boundary; with no nodes it is the default rect

Scenario: Designer view badges hidden nodes
  Given a node hidden from "kingdom"
  When built with no view-as faction
  Then the node is shown with hidden_badge true

Scenario: Viewing as a faction removes what it doesn't know about
  Given lane a,b,c where b is hidden from "kingdom", and an edge b<->x
  When built as "kingdom"
  Then b has no marker, the edge is gone, and the lane path is two runs, [a] and [c]
  (runs of one point are kept so they still draw)

Scenario: Owner colour follows the faction roster
  Given factions [player, kingdom]
  Then player -> palette[0], kingdom -> palette[1], "" and unknown ids -> neutral

Scenario: Clicking finds the nearest visible node
  Given markers at (0,0) and (100,0)
  Then node_at((10,5), 24) is the first, and node_at((50,0), 24) is ""

Scenario: The committed art set covers every node type
  Given assets/placeholder/map/map_art_set.tres
  Then texture_for returns a texture for every NodeType, and hidden_badge is set
  And a fresh MapArtSet returns null (so MapView falls back to drawn shapes)

Scenario: The viewer can be launched from the designer
  Given an imported map "m" and a configured Godot
  When the view endpoint is called
  Then Godot is launched with the viewer scene and --map=res://content/maps/m.tres
  And with no Godot, or no m.tres, it fails with a clear message and launches nothing
```

## Test-first order

1. `tests/presentation/test_map_view_model.gd`: the scenarios above, using small
   hand-built `MapDef`s plus the demo fixture imported through `DesignerMapImporter`.
2. `tests/presentation/test_map_art_set.gd`.
3. Smoke tests: `MapView` constructs and accepts the demo map; `map_viewer.tscn`
   instantiates.
4. Python: `view_map` and the endpoint in `tools/designer/test_*.py`, and the placeholder
   generator's SVGs parse (`tools/designer/test_placeholder_art.py`).
5. Manual:
   - Open the viewer scene in the editor and in play mode, on `demo_map` and a
     user-authored map: pan, zoom, fit, view-as, click.
   - Press View in Godot from the designer.

## Notes / open questions

- **Faction colour:** it follows the map's roster order. The designer colours by library
  order, so the two can differ when the library has factions a map doesn't use. A stored
  `FactionDef.color` would fix that, but it's schema plus a designer change; left for the
  user to call.
- `is_critical_asset` and loss criteria have no schema yet (spec 19), so the viewer
  can't mark critical assets.
- The viewer's rendering has no automated coverage beyond smoke tests (it needs a render
  context), the same as `LaneView`. Manual runs verify it.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `map_view_model.gd`, `map_art_set.gd`, `map_view.gd`,
  `map_viewer.gd`.
- `ocp-extension-point`: spec 19's layers (tiles, roads, routes) become new view-model
  fields and new draw passes; the existing ones don't change.
- `lsp-contract-scope`: not applicable.
- `isp-fit`: `MapViewModel` exposes `build`, `faction_color` and `node_at` plus data
  fields; `MapArtSet` exposes `texture_for`.
- `dip-direction`: `presentation/` reads `content/` definitions only. Nothing in `sim/`
  or `content/` references the viewer.

## Structured rubric notes

- `spec-type-declared`: `hybrid`. The view model and art set are TDD; the drawing and
  scene are engine glue (smoke test plus manual check).
- `tdd-plan-present`: see Scenarios and Test-first order.
- `no-drift`: implements Decision 31 (viewer before layout; placeholder art as committed
  files).
- `commit-classification-plan`:
  - `docs:` spec 18
  - `feat(presentation):` map view model
  - `feat(presentation):` art set + placeholder art
  - `feat(presentation):` map view + viewer scene
  - `feat(tools):` View in Godot
  - `docs:` Decision 31 and renumbering
