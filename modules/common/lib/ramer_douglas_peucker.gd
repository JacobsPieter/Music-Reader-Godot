extends Object
class_name RamerDouglasPeucker
## Taken from https://github.com/Scrawach/rdp/blob/82463812276f718d5a8d55ea70f7fbbe501c9ee8/addons/rdp/core/RamerDouglasPeucker.gd
## Licenced under MIT license at time of writing
## Slight modifications by Claude to fit use case.

# Returns the indices (into `points`) of the points that are kept, in ascending order.
# Ramer-Douglas-Peucker algorithm: https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm
static func calculate_indices(points: PackedVector2Array, epsilon: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	if points.size() < 3:
		for i in points.size():
			result.append(i)
		return result
	var epsilon_squared := epsilon * epsilon
	_simplify(result, points, 0, points.size() - 1, epsilon_squared)
	result.append(points.size() - 1)
	return result

# Same as before: returns the simplified points.
static func calculate(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	return select_points(points, calculate_indices(points, epsilon))

# Returns both at once: { "points": PackedVector2Array, "indices": PackedInt32Array }
static func calculate_with_indices(points: PackedVector2Array, epsilon: float) -> Dictionary:
	var indices := calculate_indices(points, epsilon)
	return {
		"points": select_points(points, indices),
		"indices": indices,
	}

# Picks the points at the given indices.
static func select_points(points: PackedVector2Array, indices: PackedInt32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(indices.size())
	for i in indices.size():
		out[i] = points[indices[i]]
	return out

# Filters any accompanying data array (same length as the input points) down to the kept points.
static func filter_by_indices(data: Array, indices: PackedInt32Array) -> Array:
	var out := []
	out.resize(indices.size())
	for i in indices.size():
		out[i] = data[indices[i]]
	return out

# indices of the points that were removed.
static func removed_indices(point_count: int, kept: PackedInt32Array) -> PackedInt32Array:
	var removed := PackedInt32Array()
	var k := 0
	for i in point_count:
		if k < kept.size() and kept[k] == i:
			k += 1
		else:
			removed.append(i)
	return removed

# Recursive calculation
static func _simplify(result: PackedInt32Array, points: PackedVector2Array, start: int, end: int, epsilon_squared: float) -> void:
	var max_distance_squared := 0.0
	var index := 0
	
	for i in range(start, end + 1):
		var distance := _perpendicular_squared(points[i], points[start], points[end])
		if distance > max_distance_squared:
			max_distance_squared = distance
			index = i
	if max_distance_squared <= epsilon_squared:
		result.append(start)
	else:
		_simplify(result, points, start, index, epsilon_squared)
		_simplify(result, points, index, end, epsilon_squared)

static func _perpendicular_squared(target: Vector2, p1: Vector2, p2: Vector2) -> float:
	var to_target := target - p1
	var to_end := p2 - p1
	# Guard: if start and end coincide (e.g. closed loop), project() would divide by zero.
	if to_end.length_squared() == 0.0:
		return to_target.length_squared()
	var project := to_target.project(to_end)
	return to_target.length_squared() - project.length_squared()
