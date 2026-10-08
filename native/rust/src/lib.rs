//! Breach's native spike in Rust (godot-rust / gdext): UnitBodies' body-parting pass as
//! the GDExtension class `BodyPartingRust`. The GDScript side is
//! `sim/skirmish/formation/body_parting.gd`; the switch is `BREACH_NATIVE`.

mod parting;

use std::time::Instant;

use godot::prelude::*;
use parting::{Bodies, Tuning, V2};

struct BreachNative;

#[gdextension]
unsafe impl ExtensionLibrary for BreachNative {}

/// UnitBodies.step's passes over packed arrays: data in, new points out.
#[derive(GodotClass)]
#[class(base = RefCounted, init)]
struct BodyPartingRust {}

#[godot_api]
impl BodyPartingRust {
    /// Parts the bodies. Per body: `points` (a fleeing body's offset, else where it
    /// stands), `bases` (a fleeing body's route point), `nexts` (a loose body's next
    /// point), `radii`, `areas`, `squads` and `factions` (indices), `flags` (1 loose,
    /// 2 fleeing). `tuning` = [passes, resist, brush]. `way.call(i, j)` gives the way two
    /// bodies on each other part. `threaded` uses Rayon's pool.
    /// Returns [points, nexts, flags (4 = moved), loosened (in order), stats] where
    /// stats = [compute usec, passes that moved something, pairs pushed].
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn part(
        &self,
        points: PackedVector2Array,
        bases: PackedVector2Array,
        nexts: PackedVector2Array,
        radii: PackedFloat64Array,
        areas: PackedFloat64Array,
        squads: PackedInt32Array,
        factions: PackedInt32Array,
        flags: PackedByteArray,
        tuning: PackedFloat64Array,
        way: Callable,
        threaded: bool,
    ) -> VarArray {
        let bases: Vec<V2> = bases.as_slice().iter().map(v2).collect();
        let mut bodies = Bodies {
            points: points.as_slice().iter().map(v2).collect(),
            nexts: nexts.as_slice().iter().map(v2).collect(),
            flags: flags.as_slice().to_vec(),
            bases: &bases,
            radii: radii.as_slice(),
            areas: areas.as_slice(),
            squads: squads.as_slice(),
            factions: factions.as_slice(),
        };
        let t = tuning.as_slice();
        let tuning = Tuning { passes: t[0] as i64, resist: t[1], brush: t[2] };
        let mut ask = |i: usize, j: usize| -> V2 {
            let w: Vector2 = way.callv(&varray![i as i64, j as i64]).to();
            V2 { x: w.x, y: w.y }
        };
        let began = Instant::now();
        let outcome = parting::part(&mut bodies, &tuning, threaded, &mut ask);
        let usec = began.elapsed().as_micros() as i64;
        let to_packed = |v: &[V2]| -> PackedVector2Array {
            v.iter().map(|p| Vector2::new(p.x, p.y)).collect()
        };
        varray![
            &to_packed(&bodies.points),
            &to_packed(&bodies.nexts),
            &PackedByteArray::from(bodies.flags.as_slice()),
            &PackedInt32Array::from(outcome.loosened.as_slice()),
            &PackedInt64Array::from(&[usec, outcome.passes, outcome.pairs]),
        ]
    }
}

fn v2(p: &Vector2) -> V2 {
    V2 { x: p.x, y: p.y }
}
