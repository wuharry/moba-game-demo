extends RefCounted
## The walkable meadow, cliff faces and crowns share a single triangulated surface.
## Stations describe a transverse geological section (x, front z, rise, face depth).

const X_MIN := -76.0
const X_MAX := 76.0
const Z_MIN := -122.0
const Z_MAX := 60.0
const COLUMN_STEP := .5
const BANDS := [
	[Vector4(-76,7,10,8),Vector4(-64,5,11,8),Vector4(-53,1,9,6),Vector4(-47,4,8,8),Vector4(-43.5,-1.3,6.5,7.8),Vector4(-39.5,-6.3,5.3,9),Vector4(-36,-5,8.6,6),Vector4(-30,0,10.7,7),Vector4(-25,-2,9.1,6),Vector4(-21,-11,5.8,6),Vector4(-16,-8,8.1,7),
	 Vector4(-12.5,-8.8,7.4,6),Vector4(-8,-11.4,6.2,5.7),
	 Vector4(-6,-17.8,4,9.5),Vector4(-4.2,-23.0,2.4,11.8),
	 Vector4(-1.2,-20.6,3.8,8),Vector4(2.2,-17.6,4.9,4.7),Vector4(6.6,-16.5,4.45,4.5),
	 Vector4(9,-20.3,3.3,6.8),Vector4(12.4,-24.0,1.55,10.6),
	 Vector4(16,-24.1,2.4,8.4),Vector4(19.4,-22.7,3.25,7.4),Vector4(23.9,-21.5,2.50,8.9),
	 Vector4(27,-20.8,1.35,14),Vector4(39,-21,2,12),Vector4(51,-20,3.7,8),Vector4(63,-24,2.3,10),Vector4(76,-19,1.6,12)],
	[Vector4(-76,-43,10,7),Vector4(-58,-39,9,7),Vector4(-48,-43,8.3,8),Vector4(-40,-40,10,6),Vector4(-29,-47,9.5,6),Vector4(-22,-44,7.4,6.3),Vector4(-16,-39,10.9,6),Vector4(-11,-40,9.8,6),Vector4(-8,-36,7.1,5),Vector4(-5,-32,8.4,5),Vector4(2,-35,8.8,5.4),Vector4(9,-41,4.1,14),Vector4(12,-43,2.8,17),Vector4(16,-47,2,16),Vector4(23,-48,5.8,12),Vector4(30,-50,9,5),Vector4(38,-44,11.3,6),Vector4(43,-47,9.7,7),Vector4(47,-53,7.9,6),Vector4(51,-51,10.8,8),Vector4(57,-49,9.8,7),Vector4(67,-57,9.3,5),Vector4(76,-54,7.4,6)],
	[Vector4(-76,-79,9.1,7),Vector4(-62,-81,7,5),Vector4(-52,-74,9.2,6),Vector4(-41,-77,10.3,7),Vector4(-32,-73,8.9,6.5),Vector4(-18,-83,6.9,7),Vector4(-5,-79,5.1,9),Vector4(7,-84,3.2,12),Vector4(19,-92,4,10),Vector4(31,-86,6.9,6),Vector4(42,-88,8.7,7),Vector4(56,-79,9.7,8),Vector4(69,-83,8.9,7),Vector4(76,-76,8.1,6)]
]
# x-position, half-width, depth and slant of each break. Their differing sizes
# leave broad planes between adjacent fissures, and no seam can open the mesh.
const JOINTS := [
	[Vector4(-58,2.9,1.8,2.8), Vector4(-43,3.5,1.8,-4.3),Vector4(-32,4.6,1.35,3.6),Vector4(-19,1.7,2.1,2.3),Vector4(-8,2.5,1.2,-1.4),Vector4(2,2,1.1,-1.8)],
	[Vector4(-55,2.5,2.1,-2.4),Vector4(-31,3.1,1.8,3.4),Vector4(-15,2.1,1.7,-3),Vector4(-5,2.3,2.9,2.4),Vector4(3,1.9,1.9,1.4),Vector4(35,2.2,3,-2.2),Vector4(47,2.3,2.4,3.4),Vector4(60,1.8,2,-2)],
	[Vector4(-48,2.8,2.3,-2.1),Vector4(-28,1.8,2.2,2),Vector4(-14,2.2,2,2.4),Vector4(34,1.8,2.6,-2.9),Vector4(51,2.8,2.1,3.1)]
]
# Embedded low rock outcrops. The shape, its contact with the ground and the
# interpolation of its material are all evaluated on the same terrain surface.
const OUTCROPS := [Vector4(-40,9,6.9,2.8),Vector4(-32,8,4.7,1.6),Vector4(-18,0.8,4.8,1.1),Vector4(-9,-1.5,3.4,1.3),Vector4(3,-3.8,3,1.1),Vector4(29,-13,3.3,1.3),Vector4(40,-20,4.2,1.6),Vector4(5,-26,5.3,2.1),Vector4(-11,-29,4.8,1.9),Vector4(39,-38,6.1,2.5),Vector4(-42,-27,5.4,1.9)]
const SECTIONS := [0.0,.045,.28,.60,.88,1.0]
const DEPTH := [0.0,.10,.34,.62,.85,1.0]
const CLEARANCE_ROWS := 78
static var _columns: Array = []
static var _prepared := false


static func path_center(z: float) -> float:
	var approach := 5.0 + 14.0 * exp(-pow((z + 23.0) / 27.0, 2.0)) - 3.0 * sin(z * .073)
	var upper_pass := 17.0 - 2.5 * sin((z + 44.0) * .07)
	var river_bend := exp(-pow((z + 19.0) / 17.0, 2.0))
	var high_bend := exp(-pow((z + 68.0) / 14.0, 2.0))
	return lerpf(approach, upper_pass, smoothstep(32.,43.,-z)) + 10.0 * river_bend - 8.0 * high_bend


# The western outcrop is the exposed end of a single raised table, with two
# different bench levels. Its inside end fades before the P10 toe inspection.
static func _west_table_rise(x: float) -> float:
	var headland := smoothstep(19.0,28.5,-x)
	var upper_step := smoothstep(37.5,41.5,-x)
	return headland * (4.85 + 1.65*upper_step + .36*sin(x*.17))


static func _station(x: float, index: int) -> Vector3:
	var stations: Array = BANDS[index]
	for i in range(1, stations.size()):
		var right: Vector4 = stations[i]
		if x <= right.x:
			var left: Vector4 = stations[i - 1]
			var t := clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
			var v := left.lerp(right, t)
			if index == 0 and x < -19.0:
				var flank := smoothstep(19.0,28.5,-x)
				# The almost upright face broadens at the projecting headland.
				v.z += _west_table_rise(x)
				v.w *= lerpf(1.0,.61,flank)
			return Vector3(v.y, v.z, v.w)
	var last: Vector4 = stations[-1]
	return Vector3(last.y,last.z,last.w)


