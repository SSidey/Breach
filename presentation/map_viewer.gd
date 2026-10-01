class_name MapViewer
extends Node2D
## The map viewer app (presentation/map_viewer.tscn), per specs/18-map-viewer.md: pick
## any map in content/maps, choose whose view to see, pan/zoom, click a node for its
## details. Engine glue around MapView; argument parsing and map discovery are tested,
## interaction is checked by hand.
##
##   godot --path . res://presentation/map_viewer.tscn -- --map=res://content/maps/<name>.tres
##
## (or open the scene and press F6; the designer's "View in Godot" runs the line above).

const MapView = preload("res://presentation/map_view.gd")
const MapDetails = preload("res://presentation/map_details.gd")

const MAPS_DIR := "res://content/maps"
const MAP_ARG := "--map="
const ZOOM_STEP := 1.15
const CLICK_SLOP := 4.0
## The info panel's width plus margins; Fit frames the map in the space right of it.
const PANEL_SPACE := 290.0

## Preselected map (defaults to --map=..., else the first map found).
var initial_map_path: String = ""

var _map_paths: PackedStringArray = []
var _map_picker: OptionButton
var _view_as_picker: OptionButton
var _info: RichTextLabel
var _dragging := false
var _press_position := Vector2.ZERO


static func map_path_from_args(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with(MAP_ARG):
			return arg.substr(MAP_ARG.length())
	return ""


## Every .tres in dir_path that loads as a MapDef, in name order.
static func list_map_paths(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var names := Array(dir.get_files()).filter(func(n): return n.ends_with(".tres"))
	names.sort()
	for file_name in names:
		var path := dir_path.path_join(file_name)
		if ResourceLoader.load(path) is MapDef:
			out.append(path)
	return out


func map_view() -> MapView:
	return $MapView


func _ready() -> void:
	if map_view().art_set != null:
		RenderingServer.set_default_clear_color(map_view().art_set.background_color.darkened(0.12))
	_build_ui()
	_map_paths = list_map_paths(MAPS_DIR)
	for path in _map_paths:
		_map_picker.add_item(path.get_file().get_basename())
	var wanted := initial_map_path
	if wanted == "":
		wanted = map_path_from_args(OS.get_cmdline_user_args())
	var index := _map_paths.find(wanted)
	if index == -1 and wanted != "":
		_info.text = "Map not found: %s" % wanted
	if not _map_paths.is_empty():
		_select_map(maxi(index, 0))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(260, 0)
	panel.add_child(box)
	_map_picker = _labelled_picker(box, "Map")
	_map_picker.item_selected.connect(_select_map)
	_view_as_picker = _labelled_picker(box, "View as")
	_view_as_picker.item_selected.connect(_on_view_as_selected)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	_add_button(buttons, "Fit", _fit)
	_add_button(buttons, "Reload", func(): _select_map(_map_picker.selected))
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.custom_minimum_size = Vector2(260, 0)
	_info.text = "Click a node for details. Drag to pan, wheel to zoom."
	box.add_child(_info)


func _labelled_picker(parent: Container, text: String) -> OptionButton:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var picker := OptionButton.new()
	parent.add_child(picker)
	return picker


func _add_button(parent: Container, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _select_map(index: int) -> void:
	if index < 0 or index >= _map_paths.size():
		return
	_map_picker.select(index)
	var map := ResourceLoader.load(_map_paths[index], "", ResourceLoader.CACHE_MODE_REPLACE)
	map_view().map = map
	map_view().selected_id = ""
	_view_as_picker.clear()
	_view_as_picker.add_item("Designer (everything)")
	for faction in map.factions:
		_view_as_picker.add_item(faction.display_name if faction.display_name else faction.id)
	map_view().view_as_faction_id = ""
	_info.text = MapDetails.summary(map)
	_fit()


func _on_view_as_selected(index: int) -> void:
	var map := map_view().map
	map_view().view_as_faction_id = "" if index <= 0 else map.factions[index - 1].id
	map_view().selected_id = ""


func _fit() -> void:
	var view := map_view()
	if view.model == null:
		return
	var bounds := view.model.bounds
	var viewport_size := get_viewport_rect().size
	var usable := Vector2(maxf(viewport_size.x - PANEL_SPACE, 1.0), viewport_size.y)
	var fit := minf(usable.x / bounds.size.x, usable.y / bounds.size.y) * 0.92
	var camera: Camera2D = $Camera
	camera.zoom = Vector2(fit, fit)
	# Shift the centre left by half the panel so the map sits in the free area.
	var offset := Vector2(PANEL_SPACE * 0.5, 0.0) / fit
	camera.position = view.to_global(bounds.get_center()) - offset


func _unhandled_input(event: InputEvent) -> void:
	var camera: Camera2D = $Camera
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom *= ZOOM_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom /= ZOOM_STEP
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_press_position = event.position
			else:
				_dragging = false
				if event.position.distance_to(_press_position) <= CLICK_SLOP:
					_click(get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		camera.position -= event.relative / camera.zoom


func _click(world_point: Vector2) -> void:
	var id := map_view().node_at(world_point)
	map_view().selected_id = id
	var map := map_view().map
	_info.text = MapDetails.node_details(map, id) if id != "" else MapDetails.summary(map)
