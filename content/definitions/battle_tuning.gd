class_name BattleTuning
extends Resource
## The battle's tuning numbers in one place (Decision 123, spec 28 round 1): every number
## the fights lean on that isn't a unit's or an item's. The values live in
## content/tuning/battle_tuning.tres - edit them there (in the inspector or as text); this
## script only names and explains them. All are placeholders until play settles them.

const PATH := "res://content/tuning/battle_tuning.tres"

static var _current: BattleTuning = null

@export_group("Morale (Decision 82)")
## The share of its blows' damage a formation lands, by band: steady, shaken, wavering,
## routing.
@export var morale_blow_share: Array[float] = []
## Morale lost when struck on a side or on the rear.
@export var morale_side_impact := 0
@export var morale_rear_impact := 0
## Morale lost for each unit of its own that falls, and per point of a fallen leader's
## leadership.
@export var morale_loss := 0
@export var morale_leader_loss := 0
## Morale regained each second out of contact, before its leadership is added.
@export var morale_recovery := 0
## Morale lost each second by how many sides it fights on (0, 1, 2, 3, 4 or more).
@export var morale_pressure: Array[int] = []
## Cells within which a friendly squad supports a side.
@export var morale_support_cells := 0.0
## The ceiling's rise per point of its best leader's leadership (Decision 81).
@export var morale_per_leadership := 0
## The bands' floors: steady at or above the first, shaken at or above the second.
@export var morale_steady_at := 0
@export var morale_shaken_at := 0

@export_group("Discipline (Decisions 92, 107 and 109)")
## What each point of a formation's best leader's leadership adds to its discipline.
@export var discipline_per_leadership := 0
## At or above this a formation re-forms as a whole to meet a flank; below it, unit by
## unit. A unit under it may break ranks to chase, the more likely the further under.
@export var discipline_meets_threats := 0
## The discipline at which it re-forms at the march pace; the pace scales with it, within
## the slowest and fastest shares of the march pace.
@export var discipline_march_pace_at := 0.0
@export var discipline_slowest := 0.0
@export var discipline_fastest := 0.0
## The discipline a formation is expected to have at most; more buys no more.
@export var discipline_expected_max := 0.0
## How far (cells) a pursuer may go from where it set out, step by step: the steadier, the
## shorter its leash; the last is no leash (inf), while it can see its enemy.
@export var discipline_leash_steps: Array[float] = []
## The share of the expected most at or above which a pursuer takes the second, third and
## fourth leash steps; under the last, the fifth. A leader's "pursues" tactic steps it one
## out, "cautious" one in.
@export var discipline_leash_shares: Array[float] = []

@export_group("Combat (Decisions 85, 88 and 93)")
## A flank blow's worth (from outside the target's front), times its damage.
@export var combat_flank_bonus := 0.0
## A striker on higher ground than its target hits this many times harder.
@export var combat_high_ground := 0.0
## Each blow's damage rolls within this share either side of its value (0: no roll).
@export var combat_damage_band := 0.0
## The contest die: a roll from 0 to this, added to initiative, decides who takes a
## contested slot (0: stats alone).
@export var combat_contest_die := 0

@export_group("Routs and flight (Decisions 82, 89, 98 and 99)")
## Crush damage per cell of a router's footprint, to friends it shoves past.
@export var rout_crush := 0
## Morale lost by a friend a router crushes, and by a friend that sees a formation rout.
@export var rout_panic := 0
@export var rout_seen := 0
## How near (cells, a router's centre to a friend's body) a router must come to a led
## formation to rally to it.
@export var rout_rally_reach := 0.0
## Seconds a caught router waits with its friend steady before it joins it.
@export var rout_steady_rally_seconds := 0.0
## Seconds with no enemy within rout_enemy_near cells before a led rout re-forms (and a
## withdrawal is safe).
@export var rout_rally_seconds := 0.0
@export var rout_enemy_near := 0.0
## The morale a re-formed rout starts at.
@export var rout_reformed_morale := 0
## How near (cells, centre to centre) a pursuer must be to strike a router.
@export var rout_strike_reach := 0.0
## How far a wholly disorderly flight fans out: degrees off its route's line, and cells out.
@export var rout_fan_degrees := 0.0
@export var rout_fan_cells := 0.0

@export_group("Pursuit (Decisions 103 and 109)")
## The rout a ragged retreat costs: up to this much shock, for a formation with no
## discipline at all.
@export var pursuit_ragged_shock := 0
## How near (cells) a unit must stand to a retreating enemy to be tempted to chase.
@export var pursuit_tempted_within := 0.0

@export_group("Ground (Decision 85)")
## A rise of more than this many quarter-cells is a cliff: impassable until climbers come.
@export var ground_cliff_quarters := 0
## The pace each quarter-cell risen costs; downhill is no faster.
@export var ground_slope_cost := 0.0
## The pace in water a quarter to a half of a unit's height deep (wading), and from a half
## to its height (slow wading); deeper is impassable until swimmers come.
@export var ground_wading := 0.0
@export var ground_slow_wading := 0.0

@export_group("Bodies (Decisions 106 and 114)")
## How many times over a unit in its formation's frame weighs, against being pushed.
@export var bodies_resist := 0.0
## How many times a tick overlapping bodies are pushed apart.
@export var bodies_passes := 0
## A loose friend of its own squad overlapping a unit in its frame by less than this
## (cells) only brushes it: it keeps its place.
@export var bodies_brush := 0.0
## How far ahead (cells) a unit looks for a body in its way, and how far clear (cells) of
## it it aims to pass.
@export var bodies_steer_look := 0.0
@export var bodies_steer_clear := 0.0


## The tuning in play: content/tuning/battle_tuning.tres, loaded once.
static func current() -> BattleTuning:
	if _current == null:
		_current = load(PATH)
	return _current
