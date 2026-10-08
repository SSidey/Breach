# Native spike: GDScript vs Rust vs C++

A measured spike, not a production port: one hot simulation loop - UnitBodies'
body-parting pass - implemented three ways behind one switch, to inform the decision on
moving hot loops to GDExtension. GDScript stays the reference and the default.

| | |
|---|---|
| Loop | `UnitBodies.step` (sim/skirmish/formation/unit_bodies.gd): find overlapping bodies through 2-cell buckets, push them apart by mass, `bodies_passes` times a tick |
| GDScript side | `sim/skirmish/formation/body_parting.gd` (gather packed arrays, call, write back) |
| Switch | `sim/skirmish/formation/native_kernels.gd`: `BREACH_NATIVE=gdscript\|rust\|cpp` (env), else project setting `breach/native/engine`, else `gdscript`; `BREACH_NATIVE_THREADS=1` lets Rust use Rayon |
| Rust | `native/rust/` - godot-rust (`godot` 0.5.5, feature `api-4-7`), class `BodyPartingRust` |
| C++ | `native/cpp/` - godot-cpp (master @ 272e7f4, `GODOTCPP_API_VERSION=4.7`), class `BodyPartingCpp` |
| Benchmark | `tools/native_bench.gd` |
| Identity | `tools/formation_digest.gd` (all sets) per engine; `tests/sim/skirmish/formation/test_body_parting.gd` |

## Interface

Data in, data out, one call a tick (all passes run natively):

```
part(points: PackedVector2Array,  # where each body stands (a router's offset)
     bases: PackedVector2Array,   # a router's point on its route
     nexts: PackedVector2Array,   # a loose unit's next point
     radii, areas: PackedFloat64Array,
     squads, factions: PackedInt32Array,   # indices, compared only for equality
     flags: PackedByteArray,      # 1 loose, 2 fleeing
     tuning: PackedFloat64Array,  # [bodies_passes, bodies_resist, bodies_brush]
     way: Callable,               # (i, j) -> Vector2: the seeded way two coincident bodies part
     threaded: bool) -> [points, nexts, flags (+4 moved), loosened (in order), stats]
```

The bodies' draw order (hash-seeded, Decision 97) stays in GDScript, and so does the
seeded angle for two bodies lying exactly on each other (`UnitBodies.part_way`, called
back through the Callable - rare, and it keeps Godot's `hash()` and `sin`/`cos` the
engine's own).

## Determinism

Results are bit-identical to GDScript (see the digests below). What it takes:

- `Vector2` is f32 (`real_t`) and GDScript `float` is f64: each operation is mirrored in
  its own precision. `length()` is `sqrtf(x*x + y*y)` widened to f64 before it meets the
  radii; `Vector2 * float` narrows the float to f32 first, so `way * depth * share` is two
  f32 multiplies; masses and shares are f64.
- Same order everywhere: pairs sorted as `i * count + j`, pushes summed in pair order
  starting from `Vector2.ZERO`, moves applied in first-touched order (which is also the
  order units are made loose, so the `loose` dictionaries keep GDScript's key order).
- No fused multiply-add: C++ builds with `-ffp-contract=off -fno-fast-math` (MSVC:
  `/fp:precise /fp:contract-`); Rust never contracts. `objdump | grep vfmadd` finds none in
  either library. Neither targets beyond baseline x86-64, so no FMA instructions exist to
  be chosen.
- Threads (Rust only): pairs are found and pushes weighed in parallel from the pass's
  snapshot, then the pair list is sorted and pushes applied serially in pair order, so the
  result is the same as serial (the digests agree). The callback is only made on the main
  thread.

## Results

Linux x86_64, Godot 4.7.2 official, 4 cores shared with another job (so whole-tick
numbers carry a few % of noise); `tools/native_bench.gd`, FormationBench's clash
(grems v militia, seed 1), 10 ticks after 10 ticks of contact, 3 runs, ms a tick,
**median** (min within ~3%; full log in the PR/hand-off).

| a side (wide) | engine | whole tick | pass (UnitBodies.step) | gather (GDScript) | call (boundary + kernel) | kernel alone | write back (GDScript) |
|---|---|---:|---:|---:|---:|---:|---:|
| 160 (10) | GDScript | 103.3 | 22.71 | - | - | - | - |
| | Rust | 84.8 | 2.36 | 0.69 | 0.56 | **0.53** | 0.28 |
| | C++ | 90.1 | 2.66 | 0.79 | 0.61 | **0.58** | 0.31 |
| | Rust + Rayon | 91.3 | 3.05 | 0.71 | 1.11 | 1.07 | 0.35 |
| 512 (32) | GDScript | 443.8 | 83.28 | - | - | - | - |
| | Rust | 393.7 | 9.06 | 2.78 | 1.79 | **1.75** | 1.41 |
| | C++ | 373.1 | 9.11 | 2.78 | 2.14 | **2.09** | 1.35 |
| | Rust + Rayon | 387.8 | 9.98 | 2.92 | 2.42 | 2.38 | 1.52 |
| 1024 (32) | GDScript | 735.3 | 135.18 | - | - | - | - |
| | Rust | 649.6 | 18.02 | 6.57 | 3.04 | **2.98** | 1.73 |
| | C++ | 626.7 | 17.81 | 6.22 | 3.41 | **3.33** | 1.66 |
| | Rust + Rayon | 621.1 | 17.04 | 6.25 | 2.63 | 2.58 | 1.69 |

Reading it:

- **The kernel is ~45x GDScript** (1024: 135 ms -> 3.0 ms Rust, 3.3 ms C++). Rust and C++
  are within noise of each other; Rust's small edge is its cheaper bucket hash (FxHash vs
  `std::unordered_map`), not the language.
- **Crossing the boundary itself is nearly free**: call minus kernel is 0.03-0.08 ms -
  packed arrays are copy-on-write, so passing them is a pointer, and both bindings read them
  as slices. What costs is **marshalling in GDScript**: walking squads' dictionaries to
  gather (6.2-6.6 ms at 1024) and write back (1.7 ms), plus the draw order (`_drawn`,
  hash-seeded draws and a sort, ~6.7 ms) which stays in GDScript. So the pass falls 7.5x
  (135 -> 18 ms), not 45x. If the native side owned the bodies' state (positions, loose and
  fleeing points kept in native arrays across ticks), the pass would cost the kernel column:
  ~3 ms at 1024.