static func _break_depth(x: float, band: int, t: float) -> float:
	var recess := 0.0
	for joint: Vector4 in JOINTS[band]:
		var cross_distance := absf(x - joint.x - joint.w * (t - .4)) / joint.y
		recess = maxf(recess, maxf(1.0 - cross_distance, 0.0) * joint.z)
	return recess


static func _section_position(x: float, band: int, row: int) -> Vector2:
	var s := _station(x, band)
	var t: float = SECTIONS[row]
	var depth: float = DEPTH[row]
	var shoulder := maxf(0.0,1.0-absf(x-(float(band)*8.0-29.0))/8.0)
	var across := sin(x*.17 + band*3.3) + .48*sin(x*.29+band)
	var recess := _break_depth(x,band,t)
	var z := s.x + (.64-depth)*s.z
	z += sin(PI*t)*(.49*across+shoulder*1.5) - recess * (.40+.36*sin(PI*t))
	var relief := s.y*t + sin(PI*t)*(.43*across - .33*recess)
	# Erosion has removed the upper lip in a broad diagonal gully. Its
	# mouth widens upwards and the side continues down to a rock shoulder.
	var cleft_x := [-21.0,-9.5,42.0]
	var cut := maxf(0.0,1.0-absf(x-float(cleft_x[band])-(t-.45)*4.5)/(2.1+2.8*t))
	z-=cut*(2.3+1.1*t)
	if band == 0:
		# Two connected limestone benches. Their heads continue into the
		# same grass terrace; the basal ramp remains in the existing section.
		var west_panel := smoothstep(-20.0,-15.0,x) * (1.0-smoothstep(-7.3,-4.0,x))
		var east_panel := smoothstep(-5.0,-1.5,x) * (1.0-smoothstep(4.5,8.0,x))
		var bench := maxf(west_panel, east_panel*.78)
		z -= bench * (1.0-t) * (1.37 + .38 * sin(t*PI))
		z += t * (west_panel*2.12 + east_panel*1.32)
		relief += t * (west_panel*1.62 + east_panel*1.02)
		# A lapped edge interrupts the shaded middle without separating the mesh.
		var bedding := t + .011*x
		var ledge := (1.0-smoothstep(.027,.12,absf(bedding-.54)))
		z += ledge * (.48*west_panel + .35*east_panel)
		var fold := _middle_cliff_fold(x, t)
		z += fold.x
		relief += fold.y
	if band == 0 and x < -19.0:
		var flank := smoothstep(19.0,28.5,-x)
		var first_fault := 1.0-smoothstep(.70,4.6,absf(x+39.8+(t-.46)*3.1))
		var second_fault := 1.0-smoothstep(.55,2.95,absf(x+28.9-(t-.40)*2.3))
		# The inner joint opens into a talus chute at the toe. At the crown a
		# solid bed bridges part of that chute instead of ending in one knife edge.
		var rim := smoothstep(.30,.86,t)
		var cleft := maxf(first_fault,second_fault*lerpf(.77,.38,rim))
		# Recesses cut the plan itself. The toe stays splayed, so each fault
		# opens upward beside the face of the adjoining buttress.
		z -= flank * cleft * (1.5+5.5*smoothstep(.0,.72,t))
		relief -= flank * cleft * (.62*t + 1.18*sin(PI*t))
	return Vector2(z, relief)


# Offset two bedding plates on the same solid wall. Finite, sloping faults
# bound the plates; shared terrain rows also move the collision and grass roots.
static func _middle_cliff_fold(x: float, t: float) -> Vector2:
	var east := x+1.10-1.28*(t-.68)
	var east_plate := smoothstep(-2.55,-1.2,east)*(1.0-smoothstep(1.75,3.25,east))
	var east_joint := 1.0-smoothstep(.26,1.43,absf(east+2.72))
	var upper_profile := smoothstep(.66,.88,t)
	var upper_strike := x+17.2+2.8*(t-.84)
	var upper_plate := smoothstep(-5.3,-2.9,upper_strike)*(1.0-smoothstep(2.45,4.05,upper_strike))
	var lower_strike := x+10.30-3.7*(t-.58)
	var lower_plate := smoothstep(-3.10,-1.55,lower_strike)*(1.0-smoothstep(.62,1.72,lower_strike))
	var lower_profile := smoothstep(.18,.56,t)*(1.0-smoothstep(.64,.90,t))
	# The upper ledge ends over a diagonal recess. Its lower bed breaks
	# forward to the east, so their profiles are distinct at the main camera.
	var cut_strike := x+13.55+4.0*(t-.67)
	var cut := (1.0-smoothstep(.40,1.92,absf(cut_strike)))
	cut *= smoothstep(.22,.60,t)*(1.0-.56*smoothstep(.82,1.0,t))
	var edge := upper_profile*upper_plate*(1.0-.32*smoothstep(.88,1.0,t))
	var offset := 1.36*edge + 2.18*lower_plate*lower_profile - 1.85*cut
	offset += 1.03*east_plate*smoothstep(.40,.91,t) - .98*east_joint*smoothstep(.12,.69,t)
	var lift := .30*upper_profile*upper_plate + .62*lower_plate*lower_profile - .66*cut
	lift += smoothstep(.40,.91,t)*(.43*east_plate-.33*east_joint)
	return Vector2(offset,lift)


static func cliff_foot_z(x: float) -> float:
	return _section_position(x,0,0).x


# Oblique strata that surface in the meadow and rise into the primary cliff.
# Each has a low toe, angled ridge and steep rear break, all cut on the same
# vertex lattice as the grass and escarpment so no independent cap can float.
# centre x,z, half-length, half-width; followed by direction x,z and ridge rise.
const BUTTRESSES := [
	[Vector4(-24.0,1.0,14.6,6.9),Vector3(.72,-.69,5.8)],
	[Vector4(-43.2,3.8,8.8,4.1),Vector3(-.62,-.78,3.75)],
	[Vector4(-13.9,-3.7,6.4,2.5),Vector3(.41,-.91,2.1)],
	[Vector4(-7.4,-32.8,9.6,6.6),Vector3(.71,-.70,4.2)],
	[Vector4(34.8,-41.1,10.0,4.1),Vector3(-.82,-.57,4.3)],
	[Vector4(51.5,-44.1,7.1,3.7),Vector3(-.29,-.96,2.9)],
	[Vector4(-35.0,-66.5,7.8,3.8),Vector3(.73,-.68,3.2)]
]


