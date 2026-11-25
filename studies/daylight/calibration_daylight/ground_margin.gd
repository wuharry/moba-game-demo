extends RefCounted

const Terrain = preload("res://calibration_daylight/terrain.gd")
const Talus = preload("res://calibration_daylight/talus.gd")
const CELL := .75
const MAX_DISTANCE := 4.5
const FORWARD := [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const BACKWARD := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)]

# R/G encode distance and drop from the nearest exposed bed. B/A encode terrain normal X/Z.
# A raised rock can favour pooled earth at its foot while its crown stays grassy.
static func build_image() -> Image:
	var width := ceili((Terrain.X_MAX - Terrain.X_MIN) / CELL)
	var height := ceili((Terrain.Z_MAX - Terrain.Z_MIN) / CELL)
	var size := Vector2i(width, height)
	var cell_size := Vector2((Terrain.X_MAX - Terrain.X_MIN) / width, (Terrain.Z_MAX - Terrain.Z_MIN) / height)
	var nearest := PackedInt32Array()
	var elevation := PackedFloat32Array()
	var bounds_min := Vector2(Terrain.X_MIN, Terrain.Z_MIN)
	nearest.resize(width * height)
	nearest.fill(-1)
	elevation.resize(width * height)
	for row in height:
		for column in width:
			var i := row * width + column
			var p := bounds_min + (Vector2(column, row) + Vector2(.5, .5)) * cell_size
			var surface := Terrain._sample(p.x, p.y)
			elevation[i] = surface.x
			if surface.z < .40 or Talus.excludes_grass(p.x, p.y):
				nearest[i] = i

	_propagate(size, nearest, false)
	_propagate(size, nearest, true)
	var bytes := PackedByteArray()
	bytes.resize(width * height * 4)
	for row in height:
		for column in width:
			var i := row * width + column
			var source := nearest[i]
			var distance_m := MAX_DISTANCE
			var drop := 0.0
			if source >= 0:
				var delta := Vector2(column - source % width, row - floori(float(source) / width))
				distance_m = (delta * cell_size).length()
				drop = elevation[source] - elevation[i]
			bytes[4 * i] = roundi(255.0 * clampf(distance_m / MAX_DISTANCE, 0.0, 1.0))
			bytes[4 * i + 1] = roundi(255.0 * smoothstep(-.35, .95, drop))
			var previous_x := maxi(column - 1, 0)
			var next_x := mini(column + 1, width - 1)
			var previous_z := maxi(row - 1, 0)
			var next_z := mini(row + 1, height - 1)
			var slope_x := (elevation[row * width + next_x] - elevation[row * width + previous_x]) / ((next_x - previous_x) * cell_size.x)
			var slope_z := (elevation[next_z * width + column] - elevation[previous_z * width + column]) / ((next_z - previous_z) * cell_size.y)
			var up := Vector3(-slope_x, 1.0, -slope_z).normalized()
			bytes[4 * i + 2] = roundi((up.x * .5 + .5) * 255.0)
			bytes[4 * i + 3] = roundi((up.z * .5 + .5) * 255.0)
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)


static func _propagate(size: Vector2i, nearest: PackedInt32Array, reverse: bool) -> void:
	var neighbors := BACKWARD if reverse else FORWARD
	var search_radius_sq := ceili(MAX_DISTANCE / CELL + 1.0) ** 2
	for row in size.y:
		var y := size.y - 1 - row if reverse else row
		for column in size.x:
			var x := size.x - 1 - column if reverse else column
			var i := y * size.x + x
			var closest := nearest[i]
			if closest == i:
				continue
			var best := search_radius_sq
			if closest >= 0:
				var dx := x - closest % size.x
				var dy := y - floori(float(closest) / size.x)
				best = dx * dx + dy * dy
			for step: Vector2i in neighbors:
				var candidate_cell := Vector2i(x, y) + step
				if candidate_cell.x < 0 or candidate_cell.x >= size.x or candidate_cell.y < 0 or candidate_cell.y >= size.y:
					continue
				var candidate := nearest[candidate_cell.y * size.x + candidate_cell.x]
				if candidate < 0 or candidate == closest:
					continue
				var dx := x - candidate % size.x
				var dy := y - floori(float(candidate) / size.x)
				var d2 := dx * dx + dy * dy
				if d2 < best:
					best = d2
					closest = candidate
			nearest[i] = closest


# Grazing and shallow mineral exposure share the same irregular shelves.
# Each entry stores centre x/z, half-width and half-depth in metres.
const CLEARINGS := [Vector4(19.1, 12.6, 5.9, 2.3), Vector4(6.7, 20.7, 3.7, 1.2),
	Vector4(28.4, 1.7, 3.3, 1.6), Vector4(-10.3, 12.0, 4.4, 1.5),
	Vector4(15.2, -17.2, 3.5, 1.5), Vector4(34.7, -32.9, 6.1, 2.1),
	Vector4(23.55, 17.15, 2.3, .78), Vector4(21.2, 5.6, 3.8, 1.15),
	Vector4(24.3, 8.9, 3.1, 1.79), Vector4(2.1, 8.0, 3.25, 1.19),
	Vector4(17.1, -.2, 3.0, 1.35)]