- **The pass is ~18% of a tick** (135 of 735 ms at 1024): the whole tick falls ~12-15%
  (735 -> 627-650 ms). The rest of the tick (~600 ms at 1024: the scrum's slot search,
  steering, combat) is still GDScript and is where the next win is.
- **Threads** (Rayon, deterministic: snapshot, parallel pair search and push weights,
  sorted, applied serially): slower below ~1,000 a side (pool wake-up and the extra sort
  cost more than 0.5-2 ms of work), 13% faster at 1024. Practical and safe, not worth it
  for this loop; worth it for a heavier loop.

### Identity (`tools/formation_digest.gd`, every tick hashed)

Per-tick hash files are byte-identical for every engine, and to the branch before this
change (`origin/feature/movement-perf`, GDScript):

| set | runs | ticks hashed | sha256 of the per-tick file (base = GDScript = Rust = C++ = Rust+Rayon) |
|---|---:|---:|---|
| standard | 26 | 13,910 | `d4cd14d5e3454ce4...` |
| clash160 | 1 | 210 | `c0de65f8d888f08a...` (run hash `dd556c40958aec25...`) |
| wide | 2 | 555 | `38f38b8cc73a24e4...` (run hashes `b3f87282a82b796d...`, `a3644aa27a3dd676...`) |

`tests/sim/skirmish/formation/test_body_parting.gd` checks the same in the suite: a crowd
(framed, loose, fleeing, friends, foes, two bodies on one spot so the callback runs)
parted bit for bit as GDScript, the same reversed, and 70 ticks of a 40-a-side battle.

## Developer experience

