extends RefCounted
## Continuous landscape beyond the playable meadow. All three authored ranges
## rise from one ground surface, which continues outside the camera's far plane.
const Terrain = preload("res://calibration_daylight/terrain.gd")
const BASE_Y := -30.0
const X_MIN := -410.0
const X_MAX := 410.0


static func _segment_coordinates(p: Vector2, a: Vector3, b: Vector3) -> Vector3:
	var start := Vector2(a.x, a.z)
	var direction := Vector2(b.x-a.x, b.z-a.z)
	var t := clampf((p-start).dot(direction)/maxf(direction.length_squared(),0.001),0.0,1.0)
	var closest := start + direction*t
	return Vector3(p.distance_to(closest),t,p.y-closest.y)


static func _crest_height(p: Vector2, spine: Array, width: float, front_ratio: float, back_ratio: float) -> float:
	var height := BASE_Y
	for i in range(spine.size()-1):
		var a: Vector3=spine[i]
		var b: Vector3=spine[i+1]
		var sample := _segment_coordinates(p,a,b)
		var crest := lerpf(a.y,b.y,sample.y)
		# A steep broken south face and a broader rear shoulder produce a mass,
		# rather than extruding every summit with an identical cross section.
		var flank_width := width*(front_ratio if sample.z>=0.0 else back_ratio)
		var profile_power := 1.22 if sample.z>=0.0 else 1.72
		var shoulder := exp(-pow(sample.x/flank_width,profile_power))
		height=maxf(height,BASE_Y+(crest-BASE_Y)*shoulder)
	return height


static func _height(x: float, z: float, ridge: Array, shoulders: Array, gullies: Array, width: float, noise: FastNoiseLite) -> float:
	var p:=Vector2(x,z)
	var height:=_crest_height(p,ridge,width,1.24,0.87)
	for row in shoulders:
		var spine: Array=row[0]
		var branch_width: float=row[1]
		height=maxf(height,_crest_height(p,spine,branch_width,1.1,0.91))
	var erosion:=0.0
	for row in gullies:
		var a: Vector3=row[0]
		var b: Vector3=row[1]
		var sample:=_segment_coordinates(p,a,b)
		var depth: float=row[2]
		var channel_width: float=row[3]
		var taper:=pow(maxf(sin(sample.y*PI),0.0),0.65)
		erosion+=depth*exp(-pow(sample.x/channel_width,2.0))*taper
	# Broad low-amplitude plane variation supports the authored structure;
	# summit silhouettes are authored, not made from high-frequency noise.
	var elevation:=smoothstep(-10.0,35.0,height)
	var relief:=noise.get_noise_2d(x,z)*2.0
	height-=erosion*elevation
	height+=relief*elevation
	var edge_fade:=1.0-smoothstep(360.0,410.0,absf(x))
	return BASE_Y+(height-BASE_Y)*edge_fade


static func _terrain_axis(start: float, finish: float, low: float, high: float, north_south: bool) -> PackedFloat32Array:
	# Span beyond the far plane in all directions; spend vertices in the
	# foreground seam, the authored massifs and their glacial valleys.
	var values := PackedFloat32Array()
	var t := start
	while t < finish:
		values.append(t)
		var detail := (t >= -442.0 and t <= 280.0) if north_south else absf(t) <= 387.0
		t += 3.6 if detail else 21.0
	values.append(finish)
	for coordinate in [low - 3.0, low, low + 3.0, high - 3.0, high, high + 3.0]:
		values.append(coordinate)
	values.sort()
	var unique := PackedFloat32Array()
	for value in values:
		if unique.is_empty() or value - unique[-1] > 0.01:
			unique.append(value)
	return unique


static func _basin(x: float, z: float, noise: FastNoiseLite) -> float:
	var rolling := 7.0 + 5.5 * sin(x * 0.022 + z * 0.011) + 4.0 * sin(z * 0.032 - x * 0.008)
	rolling += 8.5 * noise.get_noise_2d(x * 0.62, z * 0.54)
	var eastern_knoll := 23.0 * exp(-pow((x - 145.0) / 43.0, 2.0) - pow((z + 64.0) / 57.0, 2.0))
	rolling += eastern_knoll + 31.0 * exp(-pow((x - 217.0) / 57.0, 2.0) - pow((z + 48.0) / 79.0, 2.0))
	var dx := maxf(Terrain.X_MIN - x, x - Terrain.X_MAX)
	var dz := maxf(Terrain.Z_MIN - z, z - Terrain.Z_MAX)
	var distance := maxf(dx, dz)
	if distance >= 34.0:
		return rolling
	var boundary_x := clampf(x, Terrain.X_MIN, Terrain.X_MAX)
	var boundary_z := clampf(z, Terrain.Z_MIN, Terrain.Z_MAX)
	var meadow_height := Terrain.ground_height(boundary_x, boundary_z)
	return lerpf(meadow_height, rolling, smoothstep(0.0, 34.0, distance)) - clampf(-distance, 0.0, 4.0)


const HEADWALL_CELL := 32.0


