//! The bodies' state, owned natively and kept across ticks (Decision 129): who is on the
//! field and what never changes about them (unit id, radius, footprint area, initiative,
//! the seeded draw, faction, squad), the bodies in draw order, and where each stands as of
//! the last sync. The roster changes incrementally: a sync names each squad's living units,
//! and only units new to the field are enrolled (GDScript hands over their draw and
//! sizes once), units gone are dropped, and units that changed squad are moved. The
//! hot passes - body parting, the scrum's slot search - run on it, and so can the next
//! ports (the spatial grid, pathfinding).

use std::collections::HashMap;

use crate::maths::V2;

/// A body is loose (in its squad's `loose`).
pub const LOOSE: u8 = 1;
/// A body is fleeing (in its squad's `fleeing`): it stands at its base plus an offset.
pub const FLEEING: u8 = 2;
/// A squad is routing.
pub const ROUTING: u8 = 1;
/// A squad is destroyed.
pub const DESTROYED: u8 = 2;

/// A squad as last synced.
#[derive(Default, Clone)]
pub struct Squad {
    pub id: i64,
    pub faction: u32,
    pub flags: u8,
    /// Its living units' bodies, in its list's order.
    pub members: Vec<u32>,
}

/// One sync's input, flat over the squads in list order (see `Field::sync`).
pub struct SyncIn<'a> {
    pub squad_ids: &'a [i64],
    pub squad_factions: &'a [String],
    pub squad_flags: &'a [u8],
    pub squad_counts: &'a [i32],
    pub unit_ids: &'a [i64],
    /// Where each stands (a fleeing body: its offset from its base).
    pub points: &'a [V2],
    pub flags: &'a [u8],
    /// A loose body's next point; empty: unchanged.
    pub nexts: &'a [V2],
    /// A fleeing body's base on its route; empty: unchanged.
    pub bases: &'a [V2],
    /// Each unit's bearing; empty: unchanged.
    pub bearings: &'a [f64],
}

/// What a newly seen body needs once: GDScript's values, so no rule is duplicated here.
pub struct Enrol<'a> {
    pub flat: &'a [i32],
    pub radii: &'a [f64],
    pub areas: &'a [f64],
    pub draws: &'a [i64],
    pub initiatives: &'a [i64],
}

#[derive(Default)]
pub struct Field {
    seed: i64,
    stamp: u32,
    // Per body (a slot, reused once its unit leaves the field).
    pub unit_id: Vec<i64>,
    pub squad: Vec<u32>,
    pub faction: Vec<u32>,
    pub radius: Vec<f64>,
    pub area: Vec<f64>,
    pub draw: Vec<i64>,
    pub initiative: Vec<i64>,
    seen: Vec<u32>,
    enrolled: Vec<bool>,
    // Where each body stands and how, as of the last sync (or a pass that moved it).
    pub at: Vec<V2>,
    pub offset: Vec<V2>,
    pub base: Vec<V2>,
    pub next: Vec<V2>,
    pub flags: Vec<u8>,
    pub bearing: Vec<f64>,
    /// The flat index each body had in the last sync (how results go back to GDScript).
    pub flat_of: Vec<u32>,
    /// The body at each flat index of the last sync.
    pub flat: Vec<u32>,
    pub squads: Vec<Squad>,
    /// The squads in the last sync's order.
    pub order: Vec<u32>,
    /// The enrolled bodies on the field, by draw (UnitBodies._drawn's order).
    pub drawn: Vec<u32>,
    by_unit: HashMap<i64, u32>,
    by_squad: HashMap<i64, u32>,
    factions: Vec<String>,
    free: Vec<u32>,
}

impl Field {
    /// Bodies on the field.
    pub fn count(&self) -> usize {
        self.by_unit.len()
    }

    /// Brings the field to the squads as they stand. Returns the flat indices of units new
    /// to the field, to be enrolled (`enrol`) before any pass runs.
    pub fn sync(&mut self, seed: i64, input: &SyncIn) -> Vec<i32> {
        if seed != self.seed {
            *self = Field { seed, ..Field::default() };
        }
        self.stamp = self.stamp.wrapping_add(1);
        self.order.clear();
        self.flat.clear();
        let mut unknown = Vec::new();
        let mut flat = 0usize;
        for (s, &squad_id) in input.squad_ids.iter().enumerate() {
            let faction = self.faction_index(&input.squad_factions[s]);
            let sq = self.squad_slot(squad_id);
            self.order.push(sq);
            let mut members = std::mem::take(&mut self.squads[sq as usize].members);
            members.clear();
            for _ in 0..input.squad_counts[s] {
                let body = self.body_for(input.unit_ids[flat], &mut unknown, flat);
                self.place(body, flat, sq, faction, input);
                members.push(body);
                flat += 1;
            }
            let squad = &mut self.squads[sq as usize];
            squad.members = members;
            squad.faction = faction;
            squad.flags = input.squad_flags[s];
        }
        self.drop_unseen();
        unknown
    }

