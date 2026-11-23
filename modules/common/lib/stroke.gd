class_name Stroke
extends RefCounted
## The base class to use for the annotations. All hand-drawn lines need to be a subclass of this.
##
## Coordinates are in page space (see PageCanvas.page_size), not screen pixels.

var colour := Color()
var width: float = 1.0
var points := PackedVector2Array()
var pressures := PackedFloat64Array()
var tilts := PackedVector2Array()


func add_point(point: Vector2, pressure := 1.0, tilt := Vector2.ZERO) -> void:
	points.append(point)
	pressures.append(pressure)
	tilts.append(tilt)


## Compresses the points to a much more manageable size without losing too much detail.
func compress_line() -> void:
	if points.size() < 3:
		return
	var indices := RamerDouglasPeucker.calculate_indices(points, 0.1)
	points = RamerDouglasPeucker.select_points(points, indices)
	pressures = PackedFloat64Array(RamerDouglasPeucker.filter_by_indices(pressures, indices))
	tilts = PackedVector2Array(RamerDouglasPeucker.filter_by_indices(tilts, indices))


## Bounding box of everything this stroke paints, including the line thickness.
func get_bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect.grow(width * 0.5 + 1.0)


## Returns this stroke as an SVG element, or an empty string if it is too short to draw.
func to_svg() -> String:
	if points.size() < 2:
		return ""
	var d := PackedStringArray()
	d.append("M%.2f,%.2f" % [points[0].x, points[0].y])
	if points.size() == 2:
		d.append("L%.2f,%.2f" % [points[1].x, points[1].y])
	else:
		var first_mid := points[0].lerp(points[1], 0.5)
		d.append("L%.2f,%.2f" % [first_mid.x, first_mid.y])
		for i in range(1, points.size() - 1):
			var mid := points[i].lerp(points[i + 1], 0.5)
			d.append("Q%.2f,%.2f %.2f,%.2f" % [points[i].x, points[i].y, mid.x, mid.y])
		var last := points[points.size() - 1]
		d.append("L%.2f,%.2f" % [last.x, last.y])
	return (
		'<path d="%s" fill="none" stroke="#%s" stroke-opacity="%.3f" '
		+ 'stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round"/>'
	) % [" ".join(d), colour.to_html(false), colour.a, width]


## Plain Dictionary/Array data only, so JSON.stringify can write it directly.
func to_dict() -> Dictionary:
	var flat_points := []
	for point in points:
		flat_points.append(snappedf(point.x, 0.001))
		flat_points.append(snappedf(point.y, 0.001))
	var flat_pressures := []
	for pressure in pressures:
		flat_pressures.append(snappedf(pressure, 0.001))
	var flat_tilts := []
	for tilt in tilts:
		flat_tilts.append(snappedf(tilt.x, 0.001))
		flat_tilts.append(snappedf(tilt.y, 0.001))
	return {
		"colour": colour.to_html(true),
		"width": width,
		"points": flat_points,
		"pressures": flat_pressures,
		"tilts": flat_tilts,
	}


static func from_dict(data: Dictionary) -> Stroke:
	var stroke := Stroke.new()
	stroke.colour = Color.html(data.get("colour", "000000ff"))
	stroke.width = data.get("width", 1.0)
	var flat_points: Array = data.get("points", [])
	var flat_pressures: Array = data.get("pressures", [])
	var flat_tilts: Array = data.get("tilts", [])
	for i in floor(flat_points.size() / 2.0):
		var pressure: float = flat_pressures[i] if i < flat_pressures.size() else 1.0
		var tilt := Vector2.ZERO
		if i * 2 + 1 < flat_tilts.size():
			tilt = Vector2(flat_tilts[i * 2], flat_tilts[i * 2 + 1])
		stroke.add_point(Vector2(flat_points[i * 2], flat_points[i * 2 + 1]), pressure, tilt)
	return stroke