static func _headwall_add(bins: Dictionary, a:Vector3, b:Vector3, c:Vector3) -> void:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ac := Vector2(c.x - a.x, c.z - a.z)
	var area := ab.cross(ac)
	if absf(area) < 0.01:
		return
	var gradient := Vector2((b.y - a.y) * ac.y - (c.y - a.y) * ab.y, (c.y - a.y) * ab.x - (b.y - a.y) * ac.x) / area
	var lo := Vector2(minf(a.x,minf(b.x,c.x)),minf(a.z,minf(b.z,c.z)))
	var hi := Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.z,maxf(b.z,c.z)))
	var data := [Vector2(a.x,a.z), ab, ac, 1.0 / area, a.y, gradient]
	for iz in range(floori(lo.y / HEADWALL_CELL), floori(hi.y / HEADWALL_CELL) + 1):
		for ix in range(floori(lo.x / HEADWALL_CELL), floori(hi.x / HEADWALL_CELL) + 1):
			var key := Vector2i(ix, iz)
			if not bins.has(key):
				bins[key] = []
			bins[key].append(data)


static func _headwall() -> Dictionary:
	# North to south transects of an alpine range. Each station is a real
	# summit, col or ridge shoulder. Asymmetric row offsets turn south-facing
	# ribs into diagonal spurs and make neighbouring flanks occlude each other.
	var spine := PackedVector3Array([
		Vector3(-410,15,-382), Vector3(-330,54,-369), Vector3(-269,84,-368),
		Vector3(-240,102,-360), Vector3(-224,118,-355), Vector3(-208,129,-358),
		Vector3(-185,122,-361), Vector3(-162,112,-359), Vector3(-140,100,-369),
		Vector3(-106,100,-379), Vector3(-85,97,-380), Vector3(-62,91,-370),
		Vector3(-43,80,-378), Vector3(-31,88,-377), Vector3(-20,99,-370), Vector3(-9,96,-367),
		Vector3(2,97,-368), Vector3(17,108,-374), Vector3(24,111,-373),
		Vector3(34,101,-369), Vector3(48,111,-359), Vector3(57,113,-367),
		Vector3(73,119,-363), Vector3(94,139,-356), Vector3(115,135,-362),
		Vector3(130,145,-359), Vector3(148,161,-365), Vector3(160,169,-370),
		Vector3(175,167,-376), Vector3(186,177,-369), Vector3(204,185,-373),
		Vector3(225,177,-381), Vector3(241,188,-375), Vector3(264,197,-379),
		Vector3(287,167,-382), Vector3(326,122,-397), Vector3(410,16,-388)])
	var sections := []
	for i in spine.size():
		var v := spine[i]
		var roll := .59 * sin(v.x * .047 + .9) + .27 * sin(v.x * .081)
		var shift := 23.0 * sin(v.x * 0.017 + 1.1) - 8.0
		# One isolated western summit, a low asymmetric pass, then the eastern snowfield.
		# The once-continuous crown left no sky between neighboring massifs.
		v.y *= lerpf(.90, .84, smoothstep(20.0, 180.0, v.x))
		v.y += 27.0 * exp(-pow((v.x + 204.0) / 51.0, 2.0))
		v.y -= 16.0 * exp(-pow((v.x + 52.0) / 49.0, 2.0))
		v.y += 10.0 * exp(-pow((v.x - 108.0) / 46.0, 2.0))
		var toe := 159.0 + 19.0 * sin(v.x * 0.025)
		sections.append([
			Vector3(v.x + 3.0, 6.0, v.z - 74.0),
			Vector3(v.x + 8.0, v.y * 0.7, v.z - 30.0),
			v,
			Vector3(v.x + shift * 0.44 + roll * 3.0, v.y * (0.81 + roll * 0.047), v.z + toe * (0.22 + roll * 0.06)),
			Vector3(v.x + shift * 0.68 - roll * 4.0, v.y * (0.54 - roll * 0.046), v.z + toe * (0.52 - roll * 0.06)),
			Vector3(v.x + shift * 0.92 + roll * 3.0, v.y * (0.32 + roll * 0.041), v.z + toe * 0.76),
			Vector3(v.x + shift, 4.0, v.z + toe)])
	var bins := {}
	for i in range(sections.size() - 1):
		for j in range(6):
			var a:Vector3 = sections[i][j]
			var b:Vector3 = sections[i+1][j]
			var c:Vector3 = sections[i][j+1]
			var d:Vector3 = sections[i+1][j+1]
			if (i + j) % 2 == 0:
				_headwall_add(bins,a,b,d)
				_headwall_add(bins,a,d,c)
			else:
				_headwall_add(bins,a,b,c)
				_headwall_add(bins,b,d,c)
	return bins


static func _headwall_height(x:float,z:float,bins:Dictionary) -> float:
	var key := Vector2i(floori(x / HEADWALL_CELL),floori(z / HEADWALL_CELL))
	var height := BASE_Y
	for row in bins.get(key, []):
		var delta := Vector2(x,z) - (row[0] as Vector2)
		var u:float = delta.cross(row[2]) * row[3]
		var v:float = (row[1] as Vector2).cross(delta) * row[3]
		if u>=-0.0001 and v>=-0.0001 and u+v<=1.0001:
			height = maxf(height, row[4] + delta.dot(row[5]))
	return height


