extends RefCounted
## Short path herbs, sunny oat windrows and ferns rooted at a stone or bank.
## Stands have separate seeds so moving one habitat does not repaint the others.

const Forms = preload("res://calibration_daylight/meadow_herbs.gd")
const GroundMargin = preload("res://calibration_daylight/ground_margin.gd")
const Talus = preload("res://calibration_daylight/talus.gd")
const SEED := 79213
const SPECIES := ["plantain", "oats", "fern", "clover", "broad_sedge"]
# Each row gives the centre, direction of the drift in degrees and plant budget.
# The first family's x coordinate follows the actual path at an offset in metres.
const CLOVER_SITES := [Vector4(23.45, 17.95, -16, 23), Vector4(24.82, 16.55, 62, 19), Vector4(21.66, 16.68, 32, 16)]
const SITES := [
	[Vector4(3.0, 18.0, -27, 35), Vector4(-2.9, 11.3, 26, 28),
	 Vector4(2.8, -5.6, -58, 26), Vector4(-2.6, -26.4, 78, 43),
	 Vector4(2.8, -37.0, 70, 30), Vector4(3.1, -61.8, -56, 20)],
	[Vector4(22.8, 15.65, -22, 47), Vector4(16.7, 15.15, 28, 24),
	 Vector4(-6.3, 17.9, -14, 48), Vector4(34.6, 4.8, -31, 35),
	 Vector4(16.3, 11.9, -24, 29), Vector4(21.9, -.3, 53, 27),
	 Vector4(-27.5, -35.9, -22, 36), Vector4(32.4, -54.9, 31, 36)],
	[Vector4(-4.4, 10.65, -14, 23), Vector4(-7.9, 8.2, 47, 11),
	 Vector4(13.0, 17.1, 34, 24), Vector4(15.7, 16.0, 50, 10), Vector4(28.9, 0.48, -13, 29), Vector4(4.0, -.6, 31, 27),
	 Vector4(7.4, -24.7, 24, 23), Vector4(-18.5, -24.4, -33, 31),
	 Vector4(42.6, -37.0, -45, 30), Vector4(-3.50, 10.97, 38, 8)],
	CLOVER_SITES,
	GroundMargin.SEDGE_SITES
]
# Small colonies of reclining broad leaves between exposed rock and ferns.
# True world positions let these rosettes grow independently of the footpath.
const BANK_ROSETTES := [Vector4(-2.95, 11.93, 30, 18), Vector4(-5.55, 11.0, -32, 11), Vector4(30.6, .48, 27, 14)]
const SPREAD := [Vector2(1.48, 1.09), Vector2(2.25, 1.25), Vector2(1.25, .90), Vector2(.69, .43), Vector2(1.9, .78)]
const CLEARANCE := [1.5, 2.8, 2.2, 1.60, 2.15]