# The wall sheds a broken, west-to-east bed at the central bend. Each exposure
# has a planar top and several different side cuts; adjacent pieces join through
# their common ground envelope. Dimensions are half-length and half-depth.
const BEND_STONES := [
	# Three resistant beds reach the valley at different depths. Space between
	# their ends is the continuation of the two gullies in the first section.
	[Vector4(-11.3,-15.25,8.75,4.85),Vector3(-.36,3.55,.28)],
	[Vector4(-8.7,-11.65,4.75,2.6),Vector3(.48,2.30,.23)],
	[Vector4(2.0,-18.9,10.1,4.65),Vector3(-.21,5.30,-.16)],
	[Vector4(6.5,-13.3,4.20,3.40),Vector3(.65,3.65,-.39)],
	[Vector4(20.2,-24.4,12.0,4.25),Vector3(.18,4.55,-.20)],
	[Vector4(20.4,-18.3,7.25,3.70),Vector3(.48,2.85,-.22)],
	# Low dipping toes alternate between grass, limestone and shadow at eye height.
	[Vector4(-.8,-7.65,4.65,2.40),Vector3(.61,2.55,-.38)],
	[Vector4(8.3,-9.15,3.70,2.45),Vector3(.70,2.80,.39)],
	[Vector4(15.6,-11.0,3.30,2.35),Vector3(-.60,1.95,-.31)],
	[Vector4(4.1,-4.0,2.85,1.75),Vector3(-.27,.99,-.20)]
]

# An older bench on the opposite side overlaps the first one in the master
# view. The trail remains on its west flank, while the upper meadow returns
# into view beyond the brow. The ledges join the surrounding heightfield.
const HIGH_STONES := [
	[Vector4(37.6,-69.8,17.0,9.4),Vector3(.15,4.35,.06)],
	[Vector4(26.4,-70.0,11.5,7.55),Vector3(-.20,6.5,.14)],
	[Vector4(19.9,-68.5,6.95,6.0),Vector3(-.43,5.55,-.16)],
	[Vector4(22.8,-63.1,6.7,2.9),Vector3(-.44,2.65,-.26)],
	[Vector4(16.8,-65.5,2.9,2.4),Vector3(.36,1.65,-.18)]
]


# Shallow, laterally extended bedding across the trail to the east. Its
# stepped ledges stay on the far bank of the open, playable turnout.
const EAST_BANK_STONES := [
	[Vector4(42.1,-27.3,9.5,4.55),Vector3(.33,3.05,-.16)],
	[Vector4(49.8,-32.1,8.6,4.8),Vector3(-.15,4.70,.13)],
	[Vector4(38.3,-23.9,4.15,2.35),Vector3(.50,1.57,.24)]
]

# Partly buried limestone beds emerge on opposite sides of the lower walk.
const LOWER_MEADOW_BEDS := [
	[Vector4(-1.4, 4.2, 6.7, 2.7), Vector3(-.32, 1.34, .16)],
	[Vector4(3.4, 2.0, 3.0, 1.6), Vector3(-.19, .65, .13)],
	[Vector4(24.8, 2.7, 6.2, 2.7), Vector3(.34, 1.22, -.41)],
	[Vector4(27.25, 4.35, 2.95, 1.42), Vector3(.48, .48, -.16)]
]

static func _bend_spur(x: float, z: float) -> Vector2:
	var pieces: Array
	if z > -1.5 and z < 11.0 and x > -11.0 and x < 32.0:
		pieces = LOWER_MEADOW_BEDS
	elif x >= -25. and x <= 29. and z >= -32. and z <= -2.:
		pieces = BEND_STONES
	elif x >= 32. and x <= 61. and z >= -40. and z <= -18.:
		pieces = EAST_BANK_STONES
	elif x >= 12. and x <= 57. and z >= -84. and z <= -57.:
		pieces = HIGH_STONES
	else:
		return Vector2(0., 1.)
	var rise := 0.0
	var turf := 1.0
	for piece: Array in pieces:
		var span: Vector4 = piece[0]
		var cut: Vector3 = piece[1]
		var dx := x - span.x
		var dz := z - span.y
		var u := (dx + cut.x * dz) / span.z
		var v := (dz - cut.x * dx) / span.w
		# Stagger joint orientations, cap heights and apron widths; the
		# contact is always a continuous part of the walkable surface.
		var edge := maxf(maxf(absf(u)*.94,absf(v)*.88), maxf(absf(.77*u+.59*v),absf(.55*u-.78*v)))
		if edge >= 1.0:
			continue
		var cap := .88 + cut.z*u - .13*v
		var flank := (1.-edge)*(2.10 + .42*u + .40*v)
		if pieces == EAST_BANK_STONES:
			flank *= 1.68
		elif pieces == LOWER_MEADOW_BEDS:
			flank *= 1.38
			if span.x > 20.0:
				# The high end shows a bed face. The long eastern tongue dips into soil.
				flank *= lerpf(1.20, .54, smoothstep(-.60,.85,u))
		var lift := cut.y * minf(flank,cap)
		if lift > rise:
			rise = lift
			var apron := smoothstep(.87,1.,edge)
			# Weathering leaves a narrow grass brow and larger connected
			# areas on level, rear shoulders, with exposed stone to the south.
			var brow := smoothstep(cap-.105,cap+.075,flank)
			var soil := smoothstep(.18,.91,.63-.47*v+.17*u+.10*sin(x*.56+z*.32))
			turf = maxf(apron, brow*soil) if cut.y>3.5 or pieces == LOWER_MEADOW_BEDS else apron
	return Vector2(rise,turf)


# Local broken limestone at the headland base. Slabs have authored axes,
# top tilt and a cut across one shoulder. None is a separate overlapping mesh.
const WEST_TALUS := [
	# center x/z, half-length/width; unit direction x/z, rise, cap pitch
	[Vector4(-47.0,2.0,9.4,4.2),Vector4(.87,-.49,4.9,.19)],
	[Vector4(-37.0,1.1,8.3,4.4),Vector4(.57,-.82,5.9,.35)],
	[Vector4(-30.8,2.35,7.25,3.85),Vector4(.50,-.866,6.15,.44)],
	[Vector4(-25.8,2.7,8.85,4.65),Vector4(.49,-.872,7.95,.48)],
	[Vector4(-26.8,8.1,4.0,2.35),Vector4(.91,-.416,2.15,-.20)],
	[Vector4(-21.55,6.4,3.75,2.2),Vector4(.70,-.714,2.50,.28)],
	[Vector4(-24.3,10.45,2.30,1.55),Vector4(.58,-.815,.88,.13)],
	# Exposed dip slopes lean down toward the lower meadow. In an oblique
	# camera the splayed upper faces remain visible in front of the dark scarp.
	[Vector4(-25.6,4.25,10.1,4.95),Vector4(.58,-.815,7.6,.67),Vector2(-.35,3.05)],
	[Vector4(-20.45,4.25,7.50,3.85),Vector4(.22,-.976,6.5,.64),Vector2(-.46,3.18)],
	[Vector4(-15.90,3.7,5.15,3.60),Vector4(-.22,-.976,3.55,.57),Vector2(-.31,2.80)]
]

