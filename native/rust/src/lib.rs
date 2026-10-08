//! Breach's native core (Decision 129: Rust for the simulation's hot core, through
//! GDExtension with godot-rust). One class, `BodyField`: the bodies' state, owned here and
//! kept across ticks, and the hot passes that run on it - body parting (UnitBodies) and the
//! scrum's slot search (ScrumSeek, SlotSearch, ScrumSlots, ScrumNear). GDScript keeps the
//! rules and stays the reference; the switch is `BREACH_NATIVE` (NativeKernels).

mod field;
mod field_parting;
mod ghash;
mod grid;
mod maths;
mod parting;
mod scrum;

use std::time::Instant;

use godot::prelude::*;

use field::{Enrol, Field, SyncIn};
use maths::V2;
use parting::Tuning;

struct BreachNative;

#[gdextension]
unsafe impl ExtensionLibrary for BreachNative {}

/// The bodies on a battle's field (see native/README.md for the boundary).
#[derive(GodotClass)]
#[class(base = RefCounted, init)]
struct BodyField {
    field: Field,
    /// Microseconds of native work in the last call (the bench reads it).
    usec: i64,
}

#[godot_api]
impl BodyField {
    /// Brings the field to the squads as they stand, flat over the squads in list order:
    /// per squad its id, faction, flags (1 routing, 2 destroyed) and how many living units
    /// follow; per unit its id, point (a fleeing one's offset), flags (1 loose, 2 fleeing),
    /// and - when not empty - its next point, its base (fleeing) and its bearing. Returns
    /// the flat indices of units new to the field: enrol() them before any pass.
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn sync(
        &mut self,
        seed: i64,
        squad_ids: PackedInt64Array,
        squad_factions: PackedStringArray,
        squad_flags: PackedByteArray,
        squad_counts: PackedInt32Array,
        unit_ids: PackedInt64Array,
        points: PackedVector2Array,
        flags: PackedByteArray,
        nexts: PackedVector2Array,
        bases: PackedVector2Array,
        bearings: PackedFloat64Array,
    ) -> PackedInt32Array {
        let began = Instant::now();
        let factions: Vec<String> = squad_factions.as_slice().iter().map(|s| s.to_string()).collect();
        let points = v2s(&points);
        let nexts = v2s(&nexts);
        let bases = v2s(&bases);
        let input = SyncIn {
            squad_ids: squad_ids.as_slice(),
            squad_factions: &factions,
            squad_flags: squad_flags.as_slice(),
            squad_counts: squad_counts.as_slice(),
            unit_ids: unit_ids.as_slice(),
            points: &points,
            flags: flags.as_slice(),
            nexts: &nexts,
            bases: &bases,
            bearings: bearings.as_slice(),
        };
        let unknown = self.field.sync(seed, &input);
        self.usec = began.elapsed().as_micros() as i64;
        PackedInt32Array::from(unknown.as_slice())
    }

    /// Enrols the units sync() reported new (by flat index): radius, footprint area,
    /// ScrumContest.draw and initiative - GDScript's own values, handed over once.
    #[func]
    fn enrol(
        &mut self,
        flat: PackedInt32Array,
        radii: PackedFloat64Array,
        areas: PackedFloat64Array,
        draws: PackedInt64Array,
        initiatives: PackedInt64Array,
    ) {
        self.field.enrol(&Enrol {
            flat: flat.as_slice(),
            radii: radii.as_slice(),
            areas: areas.as_slice(),
            draws: draws.as_slice(),
            initiatives: initiatives.as_slice(),
        });
    }

    /// UnitBodies' passes on the field. `tuning` = [passes, resist, brush]; `way.call(draw,
    /// other draw)` gives the way two bodies on each other part. Returns [moved (flat
    /// indices), their points (a fleeing one's offset), their nexts, loosened (flat indices,
    /// in order), stats = [usec, passes that moved something, pairs pushed]].
    #[func]
    fn part(&mut self, tuning: PackedFloat64Array, way: Callable, threaded: bool) -> VarArray {
        let t = tuning.as_slice();
        let tuning = Tuning { passes: t[0] as i64, resist: t[1], brush: t[2] };
        let mut ask = |a: i64, b: i64| -> V2 {
            let w: Vector2 = way.callv(&varray![a, b]).to();
            V2::new(w.x, w.y)
        };
        let began = Instant::now();
        let out = field_parting::part_field(&mut self.field, &tuning, threaded, &mut ask);
        self.usec = began.elapsed().as_micros() as i64;
        varray![
            &PackedInt32Array::from(out.moved.as_slice()),
            &packed(&out.points),
            &packed(&out.nexts),
            &PackedInt32Array::from(out.loosened.as_slice()),
            &PackedInt64Array::from(&[self.usec, out.passes, out.pairs]),
        ]
    }

