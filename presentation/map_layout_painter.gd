class_name MapLayoutPainter
extends RefCounted
## Paints a MapLayoutView onto a CanvasItem during that item's _draw(), per
## specs/19-map-layout-and-objectives.md: terrain cells (library colours, softened so
## nodes stay readable), feature glyphs, roads, then bridges and drawbridges. MapView
## calls it before its own edges, lanes and markers. Rendering only - verified by hand.

const MapLayoutView = preload("res://presentation/map_layout_view.gd")
const MapArtSet = preload("res://presentation/map_art_set.gd")

## How far terrain colours are blended toward the background.
const TERRAIN_SOFTEN := 0.35
const ROAD_WIDTH := 9.0
const GLYPH_FONT_SIZE := 13


static func paint(canvas: CanvasItem, view: MapLayoutView, art: MapArtSet) -> void:
	for cell in view.cells:
		canvas.draw_rect(cell.rect, cell.color.lerp(art.background_color, TERRAIN_SOFTEN))
	for cell in view.cells:
		if cell.feature_glyph:
			_draw_glyph(canvas, cell, art)
	for segment in view.road_segments:
		canvas.draw_line(segment[0], segment[1], art.road_color, ROAD_WIDTH, true)
		for point in segment:
			canvas.draw_circle(point, ROAD_WIDTH * 0.5, art.road_color)
	for cell in view.cells:
		if cell.has_bridge:
			_draw_bridge(canvas, cell, art)


static func paint_selected_cell(
	canvas: CanvasItem, view: MapLayoutView, cell: Vector2i, art: MapArtSet
) -> void:
	for entry in view.cells:
		if entry.cell == cell:
			canvas.draw_rect(entry.rect.grow(-2.0), art.label_color, false, 3.0)


static func _draw_glyph(canvas: CanvasItem, cell, art: MapArtSet) -> void:
	var origin: Vector2 = cell.rect.position + Vector2(5.0, GLYPH_FONT_SIZE + 3.0)
	canvas.draw_string(
		ThemeDB.fallback_font,
		origin,
		cell.feature_glyph,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		GLYPH_FONT_SIZE,
		art.feature_glyph_color
	)


## Planks across the cell; a raised drawbridge is drawn as two stubs with a gap.
static func _draw_bridge(canvas: CanvasItem, cell, art: MapArtSet) -> void:
	var rect: Rect2 = cell.rect
	var deck := Rect2(
		rect.position + Vector2(4.0, rect.size.y * 0.3),
		Vector2(rect.size.x - 8.0, rect.size.y * 0.4)
	)
	if cell.raised:
		var stub := Vector2(deck.size.x * 0.3, deck.size.y)
		canvas.draw_rect(Rect2(deck.position, stub), art.bridge_color)
		canvas.draw_rect(Rect2(deck.end - stub, stub), art.bridge_color)
		return
	canvas.draw_rect(deck, art.bridge_color)
	var plank := deck.size.x / 6.0
	for i in range(1, 6):
		var x := deck.position.x + plank * i
		canvas.draw_line(
			Vector2(x, deck.position.y), Vector2(x, deck.end.y), art.background_color, 1.5
		)
	if cell.is_drawbridge:
		canvas.draw_rect(deck, art.label_color, false, 2.0)