static func _west_talus(x: float,z: float,covering_beds: float) -> Vector2:
	var high := 0.0
	var cover := 1.0
	for piece: Array in WEST_TALUS:
		var span: Vector4 = piece[0]
		var axis: Vector4 = piece[1]
		var dx := x-span.x
		var dz := z-span.y
		var u := (dx*axis.x+dz*axis.y)/span.z
		var v := (-dx*axis.y+dz*axis.x)/span.w
		var hull := maxf(maxf(-u,.87*u),maxf(absf(v-.12*u),maxf(.71*u+.66*v,-.78*u-.59*v)))
		if hull >= 1.0: continue
		var cut := Vector2(-.16,2.12)
		if piece.size() == 3: cut=piece[2]
		var top := .80 + axis.w*u + cut.x*v
		var flank := (1.0-hull) * (cut.y+.72*u+.25*v)
		if piece == WEST_TALUS[0] and v > .35:
			# Eroded southern foot: the bed eases into the lower meadow
			# before its main plane climbs to the original unmodified crest.
			flank *= lerpf(1.0,smoothstep(0.0,.48,flank),smoothstep(.35,.62,v))
		var h := axis.z*minf(top,flank)
		if piece.size()==3:
			# Roll the battered arris through a finite bevel, and ease into
			# the valley floor where this body feathers out.
			var radius := .25
			var overlap := maxf(radius-absf(top-flank),0.0)/radius
			h = axis.z*maxf(0.0,minf(top,flank)-overlap*overlap*radius*.25)
			h *= smoothstep(.0, .85, h)
			h -= covering_beds
		if h <= high: continue
		high = h
		var grass_seam := smoothstep(.89,1.,hull)
		cover = maxf(grass_seam,.32*smoothstep(top,top+.20,flank)*smoothstep(.50,.92,-v))
	return Vector2(high,cover)


# Solve v-.12*u=contour for world z on the first slab's long southern face.
# Following the rock edge with several mesh rows prevents it from cutting a
# different lattice diagonal in every column and exposing a comb of triangles.
static func _west_foot_contour_z(x: float,contour: float) -> float:
	var span: Vector4 = WEST_TALUS[0][0]
	var axis: Vector4 = WEST_TALUS[0][1]
	var dx_factor := -axis.y/span.w-.12*axis.x/span.z
	var dz_factor := axis.x/span.w-.12*axis.y/span.z
	return span.y+2.3+(contour-dx_factor*(x-span.x))/dz_factor


static func _valley_floor(x: float,z: float) -> float:
	var h := .36 + .79*sin(x*.046 + z*.023) + .86*sin(z*.064 - x*.029)
	h += 1.78*exp(-pow((x-32.0)/18.0,2.0)-pow((z-12.0)/20.0,2.0))
	h += .78*exp(-pow((x+22.0)/16.0,2.0)-pow((z-15.0)/13.0,2.0))
	return h


static func _surface_base(x: float,z: float) -> Vector3:
	var h := _valley_floor(x,z)
	var cover := 1.0
	for o: Vector4 in OUTCROPS:
		var dx := (x-o.x)/o.z
		var dz := (z-o.y)/(.61*o.z) + .43*dx
		var radius := maxf(maxf(absf(dx)*.81, absf(dz)*.86), (.77*absf(dx+.32*dz)+.58*absf(dz-.15*dx)))
		if radius>=1.0:continue
		var shape := minf((1.0-radius)*1.65, .90+.16*dx-.09*dz)
		h+=o.w*shape
		cover=minf(cover,smoothstep(.81,.97,radius))
	var old_buttress_h := 0.0
	var old_buttress_cover := 1.0
	for bed: Array in BUTTRESSES:
		var span:Vector4=bed[0]
		var axis:Vector3=bed[1]
		var u:=((x-span.x)*axis.x+(z-span.y)*axis.y)/span.z
		var v:=(-(x-span.x)*axis.y+(z-span.y)*axis.x)/span.w
		if absf(u)>1.02 or absf(v)>1.3:continue
		v+=.19*u
		var shoulder:=minf(1.0+v*1.04,1.0-v*1.29)
		var long_face:=minf((u+1.0)*.75,(1.0-u)*2.8)
		# Rounded intersection between major planes, with a sloping crest
		# wide enough to read at game camera distance.
		var radius:=.25
		var overlap:=maxf(radius-absf(shoulder-long_face),0.0)/radius
		var ridge:=minf(shoulder,long_face)-overlap*overlap*radius*.25
		var top:=.76+.075*u-.085*v
		overlap=maxf(radius-absf(ridge-top),0.0)/radius
		ridge=maxf(0.0,minf(ridge,top)-overlap*overlap*radius*.25)
		ridge*=smoothstep(0.0,.16,ridge)
		old_buttress_h += axis.z*ridge
		old_buttress_cover = minf(old_buttress_cover,1.0-smoothstep(.035,.16,ridge))
	if x < -18.0 and x > -63.0 and z > -13.0 and z < 16.0:
		var new_foot := smoothstep(18.0,21.0,-x)*smoothstep(-13.,-8.,z)*(1.-smoothstep(12.,16.,z))*smoothstep(-63.,-56.,x)
		h += old_buttress_h*(1.0-new_foot)
		cover = minf(cover,lerpf(old_buttress_cover,1.0,new_foot))
	else:
		h += old_buttress_h
		cover = minf(cover,old_buttress_cover)
	var bend:=_bend_spur(x,z)
	return Vector3(h+bend.x,minf(cover,bend.y),0)


