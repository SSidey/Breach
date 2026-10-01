class_name FormationSkirmishReadout
extends RefCounted
## The formation feel test's HUD text (specs/22-formation-feel-test.md): pure formatting
## over the scene's state, kept out of FormationSkirmishScene so that stays glue.

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishSlotPool = preload("res://sim/skirmish/formation/skirmish_slot_pool.gd")
const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")
const DomainProduction = preload("res://sim/skirmish/formation/domain_production.gd")


static func status(seconds: float, speed: float, paused: bool) -> String:
	return "%.1f s · ×%d%s" % [seconds, int(speed), " · PAUSED" if paused else ""]


static func pool(slot_pool: SkirmishSlotPool, domain: DomainProduction) -> String:
	return (
		"Slot pool %d: c %d · k %d · free %d · reserve %d/%d"
		% [
			slot_pool.total,
			slot_pool.assigned("c"),
			slot_pool.assigned("k"),
			slot_pool.free_slots(),
			domain.reserve.size(),
			domain.reserve_cap
		]
	)


## One line per builder type: "Grem ×2: 60% → c · 20% → reserve" (Decision 45).
static func builders(domain: DomainProduction, types: Array, names: Array) -> Array:
	var lines := []
	for index in range(types.size()):
		var under_way := domain.builds().filter(func(b): return b[0] == types[index])
		var parts := under_way.map(
			func(b): return "%d%% → %s" % [roundi(b[2] * 100.0), b[1] if b[1] != "" else "reserve"]
		)
		var doing := " · ".join(parts) if not parts.is_empty() else "idle"
		lines.append("%s ×%d: %s" % [names[index], domain.builder_count(types[index]), doing])
	return lines


## [summary text, template places] for one lane. Each place is
## [rank, column, depth, width, filled, UnitDef, progress]: the builds claimed for this
## lane are shown filling its front-most unfilled places of their type.
static func lane(
	production: FormationProduction, allowance: int, builds: Array, lane_key: String
) -> Array:
	var places := production.preview()
	var claimed := builds.filter(func(b): return b[1] == lane_key)
	var used := 0
	for place in places:
		used += place[2] * place[3]
		var progress := 0.0
		if not place[4]:
			var build_at := claimed.find_custom(func(b): return b[0] == place[5])
			if build_at != -1:
				progress = claimed[build_at][2]
				claimed.remove_at(build_at)
		place.append(progress)
	var full := production.built() > 0 and production.wanted().is_empty()
	var state := "ready - send it" if full else "building"
	var text := (
		"cells %d/%d · built %d/%d · %s"
		% [used, allowance, production.built(), places.size(), state]
	)
	return [text, places]


## chosen: [lane key, squad id], or empty when nothing is selected.
static func selected(chosen: Array, squad: SkirmishSquad) -> String:
	if chosen.is_empty():
		return "Click a squad (or Tab) to select it"
	if squad == null or squad.is_destroyed():
		return "Selected squad is gone"
	return (
		"Lane %s squad #%d: %d alive · %s · %s"
		% [
			chosen[0],
			squad.id,
			squad.living().size(),
			SkirmishUnit.Order.keys()[squad.order],
			SkirmishSquad.State.keys()[squad.state]
		]
	)
