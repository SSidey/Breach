class_name FormationLane
extends RefCounted
## One lane of the formation feel test (specs/22-formation-feel-test.md, Decision 42): its
## FormationSimulation, the player's FormationProduction and painted WaveTemplate (with the
## current brush), and the kingdom's automatic militia line. Every template change goes
## through set_template, so built units fold in and leftovers are banked at once.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")
const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const WavePresets = preload("res://sim/skirmish/formation/wave_presets.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

var key: String
var lane_width: int
var sim: FormationSimulation
var production: FormationProduction
var kingdom: FormationProduction
var template: WaveTemplate
## The unit painted on click; null erases.
var brush: UnitDef


func _init(
	lane_key: String,
	width: int,
	route_length: float,
	tick_seconds: float,
	kingdom_unit: UnitDef,
	kingdom_line: int,
	kingdom_unit_seconds: float
) -> void:
	key = lane_key
	lane_width = width
	sim = FormationSimulation.new(route_length, tick_seconds)
	production = FormationProduction.new("player", true)
	kingdom = FormationProduction.new("the_kingdom", false)
	kingdom.build_seconds = kingdom_unit_seconds
	kingdom.departure = FormationProduction.Departure.AUTO_WHEN_FULL
	kingdom.set_template(WavePresets.line(kingdom_unit, kingdom_line, kingdom_line))
	template = WaveTemplate.new(width, 0)


## One tick: the player's build, the kingdom's (when active), then the fight.
func step(with_kingdom: bool) -> Array:
	var events := production.step(sim)
	if with_kingdom:
		events.append_array(kingdom.step(sim))
	events.append_array(sim.step())
	return events


## Switches to a new template now; returns how many built units were banked.
func apply(new_template: WaveTemplate) -> int:
	template = new_template
	return production.set_template(new_template)[0]["banked"]


## Paints the brush at a cell (or erases, with erase or no brush), allowing the template up
## to `allowance` cells (its own plus the pool's free slots). Returns the units banked, or
## -1 when nothing changed.
func paint(cell: Vector2i, allowance: int, erase: bool = false) -> int:
	var edited := template.copy()
	edited.slot_limit = allowance
	var changed := edited.erase(cell) if erase or brush == null else edited.paint(brush, cell)
	return apply(edited) if changed else -1


func cells_used() -> int:
	var total := 0
	for placement in template.ordered():
		total += placement[0].footprint_depth * placement[0].footprint_width
	return total


## Sends the player's wave on its own once full (true) or waits for Send (false).
func set_auto_departure(automatic: bool) -> void:
	production.departure = (
		FormationProduction.Departure.AUTO_WHEN_FULL
		if automatic
		else FormationProduction.Departure.MANUAL
	)


func spawn_kingdom_line(unit_def: UnitDef, count: int) -> void:
	var line := []
	for column in range(count):
		line.append([unit_def, Vector2i(0, column)])
	sim.spawn_squad(count, line, "the_kingdom", false)