# Each column runs from the foreground toward the horizon. Points hold world
# height, z and turf coverage. Every cross-section uses the same row count.
static func _make_column(x: float) -> Array[Vector3]:
	var column: Array[Vector3] = []
	var near_z := Z_MAX
	var elevation := 0.0
	for band in range(3):
		var station := _station(x,band)
		var toe := _section_position(x,band,0).x
		var align := 0.0
		var outer := 0.0
		var inner := 0.0
		if band == 0 and x > -58.0 and x < -37.0:
			align = smoothstep(-58.0,-53.8,x)*(1.0-smoothstep(-42.0,-37.0,x))
			outer = _west_foot_contour_z(x,1.06)
			inner = maxf(_west_foot_contour_z(x,.69),toe+.40)
		for i in range(CLEARANCE_ROWS):
			var z := lerpf(near_z,toe,float(i)/CLEARANCE_ROWS)
			if align > 0.0:
				var registered: float
				if i <= 66:
					registered = lerpf(near_z,outer,float(i)/66.0)
				elif i <= 73:
					registered = lerpf(outer,inner,float(i-66)/7.0)
				else:
					registered = lerpf(inner,toe,float(i-73)/(CLEARANCE_ROWS-73))
				z = lerpf(z,registered,align)
			var base := _surface_base(x,z)
			column.append(Vector3(base.x+elevation,z,base.y))
		var strength := smoothstep(.18,.72,station.y/station.z)
		for row in range(SECTIONS.size()):
			var section := _section_position(x,band,row)
			if row>0:
				var spacing := .16
				if band == 0 and row >= 3:
					# Spread the upper break over several independent plan rows.
					var shoulder := smoothstep(-36.0,-32.0,x)*(1.0-smoothstep(-29.0,-25.0,x))
					spacing += .48*shoulder
				section.x=minf(section.x,column[-1].y-spacing)
			var base := _surface_base(x,section.x)
			var turf := 1.0
			if row in [1,2,3]:turf=1.0-strength
			elif row==4:turf=1.0-(.62+.16*sin(x*.25+band))*strength
			column.append(Vector3(base.x+elevation+section.y,section.x,minf(base.y,turf)))
		near_z=column[-1].y
		elevation+=station.y
		# The following meadow starts just beyond the shared crown row.
		near_z-=.32
	for i in range(CLEARANCE_ROWS+1):
		var z := lerpf(near_z,Z_MIN,float(i)/CLEARANCE_ROWS)
		var base := _surface_base(x,z)
		column.append(Vector3(base.x+elevation,z,base.y))
	# The raised table ends before the next escarpment. Its back slopes
	# down across an irregular meadow, leaving the distant ridge independent.
	if x < -19.0:
		var west_rise := _west_table_rise(x)
		for j in range(column.size()):
			var p := column[j]
			var back := smoothstep(16.0, 38.0, -p.y + 1.8*sin(x*.12))
			p.x -= west_rise*back
			# An old runoff cuts across the green flank, revealing the sloping
			# rock under its eastern rim and breaking its straight brow.
			var cut_z := (p.y+15.6)/6.8
			var cut_x := (x+25.2+1.4*cut_z)/7.4
			var worn := smoothstep(.0,.80,1.0-cut_x*cut_x-cut_z*cut_z)
			p.x -= 2.1*worn
			column[j] = p
	# Talus is debris on the lower valley floor. Its absolute height
	# intersects the escarpment; attaching its height delta to every
	# stratum would incorrectly lift falling blocks above the grass brow.
	if x > -63.0 and x < -10.0:
		var west_edge := smoothstep(10.0,14.0,-x)*smoothstep(-63.0,-56.0,x)
		for j in range(column.size()):
			var p := column[j]
			if p.y < -9.0 or p.y > 18.0: continue
			var foundation := _surface_base(x,p.y).x
			var talus := _west_talus(x,p.y-2.3,foundation-_valley_floor(x,p.y))
			if talus.x <= 0.0: continue
			var debris_top := foundation + talus.x*west_edge
			if debris_top <= p.x: continue
			var rock_weight := smoothstep(0.0,.24,debris_top-p.x)
			p.x = debris_top
			p.z = lerpf(p.z,minf(p.z,talus.y),rock_weight)
			column[j] = p
	# The end of the west bed is worn down to a broad, dipping top. The
	# same height samples feed rendering, collision and all planting queries.
	if x > -39.0 and x < -24.0:
		var along := smoothstep(-39.0,-34.0,x)*(1.0-smoothstep(-28.0,-24.0,x))
		for j in range(column.size()):
			var p := column[j]
			var z := p.y
			if z < -16.0 or z > 2.0: continue
			var across := smoothstep(-16.,-8.5,z)*(1.0-smoothstep(.2,2.,z))
			var worn_bed := 13.30 + .075*(x+30.0) - .105*(z+2.0)
			var bevel := maxf(.90-absf(p.x-worn_bed),0.0)
			var rounded_top := minf(p.x,worn_bed) - bevel*bevel/(4.0*.90)
			p.x = lerpf(p.x,rounded_top,along*across)
			column[j] = p
	# A shallow cut opens the inside shoulder at the upper switchback. The
	# hollow, the exposed bed on its west rim and its grass saddle share the
	# original terrain lattice. It tapers into the meadow before the trail.
	if x>-.5 and x<14.0:
		for j in range(column.size()):
			var p:=column[j]
			if p.y < -60.0 or p.y > -40.0:continue
			var v:=(p.y+49.4)/8.6
			var u:=(x-8.4+1.65*v)/7.9
			var hollow:=smoothstep(0.0,.90,1.0-u*u-v*v)*smoothstep(0.,3.1,14.0-x)
			if hollow<=0.0:continue
			p.x-=3.15*hollow
			var west_rim:=1.0-smoothstep(.20,.84,absf(u+.25+.72*v))
			var shelter:=smoothstep(.06,.41,hollow)
			var exposed:=shelter*(.40+.55*west_rim)
			p.z=minf(p.z,1.0-exposed)
			column[j]=p
	_grade_middle_crown(column, x)
	return column


# Grade two connected grass ledges on the upper rows of the first band.
# Share their slope with the rows behind the rim rather than leaving a
# raised lip at the front of an otherwise lower slope.
static func _grade_middle_crown(column: Array[Vector3], x: float) -> void:
	var extent := smoothstep(-24.3,-20.7,x)*(1.0-smoothstep(-7.4,-5.6,x))
	if extent <= 0.0:
		return
	var step_down := smoothstep(-15.0,-12.2,x)
	var crown := lerpf(9.20 + .065*(x+21.0), 7.22 + .065*(x+11.0), step_down)
	var crown_row := CLEARANCE_ROWS + SECTIONS.size() - 1
	var edge_z := column[crown_row].y
	var shoulder := column[crown_row-1]
	shoulder.x = lerpf(shoulder.x,crown-.85,extent*.95)
	column[crown_row-1] = shoulder
	for row in range(crown_row, crown_row + 19):
		var point := column[row]
		var distance_from_edge := edge_z-point.y
		var blend := extent*(1.0-smoothstep(3.4,6.9,distance_from_edge))
		var top := crown+.035*distance_from_edge+.075*sin(x*.67+distance_from_edge*.70)
		point.x = lerpf(point.x,top,blend)
		var dry_break := exp(-pow((x+13.6+.18*distance_from_edge)/1.48,2.0))
		var grass_strength := .98 - .79*dry_break
		# Keep the cut itself exposed, with grass returning behind its rim.
		point.z = lerpf(point.z,grass_strength,blend)
		column[row] = point