    /// Enrols the bodies `sync` reported new: their sizes, initiative and draw.
    pub fn enrol(&mut self, input: &Enrol) {
        for (k, &flat) in input.flat.iter().enumerate() {
            let body = self.flat[flat as usize];
            let b = body as usize;
            self.radius[b] = input.radii[k];
            self.area[b] = input.areas[k];
            self.draw[b] = input.draws[k];
            self.initiative[b] = input.initiatives[k];
            if !self.enrolled[b] {
                self.enrolled[b] = true;
                let draw = self.draw[b];
                let at = self.drawn.partition_point(|&o| self.draw[o as usize] <= draw);
                self.drawn.insert(at, body);
            }
        }
    }

    fn faction_index(&mut self, name: &str) -> u32 {
        match self.factions.iter().position(|f| f == name) {
            Some(i) => i as u32,
            None => {
                self.factions.push(name.to_string());
                (self.factions.len() - 1) as u32
            }
        }
    }

    fn squad_slot(&mut self, id: i64) -> u32 {
        if let Some(&sq) = self.by_squad.get(&id) {
            return sq;
        }
        self.squads.push(Squad { id, ..Squad::default() });
        let sq = (self.squads.len() - 1) as u32;
        self.by_squad.insert(id, sq);
        sq
    }

    /// The body of a unit, a new slot for one not on the field yet (noted in `unknown`).
    fn body_for(&mut self, unit_id: i64, unknown: &mut Vec<i32>, flat: usize) -> u32 {
        if let Some(&body) = self.by_unit.get(&unit_id) {
            return body;
        }
        unknown.push(flat as i32);
        let body = match self.free.pop() {
            Some(b) => b,
            None => {
                self.grow();
                (self.unit_id.len() - 1) as u32
            }
        };
        let b = body as usize;
        self.unit_id[b] = unit_id;
        self.enrolled[b] = false;
        self.by_unit.insert(unit_id, body);
        body
    }

    fn grow(&mut self) {
        self.unit_id.push(0);
        self.squad.push(0);
        self.faction.push(0);
        self.radius.push(0.0);
        self.area.push(0.0);
        self.draw.push(0);
        self.initiative.push(0);
        self.seen.push(0);
        self.enrolled.push(false);
        self.at.push(V2::ZERO);
        self.offset.push(V2::ZERO);
        self.base.push(V2::ZERO);
        self.next.push(V2::ZERO);
        self.flags.push(0);
        self.bearing.push(0.0);
        self.flat_of.push(0);
    }

    /// Writes a synced unit's state into its body.
    fn place(&mut self, body: u32, flat: usize, sq: u32, faction: u32, input: &SyncIn) {
        let b = body as usize;
        self.seen[b] = self.stamp;
        self.squad[b] = sq;
        self.faction[b] = faction;
        self.flat_of[b] = flat as u32;
        self.flat.push(body);
        let flags = input.flags[flat];
        self.flags[b] = flags;
        if !input.nexts.is_empty() {
            self.next[b] = input.nexts[flat];
        }
        if !input.bases.is_empty() {
            self.base[b] = input.bases[flat];
        }
        if !input.bearings.is_empty() {
            self.bearing[b] = input.bearings[flat];
        }
        if flags & FLEEING != 0 {
            self.offset[b] = input.points[flat];
            self.at[b] = self.base[b].add(self.offset[b]);
        } else {
            self.at[b] = input.points[flat];
        }
    }

    /// Drops the bodies no squad named this sync: the dead, the taken, the gone.
    fn drop_unseen(&mut self) {
        if self.flat.len() == self.by_unit.len() {
            return; // every body on the field was named (bodies are named once each)
        }
        let stamp = self.stamp;
        let gone: Vec<u32> = self
            .by_unit
            .values()
            .copied()
            .filter(|&b| self.seen[b as usize] != stamp)
            .collect();
        for body in gone {
            self.by_unit.remove(&self.unit_id[body as usize]);
            self.enrolled[body as usize] = false;
            self.free.push(body);
        }
        let (seen, enrolled) = (&self.seen, &self.enrolled);
        self.drawn.retain(|&b| seen[b as usize] == stamp && enrolled[b as usize]);
    }
}
