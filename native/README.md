# Breach's native core (Rust)

Decision 129: the simulation's hot core moves to Rust, through GDExtension
(godot-rust/gdext). It owns its state, and GDScript keeps the rules and stays the
reference behind one switch. The first production piece is in place:

- **`BodyField`**: the bodies' state, owned natively and kept across ticks.
- **Body parting** (UnitBodies) runs on the field.
- **The scrum's slot search** (ScrumSeek with SlotSearch, ScrumSlots and ScrumNear) runs
  on the field.

Both reproduce the GDScript reference bit for bit. The C++ kernel from the spike
(#174) is retired.

| | |
|---|---|
| Switch | `sim/skirmish/formation/native_kernels.gd`: `BREACH_NATIVE=gdscript\|rust` (env), else project setting `breach/native/engine`, else `gdscript`. `BREACH_NATIVE_THREADS=1` lets body parting use Rayon. A checkout without the library runs on GDScript, silently. |
| Rust | `native/rust/` - `godot` 0.5.5 (`api-4-7`), class `BodyField` |
| GDScript side | `body_field_sync.gd` (the sync), `body_parting.gd` (parting on the field), `scrum_seek_field.gd` (the slot search on the field) |
| Owner | `FormationSimulation._field`: one field a battle, made when the battle is (null under GDScript) |
| Benchmarks | `tools/native_bench.gd` (the two passes, split), `tools/tick_phases.gd` (a whole tick, phase by phase), `tools/formation_bench.gd` (whole ticks) |
| Identity | `tools/formation_digest.gd` (every set, both engines); `tests/sim/skirmish/formation/test_body_field.gd` and `test_body_parting.gd`; the whole suite under `BREACH_NATIVE=rust` |

## The native state and its boundary

```
GDScript (rules, reference)                    Rust: BodyField (one a battle)
-------------------------------------------    ---------------------------------------------
FormationSimulation._field ------------------> roster (persistent, incremental)
                                                 unit id -> body slot; squad id -> squad;
BodyFieldSync.scrum / .bodies  --sync------->     per body: radius, area, initiative, draw,
  one call, flat over squads in list order:       faction, squad; bodies in draw order
  ids, points, flags [, nexts, bases, bearings]  where each stands (as of the last sync):
  <- flat indices of units new to the field        at, offset/base (fleeing), next, flags,
  enrol(radius, area, draw, initiative) ------>    bearing; squads' members in list order
                                               passes on the field
BodyParting.step --------- part(tuning, way) -> parting (spike kernel, draw order)
  <- moved bodies (flat), points, nexts, loosened in order, stats
ScrumSeekField.plan ------ plan(rules' say) ---> seek: touch, contest order, kept slots,
  per fighting squad: its foes' squad ids          rings of slots, picks, presses; grids
  per unit: may seek, speed, place, goal           (native/rust/src/grid.rs); claims
  <- per unit: touch/stand/aim/press/idle, goal, next, foe_at
  within(unit, point) <- asked only on terrain
```

**What the field owns.** Everything about a body that doesn't change tick to tick:

- its unit id, radius, footprint area and initiative
- its seeded draw, `ScrumContest.draw`, which used to be hashed and sorted every tick
- its faction and squad

It also keeps the bodies in draw order and each squad's members in list order. The
roster changes incrementally. A sync names each squad's living units:

- a unit new to the field is enrolled once, with GDScript's own values, so no rule is
  copied to Rust
- a unit no squad names is dropped (the dead, the taken)
- a unit named under another squad moves with it

A battle's field lives as long as its simulation.

**What still crosses each tick: positions.** Where a body stands lives in GDScript, in
`unit.position`, `squad.loose[id]["at"]` and `squad.fleeing[id]["offset"]`. Eighteen
files write those, and every rule reads them. So the field is brought up to date by one
call a pass: the units' ids, points and flags, as packed arrays over all squads.
Making the field the single writer of positions is the next step. It means routing
those eighteen writers through the field, which is more than this PR's limit of 11
changed files.

**What GDScript still decides and hands in:** the rules.

- who may seek (front band, footprint, orders, chasers)
- a unit's place (ScrumStance.anchor)
- which squads a squad fights
- speed, which stamina changes every tick
- the ground: `terrain.factor`, called back only where there is terrain

**What comes back:** only what changed - the bodies parting moved, and each seeker's
goal, next point and foe point - written into the same dictionaries the GDScript path
writes, in the same order.

**The next ports share the field.** The spatial grid (BodyGrid, ScrumNear) is already
`grid.rs` over the field's points. Pathfinding and steering (UnitSteer) would read
`at`, `radius` and `squad` the same way. Each port that writes positions should write
them into the field first and then retire a GDScript writer, until the per-pass sync is
gone.

## Identity

The rules for matching Godot bit for bit (`native/rust/src/maths.rs`):

- `Vector2` maths is f32 (`real_t`) and GDScript `float` is f64; each operation is done
  in its own precision. `distance_to`, `length` and `dot` are f32 and widened when they
  meet an f64; `Vector2 * float` narrows the float first.
- `snappedf` is `floor(v / step + 0.5) * step`.
- `UnitMotion.vector` is `bearing * (PI / 180)` through the C library's `sin` and `cos`,
  which are the engine's own on the same platform.
- No fused multiply-add. Rust never contracts, and the library targets baseline x86-64.
- The same order everywhere: pairs, pushes, contest order, slot keys compared item by
  item, a full tie going to the slot listed first, foes in list order.
- The seeded draws reproduce Godot's `hash()` exactly (`ghash.rs`: MurmurHash3 over the
  elements' own hashes, `hash_one_uint64` for ints, djb2 for Strings, `Variant::ARRAY` as
  the seed). `test_body_field.gd` proves it against the engine's `hash()` on 10,000 keys
  of every shape the battle hashes. A slot's mirror-image draw is only computed when a
  tie needs it, which doesn't change the order of comparisons. The rare "two bodies on
  one spot" way still calls back `UnitBodies.part_way`.