static func _prepare() -> void:
	if _prepared:return
	for ix in range(int((X_MAX-X_MIN)/COLUMN_STEP)+1):
		_columns.append(_make_column(X_MIN+ix*COLUMN_STEP))
	_prepared=true
	_soften_contact(Vector2(-15.3,-2.5),Vector2(5.7,5.2),Vector2(1.65,.75),Vector2(-.67,1.47))
	_soften_contact(Vector2(-8.3,-12.5),Vector2(4.7,7.1),Vector2(.95,.49),Vector2(-.77,1.49))
	# The oblique slab end meets the terrain diagonals at a shallow angle.
	# Fair the weld in world-space metres across the lower-facing flanks.
	_soften_contact(Vector2(-22.,6.9),Vector2(11.5,8.7),Vector2(.99,.72),Vector2(-1.00,1.17))
	_soften_contact(Vector2(-22.,6.9),Vector2(11.5,8.7),Vector2(.59,.41),Vector2(-.56,.72))
	_separate_talus_ribs()
	_soften_contact(Vector2(-19.4,6.05),Vector2(11.1,8.65),Vector2(.86,.34),Vector2(-.38,.91))
	_cut_fan_bedding()
	_soften_contact(Vector2(-21.6,9.35),Vector2(4.8,2.1),Vector2(.52,.28),Vector2(-.31,.72))
	_expose_west_shoulder()
	_break_west_backwall()
	_soften_contact(Vector2(-20.75,-6.2),Vector2(3.15,3.22),Vector2(.56,.22),Vector2(-.24,.67))


# Author the crest, bevel and foot of the west face in world coordinates.
# Crest, shoulder and foot stay part of the terrain used for collision.
static func _break_west_backwall() -> void:
	var first := floori((-33.0-X_MIN)/COLUMN_STEP)
	var last := ceili((-17.0-X_MIN)/COLUMN_STEP)
	for ix in range(first,last+1):
		var x := X_MIN+ix*COLUMN_STEP
		for row in range(_columns[ix].size()):
			var vertex: Vector3 = _columns[ix][row]
			var z := vertex.y
			var window := smoothstep(-14.6,-11.6,z)*(1.0-smoothstep(-3.05,-.8,z))
			if window <= .001:
				continue
			# A diagonal grade opens backwards between two differently pitched faces.
			var cut := 1.0-smoothstep(.30,1.75,absf(z+7.48))
			var oblique := 1.0-smoothstep(-7.9,-5.9,z)
			var cut_corner := smoothstep(-11.43,-10.62,z)*(1.0-smoothstep(-9.58,-8.82,z))
			var old_edge := -23.8-.34*(z+5.6) - 1.36*cut + .85*oblique - .66*cut_corner
			var wide_face := smoothstep(-10.45,-8.10,z)*(1.0-smoothstep(-4.22,-2.42,z))
			var return_face := smoothstep(-12.35,-11.48,z)*(1.0-smoothstep(-10.48,-9.18,z))
			var short_wall := smoothstep(-5.43,-4.80,z)*(1.0-smoothstep(-3.78,-3.1,z))
			# The crest bridges the turn. The lower edge swings farther than
			# the rim, so the three adjoining faces catch different light.
			var edge_turn := 1.03*wide_face - 1.52*return_face + .38*short_wall
			var outer_edge := old_edge + edge_turn
			var rim := old_edge-lerpf(1.75,4.85,oblique)*(1.0-.36*cut)+.55*cut_corner
			rim = minf(rim+.29*edge_turn,outer_edge-.82)
			var slope_width := outer_edge-rim
			var crest := 12.85-.10*(z+8.0)-1.25*cut-.56*cut_corner
			var seam := lerpf(7.1,9.25,oblique)-1.18*cut-.92*wide_face+.32*short_wall
			var apron := smoothstep(-11.65,-10.1,z)*(1.0-smoothstep(-9.5,-8.5,z))
			var foot := 1.1+.25*sin(z*.74)+.56*apron
			var top := crest + .08*clampf(rim-x,0.0,5.0)
			var bevel := lerpf(crest,seam,clampf((x-rim)/slope_width,0.0,1.0))
			var run := x-outer_edge
			var fall_span := lerpf(1.05,1.48,oblique)+.47*apron
			var toe := lerpf(seam,foot,smoothstep(0.0,fall_span,run))
			# A fallen bed remains attached to the middle of the scarp. The
			# front is wider on its downhill end and runs out into the apron.
			# Let the eastern end turn back into the gully as one oblique
			# face, while the central shoulder keeps its full reach.
			var bed_end := smoothstep(-6.0,-4.55,z+.28*maxf(run,0.0))
			var runout := lerpf(2.3,4.18,smoothstep(-9.7,-5.3,z))-.83*bed_end
			var bed_height := minf(seam,6.18-.19*(z+6.3))
			var run_fraction := clampf(run/runout,0.0,1.0)
			var bed := lerpf(seam,bed_height,smoothstep(0.0,.46,run))
			bed -= run_fraction * (lerpf(.72,1.65,smoothstep(-8.0,-4.0,z))+.48*bed_end)
			bed = lerpf(bed,foot,smoothstep(.72,1.0,run_fraction))
			toe = lerpf(toe,bed,wide_face)
			var section := top
			if x > outer_edge:
				section = toe
			elif x > rim:
				section = bevel
			var join_start := lerpf(.80*fall_span,.82*runout,wide_face)
			var join_end := lerpf(2.8,runout+.46,wide_face)
			var merge := smoothstep(rim-3.0,rim-1.05,x)*(1.0-smoothstep(join_start,join_end,run))
			var blend := window*merge
			vertex.x = lerpf(vertex.x,section,blend)
			var crown := 1.0-smoothstep(rim-.64,rim+.29,x)
			vertex.z = lerpf(vertex.z,.96*crown,blend)
			_columns[ix][row] = vertex

	# Only horizontal ground retains the new grass. The diagonally receding
	# edge can be steep along Z even where its cross-section has a flat top.
	for ix in range(first,last+1):
		var x := X_MIN+ix*COLUMN_STEP
		for row in range(_columns[ix].size()):
			var vertex: Vector3 = _columns[ix][row]
			var z := vertex.y
			var blend := _west_surface_window(x,z)
			if blend <= .001 or vertex.z <= .02:
				continue
			var up := _broad_ground_normal(x,z)
			vertex.z *= lerpf(1.0,smoothstep(.64,.92,up.y),blend)
			_columns[ix][row] = vertex


