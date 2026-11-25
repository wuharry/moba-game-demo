extends RefCounted
## Raised buttercup cups and pale field daisies on the lower terraces.

const Talus = preload("res://calibration_daylight/talus.gd")
const LEAF_GREEN := Color(0.41, 0.65, 0.16)
const STEM_GREEN := Color(0.44, 0.62, 0.18)
const POLLEN := Color(0.94, 0.84, 0.17)

static func build(parent: Node3D, terrain: Script, leaf_material: Material, rng: RandomNumberGenerator) -> void:
	# Each drift has a distinct species and spacing. Looser pale flowers mark
	# the far shoulder. Yellow cups repeat in unequal groups along the low verge.
	# Each entry holds world x, z, length along the drift, number of plants.
	var drifts := [
		[Vector4(-2.9, 19.9, 1.49, 29), Vector4(-0.35, 18.5, 0.99, 16),
		 Vector4(-7.7, 15.1, 1.24, 15), Vector4(-5.1, 9.8, 0.88, 9)],
		[Vector4(-4.6, 20.0, 1.02, 11), Vector4(1.4, 17.1, 0.60, 5),
		 Vector4(-13.0, -3.1, 1.35, 15), Vector4(19.1, -4.9, 1.22, 9)],
		[Vector4(24.4, 9.8, 1.15, 12), Vector4(28.2, 7.7, 0.72, 7),
		 Vector4(32.1, 6.1, 0.98, 4), Vector4(32.7, -11.0, 1.45, 11)]
	]
	var rng_field := RandomNumberGenerator.new()
	rng_field.seed = 117503
	for cultivar in range(drifts.size()):
		var flower_mesh := _flower_mesh(cultivar, leaf_material)
		var transforms: Array[Transform3D] = []
		for drift: Vector4 in drifts[cultivar]:
			var along := Vector2(1.0, -.31).normalized()
			var across := along.orthogonal()
			for plant in range(int(drift.w)):
				var position := Vector2(drift.x, drift.y) + along * rng_field.randfn(0, drift.z) + across * rng_field.randfn(0, .35 * drift.z)
				var height: float = terrain.ground_height(position.x, position.y)
				if absf(position.x - terrain.path_center(position.y)) < 1.95 or not _stable_patch(terrain, position, height):
					continue
				var size := rng_field.randf_range(.78, 1.34)
				var basis := Basis(Vector3.UP, rng_field.randf() * TAU).scaled(Vector3.ONE * size)
				transforms.append(Transform3D(basis, Vector3(position.x, height - .015, position.y)))
		if transforms.is_empty():
			continue
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = flower_mesh
		batch.instance_count = transforms.size()
		for index in range(transforms.size()):
			batch.set_instance_transform(index, transforms[index])
		var blooms := MultiMeshInstance3D.new()
		blooms.name = "FieldFlowers_%02d" % cultivar
		blooms.multimesh = batch
		blooms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(blooms)

	_build_verge(parent, terrain, leaf_material, rng)


