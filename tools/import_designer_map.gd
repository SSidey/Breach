extends SceneTree
## Headless designer-map import, per specs/16-designer-map-import.md. Same path as the
## DesignerMapImport Inspector button (DesignerMapImport.run):
##
##   godot --headless --path . --script res://tools/import_designer_map.gd -- \
##       res://content/maps_src/<name>.designer.json res://content/maps/<name>.tres
##
## Prints warnings, prints errors and exits 1 if there are any (nothing is saved then),
## otherwise writes the .tres and exits 0.

const DesignerMapImport = preload("res://content/import/designer_map_import.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("usage: -- <designer.json> <output.tres>")
		quit(2)
		return
	var result := DesignerMapImport.run(args[0], args[1])
	for warning in result.warnings:
		print("warning: %s" % warning)
	for error in result.errors:
		printerr("error: %s" % error)
	if result.errors.is_empty():
		print("wrote %s" % args[1])
	quit(0 if result.errors.is_empty() else 1)
