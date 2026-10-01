class_name WavePresetStore
extends RefCounted
## Keeps the player's wave presets (Decision 43) in a small JSON file between sessions:
## a list of WavePresets dictionaries. A missing or unreadable file means no presets; an
## empty path means don't touch the disk at all (the tests use that).


static func load_presets(path: String) -> Array:
	if path.is_empty() or not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array:
		return []
	return parsed.filter(func(p): return p is Dictionary and p.has("units"))


static func save_presets(path: String, presets: Array) -> void:
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(presets, "\t"))


static func names(presets: Array) -> Array:
	return presets.map(func(p): return p.get("name", "Preset"))