static func _west_surface_window(x: float, z: float) -> float:
	var across := smoothstep(-33.0,-30.0,x)*(1.0-smoothstep(-22.0,-19.2,x))
	var along := smoothstep(-14.6,-11.6,z)*(1.0-smoothstep(-3.05,-.8,z))
	return across*along


static func _broad_ground_normal(x: float, z: float) -> Vector3:
	# Average the bright bevel at a broader scale than the tightly spaced
	# transition rows, while letting major differences between planes remain.
	var across := smoothstep(-29.1,-26.8,x)*(1.0-smoothstep(-21.3,-20.4,x))
	var along := smoothstep(-12.65,-11.4,z)*(1.0-smoothstep(-8.3,-7.5,z))
	var bevel := across*along
	var side := lerpf(.65,1.35,bevel)
	var length := lerpf(.81,1.14,bevel)
	var dx := (ground_height(x+side,z)-ground_height(x-side,z))/(2.0*side)
	var dz := (ground_height(x,z+length)-ground_height(x,z-length))/(2.0*length)
	return Vector3(-dx,1.0,-dz).normalized()


# Paired limestone bedding faces inside the two upper shoulders. The
# weathered base and skyline use the original terrain envelope.
static func _cut_fan_bedding() -> void:
	for ix in range(floori((-30.0-X_MIN)/COLUMN_STEP),ceili((-13.2-X_MIN)/COLUMN_STEP)):
		var x := X_MIN+ix*COLUMN_STEP
		for j in range(_columns[ix].size()):
			var p: Vector3 = _columns[ix][j]
			var z := p.y
			if z<1.45 or z>10.3 or p.x<3.55: continue
			var d := Vector2(x+22.05,z-4.80)
			# An exposed bedding plane pitches south into the valley, then
			# breaks more steeply east along the main crown.
			var strike := d.x-.30*d.y
			var length := d.y+.20*d.x
			var hull := maxf(absf(strike+.26*length)/5.05,absf(length)/4.25)
			hull = maxf(hull,absf(.77*strike+.43*length)/4.9)
			var mass := (1.-smoothstep(.57,1.0,hull))*smoothstep(1.45,3.05,z)
			var pale := 7.62+.24*d.x-.88*d.y
			var steep := 7.62-1.06*d.x-.44*d.y
			var radius := .72
			var overlap := maxf(radius-absf(pale-steep),0.)/radius
			var bedding := minf(pale,steep)-radius*.25*overlap*overlap
			var changed := p.x+mass*clampf(bedding-p.x,-1.35,1.55)
			var small := Vector2(x+17.6,z-5.45)
			var tip := small.x+.43*small.y
			var end := small.y-.24*small.x
			var joint := maxf(absf(tip)/2.78,absf(end)/2.94)
			var pocket := 1.-smoothstep(.53,1.,joint)
			var ledge := 4.55+.31*small.x-.46*small.y
			var lip := 4.55-1.14*small.x-.32*small.y
			overlap=maxf(.59-absf(ledge-lip),0.)/.59
			var second:=minf(ledge,lip)-.1475*overlap*overlap
			changed+=pocket*clampf(second-changed,-.64,.82)
			p.x=lerpf(p.x,changed,smoothstep(3.55,4.70,p.x))
			_columns[ix][j]=p


static func _separate_talus_ribs() -> void:
	for ix in range(floori((-30.0-X_MIN)/COLUMN_STEP),ceili((-10.0-X_MIN)/COLUMN_STEP)):
		var x := X_MIN+ix*COLUMN_STEP
		for j in range(_columns[ix].size()):
			var p: Vector3 = _columns[ix][j]
			var z := p.y
			if z < -2.3 or z > 15.2: continue
			var main := x+20.15+.38*(z-5.1)
			var width := 3.35 if main>0.0 else 2.36
			var gully := (1.-smoothstep(.02,width,absf(main)))
			gully *= smoothstep(-1.3,2.3,z)*(1.-smoothstep(8.7,14.2,z))
			var branch := x+16.05+.69*(z-4.65)
			var groove := 1.-smoothstep(.04,2.58,absf(branch))
			groove *= smoothstep(.42,3.87,z)*(1.-smoothstep(8.0,12.0,z))
			var relief := maxf(p.x-_valley_floor(x,z),0.)
			p.x -= minf(1.90*gully+1.40*groove,relief*.74)
			_columns[ix][j]=p

# The eastern side of the high west terrace is a steep talus-facing scarp.
# Leave soil on its quieter beds and expose rock where grass cannot stand.
static func _expose_west_shoulder() -> void:
	for ix in range(floori((-34.0-X_MIN)/COLUMN_STEP),ceili((-18.5-X_MIN)/COLUMN_STEP)):
		var x := X_MIN+ix*COLUMN_STEP
		for j in range(_columns[ix].size()):
			var p: Vector3 = _columns[ix][j]
			var z := p.y
			if z < -33.0 or z > -.5 or p.z <= .06: continue
			var zone := smoothstep(-33.,-25.,z)*(1.0-smoothstep(-5.,-.5,z))
			zone *= smoothstep(-34.,-29.4,x)*(1.0-smoothstep(-22.1,-18.5,x))
			var across := (ground_height(x+.35,z)-ground_height(x-.35,z))/.70
			var tangent := (ground_height(x,z+.35)-ground_height(x,z-.35))/.70
			var grade := Vector2(across,tangent).length()
			var ribs := smoothstep(-.78,.53,sin(z*.49+x*.17)+.34*sin(z*.97))
			var bare := zone*smoothstep(.43,.95,grade)*(.77+.21*ribs)
			p.z = minf(p.z,1.0-bare)
			_columns[ix][j] = p


# The diagonal buttress meets the projecting toe on different rows in every
# column. Filter the contact in metres so a slanted bedding plane crosses those
# rows as one face. The visual mesh, collision and height queries all use it.
static func _soften_contact(centre: Vector2, extent: Vector2, across_bed: Vector2, along_bed: Vector2) -> void:
	var changes: Array[Vector3] = []
	var first_column := floori((centre.x-extent.x-X_MIN)/COLUMN_STEP)
	var last_column := ceili((centre.x+extent.x-X_MIN)/COLUMN_STEP)
	for ix in range(first_column,last_column+1):
		var x := X_MIN+ix*COLUMN_STEP
		for row in range(_columns[ix].size()):
			var vertex: Vector3 = _columns[ix][row]
			var p := Vector2(x,vertex.y)
			var radius := ((p-centre)/extent).length()
			if radius >= 1.0: continue
			var total := vertex.x*4.0
			for side in [-1.0,1.0]:
				var u := across_bed*float(side)
				var v := along_bed*float(side)
				total += ground_height(p.x+u.x,p.y+u.y)*2.0
				total += ground_height(p.x+v.x,p.y+v.y)*2.0
				for end in [-1.0,1.0]:
					var corner := p+u+along_bed*float(end)
					total += ground_height(corner.x,corner.y)
			var influence := 1.0-smoothstep(.48,1.0,radius)
			changes.append(Vector3(ix,row,lerpf(vertex.x,total/16.0,influence)))
	# Applying after all samples ensures the convolution is independent of order.
	for change in changes:
		var column: Array = _columns[int(change.x)]
		var row := int(change.y)
		var vertex: Vector3 = column[row]
		vertex.x=change.z
		column[row]=vertex


