---
spec_type: hybrid
status: active
parent_spec: ../Breach — Reverse Tower Defense Design Spec.md
---

# Local Designer App (save to repo + automatic import)

## Purpose

The Lane Tile Designer is where maps are authored. Until now it lived in a claude.ai
artifact, so a map reached Godot by copying JSON out by hand, saving it into the repo,
and running the import (specs/16) as a separate step. This item makes the designer a
**local application in the repo** (Decision 30):
- **Save** writes `content/maps_src/<name>.designer.json` and then runs the Godot import,
  which produces `content/maps/<name>.tres`.
- The import's warnings and errors show in the designer.
- The saved file reopens in the designer.
- The designer's libraries are repo data in `content/designer/`.

This comes before the rest of the render plan (Decision 29), which is renumbered:
- map layout and objectives → spec 18
- map viewer → spec 19
- structures → spec 20

## Components

- **`tools/designer/`**
  - **Designer:** `index.html`, `designer.css` and `designer.js`, moved from the artifact
    and split for readable diffs. Behaviour is unchanged. Additions:
    - **`loadFromExport(data)`** rebuilds the full designer state from an export:
      - nodes: fields, garrison units, hidden-from, structure segments/boundaries/roofs,
        and approach overrides that differ from the geometric default
      - tiles, roads, links, the faction roster, relations, loss criteria, grid and base
        terrain
      - `nextId`, derived from `n<number>` ids

      Derived export fields (routes, capacity, requirements, manning) are recomputed.
      Library entries the map uses but the local library lacks (factions, terrains,
      features, emplacements, room features) are merged in.
    - A `window.BreachDesigner` API (`buildExport`, `loadFromExport`, `mapName`,
      `libraryKeys`).
    - `window.BreachDesignerHooks` callbacks, invoked on every storage write and every
      map change.
  - **`repo.js`** is loaded first and has two modes.
    - With the server answering:
      - it copies `content/designer/*.json` into the designer's library storage keys,
        then loads `designer.js` (so the designer's library migrations still apply);
      - it mirrors later library writes back to the repo (debounced);
      - it adds **Open…**, **Save** (Ctrl+S), **Save as…** (Ctrl+Shift+S), Ctrl+O, and
        **Import libraries…** (a paste from the retired artifact);
      - a header bar shows the repo, whether Godot is configured, the current file, an
        unsaved-changes marker, and the save/import result. Failed imports open a details
        dialog.
    - Without the server (the page opened from disk), it just loads `designer.js`, which
      then behaves like the old standalone prototype.
  - **`designer_repo.py`**: `DesignerRepo` holds the file operations and the import
    runner.
    - Names are whitelisted (`[A-Za-z0-9_-]{1,64}`) and libraries come from a fixed list,
      so only `content/maps_src`, `content/maps` and `content/designer` can be touched.
    - JSON is written pretty-printed with LF line endings, and unchanged content is not
      rewritten.
    - `parse_import_output` reads the tool's `warning:` / `error:` / `wrote` lines.
    - `find_godot` checks, in order: `--godot`, `GODOT_BIN` (Git Bash `/f/...` paths are
      converted on Windows), then `tools/designer/local_config.json` (gitignored).
  - **`serve.py`**: a standard-library `ThreadingHTTPServer` on `127.0.0.1`.
    - It serves the four designer files and the JSON API (`/api/health`, `/api/maps`,
      `/api/maps/<name>`, `/api/libraries/<library>`).
    - Requests must come from `localhost`/`127.0.0.1` Host and Origin headers (this
      blocks DNS rebinding and cross-site writes). PUT bodies must be JSON, up to 16 MB.
    - Writes are serialised.
  - **`README.md`**: how to run it and what Save does.
- **`content/designer/*.json`**: the designer's libraries, seeded with its defaults.
- **Hooks and CI:** a `designer-server-tests` pre-commit hook runs
  `python -m unittest discover -s tools/designer`. CI already runs every pre-commit
  hook.
- **Importer:** the "not imported yet" warning now names specs 18/20.

## Scenarios (Given/When/Then)

```
Scenario: Saving a map writes the source JSON and runs the import
  Given a designer map and a configured Godot binary
  When it is saved as "m"
  Then content/maps_src/m.designer.json holds the export (pretty JSON, LF endings)
  And Godot runs tools/import_designer_map.gd with that JSON and content/maps/m.tres
  And the response carries the import's warnings, errors and output path

Scenario: Saving without Godot still saves
  Given no Godot binary is configured
  When a map is saved
  Then the JSON is written and the import reports it did not run, saying how to configure Godot

Scenario: Unsafe names and non-map bodies are rejected
  Given a name like "../escape", or a body without format "breach-designer-map"
  When saved
  Then the request fails and nothing is written

Scenario: Maps are listed and read back
  Given saved maps "a" and "b", with only "a" imported
  When the maps are listed
  Then both are listed in name order, with their import state
  And reading "a" returns exactly what was saved

Scenario: Libraries round-trip through the repo
  Given the factions library is written
  When it is read back
  Then the same value is returned, and rewriting identical content reports no change

Scenario: Import output is parsed, including crashes
  Given Godot output with warning:/error: lines, or a non-zero exit with no error lines
  When parsed
  Then the warnings and errors are listed, and a crash still yields an error with the output tail

Scenario: Only local pages may use the API
  Given a request with a foreign Origin or Host
  When it reaches the server
  Then it is refused with 403

Scenario: A saved map reopens identically (manual / Playwright)
  Given a map saved from the designer
  When it is opened in a fresh page and exported again
  Then the export equals the saved file
```

## Test-first order

1. `tools/designer/test_designer_repo.py`: names, save + import (with a fake runner),
   no-Godot and missing-binary cases, listing/reading, libraries, output parsing, Godot
   discovery.
2. `tools/designer/test_serve.py`: a real server on an ephemeral port over a temp repo;
   covers the page, health, the map round trip, 404/400/403 cases and libraries.
3. Manual / Playwright against the running server:
   - Open `test_map`, press Ctrl+S, and confirm `content/maps/test_map.tres` is written
     and the saved JSON is byte-for-byte the original.
   - Confirm export → `loadFromExport` → export is stable for `test_map` and the demo.
   - Confirm an import failure shows its errors and leaves no `.tres`.

## Notes / open questions

- Browser storage is per-origin, so the local app can't read the artifact's libraries.
  The retired artifact gets a "Copy libraries JSON" button for the one-time move, done
  after merge with the artifact retirement.
- No JS test harness exists in the repo. The designer's browser code is covered by
  Playwright runs rather than unit tests. If a JS harness is added later,
  `loadFromExport`'s round trip is the first test to port.

## Rubric answers (qualitative, spec-baseline)

- `single-noun-phrase`: `designer_repo.py` ("designer repo" operations), `serve.py`
  (the server), `repo.js` (the designer's repo mode), `designer.js` (the designer).
- `ocp-extension-point`: a new library is one entry in `LIBRARIES` (server) and
  `LIBRARY_KEYS` (`repo.js`). `repo.js` checks at load that its keys match `designer.js`.
- `lsp-contract-scope`: not applicable.
- `isp-fit`: `DesignerRepo` has one method per API operation. The designer exposes four
  members to `repo.js`.
- `dip-direction`: `tools/` depends on `content/` (it runs the import tool). No game code
  depends on `tools/designer`.

## Structured rubric notes

- `spec-type-declared`: `hybrid`. The server logic is unit-tested; the browser UI is
  verified manually and with Playwright.
- `tdd-plan-present`: see Scenarios and Test-first order.
- `no-drift`: implements Decision 30. The specs 18–20 renumbering is recorded there.
- `commit-classification-plan`:
  - `docs:` spec 17
  - `feat(tools):` the designer moved into the repo, with `loadFromExport`
  - `feat(tools):` the local server, tests and hook
  - `feat(tools):` repo mode (Open/Save/import status/library sync)
  - `feat(content):` seeded designer libraries
  - `docs:` Decision 30 and the specs 18–20 renumbering