# The moraine presents a wooded bench in front of the alpine wall.
# West of its saddle it is narrow and high; a broader eastern shoulder recedes behind it.
static func _wooded_shoulder(x:float,z:float) -> float:
	var axis_z := -191.0 - 12.0 * sin((x+51.0)*.015) - .12*x
	var run := (z-axis_z)/42.0
	var contour := 28.0 + 21.0 * exp(-pow((x+106.0)/55.0,2.0))
	# A flatter ledge with two lower glades instead of a conical left hill.
	contour += 15.0 * exp(-pow(absf((x+238.0)/81.0),4.0))
	contour += 13.0*exp(-pow((x+36.0)/60.0,2.0)) + 8.0*exp(-pow((x-60.0)/51.0,2.0))
	contour += 3.6*sin(x*.079)*exp(-pow((x+229.0)/71.0,2.0))
	contour += 12.0 * exp(-pow((x-54.0)/48.0,2.0)) + 6.0 * exp(-pow((x-125.0)/43.0,2.0))
	return BASE_Y+(contour-BASE_Y)*exp(-run*run) * (1.0-smoothstep(268.0,338.0,absf(x)))


# Cut broad valleys down the south face. The cut tapers at each end and a
# narrower soft lip only builds up on one side of the thalweg.
# x at upper station, z at upper station, lateral reach, valley width.
const ALPINE_CHANNELS := [
	Vector4(-245,-355,-29,13), Vector4(-204,-351,39,8),
	Vector4(-179,-349,13,15), Vector4(-116,-276,-24,8),
	Vector4(13,-355,-44,15), Vector4(49,-350,23,11),
	Vector4(92,-356,-37,13), Vector4(139,-358,29,9),
	Vector4(165,-350,-28,16), Vector4(206,-360,31,12)]


static func _glacial_flank(x:float,z:float,h:float) -> float:
	if h < 44.0 or z < -361.0 or z > -219.0:
		return h
	var cut := 0.0
	var lip := 0.0
	for line: Vector4 in ALPINE_CHANNELS:
		var t := (z-line.y)/103.0
		if t <= 0.0 or t >= 1.0:
			continue
		var sweep := t*(1.22-.22*t)
		var across := (x-line.x-line.z*sweep-4.4*sin(t*PI))/line.w
		if absf(across)>3.8: continue
		var taper := pow(sin(t*PI),.65)
		cut = maxf(cut, 18.0*taper*exp(-across*across))
		var raised := across - (1.37 if line.z>0.0 else -1.37)
		lip = maxf(lip,7.0*taper*exp(-raised*raised*.92))
	var carved := h+(lip-cut)*smoothstep(44.0,83.0,h)
	var bench_t := (carved+.24*x-.17*z)/12.8
	var bench := 1.-smoothstep(.20,.76,fposmod(bench_t,1.0))
	var broken := smoothstep(-.54,.67,sin(x*.026+z*.014)+.65*sin(x*.064-z*.039))
	var flank := smoothstep(48.,75.,h)*(1.-smoothstep(118.,156.,h))*smoothstep(-359.,-335.,z)*(1.-smoothstep(-243.,-219.,z))
	return carved + 4.6*flank*broken*(bench-.48)


# Folded wooded foothills stand between the outer meadow and the high glacial
# wall. Their two crowns can overlap in projection; a saddle remains in each.
static func _subalpine_ledge(x:float, z:float) -> float:
	if x < -172.0 or x > 170.0 or z < -294.0 or z > -182.0: return BASE_Y
	var axis := -234.0 - .12*x + 7.0*sin(x*.036)
	var main := 51.0 + 15.0*exp(-pow((x-62.)/39.,2.)) + 23.*exp(-pow((x-126.)/29.,2.))
	main+=9.*exp(-pow((x+6.)/25.,2.)) - 9.0*exp(-pow((x-27.)/16.,2.))
	var ridge := exp(-pow(absf((z-axis)/30.0),1.62))*smoothstep(-56.,-18.,x)*(1.-smoothstep(146.,170.,x))
	var west_axis := -244.0+.20*x+7.*sin(x*.05+1.2)
	var west := 70.0 + 18.0*exp(-pow((x+90.)/26.,2.))-14.*exp(-pow((x+63.)/16.,2.))
	var west_spur := exp(-pow(absf((z-west_axis)/21.),1.35))*smoothstep(-165.,-138.,x)*(1.-smoothstep(-48.,-18.,x))
	return BASE_Y+maxf((main-BASE_Y)*ridge,(west-BASE_Y)*west_spur)


static func _range_elevation(x: float, z: float, descriptions: Array, headwall:Dictionary, noise: FastNoiseLite, basin: float) -> float:
	var result := basin
	if absf(x) > 425.0 or z > -109.0 or z < -450.0:
		return result
	result = maxf(result, _headwall_height(x,z,headwall))
	result = maxf(result, _wooded_shoulder(x,z))
	result = maxf(result, _subalpine_ledge(x,z))
	# A second, farther wooded shelf crosses the former low V in the middle.
	# Its broad crown and interleaved rock fronts establish a lateral skyline.
	var saddle_run := (z+265.0+.18*x) / 37.0
	var shoulder := 64.0 + 9.0*sin(x*.061) + 3.0*sin(x*.105+1.2)
	var saddle_mask := exp(-pow(absf((x+39.0)/83.0),4.0))
	result = maxf(result, BASE_Y+(shoulder-BASE_Y)*saddle_mask*exp(-pow(absf(saddle_run),2.6)))
	for row in descriptions:
		if z < float(row[4]) or z > float(row[5]):
			continue
		var peak := _height(x, z, row[0], row[1], row[2], row[3], noise)
		if row[6] == 1:
			# The front spur overlaps the western peak halfway up its flank.
			# A smaller eastern shoulder masks the foot of the higher snow ridge.
			peak += smoothstep(20.,64.,peak)*(17.*exp(-pow((x+124.)/49.,2.))+3.*exp(-pow((x-54.)/52.,2.)))
		var end_blend := smoothstep(row[4], float(row[4]) + 14.0, z) * (1.0 - smoothstep(float(row[5]) - 14.0, row[5], z))
		result = maxf(result, lerpf(basin, peak, end_blend))
	# Two diagonal moraine terraces catch soil on their tops and expose rock at their lips.
	# Make real walk-around silhouettes; sample trees from the final triangulated surface.
	var bench_zone := smoothstep(-48., -21., x) * (1.0 - smoothstep(59., 88., x))
	bench_zone *= smoothstep(-214., -195., z) * (1.0 - smoothstep(-173., -154., z))
	if bench_zone > 0.0:
		var level := result + .16 * x + 2.5 * sin(x * .061)
		var shelf := level
		for shelf_level: float in [24.0, 38.0]:
			var delta := level - shelf_level
			var top := 1.0 - smoothstep(2.1, 6.3, absf(delta))
			shelf -= .89 * delta * top
		result += (shelf - level) * bench_zone
	return _glacial_flank(x,z,result)


