extends RefCounted
## A closed, bevelled geological solid made from explicit half-space cuts.
## All inputs retain n.dot(position) <= d; coordinates and UVs stay in metres.

const EPSILON := 0.00002


static func create(planes: Array[Plane], color: Color = Color.WHITE, variant: int = 0, grass_crown: bool = false, ground_contact: Callable = Callable()) -> ArrayMesh:
	var faces := _initial_cube()
	for source in planes:
		var magnitude := source.normal.length()
		if magnitude < EPSILON:
			continue
		var plane := Plane(source.normal / magnitude, source.d / magnitude)
		faces = _clip(faces, plane)
		if faces.is_empty():
			return ArrayMesh.new()
	# A circular worn edge keeps the broad structural faces but replaces each
	# razor edge with three actual facets. The radius is in world metres.
	var bevel_planes: Array[Plane] = []
	var all_points: Array[Vector3] = []
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for face in faces:
		for point: Vector3 in face.points:
			all_points.append(point)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	var extent := maximum - minimum
	var wear := .16 + .026 * sin(float(variant) * 1.31)
	var radius := minf(0.72, minf(extent.x, minf(extent.y, extent.z)) * wear)
	for i in range(faces.size()):
		for j in range(i + 1, faces.size()):
			var normal_a: Vector3 = faces[i].normal
			var normal_b: Vector3 = faces[j].normal
			var alignment := normal_a.dot(normal_b)
			if alignment > 0.98 or alignment < -0.98:
				continue
			if not _share_edge(faces[i].points, faces[j].points):
				continue
			var bisector := (normal_a + normal_b).normalized()
			var cosine_half_angle := normal_a.dot(bisector)
			for weight in [0.25, 0.50, 0.75]:
				var normal := normal_a.lerp(normal_b, weight).normalized()
				var distance := -INF
				for point in all_points:
					distance = maxf(distance, normal.dot(point))
				# The arc centre is radius/cos(theta/2) inward along the
				# bisector. Offset the supporting tangent plane by the
				# projected centre displacement minus the same radius.
				var inset := radius * (normal.dot(bisector) / cosine_half_angle - 1.0)
				bevel_planes.append(Plane(normal, distance - inset))
	for plane in bevel_planes:
		faces = _clip(faces, plane, true)
	# Shared cutting planes partition the entire skin, including adjacent bevels.
	# This resolves metre-scale authored fractures without independent face grids
	# or their T-junctions. Every coincident point then uses one deformation.
	faces = _partition_skin(faces, minimum, maximum, variant)
	var deformed_points: Dictionary = {}
	for face in faces:
		var points: Array[Vector3] = []
		for point: Vector3 in face.points:
			var key := _vertex_key(point)
			if not deformed_points.has(key):
				deformed_points[key] = _eroded_position(point, minimum, extent, variant)
			points.append(deformed_points[key])
		face.points = points
		face.normal = _polygon_normal(points)
	var joined_normals: Dictionary = {}
	var principal_normals: Dictionary = {}
	var face_normals: Dictionary = {}
	for face in faces:
		for point: Vector3 in face.points:
			var key := _vertex_key(point)
			joined_normals[key] = joined_normals.get(key, Vector3.ZERO) + face.normal
			var face_key := str(face.group) + ":" + str(key)
			face_normals[face_key] = face_normals.get(face_key, Vector3.ZERO) + face.normal
			if not face.get("bevel", false):
				principal_normals[key] = principal_normals.get(key, Vector3.ZERO) + face.normal
	var soil_by_vertex: Dictionary = {}
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var points: Array = face.points
		var normal: Vector3 = face.normal
		var centroid := Vector3.ZERO
		for point: Vector3 in points:
			centroid += point
		centroid /= float(points.size())
		# After deformation a former planar n-gon can be mildly concave. A local
		# centre fan keeps every small boundary segment instead of spanning the
		# whole patch from one corner and folding a long, thin triangle.
		for i in range(points.size()):
			var a := centroid
			var b: Vector3 = points[i]
			var c: Vector3 = points[(i + 1) % points.size()]
			# Keep slender triangles where a cutting plane enters a bevel. Dropping
			# them leaves an unmatched edge in both the render and collision mesh.
			var area_normal := (c - a).cross(b - a)
			if area_normal.length_squared() < 1e-20:
				continue
			var actual_normal := area_normal.normalized()
			for point: Vector3 in [a, b, c]:
				var height := clampf((point.y - minimum.y) / maxf(extent.y, 0.01), 0.0, 1.0)
				var tint := lerpf(0.972, 1.0, height)
				var key := _vertex_key(point)
				var face_key := str(face.group) + ":" + str(key)
				var face_blend: Vector3 = face_normals.get(face_key, normal)
				var shading_normal := face_blend.normalized()
				if face.get("bevel", false):
					# Flat principal faces stay flat. The rounded strip meets
					# those faces tangentially and blends between its facets.
					var blended: Vector3 = principal_normals.get(key, joined_normals.get(key, normal))
					shading_normal = blended.normalized()
				# At a sharp eroded corner a principal neighbour can point across
				# the small bevel. Keep its shading normal in the actual surface
				# hemisphere rather than producing a dark inverted highlight.
				if shading_normal.dot(actual_normal) < 0.45:
					shading_normal = (shading_normal + actual_normal * 1.5).normalized()
				var mask := _crown_mask(point, shading_normal, minimum, extent, variant) if grass_crown else 0.0
				surface.set_color(Color(color.r * tint, color.g * tint, color.b * tint, mask))
				surface.set_normal(shading_normal)
				surface.set_uv(_project_uv(point, normal) * 0.06)
				if ground_contact.is_valid() and not soil_by_vertex.has(key):
					soil_by_vertex[key] = ground_contact.call(point)
				surface.set_uv2(Vector2(soil_by_vertex.get(key, 0.0), 0.0))
				surface.add_vertex(point)
	return surface.commit()