    /// ScrumSeek.plan on the field, as of a sync of the scrum's snapshot. `ints` = [tick,
    /// seed, combat_contest_die], `floats` = [reach_contact, scrum_leash]; `squads` = per
    /// fighting squad [id, foes, units], `foe_ids` its foes' squad ids; per unit (flat
    /// index in `members`): may it seek, its speed, its place (anchor), its goal [foe id,
    /// slot] (-1: none). `within.call(unit, point)` is the ground's say (an invalid
    /// Callable: open ground). Returns [codes (0 touch, 1 stand, 2 aim, 3 press, 4 idle),
    /// goal foes, goal slots, nexts, foe_ats].
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn plan(
        &mut self,
        ints: PackedInt64Array,
        floats: PackedFloat64Array,
        squads: PackedInt64Array,
        foe_ids: PackedInt64Array,
        members: PackedInt32Array,
        may_seek: PackedByteArray,
        speeds: PackedFloat64Array,
        anchors: PackedVector2Array,
        goal_foes: PackedInt64Array,
        goal_slots: PackedInt32Array,
        within: Callable,
    ) -> VarArray {
        let began = Instant::now();
        let i = ints.as_slice();
        let f = floats.as_slice();
        let params = scrum::Params { tick: i[0], seed: i[1], die: i[2], reach: f[0], leash: f[1] };
        let triples = squads.as_slice();
        let fighters: Vec<i64> = triples.chunks(3).map(|c| c[0]).collect();
        let foe_counts: Vec<i32> = triples.chunks(3).map(|c| c[1] as i32).collect();
        let member_counts: Vec<i32> = triples.chunks(3).map(|c| c[2] as i32).collect();
        let anchors = v2s(&anchors);
        let input = scrum::PlanIn {
            fighters: &fighters,
            foe_counts: &foe_counts,
            foe_ids: foe_ids.as_slice(),
            member_counts: &member_counts,
            members: members.as_slice(),
            may_seek: may_seek.as_slice(),
            speeds: speeds.as_slice(),
            anchors: &anchors,
            goal_foes: goal_foes.as_slice(),
            goal_slots: goal_slots.as_slice(),
        };
        let ground = within.is_valid();
        let mut ask = |unit: usize, p: V2| -> bool {
            !ground || within.callv(&varray![unit as i64, Vector2::new(p.x, p.y)]).to::<bool>()
        };
        let out = scrum::plan(&self.field, &input, &params, &mut ask);
        self.usec = began.elapsed().as_micros() as i64;
        varray![
            &PackedByteArray::from(out.codes.as_slice()),
            &PackedInt64Array::from(out.goal_foes.as_slice()),
            &PackedInt32Array::from(out.goal_slots.as_slice()),
            &packed(&out.nexts),
            &packed(&out.foe_ats),
        ]
    }

    /// Bodies on the field.
    #[func]
    fn count(&self) -> i64 {
        self.field.count() as i64
    }

    /// Microseconds of native work in the last sync, part or plan.
    #[func]
    fn usec(&self) -> i64 {
        self.usec
    }

    /// Where every body on the field stands, by the last sync's flat indices (tests).
    #[func]
    fn points(&self) -> PackedVector2Array {
        self.field.flat.iter().map(|&b| {
            let p = self.field.at[b as usize];
            Vector2::new(p.x, p.y)
        }).collect()
    }

    /// Godot's hash() of an Array of ints and Strings as the core computes it (the suite
    /// proves it against the engine's own).
    #[func]
    fn godot_hash(keys: VarArray) -> i64 {
        let texts: Vec<String> = keys.iter_shared().map(|v| v.to_string()).collect();
        let mut out = Vec::with_capacity(texts.len());
        for (v, text) in keys.iter_shared().zip(&texts) {
            out.push(match v.get_type() {
                VariantType::STRING => ghash::Key::Str(text),
                _ => ghash::Key::Int(v.to::<i64>()),
            });
        }
        ghash::hash(&out) as i64
    }
}

fn v2s(points: &PackedVector2Array) -> Vec<V2> {
    points.as_slice().iter().map(|p| V2::new(p.x, p.y)).collect()
}

fn packed(points: &[V2]) -> PackedVector2Array {
    points.iter().map(|p| Vector2::new(p.x, p.y)).collect()
}
