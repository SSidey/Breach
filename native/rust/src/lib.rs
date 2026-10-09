//! Breach's native core (Decision 129: Rust for the simulation's hot core, through
//! GDExtension with godot-rust). One class, `BodyField`: the bodies' state, owned here and
//! kept across ticks, and the hot passes that run on it - body parting (UnitBodies), the
//! scrum's slot search (ScrumSeek, SlotSearch, ScrumSlots, ScrumNear) and its facing
//! (FormationScrum._faces, UnitShuffle, UnitMotion). GDScript keeps the rules and stays the
//! reference; the switch is `BREACH_NATIVE` (NativeKernels).

mod blows;
mod det_math;
mod facing;
mod field;
mod field_parting;
mod ghash;
mod grid;
mod maths;
mod motion;
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

    /// FormationScrum's facing on the field, after the walk, for the units the tick's
    /// plan() was given (`squads` = per fighting squad [id, foes, units], `foe_ids`,
    /// `members` and `speeds` as plan's). `floats` = [reach_contact, the front's least
    /// dot (ScrumReach.in_front), tick seconds, pace (cells a tick at speed 1),
    /// scrum_crowding]; per unit: where it stands now, `motion` = [bearing, turn rate,
    /// backward pace], flags (1: it makes for a slot, 2: its walk chose a point to look
    /// at), its next point, the foe there and that point. Returns every unit's bearing
    /// after its turn.
    #[func]
    #[allow(clippy::too_many_arguments)]
    fn face(
        &mut self,
        floats: PackedFloat64Array,
        squads: PackedInt64Array,
        foe_ids: PackedInt64Array,
        members: PackedInt32Array,
        ats: PackedVector2Array,
        motion: PackedFloat64Array,
        speeds: PackedFloat64Array,
        flags: PackedByteArray,
        nexts: PackedVector2Array,
        foe_ats: PackedVector2Array,
        towards: PackedVector2Array,
    ) -> PackedFloat64Array {
        let began = Instant::now();
        let f = floats.as_slice();
        let params =
            facing::Params { reach: f[0], front: f[1], seconds: f[2], pace: f[3], crowding: f[4] };
        let triples = squads.as_slice();
        let foe_counts: Vec<i32> = triples.chunks(3).map(|c| c[1] as i32).collect();
        let member_counts: Vec<i32> = triples.chunks(3).map(|c| c[2] as i32).collect();
        let (ats, nexts, foe_ats, towards) = (v2s(&ats), v2s(&nexts), v2s(&foe_ats), v2s(&towards));
        let input = facing::FaceIn {
            foe_counts: &foe_counts,
            foe_ids: foe_ids.as_slice(),
            member_counts: &member_counts,
            members: members.as_slice(),
            ats: &ats,
            motion: motion.as_slice(),
            speeds: speeds.as_slice(),
            flags: flags.as_slice(),
            nexts: &nexts,
            foe_ats: &foe_ats,
            towards: &towards,
        };
        let out = facing::face(&mut self.field, &input, &params);
        self.usec = began.elapsed().as_micros() as i64;
        PackedFloat64Array::from(out.as_slice())
    }

    /// ScrumBlows.blows' search on the field, as of a sync of the scrum's snapshot:
    /// `floats` = [reach_contact, the front's least dot (ScrumReach.in_front)], `rules` per
    /// squad in the sync's order (1 fighting, 2 ordered to retreat). Returns per unit that
    /// touches a foe it strikes, in the sync's order: [its flat index, the foe's, flags (1
    /// it retreats and has turned away, 2 the blow falls on the foe's flank)].
    #[func]
    fn blows(&mut self, floats: PackedFloat64Array, rules: PackedByteArray) -> PackedInt32Array {
        let began = Instant::now();
        let f = floats.as_slice();
        let params = blows::Params { reach: f[0], front: f[1] };
        let picks = blows::picks(&self.field, rules.as_slice(), &params);
        let mut out = Vec::with_capacity(picks.len() * 3);
        for pick in &picks {
            out.extend_from_slice(&[pick.flat, pick.foe, pick.flags as i32]);
        }
        self.usec = began.elapsed().as_micros() as i64;
        PackedInt32Array::from(out.as_slice())
    }

    /// BlowLanding's counts on the field, as of the same sync as blows(): `targets` is
    /// every unit's target id by flat index, `asked` [striker id, target id] per blow.
    /// Returns per blow [the striker's squad (its place in the sync, -1: none), how many
    /// units touching the target (within `reach`) have it as theirs].
    #[func]
    fn pressed(
        &mut self,
        reach: f64,
        targets: PackedInt64Array,
        asked: PackedInt64Array,
    ) -> PackedInt32Array {
        let began = Instant::now();
        let out = blows::pressed(&self.field, targets.as_slice(), asked.as_slice(), reach);
        self.usec = began.elapsed().as_micros() as i64;
        PackedInt32Array::from(out.as_slice())
    }

    /// DetMath's `op` ("sin", "cos", "asin", "acos", or "atan2" of a and b) over the
    /// inputs, as the core computes it (the suite proves it against the GDScript).
    #[func]
    fn det_math(op: GString, a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array {
        let f: fn(f64, f64) -> f64 = match op.to_string().as_str() {
            "sin" => |x, _| det_math::sin(x),
            "cos" => |x, _| det_math::cos(x),
            "asin" => |x, _| det_math::asin(x),
            "acos" => |x, _| det_math::acos(x),
            "atan2" => det_math::atan2,
            _ => return PackedFloat64Array::new(),
        };
        let (a, b) = (a.as_slice(), b.as_slice());
        let out: Vec<f64> =
            (0..a.len()).map(|i| f(a[i], b.get(i).copied().unwrap_or(0.0))).collect();
        PackedFloat64Array::from(out.as_slice())
    }

    /// Bodies on the field.
    #[func]
    fn count(&self) -> i64 {
        self.field.count() as i64
    }

    /// Microseconds of native work in the last sync, part, plan or face.
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