static func build(parent: Node3D, terrain: Script, grass_material: Material) -> Array[Vector4]:
	var openings: Array[Vector4] = []
	var counts := PackedInt32Array([0, 0, 0, 0, 0])
	var stands := Node3D.new()
	stands.name = "MeadowCommunities"
	parent.add_child(stands)
	for kind in range(SPECIES.size()):
		var models: Array[ArrayMesh] = []
		for variation in range(3):
			models.append(Forms.mesh(kind, variation, grass_material))
		var sites: Array = SITES[kind] + BANK_ROSETTES if kind == 0 else SITES[kind]
		for site_index in range(sites.size()):
			var site: Vector4 = sites[site_index]
			var centre := Vector2(site.x, site.y)
			if kind == 0 and site_index < SITES[0].size():
				centre.x += terrain.path_center(centre.y)
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + kind * 197 + site_index * 593
			var transforms: Array = [[], [], []]
			var phases: Array = [[], [], []]
			var along := Vector2.RIGHT.rotated(deg_to_rad(site.z))
			var across := along.orthogonal()
			var spread: Vector2 = SPREAD[kind] * sqrt(site.w / 36.0)
			# Three unequal knots, a narrow gap, and a few outlying plants.
			# Centre positions are also reused for thinning competing turf.
			for knot in range(3):
				var fraction: float = [-.74, .0, .83][knot]
				var pocket := centre + along * spread.x * fraction + across * spread.y * sin(knot * 2.4)
				var widths := spread * (0.74 if knot == 1 else .53)
				if kind == 1:
					widths *= .76
					pocket += along * spread.x * fraction * .48
				var budget := roundi(site.w * [0.28, .51, .21][knot])
				var accepted := 0
				var established: Array[Vector2] = []
				for plant in range(budget):
					var local := Vector2(rng.randfn(0, .74), rng.randfn(0, .69))
					if plant % 9 == 0:
						local *= 1.8
					var p := pocket + along * local.x * widths.x + across * local.y * widths.y
					if absf(p.x - terrain.path_center(p.y)) < CLEARANCE[kind] or Talus.excludes_grass(p.x, p.y):
						continue
					# The fixed cheek-to-cheek fallback camera must still see the face.
					if kind == 1 and p.x < -6.0 and p.x > -20.0 and p.y < 8.0 and p.y > .0:
						continue
					if terrain.vegetation_weight(p.x, p.y) < .34 or GroundMargin.bank_open_fraction(p.x,p.y) > .72:
						continue
					var ground: float = terrain.ground_height(p.x, p.y)
					var dx: float = terrain.ground_height(p.x + .3, p.y) - terrain.ground_height(p.x - .3, p.y)
					var dz: float = terrain.ground_height(p.x, p.y + .3) - terrain.ground_height(p.x, p.y - .3)
					if Vector2(dx, dz).length() > .32:
						continue
					# Leave gaps between recognisable crowns and culms in a knot.
					var separated := true
					var spacing: float = [.24, .26, .35, .22, .42][kind]
					for neighbour in established:
						if p.distance_squared_to(neighbour) < spacing * spacing:
							separated = false
							break
					if not separated:
						continue
					established.append(p)
					var stable_up := Vector3(-dx, .6, -dz).normalized()
					var yaw := rng.randf() * TAU
					if kind == 1:
						# The panicles nod with a shared breeze, with occasional cross-stems.
						yaw = -.52 + .28 * sin(p.y * .53) + rng.randfn(0, .64)
					if kind == Forms.SEDGE:
						yaw = deg_to_rad(site.z) + rng.randfn(.2, .57)
					var basis := Basis(Quaternion(Vector3.UP, stable_up)).slerp(Basis.IDENTITY, .7) * Basis(Vector3.UP, yaw)
					var size := rng.randf_range(.79, 1.20)
					var variant := rng.randi_range(0, models.size() - 1)
					var scale := Vector3(size, size * rng.randf_range(.87, 1.18), size)
					if kind == Forms.OAT:
						scale.y *= .84
					elif kind == Forms.SEDGE:
						# Wide central crowns splay into shorter outriders.
						scale *= lerpf(1.25, .70, clampf(local.length() * .60, 0, 1))
					transforms[variant].append(Transform3D(basis.scaled_local(scale), Vector3(p.x, ground - .015, p.y)))
					phases[variant].append(rng.randf())
					accepted += 1
				if accepted > 2:
					var world_width := along.abs() * widths.x + across.abs() * widths.y + Vector2(.28, .28)
					openings.append(Vector4(pocket.x, pocket.y, world_width.x, world_width.y))
			for variant in range(models.size()):
				var instances: Array = transforms[variant]
				if instances.is_empty():
					continue
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.use_custom_data = true
				multi.use_colors = true
				multi.mesh = models[variant]
				multi.instance_count = instances.size()
				for i in range(instances.size()):
					multi.set_instance_transform(i, instances[i])
					multi.set_instance_color(i, Color.WHITE)
					multi.set_instance_custom_data(i, Color([.16, 1.0, .49, .15, .78][kind], phases[variant][i], 1.0 if kind == Forms.SEDGE else 0.0, 0))
				var batch := MultiMeshInstance3D.new()
				batch.name = "%s_%02d_%d" % [SPECIES[kind], site_index, variant]
				batch.multimesh = multi
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				stands.add_child(batch)
				counts[kind] += instances.size()
	parent.set_meta("meadow_herb_species", SPECIES)
	parent.set_meta("meadow_herb_counts", Array(counts))
	return openings


static func clears_base(x: float, z: float, species: int, dice: float, openings: Array[Vector4]) -> bool:
	# The existing seed stream stays intact; clearing operates on an already
	# authored tuft. Tall old blades give way to the broad replacement crowns.
	var exposed := GroundMargin.bank_open_fraction(x, z)
	if dice < exposed * (.48 if species == 0 else .95):
		return true
	for opening in openings:
		if absf(x - opening.x) >= opening.z or absf(z - opening.y) >= opening.w:
			continue
		var d := Vector2((x - opening.x) / opening.z, (z - opening.y) / opening.w).length()
		var removal := (1.0 - smoothstep(.36, 1.0, d)) * (.57 if species == 0 else .94)
		if dice < removal:
			return true
	return false


static func clover_meadow_height(x: float, z: float) -> float:
	# Taller grasses give way locally to low trifoliate patches. The openings
	# are eccentric with a broken outer edge, and retain individual short tufts.
	if x < 20.2 or x > 26.5 or z < 15.1 or z > 19.4:
		return 1.0
	var height := 1.0
	for site: Vector4 in CLOVER_SITES:
		var delta := Vector2(x - site.x - .10, z - site.y - .19)
		var turn := delta.rotated(-deg_to_rad(site.z))
		var radius := Vector2(turn.x / 1.20, turn.y / .84).length()
		radius += .105 * sin(x * 4.27 + z * 2.81)
		height = minf(height, lerpf(.135, 1.0, smoothstep(.42, 1.28, radius)))
	return height
