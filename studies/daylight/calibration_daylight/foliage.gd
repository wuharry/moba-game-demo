extends RefCounted
## Original meshes for the daylight reference study. No billboard background.
## Leaf cards use the entire supplied RGBA texture, UV 0..1. Vertex colours
## are mild multipliers; foliage normals describe the volume of a leaf clump.

const SEED_VALUE := 71903
const MeadowCommunities = preload("res://calibration_daylight/meadow_communities.gd")
const Talus = preload("res://calibration_daylight/talus.gd")
const WIND_SHAPED_COPPICE := 3
const OPEN_FORK_COPPICE := 4


static func build(parent: Node3D, terrain_script: Script, leaf_mat: Material, grass_mat: Material, bark_mat: Material) -> void:
	var root := Node3D.new()
	root.name = "DaylightVegetation"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VALUE
	var variants: Array = []
	for index in range(5):
		variants.append(_tree_meshes(SEED_VALUE + index * 83, leaf_mat, bark_mat))
	# Clusters leave the central grassy passage open and connect to terrace tops.
	var locations := [
		Vector3(-29, 1.32, -13), Vector3(-24, 0.96, -17), Vector3(-27, 1.63, -23), Vector3(-18, 1.48, -26), Vector3(-10, 1.43, -30),
		Vector3(24, 1.94, -29), Vector3(40, 1.20, -36), Vector3(43, 1.52, -20),
		Vector3(-48, 1.18, -30), Vector3(-42, 0.91, -39),
		Vector3(-44, 1.29, -56), Vector3(-34, 0.81, -63), Vector3(-12, 1.07, -59),
		Vector3(25, 1.24, -63), Vector3(38, 0.82, -69), Vector3(50, 1.04, -64),
		Vector3(-54, 1.16, -91), Vector3(-22, 0.88, -86), Vector3(-12, 1.13, -96),
		Vector3(20, 1.04, -94), Vector3(50, 1.27, -90)
	]
	for index in range(locations.size()):
		var spec: Vector3 = locations[index]
		var site := _tree_site(Vector2(spec.x, spec.z), terrain_script)
		if not site.is_finite():
			continue
		var tree := Node3D.new()
		tree.name = "Broadleaf_%02d" % index
		root.add_child(tree)
		tree.position = Vector3(site.x, terrain_script.ground_height(site.x, site.y), site.y)
		tree.rotation.y = rng.randf_range(-PI, PI)
		tree.scale = Vector3(rng.randf_range(0.94, 1.17), rng.randf_range(0.90, 1.14), rng.randf_range(0.92, 1.10)) * spec.y
		var model: Array = variants[index % variants.size()]
		for mesh_index in range(2):
			var instance := MeshInstance3D.new()
			instance.name = "LeafClumps" if mesh_index == 0 else "TrunkAndBranches"
			instance.mesh = model[mesh_index]
			tree.add_child(instance)
		var body := StaticBody3D.new()
		body.name = "TrunkCollision"
		tree.add_child(body)
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.24
		capsule.height = 3.2
		collider.shape = capsule
		collider.position.y = 1.6
		body.add_child(collider)
	_build_pine_belts(root, terrain_script, leaf_mat, bark_mat, rng)
	_build_bushes(root, terrain_script, leaf_mat, rng)
	var herb_openings := MeadowCommunities.build(root, terrain_script, grass_mat)
	_build_grass(root, terrain_script, grass_mat, herb_openings)
	preload("res://calibration_daylight/meadow_flowers.gd").build(root, terrain_script, leaf_mat, rng)
	_build_coppices(root, terrain_script, leaf_mat, bark_mat)
	_build_gully_wood(root, terrain_script, leaf_mat, bark_mat)
	_build_bank_plants(root, terrain_script, leaf_mat)
	_build_foreground_thicket(root, terrain_script, leaf_mat)


static func _tree_site(anchor: Vector2, terrain: Script) -> Vector2:
	# A short deterministic search lets the same cluster follow alternate terrain.
	for offset in [Vector2.ZERO, Vector2(-2, -1.5), Vector2(2, 2), Vector2(-3, 2), Vector2(3, -2), Vector2(0, -4.5)]:
		var p: Vector2 = anchor + offset
		if absf(p.x - terrain.path_center(p.y)) < 3.7:
			continue
		if terrain.vegetation_weight(p.x, p.y) > 0.24 and _slope(terrain, p.x, p.y) < 0.53:
			return p
	return Vector2.INF


static func _build_coppices(parent: Node3D, terrain: Script, leaves: Material, bark: Material) -> void:
	# Irregular copses on the two lips of the bend. A short approach reveals
	# the second opening, even though the crowns overlap from the main vista.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VALUE + 7811
	var models: Array[ArrayMesh] = []
	for k in range(3):
		models.append(_coppice_mesh(k, rng, leaves, bark))
	var crown_rng := RandomNumberGenerator.new()
	crown_rng.seed = SEED_VALUE + 1927
	models.append(_coppice_mesh(WIND_SHAPED_COPPICE, crown_rng, leaves, bark))
	models.append(_coppice_mesh(OPEN_FORK_COPPICE, crown_rng, leaves, bark))
	# x, z, scale, orientation. Keep the low fringe and opposing tree roots
	# on their own terrace even as the slope and ground height change.
	var groups := [
		# Crown overlaps across the lower scarps, leaving irregular windows of pale stone.
		Vector4(-22.0,-20.0,.77,1.7), Vector4(-19.8,-27.5,1.14,-.9),
		Vector4(-1.5,4.2,1.22,.52), Vector4(1.1,2.6,.87,.2),
		Vector4(-2.8,3.2,.62,1.6), Vector4(-4.1,-5.6,1.20,-.72),
		Vector4(-2.9,-2.75,.84,.66), Vector4(2.6,-2.0,1.23,-.32),
		Vector4(4.9,-1.2,.81,1.78), Vector4(3.7,-6.6,.72,.1),
		Vector4(6.7,-7.15,1.18,2.6), Vector4(10.1,-7.8,.85,1.22),
		Vector4(14.0,-19.7,1.30,-.43), Vector4(12.3,-22.1,1.78,.83),
		Vector4(13.2,-21.2,.86,.5),
		Vector4(9.5,-23.7,.65,-2.12), Vector4(32,-23.6,.83,2.2),
		Vector4(35,-25.2,1.09,-.4), Vector4(25.05,9.7,.87,-.71)]
	var index := 0
	for group: Vector4 in groups:
		var site := _tree_site(Vector2(group.x,group.y),terrain)
		if not site.is_finite() or absf(site.x-terrain.path_center(site.y)) < 5.1:
			continue
		var h: float = terrain.ground_height(site.x,site.y)
		var supported := true
		for offset: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var support_radius := group.z * (.59 if group.z >= 1.30 else .75)
			var p := site + offset * support_radius
			if terrain.vegetation_weight(p.x,p.y)<.13 or absf(terrain.ground_height(p.x,p.y)-h)>.45:
				supported=false
				break
		if not supported: continue
		var instance := MeshInstance3D.new()
		var profile := index%3
		if group.z > 1.5: profile=2
		elif group.z>1.3: profile=0
		if is_equal_approx(group.x, -4.1): profile=WIND_SHAPED_COPPICE
		if is_equal_approx(group.x, -2.9) or is_equal_approx(group.x, 25.05): profile=OPEN_FORK_COPPICE
		instance.mesh=models[profile]
		instance.name="BendCoppice_%02d" % index
		instance.position=Vector3(site.x,h-.05,site.y)
		instance.scale=Vector3.ONE*group.z
		instance.rotation.y=group.w
		parent.add_child(instance)
		index+=1
	parent.set_meta("bend_coppice_count",index)


