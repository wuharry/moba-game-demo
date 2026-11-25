extends Node3D
## An original field scout to locate the physical player at game-camera scale.

func _part(mesh: PrimitiveMesh, tint: Color, at: Vector3, stretch := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = .91
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.scale = stretch
	add_child(part)
	return part

func _taper(bottom: float, top: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = height
	m.radial_segments = 10
	return m

func _ready() -> void:
	var boots := Color("#40353a")
	var cape := Color("#9e4534")
	var linen := Color("#ded6ad")
	for side in [-1.,1.]:
		_part(_taper(.115,.13,.66), boots, Vector3(side*.14,.34,side*.07))
	_part(_taper(.37,.26,.68), cape, Vector3(0,.88,0), Vector3(1,.99,.76))
	_part(_taper(.40,.20,.33), linen, Vector3(0,1.28,0), Vector3(1,.97,.81))
	_part(_taper(.18,.19,.31), Color("#bb865f"), Vector3(0,1.51,-.035))
	_part(_taper(.40,.33,.065), boots, Vector3(0,1.65,-.02))
	_part(_taper(.245,.104,.19), Color("#ba834d"), Vector3(0,1.755,-.02))
	var bedroll := _part(_taper(.12,.12,.50), Color("#56686a"), Vector3(0,1.14,.24))
	bedroll.rotation.z = PI*.47