static func _mountain_color(p: Vector3, normal: Vector3, noise: FastNoiseLite) -> Color:
	var depth := smoothstep(110.0, 365.0, -p.z)
	var patch := noise.get_noise_2d(p.x * 0.63 + 17.0, p.z * 0.51)
	var broad := noise.get_noise_2d(p.x * 0.27, p.z * 0.24)
	var meadow := Color("62985c").lerp(Color("99b566"), smoothstep(-.32,.43,patch + broad * 0.5))
	var woods := smoothstep(.08,.37,patch - broad * .7) * smoothstep(.05,.27,1.0 - normal.y + 0.2)
	meadow = meadow.lerp(Color("3b7971"), woods * .87)
	var stone := Color("65889e").lerp(Color("698eb1"), depth)
	var foothill := smoothstep(25.0, 47.0, p.y)
	var steep := 1.0 - smoothstep(0.50, 0.87, normal.y)
	var shade := meadow.lerp(stone, maxf(foothill, steep * .8))
	# In this elevation belt, cool forest cover stays distinct from the high blue rock behind it.
	var wooded_zone := smoothstep(138.0,175.0,-p.z) * (1.0-smoothstep(208.0,252.0,-p.z))
	wooded_zone *= (1.0-smoothstep(63.0,77.0,p.y)) * smoothstep(.45,.90,normal.y)
	var forest := Color("246e67").lerp(Color("82b276"),smoothstep(-.39,.47,patch+.62*broad))
	shade = shade.lerp(forest,wooded_zone*.92)
	var far_bench := smoothstep(190.0,235.0,-p.z) * (1.0-smoothstep(279.0,304.0,-p.z))
	far_bench *= (1.0-smoothstep(71.0,91.0,p.y)) * smoothstep(.53,.88,normal.y)
	var granite := smoothstep(-.28,.40,patch + broad*.26 - .13*sin(p.x*.081+p.y*.2))
	var distant_green := Color("347c85").lerp(Color("6f9f9b"),granite)
	shade = shade.lerp(distant_green,far_bench*.94)
	var brush := noise.get_noise_2d(p.x * 1.25 + p.y * 0.68, p.z * 0.77)
	var scree := smoothstep(-.04,.44, brush + broad * .37) * foothill
	shade = shade.lerp(Color("aabdc5"), scree * .33)
	var distance_to_meadow := maxf(maxf(Terrain.X_MIN-p.x,p.x-Terrain.X_MAX),maxf(Terrain.Z_MIN-p.z,p.z-Terrain.Z_MAX))
	var seam := 1.0-smoothstep(3.0,22.0,distance_to_meadow)
	var front := Color("86bf63").lerp(Color("c4c3aa"), smoothstep(.20,.50,1.-normal.y))
	shade = shade.lerp(front, seam)
	shade.a = depth
	return shade