### Fingerprints (`tools/formation_digest.gd`, every tick hashed)

The per-tick files are byte-identical between `BREACH_NATIVE=gdscript` and `rust`
(sha256 of each per-tick file):

| set | runs | ticks hashed | per-tick file (base = GDScript = Rust = Rust + Rayon) |
|---|---:|---:|---|
| standard | 26 | 14,099 | `bf2111e4aef6d3c4b2aa51350e65d6e6fd087ab82641762a74d3af6b9304c908` |
| clash160 | 1 | 210 | `a0b69851c6636a6eb8ed39234c7cb23c1fe06be70d1b88dac13d3c690d9cbd79` (run `65c64e72...`) |
| wide | 2 | 556 | `6236171952e39ccd6ca2368ec01f190814df13dc6bab9dcf0f490248442f55b0` (runs `c63e9548...`, `84724206...`) |

"base" is `origin/feature/movement-integrate` (f4a6490) before this change, on GDScript.
Each set gives the same file under the release and the dev build, with and without
`BREACH_NATIVE_THREADS=1`.

The suite proves the same:

- `test_body_parting.gd`: a crowd parted the same as GDScript, reversed, on a field kept
  across ticks while units die and change squad, and a 40-a-side battle.
- `test_body_field.gd`: the hash, the roster, and the slot search planning a mid-fight
  scrum the same as GDScript at four moments and whatever the list order.
- The whole suite under `BREACH_NATIVE=rust`, including its reversed-list tests:
  948 of 948 pass, as they do on GDScript.

## Results

Linux x86_64, Godot 4.7.2 official, release build, 4 cores shared with another job, so
whole ticks carry a few % of noise. FormationBench's clash (grems v militia, seed 1),
mid-fight: 10 ticks after 10 ticks of contact. Figures are ms a tick, the median of 3
runs.

### The two ported passes (`tools/native_bench.gd`)

| a side (wide) | engine | whole tick | body parting | slot search (ScrumSeek.plan) |
|---|---|---:|---:|---:|
| 160 (10) | GDScript | 127.3 | 28.9 | 65.0 |
| | Rust | **28.2** | **1.39** | **3.27** |
| 512 (32) | GDScript | 565.4 | 101.0 | 293.5 |
| | Rust | **162.7** | **5.67** | **14.3** |
| 1024 (32) | GDScript | 899.6 | 168.2 | 424.0 |
| | Rust | **280.2** | **9.10** | **23.8** |

Where the Rust passes' time goes, at 1,024 a side:

| pass | sync (GDScript) | the rules' say (GDScript) | Rust's own work | crossing the boundary | write back (GDScript) |
|---|---:|---:|---:|---:|---:|
| body parting (9.1) | 4.47 | - | 2.98 | 0.03 | 1.46 |
| slot search (23.8) | 3.39 | 9.18 | 7.73 | 0.06 | 3.23 |

