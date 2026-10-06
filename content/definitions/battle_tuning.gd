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


## The tuning in play: content/tuning/battle_tuning.tres, loaded once.
static func current() -> BattleTuning:
	if _current == null:
		_current = load(PATH)
	return _current