static func _flower_mesh(cultivar: int, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	var heights := [.44, .59, .49]
	var height: float = heights[cultivar]
	var socket := Vector3(.055, height * .47, -.018)
	var bloom := Vector3(.15, height, .025)
	_stem(st, Vector3.ZERO, socket)
	_stem(st, socket, bloom)
	# A low splay of leaves makes a basal clump visible at ground level.
	for i in range(5):
		var angle := i * 2.39996 + float(cultivar) * .4
		var radius := .15 + .055 * float(i % 3)
		_leaf(st, Vector3(0, .04, 0), Vector3(cos(angle) * radius, .11 + .03 * float(i % 2), sin(angle) * radius))
	_leaf(st, socket, Vector3(-.12, .065, .09))
	_cup(st, bloom, cultivar, 1.0)
	if cultivar != 2:
		var bud := socket + Vector3(-0.13, height * 0.23, -0.02)
		_stem(st, socket, bud)
		_cup(st, bud, cultivar, 0.72)
	return st.commit()


static func _stem(st: SurfaceTool, lower: Vector3, upper: Vector3) -> void:
	for edge in range(3):
		var a := TAU * edge / 3.0
		var b := TAU * (edge + 1) / 3.0
		var normal := Vector3(cos(a) * .31, .94, sin(a) * .31).normalized()
		var n0 := Vector3(cos(a), 0, sin(a)) * 0.008
		var n1 := Vector3(cos(b), 0, sin(b)) * 0.008
		_triangle(st, lower + n0, upper + n0, lower + n1, normal, STEM_GREEN)
		_triangle(st, upper + n0, upper + n1, lower + n1, normal, STEM_GREEN)


static func _leaf(st: SurfaceTool, origin: Vector3, growth: Vector3) -> void:
	var side := growth.cross(Vector3.UP).normalized() * 0.045
	var middle := origin + growth * 0.42
	_triangle(st, origin, middle + side, origin + growth, Vector3.UP, LEAF_GREEN)
	_triangle(st, origin, origin + growth, middle - side, Vector3.UP, LEAF_GREEN)


static func _cup(st: SurfaceTool, center: Vector3, cultivar: int, scale_factor: float) -> void:
	var ivory := cultivar == 2
	var base := Color(.96, .88, .53) if ivory else Color(.96, .85, .17)
	var edge := Color(.97, .98, .81) if ivory else Color(.96, .97, .45)
	var petals := 7 if ivory else 5
	var radius := (0.121 if ivory else 0.133) * scale_factor
	var axis := Vector3(0.25 + cultivar * 0.14, 1.0, 0.22).normalized()
	var ux := Vector3.RIGHT.slide(axis).normalized()
	var uz := ux.cross(axis).normalized()
	for idx in range(petals):
		var theta := TAU * idx / petals + 0.21 * cultivar
		var radial := ux * cos(theta) + uz * sin(theta)
		var tangent := -ux * sin(theta) + uz * cos(theta)
		var root := center + radial * radius * 0.12
		var middle := center + radial * radius * 0.72 + axis * radius * 0.27
		var tip := center + radial * radius + axis * radius * 0.40
		var flank := tangent * radius * (0.23 if ivory else 0.40)
		_triangle(st, root, middle - flank, middle + flank, axis, base)
		_triangle(st, middle - flank, tip, middle + flank, axis, edge)
		var next_angle := theta + TAU / petals
		var next := ux * cos(next_angle) + uz * sin(next_angle)
		_triangle(st, center + axis * radius * 0.14, center + radial * radius * 0.24, center + next * radius * 0.24, axis, POLLEN)


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, pigment: Color) -> void:
	for point in [a, b, c]:
		st.set_color(pigment)
		st.set_uv(Vector2.ZERO)
		st.set_uv2(Vector2(1.0, 0.0))
		st.set_normal(normal)
		st.add_vertex(point)


static func _build_verge(parent: Node3D, terrain: Script, material: Material, rng: RandomNumberGenerator) -> void:
	# Following the grass side of a bend, the sedges taper east into sparse
	# daisies while the taller, coarser fronds gather at its shaded west end.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	var placed := PackedInt32Array([0, 0, 0])
	var centers := [Vector2(-5.45, 18.4), Vector2(-3.8, 18.1), Vector2(-1.8, 17.8)]
	for kind in range(3):
		var attempts: int = [9, 36, 14][kind]
		for index in range(attempts):
			var center: Vector2 = centers[kind]
			if kind == 1 and index >= 25:
				center = Vector2(24.0, 8.8)
			var point := center + Vector2(rng.randfn(0, 1.04), rng.randfn(0, 0.47))
			if absf(point.x - terrain.path_center(point.y)) < 2.35:
				continue
			var ground: float = terrain.ground_height(point.x, point.y)
			if not _stable_patch(terrain, point, ground):
				continue
			var origin := Vector3(point.x, ground - 0.02, point.y)
			if kind == 0:
				_fern(st, origin, rng)
			elif kind == 1:
				_seed_grass(st, origin, rng)
			else:
				var head := origin + Vector3(rng.randf_range(-0.18, 0.13), rng.randf_range(0.33, 0.55), 0.04)
				_stem(st, origin, head)
				_cup(st, head, 2 if index % 4 == 0 else 0, rng.randf_range(0.85, 1.15))
			placed[kind] += 1
	if placed[0] + placed[1] + placed[2] == 0:
		return
	var instance := MeshInstance3D.new()
	instance.name = 'LowerVerge'
	instance.mesh = st.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta('plant_counts', Array(placed))
	parent.add_child(instance)


