extends RefCounted
## Original herb forms, in metres, for the meadow community batches.
## UV.y is wind compliance; COLOR contains the pigments of the actual organs.

const ROSETTE := 0
const OAT := 1
const FERN := 2
const CLOVER := 3
const SEDGE := 4

static func mesh(kind: int, variant: int, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20863 + kind * 6491 + variant * 1303
	match kind:
		ROSETTE: _rosette(surface, rng, variant)
		OAT: _oat(surface, rng, variant)
		FERN: _fern(surface, rng, variant)
		CLOVER: _clover(surface, rng, variant)
		SEDGE: _sedge(surface, rng, variant)
	return surface.commit()


static func _axis(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, pigment: Color, compliance: float) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1.0e-15:
		return
	normal = normal.normalized()
	if normal.y < 0.0:
		normal = -normal
	normal = (normal + Vector3.UP * 0.45).normalized()
	for point: Vector3 in [a, b, c]:
		st.set_normal(normal)
		# Per-face pigment is independent of the MultiMesh instance tint.
		st.set_uv(Vector2(pigment.b, clampf(point.y * compliance, 0.0, 1.0)))
		st.set_uv2(Vector2(pigment.r, pigment.g))
		st.set_color(pigment)
		st.add_vertex(point)


static func _stalk(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, end_radius: float, pigment: Color, compliance: float) -> void:
	var axis := (b - a).normalized()
	var tangent := axis.cross(Vector3.FORWARD)
	if tangent.length_squared() < 0.005:
		tangent = axis.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := axis.cross(tangent).normalized()
	for side in range(3):
		var angle := TAU * side / 3.0
		var next := angle + TAU / 3.0
		var off := tangent * cos(angle) + bitangent * sin(angle)
		var next_off := tangent * cos(next) + bitangent * sin(next)
		_face(st, a + off*radius, b + off*end_radius, a + next_off*radius, pigment, compliance)
		_face(st, b + off*end_radius, b + next_off*end_radius, a + next_off*radius, pigment, compliance)


static func _fold(st: SurfaceTool, previous: PackedVector3Array, current: PackedVector3Array, pigment: Color, compliance: float, sedge_fold: bool = false) -> void:
	var left_paint := pigment.darkened(0.065)
	if sedge_fold:
		left_paint = pigment * Color(.76,.87,.94)
	_face(st, previous[0], current[0], previous[1], left_paint, compliance)
	_face(st, previous[1], current[0], current[1], left_paint, compliance)
	_face(st, previous[1], current[1], previous[2], pigment, compliance)
	_face(st, previous[2], current[1], current[2], pigment, compliance)


static func _rosette(st: SurfaceTool, rng: RandomNumberGenerator, variant: int) -> void:
	var count := 7 + variant % 3
	var bearing := rng.randf() * TAU
	for leaf in range(count):
		# Outer leaves roll out onto the ground, the younger inner leaves stand up.
		var young := leaf >= count-2
		var axis := _axis(bearing + 2.39996 * leaf + rng.randf_range(-0.21,0.21))
		var side := Vector3.UP.cross(axis)
		var radius := rng.randf_range(0.18,0.35) if not young else rng.randf_range(0.08,0.18)
		var rise := rng.randf_range(0.13,0.22) if not young else rng.randf_range(0.20,0.33)
		var width := rng.randf_range(0.044,0.074) * (0.76 if young else 1.0)
		var twist := rng.randf_range(-0.4,0.4)
		var root := axis * rng.randf_range(0.0,0.025)
		var prev := PackedVector3Array([root, root, root])
		var leaf_color := Color(0.365,0.555,0.238).lerp(Color(0.58,0.717,0.276),rng.randf_range(0.08,0.76))
		# The alternating shoulder widths give a gently scalloped spoon silhouette.
		var widths := [0.20,0.68,0.64,1.0,0.87,0.68,0.0]
		for band in range(widths.size()):
			var t := float(band+1)/widths.size()
			var rib := root + axis * radius * t + Vector3.UP * rise * (sin(PI*t*0.72)-0.24*t*t)
			rib += side * (twist*radius*0.22*t*t)
			var half_width := width * float(widths[band])
			var edge := side * half_width + Vector3.UP * half_width * twist * t
			var fold := Vector3.UP * half_width * (0.26 + .07*variant)
			var curr := PackedVector3Array([rib-edge-fold,rib,rib+edge-fold])
			_fold(st,prev,curr,leaf_color.darkened(0.15*(1.0-t)),0.7)
			prev=curr


static func _pointed_leaf(st: SurfaceTool, base: Vector3, tip: Vector3, breadth: Vector3, lift: float, pigment: Color, compliance: float) -> void:
	var rib := base.lerp(tip,0.42) + Vector3.UP * lift
	var left := rib-breadth-Vector3.UP*breadth.length()*0.19
	var right := rib+breadth-Vector3.UP*breadth.length()*0.19
	_face(st,base,left,rib,pigment.darkened(.07),compliance)
	_face(st,left,tip,rib,pigment.darkened(.07),compliance)
	_face(st,base,rib,right,pigment,compliance)
	_face(st,rib,tip,right,pigment,compliance)


static func _oat(st: SurfaceTool, rng: RandomNumberGenerator, variant: int) -> void:
	var lean := _axis(rng.randf()*TAU)
	var blade_paint := Color(0.47,0.58,0.185)
	var culm := Color(0.595,0.64,0.278)
	var seed_color := Color(0.817,0.719,0.374)
	for leaf in range(5):
		var direction := _axis(leaf*2.4+rng.randf_range(-0.5,0.5))
		var base := direction*rng.randf_range(0.0,0.05)
		var end := base+direction*rng.randf_range(0.19,0.41)+Vector3.UP*rng.randf_range(0.21,0.42)
		_pointed_leaf(st,base,end,Vector3.UP.cross(direction)*rng.randf_range(.018,.028),.13,blade_paint,.86)
	for stem in range(2 + variant % 2):
		var f := _axis(stem*2.27 + rng.randf_range(-.60,.60))
		var base := f*rng.randf_range(0.015,0.055)
		var height := rng.randf_range(0.77,1.12) * (0.85 if stem == 2 else 1.0)
		var knee := base + Vector3.UP*height*.54 + f*.055
		var head := base + Vector3.UP*height*.94 + f*.105 + lean*.105
		_stalk(st,base,knee,.010,.008,blade_paint,.90)
		_stalk(st,knee,head,.008,.006,culm,.90)
		_pointed_leaf(st,knee,knee + f*.24 + Vector3.UP*.19,Vector3.UP.cross(f)*.022,.06,blade_paint,.90)
		var node := head
		var branches := 4 + stem % 2
		for k in range(branches):
			var t := float(k+1)/branches
			var branch := _axis(k*2.4+rng.randf_range(-.4,.4))
			var next_node := head + lean*.14*t + Vector3.UP*height*(.12*t-.105*t*t)
			_stalk(st,node,next_node,.005,.0035,culm,.90)
			var limb := branch * rng.randf_range(.065,.15) * (1.0-.3*t) + lean*.045
			var joint := node + limb*.55 + Vector3.UP*.018
			var point := node + limb - Vector3.UP*rng.randf_range(.037,.092)
			_stalk(st,node,joint,.004,.003,culm,.90)
			_stalk(st,joint,point,.003,.0025,seed_color,.90)
			_spikelet(st,point,branch,seed_color,rng)
			node = next_node
		_spikelet(st,node,lean,seed_color,rng)


static func _spikelet(st: SurfaceTool, pos: Vector3, direction: Vector3, pigment: Color, rng: RandomNumberGenerator) -> void:
	var across := Vector3.UP.cross(direction)
	var length := rng.randf_range(.068,.099)
	var tip := pos + direction*length*.40 - Vector3.UP*length
	var bulge := pos.lerp(tip,.41)
	var grain := rng.randf_range(.019,.029)
	# Two uneven glumes turn towards different sides of the panicle.
	var ring := PackedVector3Array([
		bulge+across*grain,
		bulge+direction*grain*.80+Vector3.UP*grain*.27,
		bulge-across*grain*.78,
		bulge-direction*grain*.70-Vector3.UP*grain*.22
	])
	for i in range(4):
		var next := (i+1)%4
		var shade := pigment.darkened(.16 if i>=2 else .035)
		_face(st,pos,ring[i],ring[next],shade.lerp(Color(.94,.835,.525), .41 if i==0 else .06),.90)
		_face(st,tip,ring[next],ring[i],shade,.90)
	var awn_tip := tip + direction*.047 - Vector3.UP*.034
	_face(st,tip-across*.0035,awn_tip,tip+across*.0035,pigment,.90)


static func _fern(st: SurfaceTool, rng: RandomNumberGenerator, variant: int) -> void:
	var count := 4 + variant%2
	var bearing := rng.randf()*TAU
	for frond in range(count):
		var direction := _axis(bearing + frond*2.4 + rng.randf_range(-.43,.43))
		var side := Vector3.UP.cross(direction)
		var length := rng.randf_range(.37,.55)
		var height := rng.randf_range(.30,.56) * (.82 if frond==0 else 1.)
		var width := rng.randf_range(.102,.155)
		var base := direction*.033
		var sweep := rng.randf_range(-.18,.18)
		var hook := rng.randf_range(.16,.30)
		var old := base
		var pairs := 5 + (frond+variant)%3
		for row in range(pairs):
			var t := float(row+1)/(pairs+1)
			var rib := base+direction*length*pow(t,1.34)+Vector3.UP*height*(sin(t*PI*.64)+.09*t-hook*pow(t,4.0))
			rib += side*length*sweep*t*t
			_stalk(st,old,rib,.007*(1.-.51*t),.0055*(1.-.54*t),Color(.254,.48,.295),1.04)
			for sign_value in [-1.,1.]:
				var span := width*pow(sin(t*PI),.6)*(1.17-.41*t)*rng.randf_range(.88,1.1)
				var smallbase := rib + direction*length*(.018 if sign_value>0 else -.012)
				var tip := smallbase + side*float(sign_value)*span + direction*span*(.46 + .19*t) + Vector3.UP*span*(.17-.55*t)
				var paint := Color(.135,.342,.249).lerp(Color(.332,.562,.359),.10+.54*t+.30*rng.randf())
				_pointed_leaf(st,smallbase,tip,direction*span*rng.randf_range(.26,.33),span*.24,paint,1.04)
			old = rib
		var end := base+direction*length+side*length*sweep+Vector3.UP*height*(.995-hook)
		_pointed_leaf(st,old,end,side*width*.23,.011,Color(.309,.557,.375),1.04)
	# A curled young crozier breaks the starburst in the center.
	var crozier := _axis(bearing+1.1)
	var h := rng.randf_range(.24,.44)
	var crown := Vector3.UP*h + crozier*.026
	var elbow := crown + crozier*.047 + Vector3.UP*.026
	var rolled := elbow + crozier*.015 - Vector3.UP*.043
	_stalk(st,Vector3.ZERO,crown,.009,.008,Color(.38,.55,.248),1.04)
	_stalk(st,crown,elbow,.008,.008,Color(.45,.60,.27),1.04)
	_stalk(st,elbow,rolled,.008,.005,Color(.48,.62,.28),1.04)

static func _clover(st: SurfaceTool, rng: RandomNumberGenerator, variant: int) -> void:
	var bearing := rng.randf() * TAU
	var trail := _axis(bearing)
	var stalk_count := 4 + variant % 2
	var stem_color := Color(.318,.515,.299)
	var last_crown := Vector3.ZERO
	for stem in range(stalk_count):
		var t := float(stem)/float(stalk_count-1)
		# Successive leaf stalks grow from the same runner, with young, smaller heads near its tip.
		var crown := trail * (.19*t) + Vector3.UP*.006 + trail.cross(Vector3.UP)*sin(t*PI)*.035
		if stem > 0:
			_stalk(st,last_crown,crown,.0033,.0029,stem_color,.72)
		last_crown = crown
		var direction := _axis(bearing + stem*2.40 + rng.randf_range(-.33,.33))
		var rise := rng.randf_range(.139,.214) * (1.0-.14*t)
		var extension := rng.randf_range(.056,.124)
		var elbow := crown + direction*extension*.43 + Vector3.UP*rise*.64
		var head := crown + direction*extension + Vector3.UP*rise
		_stalk(st,crown,elbow,.0036,.0032,stem_color,.72)
		_stalk(st,elbow,head,.0032,.0022,stem_color,.72)
		var azimuth := bearing + stem*1.77 + rng.randf_range(-.4,.4)
		var radius := rng.randf_range(.067,.105)*(1.0-.12*t)
		# One head tilts as a unit, with slight independent movement at each leaflet.
		var slope := _axis(azimuth+.57) * rng.randf_range(.20,.72)
		for i in range(3):
			var axis := _axis(azimuth + TAU*float(i)/3.0 + rng.randf_range(-.09,.09))
			var length := radius*rng.randf_range(.90,1.04)
			var paint := Color(.259,.518,.352).lerp(Color(.456,.669,.401),rng.randf_range(.1,.74))
			_clover_leaflet(st,head,axis,length,slope,paint)


static func _clover_leaflet(st: SurfaceTool, head: Vector3, axis: Vector3, length: float, slope: Vector3, paint: Color) -> void:
	var across := Vector3.UP.cross(axis)
	# Rounded paired lobes are separated by a shallow notch. The subtle
	# difference in pigment across the folded surface brings out the midrib.
	var outline := [
		Vector2(.16,-.10), Vector2(.39,-.35), Vector2(.66,-.48), Vector2(.85,-.45),
		Vector2(.98,-.29), Vector2(1.00,-.15), Vector2(.91,0),
		Vector2(1.00,.15), Vector2(.98,.29), Vector2(.85,.45),
		Vector2(.66,.48), Vector2(.39,.35), Vector2(.16,.10)
	]
	var root := head + axis*length*.045
	var centre_offset := axis*length*.56
	var rib := root + centre_offset + Vector3.UP*(.15*length+slope.dot(centre_offset))
	var previous := root
	for p: Vector2 in outline:
		var off := (axis*p.x + across*p.y)*length
		var lift := .09*sin(PI*p.x)+.065*absf(p.y)-.08*p.x*p.x
		var current := root + off + Vector3.UP*(length*lift+slope.dot(off))
		var shade := paint.darkened(.055) if p.y<0 else paint
		_face(st,rib,previous,current,shade,.72)
		previous = current
	_face(st,rib,previous,root,paint,.72)

# Uneven fans of wide arching leaves. Elevation, opening angle and droop
# vary within the crown; the cut silhouette stays readable along the bank.
static func _sedge(st: SurfaceTool, rng: RandomNumberGenerator, variant: int) -> void:
	var fan := -.55 + .40 * variant
	var count := 5 + variant
	for leaf in range(count):
		var position := float(leaf) / (count - 1)
		var young := 1.0 - absf(position * 2.0 - 1.0)
		var angle := fan + lerpf(-1.85,1.74,position) + rng.randf_range(-.22,.22)
		var forward := _axis(angle)
		var side := Vector3.UP.cross(forward)
		var height := lerpf(.39,.72,young) * rng.randf_range(.78,1.15)
		var reach := lerpf(.53,.25,young) * rng.randf_range(.87,1.13)
		var width := rng.randf_range(.061,.094)
		var root := side * (.5-position) * .09
		var previous := PackedVector3Array([root, root, root])
		var pigment := Color(.205,.458,.240).lerp(Color(.407,.617,.309),.22+.27*young+.21*rng.randf())
		var side_curl := rng.randf_range(-.10,.10)
		for strip in range(1, 6):
			var t := float(strip) / 5.0
			var rib := root + forward * reach * pow(t,1.65) + side * side_curl * t * t
			rib.y += height * (1.54*t - (.77-.18*young)*pow(t,2.55))
			var half_width := width * pow(maxf(0.0,sin(PI*t)),.71) * (1.10-.22*t)
			var edge := side * half_width + Vector3.UP * half_width * (.32 - position*.43)
			var keel := Vector3.UP * half_width * .38
			var current := PackedVector3Array([rib-edge-keel,rib,rib+edge-keel])
			_fold(st,previous,current,pigment.lerp(Color(.628,.716,.345),.43*t*t),1.4,true)
			previous = current
