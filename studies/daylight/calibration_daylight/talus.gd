extends RefCounted

const Terrain = preload("res://calibration_daylight/terrain.gd")
const Stone = preload("res://calibration_daylight/geological_polyhedron.gd")

# Low fracture beds on either side of the lower meadow. Extents are half-sizes in metres.
const MEADOW_STONES := [
	[Vector2(-4.7, 9.1), Vector3(1.82, .77, .93), -29.0, 13],
	[Vector2(-6.85, 7.95), Vector3(.78, .42, .67), 16.0, 21],
	[Vector2(-2.65, 9.60), Vector3(.58, .31, .48), -64.0, 8],
	[Vector2(29.4, -1.1), Vector3(1.68, 1.05, 1.10), 34.0, 25],
	[Vector2(31.65, -1.85), Vector3(.84, .39, .51), 6.0, 16],
	# The broken bed emerges on the inside bank, then disappears under turf.
	[Vector2(7.75, -2.8), Vector3(2.5, .94, 1.24), -18.0, 37],
	[Vector2(11.0, -4.76), Vector3(1.33, .59, .97), -41.0, 42],
	[Vector2(5.3, -1.32), Vector3(.60, .28, .48), 12.0, 32]
]

static func excludes_grass(x: float, z: float) -> bool:
	for placement in MEADOW_STONES:
		var site: Vector2 = placement[0]
		var extent: Vector3 = placement[1]
		var delta := Vector2(x,z) - site
		var radius := maxf(extent.x, extent.z) + .13
		if delta.length_squared() > radius*radius:
			continue
		# Undo the mesh's Godot Y rotation in the XZ plane. Leave a narrow
		# fringe outside the leading face so grass still meets the rock.
		var local := delta.rotated(deg_to_rad(placement[2]))
		var footprint := local / Vector2(extent.x+.13, extent.z+.13)
		if footprint.length_squared() <= 1.0:
			return true
	return false

static func _fallen_block(extent: Vector3, variant: int, ground_contact: Callable) -> ArrayMesh:
	var planes: Array[Plane] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = variant
	# Irregular side cuts, a long sloping bed, and a shorter broken face.
	for side in range(7):
		var angle := TAU * (side + rng.randf_range(-.11, .11)) / 7.0
		var cut := Vector3(cos(angle), rng.randf_range(.13, .48), sin(angle))
		planes.append(Plane(cut / extent, rng.randf_range(.86, 1.02)))
	var tilt := rng.randf_range(.17, .44)
	planes.append(Plane(Vector3(-tilt, 1, .17) / extent, .81))
	planes.append(Plane(Vector3(.61, 1, -.24) / extent, .93))
	planes.append(Plane(Vector3(-.07, 1, -.77) / extent, 1.02))
	planes.append(Plane(Vector3.DOWN / extent, 1.15))
	return Stone.create(planes, Color(.99, .97, .90), variant, false, ground_contact)

static func build(parent: Node3D, material: Material) -> void:
	var group := Node3D.new()
	group.name = "MeadowTalus"
	parent.add_child(group)
	for placement in MEADOW_STONES:
		var site: Vector2 = placement[0]
		var rock := MeshInstance3D.new()
		var centre := Vector3(site.x, Terrain.ground_height(site.x, site.y) - .035, site.y)
		var rotation_y := deg_to_rad(placement[2])
		var contact := func(local: Vector3) -> float:
			var world := centre + local.rotated(Vector3.UP, rotation_y)
			var clearance := world.y - Terrain.ground_height(world.x, world.z)
			var soil_depth := minf(.38, (placement[1] as Vector3).y*.48)
			return 1.0-smoothstep(.015,soil_depth,clearance)
		rock.mesh = _fallen_block(placement[1], placement[3], contact)
		rock.material_override = material
		rock.name = "FallenStone_%d" % placement[3]
		rock.rotation.y = rotation_y
		rock.position = centre
		group.add_child(rock)
		rock.create_trimesh_collision()
