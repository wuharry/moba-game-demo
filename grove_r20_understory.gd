extends RefCounted

const MEADOW := preload("res://grove_r20_meadow.gdshader")


static func build(host: Node3D) -> void:
	var local := RandomNumberGenerator.new()
	local.seed = 2026112520
	var shape_noise := FastNoiseLite.new()
	shape_noise.seed = 4020
	shape_noise.frequency = .27
	var material := ShaderMaterial.new()
	material.shader = MEADOW
	var meshes: Array[ArrayMesh] = [_clump(0), _clump(1), _clump(2)]
	# Asymmetric bank and tree-foot beds, with daylight and bare-ground gaps.
	var beds := [
		Vector4(-10.0,6.5,4.2,3.0), Vector4(-8.0,1.2,3.1,4.1),
		Vector4(-9.3,-6.1,3.0,4.3), Vector4(-7.5,-13.7,4.1,2.3),
		Vector4(.2,-17.4,4.9,2.5), Vector4(8.1,-14.5,4.0,2.6),
		Vector4(11.0,-6.1,2.5,4.7), Vector4(11.3,2.8,3.2,3.8),
		Vector4(7.6,9.1,4.3,2.2), Vector4(-1.2,7.6,2.4,2.5),
		Vector4(-8.9,12.8,4.0,2.4), Vector4(2.4,14.0,3.0,2.3),
		Vector4(-7.1,5.2,1.7,2.9), Vector4(-8.1,-3.7,1.9,2.6),
		Vector4(9.1,5.9,2.6,2.7), Vector4(11.1,-10.8,2.3,3.0),
	]
	var total := 0
	var tall_total := 0
	for cell_z in range(5):
		for cell_x in range(5):
			var batches: Array = [[],[],[]]
			var pigments: Array = [[],[],[]]
			for attempt in range(2520):
				var p := Vector2(-17.5+cell_x*7.0+local.randf()*7.0,-20.0+cell_z*8.0+local.randf()*8.0)
				var road: float = host.call("_route_distance",p)
				var edge_wobble := shape_noise.get_noise_2d(p.x*1.7,p.y*1.7)
				if road < 2.05+edge_wobble*.38:
					continue
				var pond: float = host.call("_pond_radius",p)
				var y: float = host.call("_height",p.x,p.y)
				var raised_cove := p.x > 7.8 and p.y > -.5 and y > .05 and pond > .84
				if pond < 1.015 and not raised_cove:
					continue
				if y < -.48 or y > 3.7:
					continue
				var dx: float = host.call("_height",p.x+.22,p.y)
				var dz: float = host.call("_height",p.x,p.y+.22)
				if Vector2(dx-y,dz-y).length()/.22 > .68:
					continue
				var mask := 0.0
				for bed: Vector4 in beds:
					var ellipse := ((p-Vector2(bed.x,bed.y))/Vector2(bed.z,bed.w)).length()
					mask = maxf(mask,1.0-smoothstep(.35,1.15,ellipse))
				var wobble := shape_noise.get_noise_2d(p.x,p.y)
				var density := clampf(mask*.91+wobble*.49-.11,0.0,.93)
				# Three deliberate damp cores, separated by low/open pockets.
				var core := 0.0
				for bed: Vector4 in [Vector4(-8.1,7.4,1.6,2.1),Vector4(-8.5,-7.2,1.7,2.4),Vector4(10.0,5.7,1.8,2.2)]:
					var dist := ((p-Vector2(bed.x,bed.y))/Vector2(bed.z,bed.w)).length()
					core = maxf(core,1.0-smoothstep(.2,1.05,dist+wobble*.19))
				var opening := 0.0
				for gap: Vector4 in [Vector4(-8.2,1.6,1.1,1.7),Vector4(-7.4,11.1,1.3,1.0),Vector4(10.8,-.7,1.4,1.8)]:
					var dist := ((p-Vector2(gap.x,gap.y))/Vector2(gap.z,gap.w)).length()
					opening = maxf(opening,1.0-smoothstep(.35,1.1,dist))
				density *= (1.0-opening*.88)
				if local.randf() > density:
					continue
				var variant := 0
				if core > .25:
					variant = 1 if local.randf() < .3+core*.6 else 0
				if mask > .48 and local.randf() < .07+core*.16:
					variant = 2
				var height := local.randf_range(.78,1.17)
				height *= lerpf(.75,1.12,core)
				height *= lerpf(.55,1.0,smoothstep(2.05,3.2,road))
				var breadth := local.randf_range(.78,1.27)
				var basis := Basis(Vector3.UP,local.randf()*TAU).scaled(Vector3(breadth,height,breadth))
				batches[variant].append(Transform3D(basis,Vector3(p.x,y-.025,p.y)))
				pigments[variant].append(Color(core,local.randf(),0,1))
				if variant == 1:
					tall_total += 1
			for variant in range(3):
				var instances: Array = batches[variant]
				if instances.is_empty():
					continue
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.use_custom_data = true
				multi.mesh = meshes[variant]
				multi.instance_count = instances.size()
				for index in instances.size():
					multi.set_instance_transform(index,instances[index])
					multi.set_instance_custom_data(index,pigments[variant][index])
				var node := MultiMeshInstance3D.new()
				node.name = "R20_Understory_%d_%d_%d" % [cell_x,cell_z,variant]
				node.multimesh = multi
				node.material_override = material
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				host.add_child(node)
				total += instances.size()
	print("R20 UNDERSTORY | %d original clumps | shared meadow roots | route clear" % total)
	print("R20 UNDERSTORY CORES | %d tall clumps in 3 localized banks" % tall_total)


static func _clump(variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var local := RandomNumberGenerator.new()
	local.seed = 8210+variant*533
	var amount := 5 if variant < 2 else 6
	for blade in amount:
		var angle := float(blade)*2.399963+local.randf_range(-.3,.3)
		var outward := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-sin(angle),0,cos(angle))
		var height := local.randf_range(.16,.29) if variant == 0 else local.randf_range(.37,.53)
		if variant == 2:
			height = local.randf_range(.25,.42)
		var spread := local.randf_range(.12,.23) if variant < 2 else local.randf_range(.20,.34)
		var width := local.randf_range(.027,.044) if variant < 2 else local.randf_range(.062,.105)
		var root := outward*local.randf_range(.01,.065)
		for segment in range(4):
			var t0 := segment/4.0
			var t1 := (segment+1)/4.0
			var p0 := root+outward*(t0*t0*spread)+Vector3.UP*(height*sin(t0*1.38))
			var p1 := root+outward*(t1*t1*spread)+Vector3.UP*(height*sin(t1*1.38))
			var w0 := width*(.42+.58*sin(t0*PI))*(1.0-t0*.8)
			var w1 := width*(.42+.58*sin(t1*PI))*(1.0-t1*.8)
			if segment == 3:
				w1 = .001
			var verts := [p0-side*w0,p1-side*w1,p1+side*w1,p0-side*w0,p1+side*w1,p0+side*w0]
			var uvs := [Vector2(0,t0),Vector2(0,t1),Vector2(1,t1),Vector2(0,t0),Vector2(1,t1),Vector2(1,t0)]
			for k in range(6):
				st.set_normal((Vector3.UP*.94+outward*.18).normalized())
				st.set_color(Color(float(variant)*.3+.1,1,1,1))
				st.set_uv(uvs[k])
				st.add_vertex(verts[k])
	st.index()
	return st.commit()