static func _build_landscape(parent: Node3D, descriptions: Array) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3701
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.034
	noise.fractal_octaves = 2
	var headwall := _headwall()
	var xs := _terrain_axis(-950.0, 950.0, Terrain.X_MIN, Terrain.X_MAX, false)
	var zs := _terrain_axis(-950.0, 950.0, Terrain.Z_MIN, Terrain.Z_MAX, true)
	var vertices := PackedVector3Array()
	for z in zs:
		for x in xs:
			var basin := _basin(x, z, noise)
			vertices.append(Vector3(x, _range_elevation(x, z, descriptions, headwall, noise, basin), z))
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var width := xs.size()
	for iz in zs.size():
		for ix in width:
			var idx := iz * width + ix
			var across := vertices[iz * width + mini(ix + 1, width - 1)] - vertices[iz * width + maxi(ix - 1, 0)]
			var along := vertices[mini(iz + 1, zs.size() - 1) * width + ix] - vertices[maxi(iz - 1, 0) * width + ix]
			var normal := along.cross(across).normalized()
			normals.append(normal)
			colors.append(_mountain_color(vertices[idx], normal, noise))
			if ix + 1 == width or iz + 1 == zs.size():
				continue
			var center_x := (xs[ix] + xs[ix + 1]) * 0.5
			var center_z := (zs[iz] + zs[iz + 1]) * 0.5
			if center_x > Terrain.X_MIN + 3.0 and center_x < Terrain.X_MAX - 3.0 and center_z > Terrain.Z_MIN + 3.0 and center_z < Terrain.Z_MAX - 3.0:
				continue
			indices.append_array(PackedInt32Array([idx, idx + 1, idx + width, idx + 1, idx + width + 1, idx + width]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = preload("res://calibration_daylight/background.gdshader")
	var instance := MeshInstance3D.new()
	instance.name = "MountainRange_ContinuousBasin"
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	_build_exterior_woods(parent,xs,zs,vertices,noise,material)


static func _grove_vertex(st:SurfaceTool,p:Vector3,n:Vector3,tint:Color) -> void:
	st.set_normal(n)
	st.set_uv2(Vector2(1.0,0.0))
	st.set_color(tint)
	st.add_vertex(p)


static func _distant_tree(st:SurfaceTool, foot:Vector3, h:float, rng:RandomNumberGenerator, fir:bool) -> void:
	var spread := h * rng.randf_range(0.16, 0.24) if fir else h * rng.randf_range(0.32, 0.45)
	if foot.z < -160.0:
		spread *= 1.11 if fir else 1.04
	var phase := rng.randf() * TAU
	var lean := Vector3(rng.randf_range(-.09,.09),0,rng.randf_range(-.11,.11)) * h
	var trunk_color := Color("596b57")
	var shade := Color("326e67") if fir else Color("478866")
	var lit := Color("639676") if fir else Color("7aab70")
	var tint := shade.lerp(lit,rng.randf_range(.04,.47))
	if foot.z < -160.0:
		var distant_tint := Color("227e72") if foot.z > -226.0 else Color("6fadb0")
		tint = tint.lerp(distant_tint,.67)
	tint.a = smoothstep(110.,365.,-foot.z)
	trunk_color.a = tint.a
	var strip: Array = []
	var heights := [0.0,.24,.29,.34,.46,.48,.61,.63,.76,.78,.91,1.] if fir else [0.0,0.32,0.45,0.57,0.75,0.91,1.0]
	var widths := [.10,.11,.57,1.,.56,.84,.42,.64,.27,.42,.19,0.] if fir else [0.10,0.12,0.75,1.0,0.99,0.67,0.0]
	var bumps := PackedFloat32Array()
	for side in 6:
		bumps.append(rng.randf_range(.74,1.24))
	for row in heights.size():
		var ring := []
		var t:float = heights[row]
		for side in 6:
			var angle := phase + TAU * float(side) / 6.0 + sin(row * 1.2 + side) * .17
			var dir := Vector3(cos(angle),0,sin(angle))
			var amount:float = widths[row] * spread * bumps[side]
			var pos := foot + lean * t + Vector3.UP * h * t + dir * amount
			if row >= 2 and row <= 5:
				pos.y += h * .045 * sin(phase+row*1.14+float(side)*2.12)
			var normal := (dir + Vector3.UP * (.18 + 0.68 * t)).normalized()
			var skirt := .03 if fir and row in [4,6,8] else .0
			var color := trunk_color if row < 2 else tint.lightened(.10*t).darkened(skirt)
			color.a = tint.a
			ring.append([pos,normal,color])
		strip.append(ring)
	for row in range(heights.size()-1):
		for side in 6:
			var next := (side+1)%6
			var a:Array=strip[row][side]
			var b:Array=strip[row][next]
			var c:Array=strip[row+1][side]
			var d:Array=strip[row+1][next]
			for item in [a,b,c]:
				_grove_vertex(st,item[0],item[1],item[2])
			if row < heights.size()-2:
				for item in [b,d,c]:
					_grove_vertex(st,item[0],item[1],item[2])


# Match _build_landscape's two triangle indices exactly. X stores the
# rendered height, Y the magnitude of the ground gradient.
static func _grove_surface(x:float,z:float,xs:PackedFloat32Array,zs:PackedFloat32Array,vertices:PackedVector3Array) -> Vector2:
	var ix:=clampi(xs.bsearch(x)-1,0,xs.size()-2)
	var iz:=clampi(zs.bsearch(z)-1,0,zs.size()-2)
	var stride:=xs.size()
	var dx:=xs[ix+1]-xs[ix]
	var dz:=zs[iz+1]-zs[iz]
	var u:=(x-xs[ix])/dx
	var v:=(z-zs[iz])/dz
	var i:=iz*stride+ix
	var y00:=vertices[i].y
	var y10:=vertices[i+1].y
	var y01:=vertices[i+stride].y
	var y11:=vertices[i+stride+1].y
	if u+v<=1.:
		return Vector2(y00+u*(y10-y00)+v*(y01-y00),Vector2((y10-y00)/dx,(y01-y00)/dz).length())
	return Vector2(y11+(1.-u)*(y01-y11)+(1.-v)*(y10-y11),Vector2((y11-y01)/dx,(y11-y10)/dz).length())


# Ground beneath each crown gets the same site mask as the actual grove.
# Adjacent tree footprints coalesce. Unplanted terraces stay exposed.
const WOODLAND_MIN := Vector2(-350.,-306.)
const WOODLAND_TEXEL := 2.0
const WOODLAND_SIZE := Vector2i(350,133)


static func _stamp_crown(cover:PackedByteArray,x:float,z:float,radius:float) -> void:
	var centre := (Vector2(x,z)-WOODLAND_MIN)/WOODLAND_TEXEL
	var rx := radius/WOODLAND_TEXEL
	var rz := rx*.77
	for iz in range(maxi(0,floori(centre.y-rz)),mini(WOODLAND_SIZE.y,ceili(centre.y+rz)+1)):
		for ix in range(maxi(0,floori(centre.x-rx)),mini(WOODLAND_SIZE.x,ceili(centre.x+rx)+1)):
			var local:=Vector2((ix+.5-centre.x)/rx,(iz+.5-centre.y)/rz)
			var falloff:=1.-smoothstep(.12,1.,local.length_squared())
			var value:=roundi(180.*falloff)
			var offset:=iz*WOODLAND_SIZE.x+ix
			cover[offset]=mini(255,cover[offset]+value)


static func _build_exterior_woods(parent:Node3D,xs:PackedFloat32Array,zs:PackedFloat32Array,vertices:PackedVector3Array,noise:FastNoiseLite,material:ShaderMaterial) -> void:
	# Groves occupy selected exterior foothill shelves. Individual six-sided
	# crowns provide parallax beyond the playable terrace in lateral views.
	var clusters := [
		Vector4(104.,-36.,15.,8.),Vector4(134.,-57.,19.,12.),Vector4(154.,-69.,16.,11.),
		Vector4(196.,-68.,22.,8.),Vector4(222.,-42.,26.,13.),Vector4(268.,-92.,19.,10.),
		Vector4(84.,-124.,18.,11.),Vector4(31.,-137.,23.,9.),Vector4(5.,-147.,15.,8.),
		Vector4(-54.,-133.,15.,11.),Vector4(-98.,-122.,18.,12.),Vector4(-124.,-87.,20.,11.),
		Vector4(-145.,-179.,36.,13.),Vector4(-106.,-177.,34.,11.),Vector4(-83.,-182.,28.,10.),
		Vector4(-49.,-194.,31.,11.),Vector4(-19.,-197.,21.,10.),Vector4(24.,-204.,21.,10.),
		Vector4(51.,-207.,30.,11.),Vector4(83.,-204.,25.,12.),Vector4(114.,-207.,22.,9.),
		Vector4(-82.,-245.,24.,10.),Vector4(-49.,-263.,18.,12.),Vector4(-23.,-261.,16.,11.),
		Vector4(3.,-259.,21.,10.),
		Vector4(-279.,-177.,25.,12.),Vector4(-237.,-175.,22.,14.),
		Vector4(-207.,-180.,27.,10.),Vector4(-178.,-174.,17.,9.),
		Vector4(-186.,-247.,24.,12.),Vector4(-150.,-244.,22.,12.),
		Vector4(36.,-242.,20.,13.),Vector4(91.,-248.,29.,11.),
		Vector4(-103.,-263.,19.,10.),Vector4(-80.,-266.,15.,7.),Vector4(-41.,-252.,13.,8.),
		Vector4(-9.,-235.,18.,8.),Vector4(11.,-232.,12.,6.),
		Vector4(39.,-230.,14.,7.),Vector4(66.,-237.,22.,9.),
		Vector4(98.,-245.,12.,8.),Vector4(126.,-254.,25.,7.),Vector4(146.,-252.,13.,8.),
		Vector4(-153.,-186.,23.,12.),Vector4(-121.,-185.,16.,13.),
		Vector4(-61.,-192.,16.,11.),Vector4(-33.,-200.,21.,10.),
		Vector4(-13.,-198.,11.,7.),Vector4(22.,-199.,16.,9.),
		Vector4(45.,-200.,24.,14.),Vector4(95.,-208.,20.,14.),
		Vector4(119.,-204.,14.,10.)]
	var front_islands := clusters.size()
	clusters.append_array([Vector4(-17.,-183.,13.,4.), Vector4(6.,-183.,12.,5.),
		Vector4(25.,-179.,9.,3.5), Vector4(45.,-191.,12.,4.)])
	var rng := RandomNumberGenerator.new()
	rng.seed=723841
	var cover:=PackedByteArray()
	cover.resize(WOODLAND_SIZE.x*WOODLAND_SIZE.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in clusters.size():
		var cluster:Vector4 = clusters[index]
		var on_shoulder := index >= 12
		var count := rng.randi_range(43,74) if on_shoulder else rng.randi_range(20,37)
		var high_grove := index >= 33
		var front_grove := index >= 43
		if high_grove:
			count = rng.randi_range(40,69)
		# Each colony has dense lobes with irregular openings, instead of an
		# even disc of dots across a hillside.
		var core_phase := cluster.x*.12
		for tree in count:
			var angle := rng.randf()*TAU
			var radius := sqrt(rng.randf())
			var x := cluster.x + cluster.z * radius * cos(angle)
			var z := cluster.y + cluster.w * radius * sin(angle)
			if high_grove:
				var pocket := rng.randi_range(0,2)
				var shift := [-.53,.14,.68][pocket] as float
				x = cluster.x + cluster.z * (shift + cos(angle)*radius*.46)
				z = cluster.y + cluster.w * (.43*sin(core_phase+pocket*2.08)+sin(angle)*radius*.74)
			var border := maxf(maxf(Terrain.X_MIN-x, x-Terrain.X_MAX),maxf(Terrain.Z_MIN-z,z-Terrain.Z_MAX))
			if border < 2.8: continue
			var surface := _grove_surface(x,z,xs,zs,vertices)
			var h:=surface.x
			if h > (94.0 if high_grove else (82.0 if on_shoulder else 39.0)): continue
			# Leave broken glades between connected crown groups rather than even stippling.
			var grove_field:=noise.get_noise_2d(x*1.5,z*1.1)
			if on_shoulder and grove_field < -.28: continue
			# Keep a group on its flatter growing surface, not scattered high up a cliff.
			if on_shoulder and surface.y > (.98 if index >= front_islands else .88): continue
			var height := rng.randf_range(3.0,7.1) * (1.0 - .17 * radius)
			if on_shoulder:
				var near_belt := z > -220.0
				height *= rng.randf_range(1.13,1.98) if near_belt else rng.randf_range(.78,1.42)
			var fir := rng.randf() > (.25 if index % 4 < 2 else .60) if on_shoulder else (index >= 7 or rng.randf() > .62)
			if high_grove:
				height *= rng.randf_range(1.33,1.74) if front_grove else rng.randf_range(1.52,2.04)
				fir = rng.randf() < (.70 if front_grove else .84)
			if on_shoulder:
				# Two valley openings widen downhill. Each crown belongs to a group
				# of mature trees, young perimeter trees or one of the open glades.
				var across := x + .31 * (z + 205.0) + 5.0 * sin(z * .079)
				var near_pass := absf(across + 58.0) / lerpf(21.0,32.0,smoothstep(-250.0,-169.0,z))
				var east_pass := absf(across - 46.0) / lerpf(22.0,32.0,smoothstep(-249.0,-181.0,z))
				var glade_edge := smoothstep(.62, 1.58, minf(near_pass, east_pass))
				if glade_edge < .075: continue
				var along := x - .54 * (z + 200.0)
				var stand := .5 + .5 * sin(along * .069 + 1.3 * sin(z * .062))
				var age := smoothstep(.16, .91, stand) * glade_edge
				height *= lerpf(.35, 1.19, age)
				if fir:
					height *= lerpf(.91,1.24,smoothstep(.64,.94,age))
				else:
					height *= .84
			if index >= front_islands:
				height *= .67
				fir = cluster.x < 0.0 or rng.randf() < .47
			if z < -138.:
				_stamp_crown(cover,x,z,height*(.60 if fir else .82)+2.4)
			_distant_tree(st,Vector3(x,h-.12,z),height,rng,fir)
	# P34: separate near woodland islands have a broad leader, low companions
	# and a deliberately empty saddle. This is geometry, not extra fog or tint.
	var near_woods := [Vector4(-31.,-120.,16.,7.),Vector4(22.,-127.,17.,8.),Vector4(63.,-128.,14.,7.)]
	var near_count := 0
	var stand_rng := RandomNumberGenerator.new()
	stand_rng.seed=341782
	for woodland: Vector4 in near_woods:
		for i in 33:
			var angle := stand_rng.randf() * TAU
			var radius := sqrt(stand_rng.randf())
			var x := woodland.x + cos(angle) * radius * woodland.z
			var z := woodland.y + sin(angle) * radius * woodland.w
			var surface := _grove_surface(x,z,xs,zs,vertices)
			if surface.y > 1.05 or surface.x > 95.0: continue
			var h := lerpf(11.3,4.1,radius) * stand_rng.randf_range(.78,1.15)
			var fir := i % 5 != 0
			_stamp_crown(cover,x,z,h*(.60 if fir else .82)+2.4)
			_distant_tree(st,Vector3(x,surface.x-.12,z),h,stand_rng,fir)
			near_count += 1
	parent.set_meta("p34_near_woodland_count",near_count)
	print("P34_NEAR_WOODLAND ",near_count)
	var understory:=Image.create_from_data(WOODLAND_SIZE.x,WOODLAND_SIZE.y,false,Image.FORMAT_R8,cover)
	material.set_shader_parameter("woodland_cover",ImageTexture.create_from_image(understory))
	material.set_shader_parameter("woodland_bounds",Vector4(WOODLAND_MIN.x,WOODLAND_MIN.y,WOODLAND_SIZE.x*WOODLAND_TEXEL,WOODLAND_SIZE.y*WOODLAND_TEXEL))
	var trees := MeshInstance3D.new()
	trees.name = "OuterBenchWoodlands"
	trees.mesh = st.commit()
	trees.material_override = material
	trees.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var vegetation := parent.get_node_or_null("DaylightVegetation")
	if vegetation != null:
		vegetation.add_child(trees)
	else:
		parent.add_child(trees)


static func build(parent: Node3D) -> void:
	# Low western headland; stepped double crest; a deep centre saddle;
	# broad eastern massif with an offset crown. Spacing/heights are unequal.
	var near_ridge: Array=[
		Vector3(-410,-20,-222),Vector3(-344,21,-211),Vector3(-316,31,-198),
		Vector3(-302,27,-193),Vector3(-281,39,-196),Vector3(-267,44,-200),
		Vector3(-254,39,-201),Vector3(-229,29,-215),Vector3(-203,30,-220),
		Vector3(-181,44,-211),Vector3(-165,49,-205),Vector3(-157,57,-200),
		Vector3(-149,54,-199),Vector3(-142,56,-202),Vector3(-130,46,-211),
		Vector3(-117,43,-219),Vector3(-104,35,-228),Vector3(-79,28,-232),
		Vector3(-57,31,-225),Vector3(-42,42,-213),Vector3(-27,46,-206),
		Vector3(-19,44,-205),Vector3(-7,49,-208),Vector3(4,48,-213),
		Vector3(17,43,-215),Vector3(31,45,-220),Vector3(47,37,-230),
		Vector3(66,31,-235),Vector3(91,33,-228),Vector3(114,44,-217),
		Vector3(128,49,-212),Vector3(139,51,-211),Vector3(149,46,-216),
		Vector3(162,48,-221),Vector3(185,39,-229),Vector3(211,35,-232),
		Vector3(240,41,-224),Vector3(270,43,-219),Vector3(295,37,-224),
		Vector3(330,25,-235),Vector3(410,-20,-245)
	]
	var near_shoulders: Array=[
		[[Vector3(-282,37,-198),Vector3(-270,29,-181),Vector3(-245,15,-159),Vector3(-230,-3,-135)],18.0],
		[[Vector3(-157,55,-201),Vector3(-173,42,-183),Vector3(-171,29,-166),Vector3(-191,5,-138)],15.0],
		[[Vector3(-144,52,-205),Vector3(-128,36,-186),Vector3(-130,20,-169),Vector3(-111,3,-140)],18.5],
		[[Vector3(-18,43,-208),Vector3(-31,33,-188),Vector3(-26,22,-170),Vector3(-42,1,-140)],18.0],
		[[Vector3(6,45,-215),Vector3(23,35,-191),Vector3(31,17,-172),Vector3(49,0,-143)],15.0],
		[[Vector3(139,48,-215),Vector3(123,37,-193),Vector3(116,21,-170),Vector3(101,2,-144)],20.0],
		[[Vector3(154,44,-219),Vector3(175,30,-193),Vector3(190,19,-173),Vector3(213,0,-144)],17.0],
		[[Vector3(264,40,-221),Vector3(249,28,-190),Vector3(255,7,-153)],21.0]
	]
	var near_gullies: Array=[
		[Vector3(-272,0,-194),Vector3(-286,0,-151),7.5,6.0],
		[Vector3(-153,0,-198),Vector3(-150,0,-145),10.0,7.5],
		[Vector3(-119,0,-214),Vector3(-98,0,-165),7.0,7.0],
		[Vector3(-19,0,-205),Vector3(-7,0,-150),9.0,8.0],
		[Vector3(35,0,-221),Vector3(56,0,-163),6.0,8.0],
		[Vector3(141,0,-212),Vector3(153,0,-149),9.0,8.5],
		[Vector3(263,0,-220),Vector3(277,0,-160),6.0,9.0]
	]
	# Middle range: one high broken massif west of centre; a low saddle lets
	# the far pale range appear behind it instead of another parallel wall.
	var middle_ridge: Array=[
		Vector3(-410,-19,-303),Vector3(-342,45,-288),Vector3(-309,56,-275),
		Vector3(-285,52,-278),Vector3(-260,61,-270),Vector3(-242,64,-264),
		Vector3(-230,58,-272),Vector3(-199,43,-289),Vector3(-172,48,-283),
		Vector3(-150,68,-271),Vector3(-132,73,-264),Vector3(-122,82,-257),
		Vector3(-114,77,-255),Vector3(-107,80,-260),Vector3(-94,68,-272),
		Vector3(-80,66,-279),Vector3(-64,55,-291),Vector3(-39,42,-304),
		Vector3(-7,49,-293),Vector3(14,77,-291),Vector3(27,86,-289),
		Vector3(42,90,-289),Vector3(54,92,-292),Vector3(67,89,-293),
		Vector3(85,99,-295),Vector3(119,101,-306),Vector3(147,104,-298),
		Vector3(176,131,-292),Vector3(201,133,-280),Vector3(212,124,-280),
		Vector3(229,61,-284),Vector3(248,62,-291),Vector3(280,47,-303),
		Vector3(323,50,-300),Vector3(356,38,-309),Vector3(410,-19,-321)
	]
	var middle_shoulders: Array=[
		[[Vector3(-245,60,-268),Vector3(-260,40,-242),Vector3(-247,14,-213)],22.0],
		[[Vector3(-122,77,-258),Vector3(-143,57,-240),Vector3(-148,28,-216),Vector3(-169,6,-198)],20.0],
		[[Vector3(-106,74,-261),Vector3(-91,56,-239),Vector3(-86,36,-222),Vector3(-62,11,-207)],17.0],
		[[Vector3(57,83,-289),Vector3(68,77,-270),Vector3(78,48,-254),Vector3(72,20,-233)],25.0],
		[[Vector3(205,65,-277),Vector3(222,42,-251),Vector3(237,14,-222)],25.0]
	]
	var middle_gullies: Array=[
		[Vector3(-122,0,-255),Vector3(-112,0,-213),9.0,9.0],
		[Vector3(-248,0,-265),Vector3(-232,0,-224),7.0,8.5],
		[Vector3(47,0,-269),Vector3(62,0,-223),8.0,11.0],
		[Vector3(204,0,-273),Vector3(191,0,-221),8.0,11.0]
	]
	_build_landscape(parent, [
		[middle_ridge, middle_shoulders, middle_gullies, 44.0, -343.0, -183.0, 1],
		[near_ridge, near_shoulders, near_gullies, 28.0, -276.0, -117.0, 0]
	])
