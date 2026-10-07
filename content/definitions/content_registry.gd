class_name ContentRegistry
extends RefCounted
## The registry of tags, traits and statuses (Decision 128), read from content/registry/*.json
## - the one place each is defined, described and tagged, which the designer's Library
## browses. A trait's tags say where it may sit (each tag's targets: unit, leader, weapon,
## armour, tool, material, structure); it may sit where all its tags agree, narrowed by
## its "only". Content checks its traits and tags against it here. Pure, cached.

const DIR := "res://content/registry/"
const KINDS := ["tags", "traits", "statuses"]

static var _cache := {}


## {"tags": {id: entry}, "traits": {id: entry}, "statuses": {id: entry}}.
static func current() -> Dictionary:
	if _cache.is_empty():
		for kind in KINDS:
			var read = JSON.parse_string(FileAccess.get_file_as_string(DIR + kind + ".json"))
			_cache[kind] = {}
			for entry in read[kind] if read is Dictionary else []:
				_cache[kind][entry["id"]] = entry
	return _cache


## The kinds of thing the trait may sit on: where all its tags' targets agree, within its
## "only" if it has one. Empty for an unknown trait.
static func targets(trait_id: String) -> Array:
	var entry: Dictionary = current()["traits"].get(trait_id, {})
	if entry.is_empty():
		return []
	var out = null
	for tag in entry.get("tags", []):
		var reach: Array = current()["tags"].get(tag, {}).get("targets", [])
		out = reach.duplicate() if out == null else out.filter(func(k): return reach.has(k))
	if out == null:
		return []
	if entry.has("only"):
		out = out.filter(func(k): return entry["only"].has(k))
	return out


## What is wrong with `traits` (id -> level) on `what`, a thing of `kinds`: unknown traits,
## and ones that may not sit on any of those kinds.
static func trait_errors(traits: Dictionary, kinds: Array, what: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for trait_id in traits:
		if not current()["traits"].has(trait_id):
			errors.append("%s: unknown trait '%s'" % [what, trait_id])
		elif not targets(trait_id).any(func(k): return kinds.has(k)):
			errors.append("%s: trait '%s' can't sit on a %s" % [what, trait_id, kinds[0]])
	return errors


## What is wrong with `tags` on `what`, a thing of `tagged` (unit, item, trait, status):
## unknown tags, and ones not for that kind of thing.
static func tag_errors(tags: Array, tagged: String, what: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for tag in tags:
		var entry: Dictionary = current()["tags"].get(tag, {})
		if entry.is_empty():
			errors.append("%s: unknown tag '%s'" % [what, tag])
		elif entry.get("tags", "") != tagged:
			errors.append("%s: tag '%s' is for a %s, not a %s" % [what, tag, entry["tags"], tagged])
	return errors