static func _sample(x: float,z: float) -> Vector3:
	_prepare()
	var lattice := clampf((x-X_MIN)/COLUMN_STEP,0.0,float(_columns.size()-1))
	var ix := mini(floori(lattice),_columns.size()-2)
	var u := lattice-ix
	var a: Array = _columns[ix]
	var b: Array = _columns[ix+1]
	var lo := 0
	var hi := a.size()-1
	while hi-lo>1:
		var j := (lo+hi)>>1
		if z>lerpf(a[j].y,b[j].y,u):hi=j
		else:lo=j
	var left_near: Vector3=a[lo]
	var right_near: Vector3=b[lo]
	var left_far: Vector3=a[hi]
	var right_far: Vector3=b[hi]
	var near:=left_near.lerp(right_near,u)
	var far:=left_far.lerp(right_far,u)
	var diag:=left_far.lerp(right_near,u)
	if z>diag.y and near.y>diag.y+.000001:
		return near.lerp(diag,clampf((near.y-z)/(near.y-diag.y),0.0,1.0))
	if diag.y>far.y+.000001:
		return diag.lerp(far,clampf((diag.y-z)/(diag.y-far.y),0.0,1.0))
	return near


static func ground_height(x: float,z: float) -> float:
	return _sample(x,z).x


static func vegetation_weight(x: float,z: float) -> float:
	return smoothstep(.52,.98,_sample(x,z).z)


static func _point(ix: int,j: int) -> Vector3:
	var value: Vector3=_columns[ix][j]
	return Vector3(X_MIN+ix*COLUMN_STEP,value.x,value.y)


# Meadow within a metre or two of a rock toe can leave a soil stain. A lawn
# above a projecting cliff is excluded by the signed height test.
static func _foot_soil(point: Vector3) -> float:
	var strength := 0.0
	for offset: Vector2 in [Vector2(0,1.6), Vector2(1.2,.85), Vector2(-1.2,.85),
			Vector2(0,-1.6), Vector2(1.2,-.85), Vector2(-1.2,-.85)]:
		var nearby := _sample(point.x + offset.x, point.z + offset.y)
		var rise := point.y - nearby.x
		var lower_lawn := smoothstep(-.45,-.06,rise) * (1.0-smoothstep(.12,1.25,rise))
		strength = maxf(strength, lower_lawn * smoothstep(.63,.97,nearby.z))
	return strength


static func _triangle(surface: SurfaceTool,ids: Array,normals: Array,foot_soil: Array) -> void:
	for id: Vector2i in ids:
		var value: Vector3=_columns[id.x][id.y]
		var p:=_point(id.x,id.y)
		var tone:=.91+.085*sin(p.x*.19+p.y*.26)+.05*sin(p.z*.33+p.y*.24)
		surface.set_color(Color(tone*.96,tone*.99,tone*1.02,value.z))
		# Adjacent triangles and the grass/rock partitions share the same
		# normal at a vertex. Visible planes come from the sculpted strata.
		surface.set_normal(normals[id.x][id.y])
		surface.set_uv(Vector2(p.x,p.z)*.05)
		var bed_centre := Vector2(24.8,2.7) if p.x > 12.0 else Vector2(-1.4,4.2)
		var span := Vector2(6.55,3.45) if p.x > 12.0 else Vector2(6.9,2.95)
		var delta := Vector2(p.x,p.z)-bed_centre
		var shear := .34 if p.x > 12.0 else -.32
		var radius := (Vector2(delta.x+shear*delta.y,delta.y-shear*delta.x)/span).length()
		var cap_mask := 1.-smoothstep(.80,1.21,radius)
		surface.set_uv2(Vector2(foot_soil[id.x][id.y],cap_mask))
		surface.add_vertex(p)


static func build(parent: Node3D,rock_material: Material,ground_material: Material) -> void:
	_prepare()
	var grass:=SurfaceTool.new()
	var rock:=SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normals:Array=[]
	var foot_soil:Array=[]
	for ix in range(_columns.size()):
		var vertices:=PackedVector3Array()
		var soil_column:=PackedFloat32Array()
		for j in range(_columns[ix].size()):
			var across:=_point(mini(ix+1,_columns.size()-1),j)-_point(maxi(ix-1,0),j)
			var forward:=_point(ix,maxi(j-1,0))-_point(ix,mini(j+1,_columns[ix].size()-1))
			var normal := forward.cross(across).normalized()
			var point := _point(ix,j)
			var blend := _west_surface_window(point.x,point.z)*smoothstep(3.1,6.3,point.y)
			if blend > .001:
				var return_face := smoothstep(-10.65,-9.76,point.z)*(1.0-smoothstep(-8.32,-7.12,point.z))
				normal = normal.slerp(_broad_ground_normal(point.x,point.z),lerpf(.88,.44,return_face)*blend)
			vertices.append(normal)
			soil_column.append(_foot_soil(_point(ix,j)) if _columns[ix][j].z < .999 else 0.0)
		normals.append(vertices)
		foot_soil.append(soil_column)
	for ix in range(_columns.size()-1):
		for j in range(_columns[ix].size()-1):
			var a:=Vector2i(ix,j)
			var b:=Vector2i(ix+1,j)
			var c:=Vector2i(ix,j+1)
			var d:=Vector2i(ix+1,j+1)
			for ids: Array in [[a,c,b],[b,c,d]]:
				var is_meadow:=true
				for id:Vector2i in ids:
					if _columns[id.x][id.y].z<.999:is_meadow=false
				_triangle(grass if is_meadow else rock,ids,normals,foot_soil)
	for part in [[grass,ground_material,"ContinuousMeadow"],[rock,rock_material,"ExposedEscarpments"]]:
		var instance:=MeshInstance3D.new()
		instance.name=part[2]
		instance.mesh=part[0].commit()
		instance.material_override=part[1]
		parent.add_child(instance)
		instance.create_trimesh_collision()
