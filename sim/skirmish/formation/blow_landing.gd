class_name BlowLanding
extends RefCounted
## Lands a tick's blows (Decision 118, spec 28 part 4): each blow's roll, seeded by the
## battle, the tick and the striker (Decision 93; never the list, Decision 97), read by
## BlowRoll against its target, with the striker's margin shifted by its formation's
## morale band, by high ground, by each foe beyond the first that the target is fighting
## off, and by how tired it is (FormationStamina). With rolls off (the plain arithmetic
## the rule tests lean on) every blow is a hit at its weapons' full damage. What each
## deals is BlowDamage's. Pure over the squads it is given.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const BlowRoll = preload("res://sim/skirmish/formation/blow_roll.gd")
const BlowDamage = preload("res://sim/skirmish/formation/blow_damage.gd")
const FormationWounds = preload("res://sim/skirmish/formation/formation_wounds.gd")
const FormationStamina = preload("res://sim/skirmish/formation/formation_stamina.gd")
const BattleRolls = preload("res://sim/skirmish/formation/battle_rolls.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")


## Lands the melee blows ([striker, target, damage, flank]) and ranged shots ([shooter,
## target, damage, its squad]): sets each one's damage to what landed and appends how it
## landed (BlowRoll's outcomes). `rolls` = [battle seed, tick], or [] for no rolls.
static func land(
	melee: Array, shots: Array, squads: Array, terrain: FormationTerrain, rolls: Array
) -> void:
	if rolls.is_empty():
		for blow in melee:
			blow[2] = BlowDamage.dealt(blow[0], blow[1], blow[2], BlowRoll.HIT, false, 1.0)
			FormationWounds.scorch(blow[1], blow[0].melee_parts, blow[2])
			blow.append(BlowRoll.HIT)
		for shot in shots:
			shot[2] = BlowDamage.dealt(shot[0], shot[1], shot[2], BlowRoll.HIT, true, 1.0)
			FormationWounds.scorch(shot[1], shot[0].ranged_parts, shot[2])
			shot.append(BlowRoll.HIT)
		return
	var squad_of := {}  # unit id -> [unit, its squad]
	for squad in squads:
		for unit in squad.living():
			squad_of[unit.id] = [unit, squad]
	var pressed := _pressed(squad_of)
	for blow in melee:
		_land(blow, false, blow[3], squad_of, pressed, terrain, rolls)
	for shot in shots:
		var flank := BlowRoll.from_flank(shot[1], shot[0].position)
		_land(shot, true, flank, squad_of, pressed, terrain, rolls)


static func _land(
	blow: Array,
	ranged: bool,
	flank: bool,
	squad_of: Dictionary,
	pressed: Dictionary,
	terrain: FormationTerrain,
	rolls: Array
) -> void:
	var striker: SkirmishUnit = blow[0]
	var target: SkirmishUnit = blow[1]
	var tuning := BattleTuning.current()
	var shift := 0.0
	if squad_of.has(striker.id):
		shift += tuning.blow_morale_shift[FormationMorale.band(squad_of[striker.id][1])]
	if terrain != null and terrain.high_ground(striker.position, target.position):
		shift += tuning.blow_high_ground
	shift += maxi(0, pressed.get(target.id, 0) - 1) * tuning.blow_surrounded
	shift += BlowDamage.spill(striker, ranged) + FormationStamina.skill_shift(striker)
	var roll := BattleRolls.uniform(rolls[0], [rolls[1], striker.id, "blow", ranged])
	var side := BlowRoll.side(target, striker.position, flank)
	var landed := BlowRoll.outcome(
		BlowRoll.margin(striker, ranged, shift, roll), target, side, ranged
	)
	var spread := BattleRolls.uniform(rolls[0], [rolls[1], striker.id, "damage", ranged])
	blow[2] = BlowDamage.dealt(striker, target, blow[2], landed, ranged, spread)
	FormationWounds.scorch(target, striker.ranged_parts if ranged else striker.melee_parts, blow[2])
	blow.append(landed)


## Target id -> how many foes touching it are fighting it this tick.
static func _pressed(squad_of: Dictionary) -> Dictionary:
	var out := {}
	for unit_id in squad_of:
		var unit: SkirmishUnit = squad_of[unit_id][0]
		if not squad_of.has(unit.target_id):
			continue
		var foe: Array = squad_of[unit.target_id]
		if ScrumReach.touching(squad_of[unit_id][1], unit, foe[1], foe[0]):
			out[unit.target_id] = out.get(unit.target_id, 0) + 1
	return out