const SEDGE_SITES := [Vector4(20.4, 15.5, -24, 36), Vector4(23.5, 15.1, -18, 26),
	Vector4(8.3, 18.4, -32, 29), Vector4(2.1, 9.0, -31, 22),
	Vector4(30.3, 4.0, -45, 27), Vector4(-13.3, 10.4, 17, 15),
	Vector4(22.0, -18.7, 32, 25), Vector4(32.1, -35.0, -32, 20),
	Vector4(-1.6, 7.2, -23, 48), Vector4(4.7, 5.0, -32, 24),
	Vector4(23.9, 6.0, 14, 37), Vector4(28.0, 5.1, 32, 19),
	Vector4(19.0, 3.9, -32, 28), Vector4(19.8, 8.5, 29, 34),
	Vector4(25.5, 6.9, -23, 29), Vector4(5.3, 8.1, 31, 29),
	Vector4(17.6, 8.5, 52, 31), Vector4(23.2, 12.3, -16, 31), Vector4(21.6, 11.0, -40, 20),
	Vector4(26.5, 13.35, -28, 35), Vector4(28.1, 15.7, 31, 21)]


static func _sedge_cover_at(local: Vector2, site: Vector4) -> float:
	var turn := local.rotated(-deg_to_rad(site.z))
	var radius := Vector2(turn.x / 3.55, (turn.y + .20 * sin(turn.x * 1.41)) / 1.72)
	return 1.0 - smoothstep(.16,1.75,radius.length_squared())


static func _worn_tongues(local: Vector2, site: Vector4) -> float:
	var u := local.x / site.z
	var v := (local.y + .38 * local.x) / site.w
	# Broad compact pockets, with grass left between them.
	var yaw := .52 * sin(site.x * .72 + site.y * .46)
	var bend := .12 * sin(4.7 * u + site.y)
	var first := Vector2((u+.25)/.43, (v+.15+yaw*u+bend)/.64)
	var second := Vector2((u-.57)/.25, (v-.43-yaw*u)/.36)
	var pocket := 1.0 - smoothstep(.25,1.0,first.length_squared())
	var satellite := 1.0 - smoothstep(.19,1.0,second.length_squared())
	return maxf(pocket, satellite * .66)


static func bank_open_fraction(x: float, z: float) -> float:
	var exposed := 0.0
	for site: Vector4 in CLEARINGS:
		var local := Vector2(x-site.x, z-site.y)
		if absf(local.x) > site.z*1.1 or absf(local.y) > site.w+site.z*.48:
			continue
		exposed = maxf(exposed,_worn_tongues(local,site))
	return exposed


static func _pasture_image(bounds: Vector4) -> Image:
	# Painted tongue tips are narrower than the terrain-normal grid. Rasterise
	# only the affected regions on a 0.20 m grid to preserve the grass wedges.
	var size := Vector2i(ceili(bounds.z/.20),ceili(bounds.w/.20))
	var step := Vector2(bounds.z/size.x,bounds.w/size.y)
	var min_xz := Vector2(bounds.x,bounds.y)
	var pixels := PackedByteArray()
	pixels.resize(size.x*size.y*2)
	for channel in 2:
		var sites: Array = CLEARINGS if channel == 0 else SEDGE_SITES
		for site: Vector4 in sites:
			var extent := Vector2(site.z*1.10,site.w+site.z*.48) if channel == 0 else Vector2(5.4,5.4)
			var centre := Vector2(site.x,site.y)
			var start := Vector2i(((centre-extent-min_xz)/step).floor()).clamp(Vector2i.ZERO,size)
			var finish := Vector2i(((centre+extent-min_xz)/step).ceil()).clamp(Vector2i.ZERO,size)
			for row in range(start.y,finish.y):
				for column in range(start.x,finish.x):
					var local := min_xz+(Vector2(column,row)+Vector2(.5,.5))*step-centre
					var mask := _worn_tongues(local,site) if channel == 0 else _sedge_cover_at(local,site)
					var offset := (row*size.x+column)*2+channel
					pixels[offset] = maxi(pixels[offset],roundi(mask*255))
	return Image.create_from_data(size.x,size.y,false,Image.FORMAT_RG8,pixels)


static func apply(materials: Array) -> void:
	var image := build_image()
	var field := ImageTexture.create_from_image(image)
	var bounds := Vector4(Terrain.X_MIN, Terrain.Z_MIN, Terrain.X_MAX - Terrain.X_MIN, Terrain.Z_MAX - Terrain.Z_MIN)
	var openings := ImageTexture.create_from_image(_pasture_image(bounds))
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("sward_opening", openings)
		material.set_shader_parameter("ground_edge_field", field)
		material.set_shader_parameter("ground_edge_bounds", bounds)