- **Body parting: 168 -> 9.1 ms.** The spike's pass was 18 ms. The per-tick draws, the sort
  and the radius, area and index lookups are gone. Rust's work is 3 ms. Most of the rest
  is the position sync, which goes once the field owns positions (see the boundary).
- **The slot search: 424 -> 24 ms (18x).** Rust's work is 7.7 ms. GDScript now spends
  about 16 ms around it: the sync, the rules' say (anchors, chasers, foe ids), and
  writing back.
- **Rayon** (`BREACH_NATIVE_THREADS=1`, parting only) is within noise or slower at every
  size: 3 ms isn't worth a thread pool.

### Where a tick's time goes now (`tools/tick_phases.gd`, 1,024 a side, 32 wide)

| phase | GDScript | Rust |
|---|---:|---:|
| deaths, wounds, morale (FormationDeaths, Taking, Wounds, Recovery, Morale) | 86.1 | 66.4 |
| scrum: face foes (FormationScrum._faces: ScrumNear, ScrumBlows.nearest_touching) | 37.5 | 37.0 |
| scrum: walk (UnitSteer.toward, GroundBodies.underfoot) | 34.8 | 29.8 |
| fight (ScrumBlows.blows, BlowLanding) | 33.5 | 26.9 |
| scrum: seek (the slot search) | 445.9 | 26.5 |
| shuffle, units to their places (FormationShuffle, FormationMarch.sync_units) | 23.3 | 15.6 |
| rout, carry, groups, stamina | 12.6 | 11.9 |
| bodies (UnitBodies) | 161.0 | 9.6 |
| scrum: the bodies snapshot (ScrumSlots.bodies, BodyGrid) | 7.6 | 7.0 |
| everything else | 10.0 | 9.5 |
| **whole tick** | **852** | **240** |

`tools/formation_bench.gd` mid-fight, average and worst, GDScript -> Rust:

- 160 a side: 124 -> 48 ms
- 512 a side: 481 -> 157 ms
- 1,024 a side: 938 -> 313 ms (worst 1,260 -> 487)

**Marching is unchanged**: 318-354 ms at 1,024 a side, before any contact. Neither
ported pass is what a marching tick spends.

Reading it: at 1,024 a side the tick is about 3.5x faster, but it is still 2.4x the
100 ms budget. What is left is GDScript rule code over every unit. The worst of it:

- the deaths/wounds/morale phase (66 ms, the largest now)
- the scrum's facing and walking (67 ms together: foe searches and steering per unit)
- blows (27 ms)
- the per-tick syncs and write-backs around the two ports (about 20 ms)
- marching

The next ports, in order of payoff:

1. Positions owned by the field, which removes the syncs.
2. ScrumNear, facing and steering.
3. Blows.
4. A profile of the deaths/wounds phase, which may be a GDScript fix rather than a port.

## Building

```
bash native/build.sh          # release (thin LTO): what to measure and ship
bash native/build.sh dev      # optimised without LTO: rebuilds in seconds
```

This puts `native/bin/[lib]breach_rust.<platform>.<ext>` in place. It is git-ignored, as
is `native/rust/target`. Results are the same bit for bit under either profile.
`cargo test` in `native/rust` checks the hash against values printed by Godot.

`native/` holds a `.gdignore`, so the editor never scans it. `breach_rust.gdextension`
is loaded at run time by NativeKernels only when Rust is chosen and built. An export
would need the library and the `.gdextension` added.

- **Windows:** `rustup` with `x86_64-pc-windows-msvc` and the Visual Studio Build Tools.
  Run `bash native/build.sh` in Git Bash; it maps MINGW/MSYS to `windows.x86_64` and
  `.dll`.
- **macOS:** the Xcode command-line tools. Build `aarch64-apple-darwin` and
  `x86_64-apple-darwin` and join them with `lipo` into the `.universal.dylib`. Sign it
  ad hoc (`codesign -s -`) so it loads on Apple silicon.
- **CI:** a matrix (ubuntu, windows, macos) running `bash native/build.sh`, caching
  `~/.cargo` and `native/rust/target`, and uploading `native/bin/*`. The gdUnit job then
  runs the suite twice, plain and with `BREACH_NATIVE=rust`, plus
  `tools/formation_digest.gd` under each, and diffs the files. The identity check is
  what lets the core be trusted.
