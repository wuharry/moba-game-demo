extends RefCounted

const Stone = preload("res://calibration_daylight/geological_polyhedron.gd")

# Centre on the slope, half-sizes in metres, long-axis yaw and stone profile.
# The west pocket trails from two thick broken beds into smaller rubble
# where the slope meets the grass. The second pocket stays tucked in shadow.
const POCKETS := [
	[
		[Vector2(-14.30,-2.85), Vector3(1.83,1.07,1.03), -36.0, 118],
		[Vector2(-15.56,-.80), Vector3(1.37,.84,.86), -54.0, 127],
		[Vector2(-13.05,-.96), Vector3(.80,.48,.54), -24.0, 122],
		[Vector2(-13.79,.15), Vector3(.46,.27,.41), -29.0, 133],
		[Vector2(-14.67,1.09), Vector3(.33,.20,.27), 8.0, 138]
	],
	[
		[Vector2(-11.53,-5.44), Vector3(.94,.73,.60), -24.0, 145],
		[Vector2(-10.26,-5.54), Vector3(.53,.46,.46), 27.0, 152],
		[Vector2(-9.47,-6.48), Vector3(.47,.32,.34), -43.0, 171],
		[Vector2(-9.72,-4.69), Vector3(.31,.23,.27), 9.0, 163],
		[Vector2(-10.58,-4.75), Vector3(.24,.17,.19), -64.0, 166]
	],
	[
		[Vector2(-19.85,10.10), Vector3(2.0,.92,1.25), -31.0, 176],
		[Vector2(-18.45,11.85), Vector3(1.10,.76,.73), -52.0, 182],
		[Vector2(-19.45,12.55), Vector3(.52,.38,.43), -19.0, 193]
	]
]


static func build(parent: Node3D, terrain: Script, rock_material: Material) -> void:
	var group := Node3D.new()
	group.name = "MidCliffTalus"
	parent.add_child(group)
	for pocket: Array in POCKETS:
		for item: Array in pocket:
			var site: Vector2 = item[0]
			var extent: Vector3 = item[1]
			if absf(site.x - terrain.path_center(site.y)) < 4.5 + extent.length():
				continue

			var basis := _resting_basis(terrain, site, deg_to_rad(item[2]))
			var height: float = terrain.ground_height(site.x, site.y)
			var centre := Vector3(site.x, height - .27*extent.y, site.y)
			var rock := MeshInstance3D.new()
			rock.name = "CliffFragment_%d" % item[3]
			rock.material_override = rock_material
			var contact := func(local: Vector3) -> float:
				var world := centre + basis * local
				var clearance: float = world.y - terrain.ground_height(world.x, world.z)
				return 1.0-smoothstep(.015, extent.y*.65, clearance)
			rock.mesh = _fragment(extent, item[3], contact)
			rock.transform = Transform3D(basis, centre)
			group.add_child(rock)
			if extent.y >= .32:
				rock.create_trimesh_collision()


static func _resting_basis(terrain: Script, site: Vector2, yaw: float) -> Basis:
	var dx: float = (terrain.ground_height(site.x+.4, site.y) - terrain.ground_height(site.x-.4, site.y)) / .8
	var dz: float = (terrain.ground_height(site.x, site.y+.4) - terrain.ground_height(site.x, site.y-.4)) / .8
	var lean := Vector2(dx,dz).limit_length(.56)
	var up := Vector3(-lean.x, 1.0, -lean.y).normalized()
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
	right = (right - right.dot(up)*up).normalized()
	return Basis(right, up, right.cross(up))


static func _fragment(extent: Vector3, profile: int, contact: Callable) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = profile
	# Two broad bedding faces and one shallow shoulder chip. The side planes
	# have unequal angles so neighbouring fragments never repeat a silhouette.
	var planes: Array[Plane] = []
	for side in 6:
		var angle := TAU*(side+rng.randf_range(-.15,.15))/6.0
		var wall := Vector3(cos(angle), rng.randf_range(.09,.33), sin(angle))
		planes.append(Plane(wall/extent,rng.randf_range(.88,1.03)))
	var fall := rng.randf_range(-.12,.31)
	planes.append(Plane(Vector3(-fall,1.0,.26)/extent,.81))
	planes.append(Plane(Vector3(.69,1.0,-.20)/extent,.98))
	planes.append(Plane(Vector3(-.31,.81,-.71)/extent,.94))
	planes.append(Plane(Vector3.DOWN/extent,1.32))
	return Stone.create(planes, Color(.94,.939,.923), profile, false, contact)