static func _partition_skin(faces: Array[Dictionary], minimum: Vector3, maximum: Vector3, variant: int) -> Array[Dictionary]:
	for i in range(faces.size()):
		faces[i].group = i
	var u := Vector3(0.927, 0.19, 0.324).normalized()
	var v := Vector3(-0.35, 0.06, 0.935).normalized()
	v = (v - u * u.dot(v)).normalized()
	var w := u.cross(v).normalized()
	var center := (minimum + maximum) * 0.5
	var radius := (maximum - minimum) * 0.5
	for axis: Vector3 in [u, v, w]:
		var spacing := 1.10
		var phase := float(posmod(variant, 5)) * 0.13
		var low := axis.dot(center) - axis.abs().dot(radius)
		var high := axis.dot(center) + axis.abs().dot(radius)
		for index in range(ceili((low - phase) / spacing), floori((high - phase) / spacing) + 1):
			var plane := Plane(axis, float(index) * spacing + phase)
			var pieces: Array[Dictionary] = []
			for face in faces:
				var bounds := Vector2(INF, -INF)
				for point: Vector3 in face.points:
					var distance := plane.normal.dot(point) - plane.d
					bounds.x = minf(bounds.x, distance)
					bounds.y = maxf(bounds.y, distance)
				if bounds.x >= -EPSILON or bounds.y <= EPSILON:
					pieces.append(face)
					continue
				for side in [-1.0, 1.0]:
					var points := _split_polygon(face.points, plane, side)
					if points.size() >= 3:
						pieces.append({"normal": face.normal, "points": points, "bevel": face.get("bevel", false), "group": face.group})
			faces = pieces
	return faces


static func _intersection(a: Vector3, b: Vector3, da: float, db: float) -> Vector3:
	# Adjacent faces traverse their shared edge in opposite directions. Lerp
	# from the same endpoint to produce bit-identical intersection coordinates.
	if b < a:
		return b.lerp(a, db / (db - da))
	return a.lerp(b, da / (da - db))


static func _split_polygon(input: Array, plane: Plane, side: float) -> Array[Vector3]:
	var output: Array[Vector3] = []
	for i in range(input.size()):
		var a: Vector3 = input[i]
		var b: Vector3 = input[(i + 1) % input.size()]
		var da := (plane.normal.dot(a) - plane.d) * side
		var db := (plane.normal.dot(b) - plane.d) * side
		if da <= EPSILON:
			_append_distinct(output, a)
		if (da < -EPSILON and db > EPSILON) or (da > EPSILON and db < -EPSILON):
			_append_distinct(output, _intersection(a, b, da, db))
	return output


static func _eroded_position(point: Vector3, minimum: Vector3, extent: Vector3, variant: int) -> Vector3:
	var center := minimum + extent * 0.5
	var p := point - center
	var sign_value := -1.0 if posmod(variant, 2) == 0 else 1.0
	var offset := float(posmod(variant, 5) - 2) * 0.29
	var scale_factor := minf(1.0, minf(extent.x, minf(extent.y, extent.z)) / 4.5)
	var bottom_fade := smoothstep(minimum.y + 0.08, minimum.y + minf(1.4, extent.y * 0.24), point.y)
	var front := smoothstep(-extent.z * 0.22, extent.z * 0.33, p.z)
	# Only three authored geological events. Their 2-4 m influence zones leave
	# wide quiet faces between them; there is no noise or per-vertex randomness.
	var ridge_line := p.x - sign_value * p.y * 0.34 - offset - extent.x * 0.16
	var fracture_line := p.x + sign_value * p.y * 0.43 + p.z * 0.12 + extent.x * 0.20 - offset
	var ridge := _localized_band(ridge_line, 2.0 * maxf(scale_factor, 0.55))
	var fracture := _localized_band(fracture_line, 1.20 * maxf(scale_factor, 0.55))
	var strata_line := p.y - p.x * sign_value * 0.21 + p.z * 0.16 + extent.y * 0.08
	var strata := _localized_band(strata_line, 0.90 * maxf(scale_factor, 0.55)) * _localized_band(p.x + extent.x * 0.14, extent.x * 0.38)
	var depth := (0.62 * ridge - 0.57 * fracture + 0.22 * strata) * front
	var lateral := -sign_value * (0.20 * fracture + 0.13 * ridge) * front
	var crown := smoothstep(0.65, 0.95, (point.y - minimum.y) / maxf(extent.y, 0.01))
	var crown_cut := _localized_band(p.x + extent.x * 0.18 + sign_value * p.z * 0.22 - offset, 1.42)
	var crown_lift := _localized_band(p.x - extent.x * 0.25 - p.z * 0.12, 2.15)
	var vertical := crown * (-0.64 * crown_cut + 0.26 * crown_lift) * (0.30 + 0.70 * front)
	return point + Vector3(lateral, vertical, depth) * bottom_fade * scale_factor


