extends SceneTree
## Headless import of the shared terrain library, per
## specs/19-map-layout-and-objectives.md (DesignerLibraryImport.run):
##
##   godot --headless --path . --script res://tools/import_designer_library.gd
##   godot ... -- <terrain.json> <maps_src dir> <out.tres>     (all three, or none)
##
## Defaults: content/designer/terrain.json, content/maps_src, content/terrain/
## terrain_library.tres. Prints errors and exits 1 if there are any (nothing is written
## then - including when a saved map still uses a terrain the new library drops),
## otherwise writes the .tres and exits 0. The designer's server runs this whenever the
## terrain library is saved.

const DesignerLibraryImport = preload("res://content/import/designer_library_import.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 0 and args.size() != 3:
		printerr("usage: [-- <terrain.json> <maps_src dir> <output.tres>]")
		quit(2)
		return
	var result = (
		DesignerLibraryImport.run()
		if args.is_empty()
		else DesignerLibraryImport.run(args[0], args[1], args[2])
	)
	for error in result.errors:
		printerr("error: %s" % error)
	if result.errors.is_empty():
		print("wrote %s" % (DesignerLibraryImport.LIBRARY_TRES if args.is_empty() else args[2]))
	quit(0 if result.errors.is_empty() else 1)