static func _coppice_mesh(profile: int, rng: RandomNumberGenerator, material: Material, bark: Material) -> ArrayMesh:
	var green := SurfaceTool.new()
	green.begin(Mesh.PRIMITIVE_TRIANGLES)
	green.set_material(material)
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_material(bark)
	# Coppiced stems share a low stool. The dominant stem rises through the
	# canopy; two outward fans and one trailing spray keep the outline open.
	var tops := [Vector3(-.34,3.0,.38),Vector3(1.5,2.05,-.35),Vector3(-1.52,1.42,.24),Vector3(.77,.92,.88)]
	var masses := [Vector3(1.38,1.10,1.08),Vector3(1.39,.83,1.11),Vector3(1.03,.73,.92),Vector3(1.03,.55,.87)]
	var height_bias := [.96,.58,1.13,1.0,1.0]
	var reach_bias := [1.08,1.44,.88,1.0,1.0]
	if profile == WIND_SHAPED_COPPICE:
		# One long windward bough and a shallow split give the canopy a broad,
		# uneven outline from above. Leave the outer fork visible from the path.
		tops.assign([Vector3(-.52,2.9,.36),Vector3(2.18,2.13,-.42),
			Vector3(-1.98,2.25,-.23),Vector3(.9,1.63,1.37)])
		masses.assign([Vector3(1.58,.67,.98),Vector3(1.49,.60,.92),
			Vector3(1.35,.60,.96),Vector3(.88,.48,.67)])
	elif profile == OPEN_FORK_COPPICE:
		# Exposed stems and gaps between the three small crowns keep this
		# sapling recognizable beside the full, low crown of a mature tree.
		tops.assign([Vector3(-.39,3.22,-.10),Vector3(1.19,2.12,-.53),
			Vector3(-1.35,1.83,.85)])
		masses.assign([Vector3(.68,.52,.60),Vector3(.63,.45,.60),Vector3(.57,.40,.55)])
	for i in range(tops.size()):
		var end: Vector3=tops[i]
		end.y*=height_bias[profile]
		end.x*=reach_bias[profile]
		end+=Vector3(rng.randf_range(-.22,.22),rng.randf_range(-.15,.20),rng.randf_range(-.25,.25))
		var direction:=Vector3(end.x,0,end.z).normalized()
		var start:=direction*.10 - Vector3.UP*.06
		var stem:=start.lerp(end,.56)-direction*.20
		_tube(wood,PackedVector3Array([start,stem,end]),PackedFloat32Array([.12,.074,.014]),6)
		var mass: Vector3=masses[i]
		mass.x*=reach_bias[profile]
		mass.y*=height_bias[profile]
		_leaf_clump(green,end,mass,rng,14, .88 if i==3 else 1.06,direction)
		if profile != OPEN_FORK_COPPICE or i == 0:
			var spray:=end+direction*mass.x*.71+Vector3.UP*(.43 if i==0 else -.04)
			_leaf_clump(green,spray,mass*Vector3(.64,.65,.62),rng,9,1.14,direction)
		if profile < WIND_SHAPED_COPPICE and (i==1 or i==2):
			# A shorter lower fork fills part of the bright gap under this branch;
			# the opposite sides keep distinct silhouettes when seen along the path.
			var low:=end*.59+direction*.44+Vector3(.13,-.12,.25)
			_leaf_clump(green,low,mass*Vector3(.82,.81,.74),rng,7,.84,direction)
	var result := green.commit()
	wood.commit(result)
	return result



# A dogwood thicket at a limestone cleft has a shady, continuous lower leaf
# mass and several uneven sunward fans. The leaning stems remain visible
# through the space between crowns from either side of the bank.
static func _gully_lobe(st: SurfaceTool, end: Vector3, size: Vector3, angle: float, tint: Color, rng: RandomNumberGenerator, core_scale: float = 1.0) -> void:
	var along := Vector3(cos(angle), 0, sin(angle))
	var across := Vector3(-along.z, 0, along.x)
	var phase := rng.randf_range(0.0, TAU)
	var vertices := PackedVector3Array()
	var local_normals := PackedVector3Array()
	var colors := PackedColorArray()
	var slices := 13
	for ring in range(5):
		var y: float = [-.91,-.62,.03,.67,.91][ring]
		var span: float = [.23,.77,1.,.86,.48][ring]
		for side in range(slices):
			var a := TAU*side/slices + phase + sin(float(ring))*0.09
			var d := along*cos(a) + across*sin(a)
			var step := 1.0 + .16*sin(3.0*a+phase) + .105*cos(5.0*a-.8*ring)
			var h := size.y*(y + .17*sin(3.0*a+phase)*span + .13*cos(a))
			var p := along*(cos(a)*size.x*step*span + size.x*(.26+.15*y)) + across*sin(a)*size.z*step*span
			vertices.append(end+(p+Vector3.UP*h)*core_scale)
			local_normals.append((d*(1.0-absf(y)*.61)+Vector3.UP*(y+.25)).normalized())
			var lightness := smoothstep(-.77,1.,y+.16*sin(3.*a+phase)-.12*cos(a*2.))
			var color := Color(.027,.268,.213).lerp(tint,lightness)
			colors.append(color)
	var order := PackedInt32Array()
	for ring in range(4):
		for side in range(slices):
			var k := ring*slices+side
			var next := ring*slices+(side+1)%slices
			order.append_array(PackedInt32Array([k,k+slices,next,next,k+slices,next+slices]))
	for side in range(1,slices-1):
		order.append_array(PackedInt32Array([0,side+1,side,4*slices,4*slices+side,4*slices+side+1]))
	for index in order:
		st.set_uv(Vector2.ZERO)
		st.set_uv2(Vector2(.74,1.))
		st.set_color(colors[index])
		st.set_normal(local_normals[index])
		st.add_vertex(vertices[index])
	# Short, slightly drooping sprays skim the silhouette in unequal packets.
	for cluster in range(11):
		var a := angle + TAU*cluster/11. + rng.randf_range(-.41,.40)
		var d := Vector3(cos(a),0,sin(a))
		var t := Vector3(-d.z,0,d.x)
		var h := rng.randf_range(-.38,.77)
		var radial_length := 1.0/sqrt(pow(d.dot(along)/size.x,2.)+pow(d.dot(across)/size.z,2.))
		var branch := end + along*size.x*.26 + d*radial_length*(.99-.15*absf(h)) + Vector3.UP*h*size.y
		var normal := (d * (1.0 - absf(h) * .61) + Vector3.UP * (h + .25)).normalized()
		for spray in range(2 + cluster%2):
			var offset := t * float(spray-1)*.19 + d*rng.randf_range(-.09,.22)
			var width := rng.randf_range(.82,1.18)*size.z
			var face := (d*1.18+Vector3.UP*rng.randf_range(.20,.68)+t*rng.randf_range(-.29,.29)).normalized()
			var tangent := Vector3.UP.cross(face).normalized()
			var rising := face.cross(tangent)
			var spin := Basis(face, rng.randf_range(-.95,.51))
			var pigment := Color(.065,.37,.258).lerp(tint,clampf(.56+.34*h,0.,1.)).lightened(rng.randf_range(.015,.069))
			_curved_card(st,branch+offset,spin*tangent*width,spin*rising*width*.75,normal,pigment,true)