| | Rust (godot-rust) | C++ (godot-cpp) |
|---|---|---|
| Setup | `cargo` only; `godot = { version = "0.5.5", features = ["api-4-7"] }` - the 4.7 API ships in the crate, no dump needed | clone godot-cpp (pinned), Python + CMake (or SCons); 4.7 API bundled in master (`GODOTCPP_API_VERSION=4.7`) |
| Clean build (-j2, shared box) | 3 min 09 s (deps incl. gdext codegen) | 7 min 37 s (godot-cpp's ~1,100 generated binding files) |
| Rebuild after touching the kernel | dev: 0.8 s; release (thin LTO, 1 codegen unit): ~1 min 30 s (drop LTO for iteration) | 3 s |
| Library size (Linux, release) | 3.6 MB (3.3 MB stripped; includes Rayon) | 1.9 MB (libstdc++ static) |
| Registering a class | `#[derive(GodotClass)]`, `#[godot_api]`, `#[func]` - 30 lines | `GDCLASS`, `_bind_methods`, `ClassDB::bind_method(D_METHOD(...11 names...))`, entry point - 50 lines |
| Packed arrays | `as_slice()` / `collect()` into `PackedVector2Array` | `ptr()` / `ptrw()` |
| Calling back into GDScript | `way.callv(&varray![i, j]).to::<Vector2>()` | `Vector2 w = way.call(i, j);` |
| A bug in the kernel | a panic is caught at the boundary and reported as a Godot error; with the default "balanced" safeguards out-of-range access panics instead of corrupting memory | out-of-range or a bad pointer crashes or corrupts the whole Godot process |
| Debugging | gdb/lldb on the Godot process (rust-gdb for pretty types); `godot_print!` | gdb/lldb on the Godot process; `UtilityFunctions::print` |

Both reload on restart only (`reloadable = false` here; gdext and godot-cpp both support
hot reload in the editor if wanted). Neither crashed during the spike; the one gotcha was
the repo's own GDScript checks walking godot-cpp's test project, hence the out-of-tree
clone.

### Blending with GDScript

- Calling convention: a GDExtension method called from GDScript is a `callv` through
  ClassDB (variant arguments, ~microseconds) - fine once a tick, wrong per unit. Keep the
  interface coarse: one call, packed arrays in and out.
- Typed arrays: `Packed*Array` are the right currency (contiguous, COW, slices on both
  sides). `Array`/`Dictionary` of objects (the sim's squads, `loose`, `fleeing`) can't be
  read efficiently from native - that's the gather/write-back cost above.
- Godot types: gdext and godot-cpp re-implement `Vector2` maths themselves, so identity
  needs care (both kernels spell Godot's own formulas out on plain f32 pairs); anything
  hashed with Godot's `hash()` or using `sin`/`cos` is best left to GDScript or called
  through the engine (here: the draws and `part_way`).

## Building

```
bash native/build.sh          # both; or: bash native/build.sh rust | cpp
```

Outputs `native/bin/[lib]breach_{rust,cpp}.<platform>.<ext>` (git-ignored, as are
`native/rust/target` and `native/cpp/build`). godot-cpp is cloned at its pinned commit
outside the repository (`~/.cache/breach-native/`, or `GODOT_CPP_DIR`): its own test
project's `.gd` files would otherwise trip the repo's GDScript checks. `native/`
holds a `.gdignore`: the editor never scans it, the `.gdextension` files are loaded at run
time by NativeKernels only when chosen and built, so a checkout without binaries runs on
GDScript with no errors. (An export would need the library and `.gdextension` added to the
export - out of scope for the spike.)

### Windows (not built here)

- Rust: `rustup` with the `x86_64-pc-windows-msvc` toolchain plus the Visual Studio Build
  Tools (MSVC linker + Windows SDK) - or `x86_64-pc-windows-gnu` with MinGW. Then
  `cargo build --release` gives `breach_native.dll`; copy it to
  `native/bin/breach_rust.windows.x86_64.dll`. No other tools.
- C++: Visual Studio 2022 Build Tools (C++ workload), CMake >= 3.17, Python 3 (godot-cpp
  generates its bindings with it), git. `cmake -S native/cpp -B native/cpp/build
  -DGODOTCPP_TARGET=template_release -DGODOTCPP_API_VERSION=4.7` then `cmake --build
  native/cpp/build --config Release`. `native/build.sh` runs as-is in Git Bash (it maps
  MINGW/MSYS to `windows.x86_64` and `.dll`).
- macOS: Xcode command-line tools; Rust targets `aarch64-apple-darwin` and
  `x86_64-apple-darwin` joined with `lipo` into the `.universal.dylib`; C++ the same with
  `-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"`. Unsigned dylibs need ad-hoc signing
  (`codesign -s -`) to load on Apple silicon.

### CI per platform

A matrix job (ubuntu-latest, windows-latest, macos-latest) each running
`bash native/build.sh <engine>` with the toolchain preinstalled on GitHub's images
(rustup and MSVC/Xcode are already there; godot-cpp needs only Python and CMake), caching
`~/.cargo` + `native/rust/target` (Rust) or `native/cpp/build` (C++, keyed on the
godot-cpp commit), uploading `native/bin/*` as artifacts; a final job gathers them into
the release/export. The gdUnit job would then run the suite twice: plain (GDScript) and
with `BREACH_NATIVE=<engine>`, plus `tools/formation_digest.gd` under each, diffing the
hashes - the identity check is what lets a native kernel be trusted.

## Recommendation

**Rust**, for the hot loops that are worth porting, with GDScript staying the reference
behind the switch and the digest as the gate:

- Speed is a wash between Rust and C++ (kernel 3.0 vs 3.3 ms at 1024; both ~45x GDScript),
  and both reproduce the GDScript path bit for bit, so the choice is on everything else.
- Rust is the easier toolchain to put on every dev machine and CI runner (rustup + cargo;
  no binding generation step, no SCons/CMake/Python), its failures stay inside the engine
  as errors rather than crashes, and threading is a crate away and deterministic by
  construction (Rayon over a snapshot, applied in order) - the user's point about the move
  from C++ to Rust holds here. C++ wins on rebuild-in-release time (3 s vs ~90 s with LTO;
  dev builds are under a second in Rust) and binary size (1.9 vs 3.6 MB) - neither matters
  much.
- But the spike also shows **where the time is**: porting the pass alone saves ~117 ms of a
  735 ms tick at 1,024 a side; marshalling (dictionary walks, draws) is now most of the
  remaining pass, and ~600 ms of the tick is in other loops. A production port should (1)
  move body state into native-owned packed arrays (pass -> ~3 ms), and (2) profile and port
  the scrum's slot search next, rather than port loops one call at a time.
