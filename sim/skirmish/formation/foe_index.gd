class_name FoeIndex
extends RefCounted
## The foes near a squad's units, found through one grid a faction (ScrumNear) rather than
## one a squad (spec 30 round 3): for a phase of a tick, the living units of every squad
## hostile to a faction and not routing are indexed once where they stand, and each squad
## searches only among the squads it may strike - those it fights (ScrumSeek.foe_units),
## or the ones ScrumBlows lets it strike. A search gives back the same foes, in the same
## order, as an index of that squad's foes alone would (Decision 97). Take a new FoeIndex
## once units have moved. Pure; cells.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumNear = preload("res://sim/skirmish/formation/scrum_near.gd")


## A new index over `squads` as they stand; each faction's grid is made when first asked.
static func of(squads: Array) -> Dictionary:
	return {"squads": squads, "factions": {}}


## As ScrumNear.index over ScrumSeek.foe_units(squad): a search among the living units of
## the squads it fights - on its front, its edges, or that fight it - not routing. Its
## "any" is whether there are any.
static func fought(index: Dictionary, squad: SkirmishSquad) -> Dictionary:
	var hostile := _hostile(index, squad)
	var only := {}
	for other_id in _links(index).get(squad.id, {}):
		for other in hostile["by_id"].get(other_id, []):
			only[other] = true
	return _view(hostile, only)


## [[unit, squad], ...]: ScrumSeek.foe_units(squad), in its order, from fought()'s search.
static func listed(near: Dictionary) -> Array:
	var squads: Array = near["only"].keys()
	var rank: Dictionary = near["rank"]
	squads.sort_custom(func(a, b): return rank[a] < rank[b])
	var out := []
	for other in squads:
		out.append_array(near["members"][other])
	return out


## As ScrumNear.index over the foes ScrumBlows lets the squad strike ({} if none): every
## hostile unit not routing for a squad fighting or retreating; for any other, only those of
## retreating squads - a retreat is struck as it goes (Decisions 95 and 101); none for a
## routing or destroyed one.
static func struck(index: Dictionary, squad: SkirmishSquad) -> Dictionary:
	if squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
		return {}
	var hostile := _hostile(index, squad)
	var all := (
		squad.state == SkirmishSquad.State.FIGHTING or squad.order == SkirmishUnit.Order.RETREAT
	)
	var near := _view(hostile, hostile["standing"] if all else hostile["retreating"])
	return near if near["any"] else {}


## A search of the faction's index among the squads `only` names; with none of their units
## to find, an empty one, and the faction's grid is not made for it.
static func _view(hostile: Dictionary, only: Dictionary) -> Dictionary:
	var any := only.keys().any(func(other): return not hostile["members"][other].is_empty())
	if any and not hostile.has("near"):
		hostile["near"] = ScrumNear.index(hostile["foes"])
	var near: Dictionary = (hostile["near"] if any else ScrumNear.index([])).duplicate()
	near["only"] = only if any else {}  # a duplicate: its own "last" (ScrumNear.gap_to)
	near["rank"] = hostile["rank"]
	near["members"] = hostile["members"]
	near["any"] = any
	return near


## The index of the living units hostile to the squad's faction and not routing, with
## "by_id": squad id -> those squads; "rank": squad -> where it comes in the squads;
## "members": squad -> its entries; "standing" and "retreating": the squads not destroyed,
## and of them those retreating, each as {squad: true}.
static func _hostile(index: Dictionary, squad: SkirmishSquad) -> Dictionary:
	var factions: Dictionary = index["factions"]
	if factions.has(squad.faction_id):
		return factions[squad.faction_id]
	var out := {"by_id": {}, "rank": {}, "members": {}, "standing": {}, "retreating": {}}
	var foes := []
	for other in index["squads"]:
		if other.faction_id == squad.faction_id or other.state == SkirmishSquad.State.ROUTING:
			continue
		out["rank"][other] = out["rank"].size()
		if not out["by_id"].has(other.id):
			out["by_id"][other.id] = []
		out["by_id"][other.id].append(other)
		var members := []
		for unit in other.living():
			members.append([unit, other])
		out["members"][other] = members
		foes.append_array(members)
		if other.state != SkirmishSquad.State.DESTROYED:
			out["standing"][other] = true
			if other.order == SkirmishUnit.Order.RETREAT:
				out["retreating"][other] = true
	out["foes"] = foes  # indexed when first searched (_view)
	factions[squad.faction_id] = out
	return out


## Squad id -> {id of a squad it fights: true}, both ways (ScrumSeek.foe_ids): its front's
## foe, and those on its edges. Made once an index.
static func _links(index: Dictionary) -> Dictionary:
	if index.has("links"):
		return index["links"]
	var links := {}
	for squad in index["squads"]:
		var foes := [squad.engaged_with]
		for contact in squad.flank_contacts.values():
			foes.append(contact["foe"])
		for foe_id in foes:
			_link(links, squad.id, foe_id)
			_link(links, foe_id, squad.id)
	index["links"] = links
	return links


static func _link(links: Dictionary, from_id: int, to_id: int) -> void:
	if not links.has(from_id):
		links[from_id] = {}
	links[from_id][to_id] = true