static func _gully_tree(profile: int, leaves: Material, bark: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42311 + profile * 178
	var canopy := SurfaceTool.new()
	canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
	canopy.set_material(leaves)
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_material(bark)
	# Profiles progress from coppiced stems on saturated soil to two mature
	# trees with lifted branch forks and a fully lit asymmetric shoulder.
	var height: float = [3.82,1.64,3.17,7.7,9.0][profile]
	var spread: float = [1.82,1.55,1.02,2.10,2.46][profile]
	var tones := [Color(.184,.593,.337), Color(.275,.57,.31), Color(.098,.553,.343), Color(.134,.609,.329), Color(.079,.495,.282)]
	var dominant: Color = tones[profile]
	var scaffold := [Vector4(-.34,.77,.13,.94),Vector4(.71,.63,.12,.90),
		Vector4(-.80,.47,.40,.73),Vector4(.24,.91,-.19,.76),
		Vector4(.06,.46,-.61,.86),Vector4(.94,.34,-.18,.62)]
	for i in range(scaffold.size()):
		var b: Vector4 = scaffold[i]
		if profile >= 3:
			if i==0: b=Vector4(-.35,.83,.40,.95)
			if i==1: b=Vector4(.77,.71,-.12,1.08)
			if i==2: b=Vector4(-1.02,.57,-.23,.70)
			if i==3: b=Vector4(.03,1.02,-.18,.83)
			if i==4: b=Vector4(.29,.65,.74,.96)
			if i==5: b=Vector4(1.13,.56,.52,.54)
			if profile==4:
				if i==0: b=Vector4(-.41,.88,.10,1.03)
				if i==2: b=Vector4(-.88,.62,-.21,.83)
				if i==3: b=Vector4(-.12,1.04,-.12,.97)
			if i==4: b.x-=.15
		var end := Vector3(b.x*spread,b.y*height,b.z*spread)
		var dir := Vector3(end.x,0,end.z).normalized()
		var across := Vector3(-dir.z,0,dir.x)
		var stem := dir*.15-Vector3.UP*.08
		var fork := end*.44+across*.15-dir*.16
		if profile >= 3:
			var rise := height*(.31 if i%2==0 else .26)
			stem=Vector3(.14,rise,-.10)
			fork=stem.lerp(end,.54)+Vector3(-.22,-.15,.16)
			if i==0:
				_tube(wood,PackedVector3Array([Vector3.ZERO,Vector3(-.12,.9,.105),stem,end*.78]),
					PackedFloat32Array([.37,.29,.23,.09]),8)
		_tube(wood,PackedVector3Array([stem,fork,end]), PackedFloat32Array([(.19 if profile>=3 else .13)*b.w,(.12 if profile>=3 else .081)*b.w,.013]),6)
		var shade := dominant.darkened(.07 if i==4 else .0)
		var a := atan2(dir.z,dir.x)
		var outer := end+dir*spread*.29 + Vector3.UP*height*.02
		_gully_lobe(canopy,end,Vector3(1.01*spread,(.212 if profile>=3 else .29)*height,.71*spread)*b.w,a,shade,rng)
		_gully_lobe(canopy,outer+across*spread*.35,Vector3(.72*spread,(.15 if profile>=3 else .18)*height,.54*spread)*b.w,a+.55,shade.lightened(.052),rng)
	if profile>=3:
		# Interior foliage links the main forks into one crown; the asymmetric
		# upper / windward fringe outlines the individual boughs beyond it.
		_gully_lobe(canopy,Vector3(.10*spread,.73*height,-.09*spread),Vector3(1.17*spread,.223*height,.93*spread),-.19,dominant.darkened(.165),rng)
		_gully_lobe(canopy,Vector3(-.31*spread,.82*height,.04*spread),Vector3(.93*spread,.204*height,.68*spread),2.57,dominant.darkened(.072),rng)
	var mesh := canopy.commit()
	wood.commit(mesh)
	return mesh


static func _build_gully_wood(parent: Node3D, terrain: Script, leaves: Material, bark: Material) -> void:
	var models: Array[ArrayMesh] = []
	for profile in 5: models.append(_gully_tree(profile,leaves,bark))
	# The first group crosses the shadow mouth in depth. A second smaller
	# group rides the upper bench; bare stone separates the two in the vista.
	var sources := [
		[Vector2(-1.9,-9.0),3,1.13,.35], [Vector2(-6.8,-19.7),2,1.04,-.36],
		[Vector2(-3.2,-10.1),1,1.17,.24], [Vector2(-4.4,-23.6),0,.87,-.74],
		[Vector2(12.2,-21.6),0,.87,.57], [Vector2(10.0,-15.3),1,.93,-.33],
		[Vector2(13.7,-24.8),2,.95,-.86], [Vector2(-34.,-16.),2,1.13,.4],
		[Vector2(49.0,-54.0),4,1.24,-.81], [Vector2(44.6,-55.9),2,1.32,.71],
		[Vector2(54.8,-57.5),0,.96,.39], [Vector2(49.3,-55.9),1,.87,1.2],
	]
	var occupied: Array[Vector2]=[]
	var group := Node3D.new()
	group.name="GullyWood"
	parent.add_child(group)
	for item: Array in sources:
		var anchor: Vector2 = item[0]
		var best := Vector2.INF
		var best_score := INF
		for dx in range(-4,5):
			for dz in range(-4,5):
				var p := anchor+Vector2(dx,dz)*.72
				var steep := _slope(terrain,p.x,p.y)
				var weight: float = terrain.vegetation_weight(p.x,p.y)
				if weight < .26 or steep > .72 or absf(p.x-terrain.path_center(p.y)) < 4.7: continue
				var room := true
				for other in occupied:
					if p.distance_squared_to(other)<3.0: room=false
				if not room: continue
				var score := anchor.distance_to(p)+steep*.89-weight*.30
				if score<best_score: best_score=score;best=p
		if not best.is_finite():continue
		var shrub := MeshInstance3D.new()
		shrub.name="BankDogwood_%02d" % occupied.size()
		shrub.mesh=models[item[1]]
		shrub.position=Vector3(best.x,terrain.ground_height(best.x,best.y)-.07,best.y)
		shrub.rotation.y=item[3]
		shrub.scale=Vector3.ONE*float(item[2])
		group.add_child(shrub)
		if int(item[1]) >= 3:
			var trunk_body := StaticBody3D.new()
			trunk_body.name = "TrunkCollision"
			var collider := CollisionShape3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = .235
			capsule.height = 2.8
			collider.shape = capsule
			collider.position.y = capsule.height*.5
			trunk_body.add_child(collider)
			shrub.add_child(trunk_body)
		occupied.append(best)
	group.set_meta("root_sites",occupied)


static func _build_pine_belts(parent: Node3D, terrain: Script, material: Material, bark: Material, rng: RandomNumberGenerator) -> void:
	var variants: Array[ArrayMesh] = []
	for k in range(4):
		variants.append(_pine_mesh(material, bark, rng))
	var clusters := [
		Vector4(-49,-73,17,7), Vector4(-20,-88,14,7), Vector4(3,-66,9,4),
		Vector4(22,-80,15,8), Vector4(48,-67,12,7), Vector4(48,-98,18,7),
		Vector4(-6,-102,11,5), Vector4(-56,-52,6,5), Vector4(52,-48,6,3),
		Vector4(-30,-59,9,5), Vector4(-1,-76,6,4), Vector4(28,-57,8,5)
	]
	var used: Array[Vector2] = []
	for cluster: Vector4 in clusters:
		for k in range(int(cluster.w) * 2):
			var z := cluster.y + rng.randf_range(-4.5,4.5)
			var p := _tree_site(Vector2(cluster.x + rng.randf_range(-cluster.z,cluster.z),z),terrain)
			if not p.is_finite() or p.x < -65 or p.x > 65 or p.y < -104:
				continue
			var spaced := true
			for prev in used:
				if prev.distance_squared_to(p) < 8.3:
					spaced = false
					break
			if not spaced:
				continue
			used.append(p)
			var mesh := MeshInstance3D.new()
			mesh.mesh = variants[used.size() % variants.size()]
			mesh.name = "TerraceFir_%02d" % used.size()
			mesh.position = Vector3(p.x, terrain.ground_height(p.x,p.y)-0.06,p.y)
			var height := rng.randf_range(0.66,1.43)
			var width := height * rng.randf_range(0.86,1.15)
			mesh.scale = Vector3(width,height,width)
			mesh.rotation.y = rng.randf()*TAU
			parent.add_child(mesh)
	# Bring two conifers down from the distant belt to the east bench while
	# leaving the grass saddle between the banks open. Vary crown height and
	# width independently so they read as trees of different ages.
	var outliers := [Vector4(25.8,-5.2,.76,.82),Vector4(28.95,-7.34,.62,.69)]
	for site: Vector4 in outliers:
		var p := _tree_site(Vector2(site.x,site.y),terrain)
		if not p.is_finite() or absf(p.x-terrain.path_center(p.y)) < 5.0:
			continue
		var tree := MeshInstance3D.new()
		tree.name = "EastBenchFir_%02d" % used.size()
		tree.mesh = variants[used.size() % variants.size()]
		tree.position = Vector3(p.x,terrain.ground_height(p.x,p.y)-.06,p.y)
		tree.scale = Vector3(site.w,site.z,site.w)
		tree.rotation.y = .38 + site.y*.37
		parent.add_child(tree)
		used.append(p)
	parent.set_meta("pine_count", used.size())


static func _pine_mesh(material: Material, bark: Material, rng: RandomNumberGenerator) -> ArrayMesh:
	var crown := SurfaceTool.new()
	crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	crown.set_material(material)
	# Branches droop from staggered centres. The irregular fringe and pinched
	# branch roots distinguish each tier from the regular cones of a prop tree.
	var twist := rng.randf() * TAU
	var crown_height := rng.randf_range(7.4,9.1)
	var spread := rng.randf_range(1.18,1.64)
	var count := rng.randi_range(54,76)
	var lean := Vector3(rng.randf_range(-.43,.43),0,rng.randf_range(-.28,.28))
	var lowest := rng.randf_range(.9,1.72)
	for branch in range(count):
		var h := float(branch)/float(count-1)
		var y := lowest + h * (crown_height-lowest)
		var radius := spread*pow(1.0-h,0.69)*lerpf(.68,1.0,smoothstep(0.0,.16,h))
		var a := twist+branch*2.39996+rng.randf_range(-.36,.36)
		var outward := Vector3(cos(a),0,sin(a))
		var across := Vector3(-outward.z,0,outward.x)
		var hub := lean*h*h + Vector3.UP*y
		var extent := maxf(.11,radius*rng.randf_range(.70,1.28))
		var width := extent*rng.randf_range(.30,.53)
		var droop := extent*rng.randf_range(.23,.51)
		var lift := lerpf(.64,.20,h)
		var hook := rng.randf_range(-.22,.22)*extent
		var points := [hub+Vector3.UP*lift,
			hub+outward*extent*.46+Vector3.UP*(lift*.38),
			hub+outward*extent*.53-across*width-Vector3.UP*droop*.50,
			hub+outward*extent*.69+across*width*.82-Vector3.UP*droop*.58,
			hub+outward*extent+across*hook-Vector3.UP*droop*.76,
			hub-Vector3.UP*.21,
			hub+outward*extent*.83-across*width*.50-Vector3.UP*droop,
			hub+outward*extent*.91+across*width*.33-Vector3.UP*droop*1.14]
		var shade := rng.randf_range(.85,1.04)
		for i in [0,2,1,0,1,3,1,2,6,1,6,4,1,4,7,1,7,3,2,5,6,6,5,4,4,5,7,7,5,3]:
			var normal := (outward*.55+Vector3.UP*(.92 if i==0 or i==1 else .41)).normalized()
			var wash := (.67 if i==0 or i==1 else .34)+h*.22
			if i==5: wash=.06
			var pigment := Color(.058,.23,.19).lerp(Color(.19,.44,.28),wash)*shade
			pigment.a=1.0
			_solid_leaf_vertex(crown,points[i],normal,pigment)
	var mesh := crown.commit()
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_material(bark)
	_tube(wood,PackedVector3Array([Vector3.ZERO,Vector3(0,1.8,0),Vector3(.09,crown_height,0)]),PackedFloat32Array([.19,.14,.026]),7)
	wood.commit(mesh)
	return mesh


static func _solid_leaf_vertex(surface: SurfaceTool, point: Vector3, normal: Vector3, pigment: Color) -> void:
	surface.set_uv(Vector2.ZERO)
	surface.set_uv2(Vector2(1,0))
	surface.set_normal(normal)
	surface.set_color(pigment)
	surface.add_vertex(point)


static func _bough_offset(unit: Vector3, phase: float) -> Vector3:
	var bump := .91 + .15*sin(unit.x*5.8 + unit.z*2.6 + phase)*sin(unit.y*6.3 - phase) + .11*sin(unit.z*6.2+phase*.7)
	var asym := Vector3(unit.y*unit.y*sin(phase)*.19, .11*sin(phase+unit.x*3.2), unit.x*unit.y*.19)
	return unit*bump+asym


# Crown skins and their surrounding leaf cards share a normal field.
# Small lobes retain a readable lit side under both direct and grazing light.
static func _canopy_normal(radial: Vector3) -> Vector3:
	return (radial + Vector3.UP * .32).normalized()


static func _crown_volume(surface: SurfaceTool, centre: Vector3, radii: Vector3, phase: float, brightness: float) -> void:
	var rings: Array = []
	for level in range(7):
		var latitude := -1.30 + float(level)*.43
		var ring := PackedVector3Array()
		for side in range(14):
			var angle := TAU*float(side)/14.0 + phase + .12*float(level)
			ring.append(Vector3(cos(angle)*cos(latitude),sin(latitude),sin(angle)*cos(latitude)))
		rings.append(ring)
	for level in range(-1,7):
		for side in range(14):
			var j := (side+1)%14
			var points: Array
			if level==-1:
				points = [Vector3.DOWN,rings[0][side],rings[0][j]]
			elif level==6:
				points = [rings[6][side],Vector3.UP,rings[6][j]]
			else:
				points = [rings[level][side],rings[level+1][side],rings[level][j],rings[level][j],rings[level+1][side],rings[level+1][j]]
			for n: Vector3 in points:
				var offset := _bough_offset(n,phase)
				var zone := smoothstep(-.8,.95,n.y+.22*sin(n.x*5+n.z*3+phase))
				var pigment := Color(.095,.27,.205).lerp(Color(.30,.50,.22),zone)*brightness
				pigment.a = 1.0
				surface.set_uv(Vector2.ZERO)
				surface.set_uv2(Vector2(0.7,0))
				surface.set_normal(_canopy_normal(offset.normalized()))
				surface.set_color(pigment)
				surface.add_vertex(centre+offset*radii*.65)


static func _tree_meshes(seed_value: int, leaf_mat: Material, bark_mat: Material) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.set_material(leaf_mat)
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_material(bark_mat)
	var profile := int((seed_value - SEED_VALUE) / 83) % 5
	var crown_shapes := [Vector3(1.31, 0.88, 1.02), Vector3(0.91, 1.28, 0.84), Vector3(1.09, 1.03, 1.20), Vector3(0.92, 1.17, 1.03), Vector3(1.20, 0.95, 0.91)]
	var crown_shape: Vector3 = crown_shapes[profile]
	var lean := Vector3(rng.randf_range(-0.62, 0.62), 0, rng.randf_range(-0.45, 0.45))
	var trunk := PackedVector3Array([
		Vector3.ZERO, Vector3(0.04, 0.9, -0.07),
		Vector3(-0.11, 1.8, 0.04) + lean * 0.35,
		Vector3(0.12, 2.8, 0.0) + lean * 0.70,
		Vector3(0.10, 3.8, -0.04) + lean
	])
	_tube(wood, trunk, PackedFloat32Array([0.28, 0.23, 0.19, 0.14, 0.08]), 7)
	# Three unequal structural boughs determine the crown, rather than a ring
	# of equally weighted leafy spheres. Smaller terminal sprays continue the
	# direction of each bough and leave readable openings between branches.
	var major_angle := rng.randf() * TAU
	var directions := [major_angle, major_angle + 2.05, major_angle + 4.10]
	var reaches := [1.20, 1.60, 1.10]
	var heights := [4.75, 4.10, 3.85]
	var masses := [Vector3(1.62, 1.38, 1.35), Vector3(1.48, 1.20, 1.14), Vector3(1.17, 1.12, 1.05)]
	for bough in range(3):
		var angle: float = directions[bough] + rng.randf_range(-0.19, 0.19)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var across := Vector3(-direction.z, 0, direction.x)
		var reach: float = reaches[bough] * crown_shape.x
		var height: float = heights[bough] + (crown_shape.y - 1.0) * 2.0
		var centre := direction * reach + Vector3.UP * height + lean
		var origin := trunk[3] if bough == 0 else trunk[2]
		var elbow := origin.lerp(centre, 0.43) - Vector3.UP * 0.16
		var tip := centre + direction * 0.52 + Vector3.UP * 0.24
		_tube(wood, PackedVector3Array([origin, elbow, centre, tip]), PackedFloat32Array([0.135 if bough == 0 else 0.105, 0.085, 0.045, 0.009]), 6)
		var mass: Vector3 = masses[bough] * Vector3(crown_shape.x, sqrt(crown_shape.y), crown_shape.z)
		_leaf_clump(leaves, centre, mass, rng, 17 if bough == 0 else 14, 0.99 - float(bough) * 0.055, direction)
		# A rising spray and a smaller lateral spray break the ellipsoid edge.
		var spray_a := centre + direction * mass.x * 0.48 + Vector3.UP * 0.25
		var spray_b := centre - direction * mass.x * 0.22 + across * mass.z * (0.55 if bough % 2 == 0 else -0.55) - Vector3.UP * 0.12
		_tube(wood, PackedVector3Array([centre - direction * 0.3, spray_a]), PackedFloat32Array([0.032, 0.007]), 5)
		_tube(wood, PackedVector3Array([elbow, spray_b]), PackedFloat32Array([0.043, 0.008]), 5)
		_leaf_clump(leaves, spray_a, mass * Vector3(0.61, 0.92, 0.61), rng, 9, 1.02, direction)
		_leaf_clump(leaves, spray_b, mass * Vector3(0.49, 0.82, 0.62), rng, 8, 0.91, across)
	# The leader is offset toward the dominant bough, exposing a sky notch
	# between it and the lower side branches instead of closing a round cap.
	var leader_dir := Vector3(cos(major_angle), 0, sin(major_angle))
	var leader := lean + leader_dir * 0.32 + Vector3.UP * (5.28 + (crown_shape.y - 1.0) * 2.0)
	_tube(wood, PackedVector3Array([trunk[3], leader]), PackedFloat32Array([0.075, 0.012]), 6)
	_leaf_clump(leaves, leader, Vector3(1.22, 1.20, 1.11) * crown_shape, rng, 14, 1.0, leader_dir)
	# This connecting shoulder hides the bare upper trunk while preserving
	# smaller sky openings at the ends of the unequal branch masses.
	_leaf_clump(leaves, lean + leader_dir * 0.20 + Vector3.UP * 3.98, Vector3(1.18, 1.12, 1.10) * crown_shape, rng, 12, 0.93, leader_dir)
	# Long visible roots anchor the tree to the slope without round tree bases.
	for index in range(4):
		var angle := float(index) * TAU / 4.0 + rng.randf_range(-0.3, 0.3)
		var edge := Vector3(cos(angle) * 0.70, 0.025, sin(angle) * 0.70)
		_tube(wood, PackedVector3Array([Vector3(0, 0.25, 0), edge]), PackedFloat32Array([0.095, 0.012]), 5)
	return [leaves.commit(), wood.commit()]


static func _leaf_clump(surface: SurfaceTool, centre: Vector3, radii: Vector3, rng: RandomNumberGenerator, count: int, brightness: float, growth_direction: Vector3 = Vector3.RIGHT) -> void:
	var phase := rng.randf() * TAU
	var along := Vector3(growth_direction.x, 0, growth_direction.z).normalized()
	var across := Vector3(-along.z, 0, along.x)
	_crown_volume(surface, centre, radii, phase, brightness)
	var sprays := ceili(float(count)*1.52)
	var sphere_rotation := rng.randf()*TAU
	for index in range(sprays):
		# Grow textured sprays all around each actual branch mass. The opaque
		# interior sits far enough inside that gaps read as shaded foliage.
		var hy := lerpf(-.88,.97,(float(index)+.5)/float(sprays))
		var angle := float(index)*2.39996 + sphere_rotation + rng.randf_range(-.20,.20)
		var horizontal := sqrt(1.0-hy*hy)
		var radial := Vector3(horizontal*cos(angle),hy,horizontal*sin(angle))
		var pos := _bough_offset(radial,phase)
		var place := centre + pos*radii*rng.randf_range(.68,.79)
		var normal := _canopy_normal(radial)
		var card_normal := (radial+along*.17+Vector3.UP*.12).normalized()
		var axis := Vector3.UP if absf(card_normal.y)<.88 else across
		var right := card_normal.cross(axis).normalized()
		var up := right.cross(card_normal).normalized()
		var spin := Basis(card_normal,rng.randf_range(-.52,.52))
		var size := rng.randf_range(.97,1.35)
		var shade := brightness*lerpf(.77,1.01,smoothstep(-.84,.88,hy))
		_curved_card(surface,place,spin*right*size*radii.x,spin*up*size*radii.y,normal,Color(shade*.91,shade,shade*.96),false,centre,radii)
	# Two intersecting interior sprays carry the middle-distance silhouette;
	# individual terminal cards provide detail only at the perimeter.
	for index in range(2):
		var axis := Vector3(sin(phase + index * 1.2), 0.24, cos(phase + index * 1.2)).normalized()
		var right := axis.cross(Vector3.UP).normalized()
		var up := right.cross(axis).normalized()
		_curved_card(surface, centre, right * radii.x * 1.85, up * radii.y * 1.8, Vector3(0, 0.8, 0.25).normalized(), Color(0.80, 0.89, 0.84), false, centre, radii)


static func _curved_card(surface: SurfaceTool, centre: Vector3, right: Vector3, up: Vector3, normal: Vector3, colour: Color, bank_spray: bool = false, crown_centre: Vector3 = Vector3.ZERO, crown_radii: Vector3 = Vector3.ZERO) -> void:
	var verts: Array[Vector3] = []
	var tex: Array[Vector2] = []
	for row in range(3):
		for col in range(3):
			var u := float(col) * 0.5
			var v := float(row) * 0.5
			var curve := (1.0 - absf(u - 0.5) * 2.0) * (1.0 - absf(v - 0.5) * 2.0) * 0.13
			verts.append(centre + right * (u - 0.5) + up * (0.5 - v) + normal * curve)
			tex.append(Vector2(u, v))
	for row in range(2):
		for col in range(2):
			var a := row * 3 + col
			for i in [a, a + 3, a + 1, a + 1, a + 3, a + 4]:
				var vertex_normal := normal
				if crown_radii != Vector3.ZERO:
					var radial := (verts[i] - crown_centre) / crown_radii
					if radial.length_squared() > .0001:
						vertex_normal = _canopy_normal(radial.normalized())
				surface.set_normal(vertex_normal)
				surface.set_color(colour)
				surface.set_uv(tex[i])
				surface.set_uv2(Vector2(0., 1. if bank_spray else 0.))
				surface.add_vertex(verts[i])


static func _tube(surface: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, sides: int) -> void:
	# Construct one ring per control point, then share those exact positions
	# between adjoining segments. Projecting the previous frame onto the new
	# tangent plane avoids frame flips at bends and eliminates open ring seams.
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	var previous_axis := Vector3.ZERO
	for point_index in range(points.size()):
		var tangent: Vector3
		if point_index == 0:
			tangent = (points[1] - points[0]).normalized()
		elif point_index == points.size() - 1:
			tangent = (points[point_index] - points[point_index - 1]).normalized()
		else:
			tangent = (points[point_index + 1] - points[point_index - 1]).normalized()
		var x_axis := previous_axis - tangent * previous_axis.dot(tangent)
		if x_axis.length_squared() < 0.00001:
			var axis := Vector3.UP if absf(tangent.y) < 0.95 else Vector3.RIGHT
			x_axis = tangent.cross(axis)
		x_axis = x_axis.normalized()
		var z_axis := tangent.cross(x_axis).normalized()
		previous_axis = x_axis
		var ring := PackedVector3Array()
		var normals := PackedVector3Array()
		for side in range(sides):
			var angle := TAU * float(side) / float(sides)
			var normal := x_axis * cos(angle) + z_axis * sin(angle)
			ring.append(points[point_index] + normal * radii[point_index])
			normals.append(normal)
		rings.append(ring)
		ring_normals.append(normals)
	for segment in range(points.size() - 1):
		for side in range(sides):
			var next_side := (side + 1) % sides
			var vertices := [rings[segment][side], rings[segment][next_side], rings[segment + 1][side], rings[segment + 1][next_side]]
			var normals := [ring_normals[segment][side], ring_normals[segment][next_side], ring_normals[segment + 1][side], ring_normals[segment + 1][next_side]]
			for i in [0, 2, 1, 1, 2, 3]:
				surface.set_normal(normals[i])
				surface.set_uv(Vector2(float(side + i % 2) / float(sides), float(segment + int(i / 2)) * 0.45))
				surface.set_color(Color(0.94, 0.96, 0.98))
				surface.add_vertex(vertices[i])


static func _build_bushes(parent: Node3D, terrain: Script, material: Material, rng: RandomNumberGenerator) -> void:
	var variants: Array[ArrayMesh] = []
	for index in range(3):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		var rise := .45 + .12 * index
		_leaf_clump(surface, Vector3(-.20,rise,0), Vector3(.75,rise+.10,.60), rng, 12, 1.04)
		_leaf_clump(surface, Vector3(.43,rise*.64,.12), Vector3(.62,.37,.48), rng, 8, 1.13)
		_leaf_clump(surface, Vector3(-.45,rise*1.54,.11), Vector3(.48,rise*.92,.47), rng, 9, 1.22)
		variants.append(surface.commit())
	# Each island has a dominant windward shoulder and smaller satellite crowns.
	# Coordinates are projected against the fixed vista, while the root height and
	# support follow the actual ground and the lateral clearance follows its bend.
	var islands := [Vector4(-2.4,7.4,1.28,-.19),Vector4(-14.6,-12.4,1.13,-.40),
		Vector4(-8.8,-4.5,1.03,.27), Vector4(2.4,-22.6,.82,-.12),
		Vector4(27,-2.8,.73,.38), Vector4(38,-13.8,.95,-.46),
		Vector4(-37,-22,1.15,-.23),Vector4(32,-45,.91,.18),Vector4(-2.9,20.0,.74,.27),
		Vector4(-1.9,6.8,.72,-.32),Vector4(21.8,5.5,.86,.21),Vector4(27.5,4.7,.52,-.35),
		Vector4(19.4,-5.8,.83,-.66),Vector4(26.1,-13.8,.61,.44)]
	var offsets := [Vector3(-1.75,.59,.32),Vector3(-.56,.90,-.26),Vector3(.48,1.16,.0),
		Vector3(1.68,.62,-.34),Vector3(2.67,.38,.13)]
	var placed := 0
	var island_rng := rng
	for island_index in islands.size():
		var island: Vector4 = islands[island_index]
		if island_index == 12:
			# New islands preserve the original shared stream used by meadow flowers.
			island_rng = RandomNumberGenerator.new()
			island_rng.state = rng.state
		var bearing := Vector2(cos(island.w),sin(island.w))
		for j in range(offsets.size()):
			var offset: Vector3 = offsets[j]
			var site := Vector2(island.x,island.y) + (bearing*offset.x + bearing.orthogonal()*offset.z)*island.z
			var size := offset.y * island.z
			if absf(site.x-terrain.path_center(site.y)) < 2.45 + size: continue
			if terrain.vegetation_weight(site.x,site.y) < .35 or _slope(terrain,site.x,site.y) > .60: continue
			var bush := MeshInstance3D.new()
			bush.name = "Shrub_%03d" % placed
			bush.mesh = variants[(placed + j)%variants.size()]
			bush.position = Vector3(site.x, terrain.ground_height(site.x,site.y)-.025, site.y)
			bush.rotation.y = island_rng.randf() * TAU
			bush.scale = Vector3(1.32,1.18,1.04)*size
			parent.add_child(bush)
			placed += 1


# The coarse shaded volume supports twigs whose paired blades extend beyond
# the shrub. Distinct upward fans on the sunward shoulder break the mossy outline.
static func _brake_sprays(st: SurfaceTool, rng: RandomNumberGenerator, variation: int) -> void:
	var fans := [Vector4(2.56,.71,1.41,.72), Vector4(-1.03,.57,1.14,.62),
		Vector4(.15,.90,.62,.41),Vector4(-2.76,.89,.51,.35)]
	for spray in 26:
		var fan: Vector4=fans[spray%4]
		var angle := fan.x + rng.randf_range(-.60,.54) + .13*variation
		var forward:=Vector3(cos(angle),0,sin(angle))
		var sideways:=Vector3.UP.cross(forward)
		var origin:=Vector3(-.22,fan.z + rng.randf_range(-.15,.08),-.05)+forward*fan.y
		origin+=sideways*rng.randf_range(-.19,.21)
		var rise:=fan.w*rng.randf_range(.57,1.11)
		var stretch:=rng.randf_range(.36,.61)
		var stem_width:=sideways*.010
		var old:=origin
		for j in range(1,4):
			var u:=float(j)/3.
			var tip:=origin+forward*stretch*u+Vector3.UP*rise*(u*1.32-.32*u*u)
			for v:Vector3 in [old-stem_width,old+stem_width,tip+stem_width,old-stem_width,tip+stem_width,tip-stem_width]:
				_solid_leaf_vertex(st,v,Vector3.UP, Color(.222,.453,.21))
			old=tip
		for i in range(5):
			var t:float=i/4.0
			var base:=origin+forward*stretch*t+Vector3.UP*rise*(1.32*t-.32*t*t)
			for side:float in [-1.,1.]:
				var length_leaf:=lerpf(.28,.14,t)*rng.randf_range(.88,1.21)
				var lean:=(forward*.67+side*sideways*.92+Vector3.UP*(.38+.38*t)).normalized()*length_leaf
				var tip:=base+lean
				var spread:=lean.cross(Vector3.UP).normalized()*length_leaf*.24
				var middle:=base+lean*.53+Vector3.UP*length_leaf*.12
				var normal:=(forward*.50+Vector3.UP).normalized()
				var bias:=smoothstep(.61,2.1,base.y+.18*forward.x)
				var tone:=Color(.066,.407,.238).lerp(Color(.40,.69,.217),bias)
				for point:Vector3 in [base,middle-spread,middle, middle, middle-spread,tip,base,middle,middle+spread,middle,middle+spread,tip]:
					st.set_uv(Vector2.ZERO)
					st.set_uv2(Vector2(1.,1.))
					st.set_normal(normal)
					st.set_color(tone)
					st.add_vertex(point)


static func _build_foreground_thicket(parent: Node3D, terrain: Script, material: Material) -> void:
	# A sunlit low brake in front of the damp scarp. The growing edge leans
	# into the grassland; two smaller offshoots leave bits of meadow visible.
	var rng := RandomNumberGenerator.new()
	rng.seed=SEED_VALUE+1106
	var models: Array[ArrayMesh]=[]
	for k in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(material)
		var parts := [Vector4(-.27,.65,.04,.95),Vector4(.44,.51,-.12,.88),
			Vector4(-.54,.39,-.32,.71),Vector4(-.25,1.13,-.04,.80),
			Vector4(.27,.83,.43,.69),Vector4(-.48,1.42,-.12,.50),Vector4(.87,.35,.21,.45)]
		for i in parts.size():
			var l: Vector4=parts[i]
			var pos:=Vector3(l.x,l.y,l.z)
			pos.y*=1.0-.09*k
			var sun:=smoothstep(.32,1.25,l.y)
			var paint:=Color(.071,.414,.271).lerp(Color(.406,.711,.276),sun*.92+.04)
			_gully_lobe(st,pos,Vector3(1.0,.76,.84)*l.w,1.17*i+.25*k,paint,rng,.81)
		_brake_sprays(st,rng,k)
		models.append(st.commit())
	var sources:=[Vector4(9.47,12.85,1.49,-.19),Vector4(11.63,13.47,.81,2.53),Vector4(13.68,12.06,.43,-1.30)]
	for i in sources.size():
		var site:Vector4=sources[i]
		if absf(site.x-terrain.path_center(site.y)) < 1.0+site.z or terrain.vegetation_weight(site.x,site.y)<.44:continue
		if _slope(terrain,site.x,site.y)>.38:continue
		var instance:=MeshInstance3D.new()
		instance.name="Shrub_ForegroundBrake_%02d" % i
		instance.mesh=models[i]
		instance.position=Vector3(site.x,terrain.ground_height(site.x,site.y)-.085,site.y)
		instance.rotation.y=site.w
		instance.scale=Vector3.ONE*site.z
		parent.add_child(instance)


static func _build_bank_plants(parent: Node3D, terrain: Script, material: Material) -> void:
	# Sheltered pockets along the upper switchback. Sample all the leaf edges
	# against the actual bank so the short leaves follow breaks in the slope.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VALUE + 8137
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	var shelves := [Vector2(4.0,-41.95),Vector2(9.6,-42.65),Vector2(11.2,-44.5),
		Vector2(12.5,-49.3),Vector2(12.7,-52.0),Vector2(1.45,-47.5)]
	var roots: Array[Vector2] = []
	for shelf: Vector2 in shelves:
		for attempt in range(14):
			var p := shelf + Vector2(rng.randfn(0,.63),rng.randfn(0,.89))
			if absf(p.x - terrain.path_center(p.y)) < 2.7 or terrain.vegetation_weight(p.x,p.y) < .43:
				continue
			var grade := _slope(terrain,p.x,p.y)
			if grade < .25 or grade > 1.16: continue
			var supported := true
			for bearing: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				var ring := p + .24*bearing
				if terrain.vegetation_weight(ring.x,ring.y)<.20: supported=false
			for prev in roots:
				if p.distance_squared_to(prev)<.095: supported=false
			if not supported: continue
			roots.append(p)
			var dx: float = (terrain.ground_height(p.x+.08,p.y) - terrain.ground_height(p.x-.08,p.y))/.16
			var dz: float = (terrain.ground_height(p.x,p.y+.08) - terrain.ground_height(p.x,p.y-.08))/.16
			var normal := Vector3(-dx,1.0,-dz).normalized().lerp(Vector3.UP,.23).normalized()
			var phase := rng.randf()*TAU
			var leaves := rng.randi_range(5,8)
			for blade in range(leaves):
				var a := phase + TAU*blade/leaves + rng.randf_range(-.37,.37)
				var ahead := Vector2(cos(a),sin(a))
				var reach := rng.randf_range(.14,.32)/sqrt(1.0+pow(ahead.dot(Vector2(dx,dz)),2))
				var across := Vector2(-ahead.y,ahead.x)*rng.randf_range(.022,.046)
				var mid := p + ahead*reach*.52
				var end := p + ahead*reach
				var arch := rng.randf_range(.048,.092)
				var points := [p,mid-across,mid,mid+across,end]
				var rise := [-.008,arch*.71,arch,arch*.71,arch*.48]
				var shade := rng.randf_range(.90,1.06)
				for vertex in [0,1,2,0,2,3,1,4,2,2,4,3]:
					var v: Vector2=points[vertex]
					var pos := Vector3(v.x,terrain.ground_height(v.x,v.y)+float(rise[vertex]),v.y)
					var pigment := Color(.105,.23,.095) if vertex==0 else Color(.20,.38,.135)
					if vertex==2 or vertex==4: pigment=Color(.24,.42,.155)
					pigment*=shade
					pigment.a=1.0
					_solid_leaf_vertex(st,pos,normal,pigment)
	if roots.is_empty(): return
	var plants := MeshInstance3D.new()
	plants.name="SwitchbackGroundcover"
	plants.mesh=st.commit()
	plants.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plants.set_meta("root_count",roots.size())
	parent.add_child(plants)


static func _build_grass(parent: Node3D, terrain: Script, material: Material, herb_openings: Array[Vector4]) -> void:
	# Dedicated seeds separate authored placement from changes in tree meshes.
	var placement_rng := RandomNumberGenerator.new()
	placement_rng.seed = SEED_VALUE + 1909
	var mesh_rng := RandomNumberGenerator.new()
	mesh_rng.seed = SEED_VALUE + 2803
	var grass_meshes: Array = [[], [], []]
	for species in range(3):
		for variation in range(2):
			grass_meshes[species].append(_grass_mesh(mesh_rng, material, species))
	# Large, deliberately placed communities define the medium-distance shape.
	# They are not a global noise threshold and need not fill every available metre.
	var tall_patches := [
		Vector4(-5.6, 18.6, 6.9, 2.9), Vector4(11.8, 17.2, 7.6, 2.1),
		Vector4(23.8, 14.3, 8.2, 2.4), Vector4(-14, 11, 6, 6),
		Vector4(24, 23, 8, 8), Vector4(37, 7, 7, 11),
		Vector4(-24, -5, 7, 5), Vector4(-33, -31, 9, 6),
		Vector4(36, -47, 10, 6)
	]
	var meadow_patches := [
		Vector4(-24, 19, 22, 19), Vector4(28, 18, 19, 23),
		Vector4(-23, -25, 20, 14), Vector4(32, -27, 20, 18),
		Vector4(-28, -61, 23, 13), Vector4(35, -64, 20, 15)
	]
	var open_patches := [Vector4(-3, 19, 6, 5), Vector4(20, -6, 6, 7), Vector4(-45, 4, 8, 5), Vector4(3, -50, 6, 5)]
	var foreground_knolls := [Vector4(26.3, 13.25, 2.6, 1.65), Vector4(28.35, 15.9, 2.75, 1.4)]
	var tall_foreground := [Vector4(9.85, 23.5, 4.6, 2.85), Vector4(20.0, 20.0, 3.8, 2.35), Vector4(27.6, 16.3, 3.70, 2.60)]
	var meadow_tongues := [Vector4(16.2, 13.4, 5.3, 5.2), Vector4(24.9, 7.2, 7.4, 4.3), Vector4(29.5, .8, 4.6, 3.3)]
	# P34-D: four asymmetrical banks across the middle shelf. Their open saddle
	# remains wider than the path; each lobe has a lower grazed perimeter.
	var middle_stands := [Vector4(15.9, 6.8, 4.9, 6.4), Vector4(24.4, -6.8, 7.3, 5.2), Vector4(3.0, 11.0, 3.5, 5.1), Vector4(35.1, -15.4, 6.1, 4.2)]
	# Offsets from the winding path, not a continuous symmetrical border.
	# These tongues reclaim its broad short-grass shoulders while leaving the
	# central three metres and the space between communities visibly open.
	var shoulder_patches := [
		Vector4(4.5, 25, 3.0, 9.0), Vector4(-4.0, 9, 3.3, 8.0),
		Vector4(4.3, -8, 3.0, 9.0), Vector4(-4.6, -26, 3.6, 10.0),
		Vector4(4.8, -45, 3.3, 11.0), Vector4(-4.2, -64, 3.3, 10.0)
	]
	var tall_shoulders := [Vector4(5.1, 23, 2.5, 5.0), Vector4(-5.0, 5, 2.6, 5.5), Vector4(5.0, -9, 2.4, 6.0), Vector4(-5.2, -28, 2.7, 6.0)]
	var species_counts := PackedInt32Array([0, 0, 0])
	for cz in range(10):
		for cx in range(10):
			var base_x := -60.0 + float(cx) * 12.0
			var base_z := -75.0 + float(cz) * 12.0
			# Fewer, larger/legible clusters replace P08's 74k tiny tufts.
			var near_vista := base_x >= -12.0 and base_x < 36.0 and base_z >= 9.0 and base_z < 28.0
			var candidates := 1700 if near_vista else (830 if base_z > -12.0 else (590 if base_z > -35.0 else 340))
			var transforms: Array = [[], [], []]
			var colours: Array = [[], [], []]
			var custom: Array = [[], [], []]
			for candidate in range(candidates):
				var x := base_x + placement_rng.randf() * 12.0
				var z := base_z + placement_rng.randf() * 12.0
				var slope := _slope(terrain, x, z)
				if slope > 0.67:
					continue
				var terrain_weight := 1.0
				if terrain.has_method("vegetation_weight"):
					terrain_weight = clampf(terrain.vegetation_weight(x, z), 0.0, 1.0)
				if terrain_weight < 0.01:
					continue
				var path_x: float = terrain.path_center(z) if terrain.has_method("path_center") else 5.0 + 7.0 * sin((z + 12.0) * 0.032)
				var path_distance := absf(x - path_x)
				# Erosion and alternating long-grass tongues give each shoulder a
				# different edge. Low non-colliding basal plants can reach the tread.
				var side := signf(x-path_x)
				var edge_waviness := sin(z*.36+side*1.3)*.68 + sin(z*.75+x*.19)*.27
				var verge := smoothstep(.44,3.55,path_distance+edge_waviness)
				var shoulder_weight := _grass_patch_weight(x - path_x, z, shoulder_patches)
				var bank_x := x + .76 * sin(z * .27) + .42 * sin(z * .62 + x * .20)
				var bank_z := z + .77 * sin(x * .29) + .39 * sin(x * .68 + z * .31)
				var middle_stand := _grass_patch_weight(bank_x, bank_z, middle_stands)
				middle_stand *= smoothstep(3.3, 6.4, path_distance) * (1.0 - smoothstep(.34, .58, slope))
				# Keep original retention/species RNG decisions; authored stands modify only
				# accepted tufts below, after orientation draws, so other habitats stay fixed.
				var tongue := _grass_patch_weight(bank_x, bank_z, meadow_tongues)
				tongue *= smoothstep(3.3, 6.3, path_distance) * (1.0 - smoothstep(.30, .47, slope))
				var tall_weight := maxf(_grass_patch_weight(x, z, tall_patches), _grass_patch_weight(x - path_x, z, tall_shoulders) * 0.78)
				var meadow_weight := maxf(_grass_patch_weight(x, z, meadow_patches), shoulder_weight)
				var clearing := _grass_patch_weight(x, z, open_patches)
				var patch_strength := maxf(maxf(tall_weight, meadow_weight * 0.90), tongue * .84)
				var retention := lerpf(0.10, 0.95, patch_strength) * lerpf(1.0, 0.22, clearing) * terrain_weight
				retention *= lerpf(0.16,1.0,verge)
				if placement_rng.randf() > retention:
					continue
				var species := 0
				var choose := placement_rng.randf()
				if tall_weight > 0.18 and path_distance + edge_waviness > 3.25 and slope < 0.50 and choose < tall_weight * 0.90:
					species = 2
				elif meadow_weight > 0.15 and path_distance + edge_waviness > 1.82 and choose < 0.33 + meadow_weight * 0.56:
					species = 1
				var height_scale := placement_rng.randf_range(0.85, 1.18)
				if species == 0:
					height_scale *= lerpf(0.72, 1.12, meadow_weight) * lerpf(0.72, 1.0, verge)
				elif species == 2:
					var windrow := .5+.5*sin(z*.90 + x*.24 + 1.35*sin(x*.28))
					height_scale *= lerpf(.65,1.09,tall_weight)*lerpf(.86,1.12,windrow)
				var width_scale := placement_rng.randf_range(0.90, 1.19)
				var crosswind := .55 + sin(z*.13+x*.095)*.38
				var orientation := placement_rng.randf()*TAU if species == 0 else crosswind+placement_rng.randfn(0.0,.70)
				height_scale *= MeadowCommunities.clover_meadow_height(x, z)
				var high_sward := _grass_patch_weight(x,z,tall_foreground) if path_distance > 3.2 else 0.0
				var long_grass := maxf(high_sward, tongue * .95)
				if species == 0 and long_grass > .34 and slope < .42 and choose < .45 + .34 * long_grass:
					species = 1
					height_scale = maxf(height_scale,.91)
					orientation = crosswind + .55*sin(x*2.83+z*1.75)
				if species > 0 and path_distance > 3.2:
					var knoll := _grass_patch_weight(x, z, foreground_knolls)
					height_scale *= 1.0 + maxf(.40 * knoll, .78 * long_grass)
					width_scale *= 1.0 + maxf(.18 * knoll, .35 * long_grass)
				# Contiguous grazed openings between the wind-bent meadow tongues.
				# Retain deterministic placement of the other habitats.
				var clearing_edge := sin(x * .23 + z * .10 + .9 * sin(z * .31))
				var opening := smoothstep(-.5, .55, clearing_edge) * smoothstep(-9., 1., z) * smoothstep(-4., 7., x)
				opening *= 1.0 - (.76 if species > 0 else .26) * long_grass
				if middle_stand > .16:
					# Broad, bowed fans read as linked clumps rather than extra pinpricks.
					species = 1 if choose < .92 else 2
					height_scale = lerpf(.79, 1.58, middle_stand) * (.88 + .18 * sin(x * .67 + z * .29))
					width_scale = lerpf(1.50, 2.48, middle_stand)
					opening *= 1.0 - middle_stand * .96
				var basis := Basis(Vector3.UP, orientation).scaled(Vector3(width_scale, height_scale * lerpf(1., .62, opening), width_scale))
				var tint := placement_rng.randf_range(0.98, 1.025)
				# Preserve a coherent pigment shift within each meadow tongue.
				var warmth := tongue * lerpf(.38, 1.0, smoothstep(-.8, .9, sin(x * .26 + z * .19)))
				var wind_phase := placement_rng.randf()
				if wind_phase < opening * .91: continue
				if middle_stand > .16 and wind_phase < .20 * middle_stand: continue
				if Talus.excludes_grass(x,z) or MeadowCommunities.clears_base(x, z, species, wind_phase, herb_openings): continue
				transforms[species].append(Transform3D(basis, Vector3(x, terrain.ground_height(x, z) - 0.012, z)))
				colours[species].append(Color(tint, tint, tint, 1.0))
				# R stores species, G wind phase, B the warmth of the local community.
				custom[species].append(Color(float(species) / 2.0, wind_phase, -1.0 if middle_stand > .16 else warmth, 1.0))
			for species in range(3):
				if transforms[species].is_empty():
					continue
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.use_colors = true
				multi.use_custom_data = true
				multi.mesh = grass_meshes[species][(cx + cz + species) % 2]
				multi.instance_count = transforms[species].size()
				for index in range(multi.instance_count):
					multi.set_instance_transform(index, transforms[species][index])
					multi.set_instance_color(index, colours[species][index])
					multi.set_instance_custom_data(index, custom[species][index])
				var batch := MultiMeshInstance3D.new()
				batch.name = "Grass_%s_%02d_%02d" % [["short", "meadow", "arching"][species], cx, cz]
				batch.multimesh = multi
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(batch)
				species_counts[species] += multi.instance_count
	parent.set_meta("grass_tuft_count", species_counts[0] + species_counts[1] + species_counts[2])
	parent.set_meta("grass_species_counts", Array(species_counts))


static func _grass_patch_weight(x: float, z: float, patches: Array) -> float:
	var strongest := 0.0
	var warped_x := x + sin(z * 0.33) * 0.65 + sin(z * 0.71) * 0.22
	var warped_z := z + sin(x * 0.27) * 0.72
	for patch: Vector4 in patches:
		var dx := (warped_x - patch.x) / patch.z
		var dz := (warped_z - patch.y) / patch.w
		var distance_squared := dx * dx + dz * dz
		if distance_squared < 1.85:
			strongest = maxf(strongest, pow(clampf(1.0 - distance_squared / 1.85, 0.0, 1.0), 1.35))
	return strongest


static func _grass_mesh(rng: RandomNumberGenerator, material: Material, species: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var tuft_angle := rng.randf() * TAU
	var lean := Vector3(cos(tuft_angle), 0, sin(tuft_angle))
	if species == 0:
		# A short graze-tolerant tussock, with reclining outside leaves and a lifted core.
		for blade in range(7):
			var angle := tuft_angle + blade * 2.4 + rng.randf_range(-0.35, 0.35)
			var direction := Vector3(cos(angle), 0, sin(angle))
			var origin := direction * rng.randf_range(0.012, 0.065)
			var outer := blade < 4
			var height := rng.randf_range(0.19, 0.30) * (0.84 if outer else 1.0)
			var bend := rng.randf_range(0.52, 0.87) if outer else rng.randf_range(0.18, 0.42)
			_grass_blade(surface, origin, angle, height, rng.randf_range(0.011, 0.018), bend, 4, 0.28 if outer else 0.14)
	elif species == 1:
		# Two unequal blade fans share a foot, bowing in the prevailing direction.
		for blade in range(7):
			var second_fan := blade >= 4
			var fan_step := float(blade - 4) - 1.0 if second_fan else float(blade) - 1.5
			var opening := -0.72 if second_fan else 0.52
			var angle := tuft_angle + opening + fan_step * 0.43 + rng.randf_range(-0.17, 0.17)
			var origin := lean * (-0.056 if second_fan else 0.036)
			origin += Vector3(-lean.z, 0, lean.x) * rng.randf_range(-0.044, 0.044)
			var height := rng.randf_range(0.65, 0.91) * (1.0 - absf(fan_step) * 0.085)
			var bend := rng.randf_range(0.24, 0.49) + 0.09 * absf(fan_step)
			_grass_blade(surface, origin, angle, height, rng.randf_range(0.037, 0.057), bend, 6, rng.randf_range(0.21, 0.36))
	else:
		# A few young upright leaves rise above swept, arching shoulders.
		for blade in range(9):
			var angle := tuft_angle + blade * 2.4 + rng.randf_range(-0.32, 0.32)
			angle = lerp_angle(angle, tuft_angle, 0.19)
			var direction := Vector3(cos(angle), 0, sin(angle))
			var central := blade % 4 == 0
			var origin := direction * rng.randf_range(0.017, 0.083)
			var height := rng.randf_range(1.03, 1.33) if central else rng.randf_range(0.77, 1.10)
			var bend := rng.randf_range(0.22, 0.43) if central else rng.randf_range(0.59, 0.83)
			var droop := rng.randf_range(0.14, 0.23) if central else rng.randf_range(0.34, 0.50)
			_grass_blade(surface, origin, angle, height, rng.randf_range(0.024, 0.042), bend, 7, droop)
	return surface.commit()


static func _grass_blade(surface: SurfaceTool, origin: Vector3, angle: float, height: float, width: float, bend: float, steps: int, droop: float) -> void:
	var forward := Vector3(cos(angle), 0, sin(angle))
	var right := Vector3(-sin(angle), 0, cos(angle))
	var curl := sin(angle * 2.1 + height * 3.0)
	var rib_row := maxi(1, floori(float(steps - 1) * 0.42))
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for step in range(steps):
		var t := float(step) / float(steps - 1)
		var buried_sheath := .043 * (1.0 - smoothstep(0.0, .22, t))
		var centre := origin + Vector3.UP * (height * (t - droop * pow(t, 3.6)) - buried_sheath)
		centre += forward * height * bend * (0.22 * t + 0.88 * t * t)
		centre += right * curl * height * (0.14 * t * t * t - 0.07 * sin(PI*t))
		var width_axis := right.rotated(Vector3.UP, curl * 0.70 * t * t)
		# The blade fattens just above the sheath, then narrows into a curled thread.
		var w := width * (.27 + 1.05 * sin(PI * t)) * pow(1.0 - t, 1.18)
		var base_normal := (Vector3.UP + forward * (0.23 - 0.35 * t)).normalized()
		for lane in range(3):
			var lateral := float(lane - 1)
			var ridge := forward * w * 0.38 if lane == 1 else Vector3.ZERO
			points.append(centre + width_axis * lateral * w + ridge)
			normals.append((base_normal + width_axis * lateral * (0.32 - 0.12 * t)).normalized())
	# One folded cross section per blade adds just two triangles. Beyond the
	# shoulder, the slender tip twists freely and ends in a single vertex.
	for step in range(steps - 1):
		var a := step * 3
		var indices: Array
		if step == steps - 2:
			indices = [a, a + 4, a + 2]
		elif step + 1 == rib_row:
			indices = [a, a + 3, a + 4, a, a + 4, a + 2, a + 2, a + 4, a + 5]
		elif step == rib_row:
			indices = [a, a + 3, a + 1, a + 1, a + 3, a + 5, a + 1, a + 5, a + 2]
		else:
			indices = [a, a + 3, a + 2, a + 2, a + 3, a + 5]
		for index: int in indices:
			var t := float(floori(float(index) / 3.0)) / float(steps - 1)
			var u := float(index % 3) * 0.5
			surface.set_normal(normals[index])
			surface.set_uv(Vector2(u, t))
			var gradient := lerpf(0.88, 1.0, t)
			surface.set_color(Color(gradient, gradient, gradient, 1.0))
			surface.add_vertex(points[index])


static func _slope(terrain: Script, x: float, z: float) -> float:
	var dx: float = terrain.ground_height(x + 0.45, z) - terrain.ground_height(x - 0.45, z)
	var dz: float = terrain.ground_height(x, z + 0.45) - terrain.ground_height(x, z - 0.45)
	return Vector2(dx, dz).length() / 0.9