static func _stable_patch(terrain: Script, point: Vector2, elevation: float) -> bool:
	for offset in [Vector2.ZERO, Vector2(0.32, 0.12), Vector2(-0.28, 0.20), Vector2(-0.04, -0.34)]:
		var sample: Vector2 = point + offset
		if Talus.excludes_grass(sample.x, sample.y):
			return false
		if terrain.vegetation_weight(sample.x, sample.y) < 0.38 or absf(terrain.ground_height(sample.x, sample.y) - elevation) > 0.19:
			return false
	return true


static func _fern(st: SurfaceTool, origin: Vector3, rng: RandomNumberGenerator) -> void:
	var phase := rng.randf() * TAU
	for index in range(6):
		var angle := phase + index * TAU / 6.0 + rng.randf_range(-0.16, 0.16)
		var reach := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.43, 0.77)
		var lateral := reach.cross(Vector3.UP).normalized()
		var rise := rng.randf_range(0.46, 0.72)
		var previous := origin
		for segment in range(1, 7):
			var t := segment / 6.0
			var center := origin + reach * t + Vector3.UP * rise * (1.8 * t - 0.94 * t * t)
			_stem(st, previous, center)
			previous = center
			for side in [-1.0, 1.0]:
				var blade := lateral * float(side) * (0.19 - 0.11 * t) + reach * 0.18 + Vector3.UP * 0.045
				var wing := blade.cross(Vector3.UP).normalized() * (0.047 - 0.018 * t)
				var rib := center + blade * 0.48 + Vector3.UP * 0.018
				var tone := Color(0.15, 0.41, 0.20).lerp(Color(0.26, 0.58, 0.22), t)
				_triangle(st, center, rib + wing, center + blade, Vector3.UP, tone)
				_triangle(st, center, center + blade, rib - wing, Vector3.UP, tone.darkened(0.08))


static func _seed_grass(st: SurfaceTool, origin: Vector3, rng: RandomNumberGenerator) -> void:
	var phase := rng.randf() * TAU
	for blade in range(7):
		var angle := phase + TAU * blade / 7.0
		var forward := Vector3(cos(angle), 0, sin(angle))
		var side := forward.cross(Vector3.UP) * rng.randf_range(0.019, 0.034)
		var height := rng.randf_range(0.63, 1.18)
		var bend := origin + forward * 0.09 + Vector3.UP * height * 0.62
		var tip := origin + forward * rng.randf_range(0.18, 0.44) + Vector3.UP * height
		var green := Color(0.35, 0.56, 0.14)
		var tip_color := Color(0.63, 0.69, 0.22)
		_triangle(st, origin - side, bend - side, origin + side, Vector3.UP, green)
		_triangle(st, origin + side, bend - side, bend + side, Vector3.UP, green)
		_triangle(st, bend - side, tip, bend + side, Vector3.UP, tip_color)
		if blade < 2:
			# Alternating spikelets form a tapered head along the swept upper stem.
			var extension := forward * 0.092 + Vector3.UP * 0.23
			for grain in range(4):
				var t := grain / 4.0
				var start := tip + extension * t
				var end := start + extension * 0.46
				var wing := side * (1.45 - t * 0.50) * (1 if grain % 2 == 0 else -1)
				_triangle(st, start, end + wing, end, Vector3.UP, Color(0.87, 0.76, 0.40))