static func _localized_band(distance: float, half_width: float) -> float:
	return 1.0 - smoothstep(0.12, 1.0, absf(distance) / maxf(half_width, 0.01))


static func _polygon_normal(points: Array[Vector3]) -> Vector3:
	var normal := Vector3.ZERO
	for i in range(1, points.size() - 1):
		normal += (points[i + 1] - points[0]).cross(points[i] - points[0])
	return normal.normalized()


static func _crown_mask(point: Vector3, normal: Vector3, minimum: Vector3, extent: Vector3, variant: int) -> float:
	var height := (point.y - minimum.y) / maxf(extent.y, 0.01)
	if height <= 0.65 or normal.y <= 0.52:
		return 0.0
	var center := minimum + extent * 0.5
	var p := point - center
	var sign_value := -1.0 if posmod(variant, 2) == 0 else 1.0
	var exposed_joint := _localized_band(p.x + sign_value * p.z * 0.36 + extent.x * 0.18, 1.05)
	var bare_pocket := _localized_band(p.x - extent.x * 0.24, 1.7) * _localized_band(p.z - extent.z * 0.23, 1.5)
	var cover := 1.0 - maxf(exposed_joint * 0.92, bare_pocket * 0.85)
	return clampf(smoothstep(0.65, 0.79, height) * smoothstep(0.52, 0.78, normal.y) * cover, 0.0, 1.0)


static func _initial_cube() -> Array[Dictionary]:
	var extent := 2048.0
	var faces: Array[Dictionary] = []
	for axis in range(3):
		for sign_value in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var points: Array[Vector3] = []
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point := normal * extent
				point[(axis + 1) % 3] = corner.x * extent
				point[(axis + 2) % 3] = corner.y * extent
				points.append(point)
			_orient(points, normal)
			faces.append({"normal": normal, "points": points})
	return faces


static func _clip(faces: Array[Dictionary], plane: Plane, bevel_face: bool = false) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var cut_points: Array[Vector3] = []
	for face in faces:
		var input: Array = face.points
		var clipped: Array[Vector3] = []
		for i in range(input.size()):
			var current: Vector3 = input[i]
			var next: Vector3 = input[(i + 1) % input.size()]
			var a := plane.normal.dot(current) - plane.d
			var b := plane.normal.dot(next) - plane.d
			var inside_a := a <= EPSILON
			var inside_b := b <= EPSILON
			if inside_a:
				_append_distinct(clipped, current)
			if inside_a != inside_b:
				var point := _intersection(current, next, a, b)
				_append_distinct(clipped, point)
				_append_distinct(cut_points, point)
		if clipped.size() >= 3:
			output.append({"normal": face.normal, "points": clipped, "bevel": face.get("bevel", false)})
	if cut_points.size() >= 3:
		var center := Vector3.ZERO
		for point in cut_points:
			center += point
		center /= float(cut_points.size())
		var reference := Vector3.UP if absf(plane.normal.y) < 0.8 else Vector3.RIGHT
		var tangent := plane.normal.cross(reference).normalized()
		var bitangent := plane.normal.cross(tangent).normalized()
		cut_points.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			var offset_a := a - center
			var offset_b := b - center
			return atan2(offset_a.dot(bitangent), offset_a.dot(tangent)) < atan2(offset_b.dot(bitangent), offset_b.dot(tangent)))
		_orient(cut_points, plane.normal)
		output.append({"normal": plane.normal, "points": cut_points, "bevel": bevel_face})
	return output


static func _vertex_key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0))


static func _append_distinct(points: Array[Vector3], point: Vector3) -> void:
	for existing in points:
		if existing.distance_squared_to(point) < EPSILON * EPSILON:
			return
	points.append(point)


static func _orient(points: Array[Vector3], normal: Vector3) -> void:
	# A clipped face may begin with nearly collinear points. Use the summed
	# polygon area so a tiny local cross product cannot turn a whole face inward.
	if _polygon_normal(points).dot(normal) < 0.0:
		points.reverse()


static func _share_edge(a: Array, b: Array) -> bool:
	var shared := 0
	for point_a: Vector3 in a:
		for point_b: Vector3 in b:
			if point_a.distance_squared_to(point_b) < 0.000001:
				shared += 1
				break
	return shared >= 2


static func _project_uv(point: Vector3, normal: Vector3) -> Vector2:
	var major := normal.abs()
	if major.y > major.x and major.y > major.z:
		return Vector2(point.x, point.z)
	if major.x > major.z:
		return Vector2(point.z, point.y)
	return Vector2(point.x, point.y)
