extends Node3D

const LAND := preload("res://refine_sunvine_ground.gdshader")
const WATER := preload("res://refine_sunvine_water.gdshader")
const SKY_PAINT := preload("res://refine_sunvine_sky.gdshader")
const CANOPY := preload("res://refine_sunvine_canopy.gdshader")
const RIDGE := preload("res://refine_sunvine_ridge.gdshader")
const STRATA := preload("res://refine_sunvine_strata.gdshader")
const STONE := preload("res://painted_stone.gdshader")
const STONE_ATLAS := preload("res://textures/painted_stone.png")
const GROUND_ATLAS := preload("res://textures/refinement_ground.png")
const PLANT := preload("res://painted_plants.gdshader")
const PLANT_ATLAS := preload("res://textures/painted_plants.png")
const ORRERY := preload("res://models/garden_hero.glb")

const POND := Vector2(8.7, -1.0)
const POND_RADIUS := Vector2(6.0, 8.5)
const ORRERY_POSITION := Vector3(-7.85, 0.12, -11.4)
const RIDGE_LANDMARKS := [
    [[-47., -40., 23., 9., 9.4, .31], [-30., -38., 14., 8., 11.9, -.17], [-11., -43., 24., 8., 6.4, -.38],
        [8., -36., 24., 12., 10.6, .15], [29., -37., 19., 9., 13.8, -.36], [52., -43., 25., 8., 8.5, .32]],
    [[-76., -65., 22., 11., 23., -.36], [-57., -58., 28., 12., 22., .26], [-33., -63., 24., 11., 27.6, -.47],
        [-15., -67., 14., 13., 12.6, .21], [2., -69., 26., 14., 18.3, -.18], [25., -61., 23., 15., 25.4, -.36],
        [58., -59., 29., 10., 20.7, .38], [81., -67., 26., 13., 19.7, .28]],
    [[-102., -100., 33., 16., 31., .24], [-74., -102., 27., 18., 42.7, -.41], [-41., -97., 25., 16., 33.1, .45],
        [-15., -101., 22., 14., 23.5, -.20], [14., -102., 28., 13., 30.4, .29], [43., -103., 32., 13., 40.2, -.33],
        [72., -100., 26., 17., 29.7, .19], [102., -104., 33., 14., 33., -.31]],
]
const MAIN := [
    Vector2(-0.4, 13.2), Vector2(.4, 7), Vector2(-1.15, 2.0),
    Vector2(-2.5, -3.7), Vector2(-1.25, -9.1), Vector2(.30, -13.25),
    Vector2(5.10, -13.55),
]
const GARDEN_BRANCH := [Vector2(-1.0, 3), Vector2(-4.6, 0.8), Vector2(-6.9, -2.0), Vector2(-7.35, -7.9)]
const POND_BRANCH := [
    Vector2(5.1, -13.55), Vector2(10.4, -12.3), Vector2(14.5, -9.5),
    Vector2(16.5, -4.5), Vector2(16.4, 4), Vector2(14.8, 7.5),
    Vector2(9.5, 8.9), Vector2(4.8, 7.6), Vector2(.4, 7),
]
const ORCHARD_BRANCH := [Vector2(.27, 8.73), Vector2(-3.52, 9.94), Vector2(-7.21, 11.0),
    Vector2(-10.25, 11.6), Vector2(-13.22, 11.10), Vector2(-15.44, 8.72)]

var rng := RandomNumberGenerator.new()
var hills := FastNoiseLite.new()
var limestone: ShaderMaterial
var foundation: ShaderMaterial
var driftstone: ShaderMaterial
var jade: StandardMaterial3D
var copper: StandardMaterial3D
var timber: StandardMaterial3D
var leaves: ShaderMaterial
var evergreen: ArrayMesh
var cherry: ArrayMesh
var golden: ArrayMesh


func review_views() -> Array:
    return [
        [Vector3(5.4, 4.6, 15.6), Vector3(-3.6, 2.15, -8.2), 46.0],
        [Vector3(11.2, 26.2, 24.0), Vector3(-1.5, 0.7, -4.1), 45.0],
    ]


func route() -> PackedVector2Array:
    return PackedVector2Array(MAIN)


func _ready() -> void:
    rng.seed = 98154
    hills.seed = 75153
    hills.frequency = 0.076
    hills.fractal_octaves = 3
    _lighting()
    limestone = _stone(Color("e8d8b8"), 4.1, 0.006)
    foundation = _stone(Color("b0ad90"), 5.8, 0.008)
    driftstone = _stone(Color("bac3a1"), 4.7, 0.009)
    jade = _solid(Color("366e66"), 0.63)
    copper = _solid(Color("998149"), 0.58, 0.46)
    timber = _solid(Color("504130"), 0.88)
    leaves = ShaderMaterial.new()
    leaves.shader = CANOPY
    leaves.set_shader_parameter("ground_atlas", GROUND_ATLAS)
    evergreen = _leaf_mesh(Color("323e28"), Color("889d43"), 11)
    cherry = _leaf_mesh(Color("6d433c"), Color("d58670"), 12)
    golden = _leaf_mesh(Color("6d592c"), Color("bc984b"), 29)
    _terrain()
    _water()
    _architecture()
    _court_inlay()
    _upper_gardens()
    _shore_treatment()
    _boulder_groups()
    _trees()
    _understory()
    _garden_flowers()
    _garden_edges()
    _forecourt()
    _lower_orchard()


func _lighting() -> void:
    var env := Environment.new()
    var sky := Sky.new()
    var color := ShaderMaterial.new()
    color.shader = SKY_PAINT
    sky.sky_material = color
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 0.94
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("c0d6d6")
    env.ambient_light_energy = 0.50
    env.ssao_enabled = true
    env.ssao_radius = 1.6
    env.ssao_intensity = 1.35
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_DEPTH
    env.fog_light_color = Color("a9cbd1")
    env.fog_depth_begin = 37.0
    env.fog_depth_end = 116.0
    env.fog_density = 0.78
    env.fog_sky_affect = 0.08
    var scene_environment := WorldEnvironment.new()
    scene_environment.environment = env
    add_child(scene_environment)
    var sun := DirectionalLight3D.new()
    sun.light_color = Color("fff0cd")
    sun.light_energy = 1.08
    sun.light_angular_distance = 1.58
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 52.0
    sun.rotation_degrees = Vector3(-43.0, -51.0, 0.0)
    add_child(sun)


func _terrain() -> void:
    var ground := ShaderMaterial.new()
    ground.shader = LAND
    ground.set_shader_parameter("stone_atlas", STONE_ATLAS)
    ground.set_shader_parameter("ground_atlas", GROUND_ATLAS)
    var mesh := _terrain_patch(Vector2(-43, -32), Vector2(43, 31), 144, 106, true)
    _mesh(mesh, ground, Vector3.ZERO)
    var floor := StaticBody3D.new()
    floor.name = "Walkable garden"
    var hit := CollisionShape3D.new()
    hit.shape = mesh.create_trimesh_shape()
    floor.add_child(hit)
    add_child(floor)
    var escarpment := _solid(Color("6d9a83"), 0.97)
    var valley := PlaneMesh.new()
    valley.size = Vector2(262.0, 223.0)
    _mesh(valley, escarpment, Vector3(0, -2.4, -37.0))
    var tiers := [
        [Vector2(-82., -57.), Vector2(79., -29.), Vector2i(124, 42), Color("3d6859"), Color("779779")],
        [Vector2(-108., -86.), Vector2(112., -44.), Vector2i(119, 39), Color("4b7181"), Color("739894")],
        [Vector2(-135., -124.), Vector2(141., -74.), Vector2i(102, 33), Color("587f93"), Color("93afb3")],
    ]
    for layer in range(tiers.size()):
        var tier: Array = tiers[layer]
        var material := ShaderMaterial.new()
        material.shader = RIDGE
        material.set_shader_parameter("pine_shadow", tier[3])
        material.set_shader_parameter("sun_rock", tier[4])
        material.set_shader_parameter("detail_strength", [0.70, 0.38, 0.19][layer])
        var ridge := _mesh(_terrain_patch(tier[0], tier[1], tier[2].x, tier[2].y, false, layer), material, Vector3.ZERO)
        ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _terrain_patch(start: Vector2, end: Vector2, subdivisions_x: int, subdivisions_z: int, walkable: bool, ridge_tier := 0) -> ArrayMesh:
    var positions := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    var width := subdivisions_x + 1
    for j in range(subdivisions_z + 1):
        var z := lerpf(start.y, end.y, float(j) / float(subdivisions_z))
        for i in range(width):
            var x := lerpf(start.x, end.x, float(i) / float(subdivisions_x))
            var p := Vector2(x, z)
            var y := _height(p) if walkable else _ridge_height(p, ridge_tier)
            var eps := 0.14
            var hx := _height(p + Vector2(eps, 0)) - _height(p - Vector2(eps, 0)) if walkable else _ridge_height(p + Vector2(eps, 0), ridge_tier) - _ridge_height(p - Vector2(eps, 0), ridge_tier)
            var hz := _height(p + Vector2(0, eps)) - _height(p - Vector2(0, eps)) if walkable else _ridge_height(p + Vector2(0, eps), ridge_tier) - _ridge_height(p - Vector2(0, eps), ridge_tier)
            positions.append(Vector3(x, y, z))
            normals.append(Vector3(-hx, eps * 2.0, -hz).normalized())
            var route_dist := _road_dist(p) if walkable else 40.0
            var orchard := 1.0 - smoothstep(.48, 1.45, _path_distance(p, ORCHARD_BRANCH)) if walkable else 0.0
            var track := maxf(1.0 - smoothstep(1.0, 3.10, route_dist), orchard * .88)
            var sand := 1.0 - smoothstep(0.0, 0.25, absf(_pond_math(p) - 1.0))
            colors.append(Color(track, orchard, sand))
            if i < subdivisions_x and j < subdivisions_z:
                var index := j * width + i
                indices.append_array(PackedInt32Array([index, index + 1, index + width + 1, index, index + width + 1, index + width]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = positions
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _height(p: Vector2) -> float:
    var y := hills.get_noise_2dv(p) * 0.72
    var route_dist := _road_dist(p)
    var edge := smoothstep(7.4, 24.2, absf(p.x))
    y += edge * (1.2 + 3.1 * maxf(0.0, hills.get_noise_2dv(p * .53)))
    var western_fold := 1.0 - smoothstep(.12, 1.0, ((p - Vector2(-25., -9.)) / Vector2(17., 21.)).length())
    var orchard_back := 1.0 - smoothstep(.08, 1.0, ((p - Vector2(-15., -22.5)) / Vector2(27., 8.0)).length())
    y += western_fold * 3.15 + orchard_back * 2.24
    if p.x < -10.5:
        var terrace := _terrace_line(p.y)
        var gardens := smoothstep(-5.6, -3.3, p.y) * (1.0 - smoothstep(11.3, 14.2, p.y))
        y += gardens * (.30 * smoothstep(.04, .53, terrace - p.x)
            + .39 * smoothstep(2.1, 2.62, terrace - p.x)) * (1.0 - smoothstep(7.4, 12.0, terrace - p.x))
    y += maxf(0.0, -p.y - 16.0) * 0.17
    y *= smoothstep(2.1, 5.3, route_dist)
    var pond_edge := _pond_math(p)
    var basin := smoothstep(0.75, 1.11, pond_edge)
    return lerpf(-1.15 + y * 0.22, y, basin)


func _paving_stage_height(p: Vector2) -> float:
    return lerpf(_height(p), 0.0, .70)


func _terrace_line(z: float) -> float:
    return -13.42 + 1.43 * cos((z - 4.08) * .238) - maxf(0.0, z - 9.0) * .21


func _mountain(p: Vector2) -> float:
    var falloff := 1.0 - exp(-maxf(0.0, -p.y - 29.5) * 0.14)
    var folds := maxf(0.0, 0.38 + hills.get_noise_2dv(p * Vector2(.85, .63)))
    var row := sin(p.x * .18 + .85 * sin(p.y * .137)) * .43 + .57
    var ridgeline := exp(-pow((p.y + 50.0 + 7.5 * sin(p.x * .105)) / 13.0, 2.0))
    return (folds * 13.0 + row * ridgeline * 10.2 - 1.0) * falloff + 1.34


func _ridge_height(p: Vector2, layer: int) -> float:
    var relief := 0.0
    var scarp := hills.get_noise_2dv(p * Vector2(.89, 1.23))
    for spec: Array in RIDGE_LANDMARKS[layer]:
        var lateral := (p.x - float(spec[0])) / float(spec[2])
        var depth := (p.y - float(spec[1])) / float(spec[3])
        var pinch := sin(lateral * 3.75 + depth * 2.6 + float(spec[5]) * 4.0)
        var contour := Vector2(lateral + depth * float(spec[5]) + .099 * pinch,
            depth + sin(lateral * 2.03) * .22 - .069 * pinch)
        var ledge := maxf(0.0, 1.0 - contour.length())
        var cleft := smoothstep(.28, .78, .5 + .5 * sin(p.x * .37 + p.y * .18 + scarp * 1.55))
        var height := pow(ledge, .80) * (1.0 + scarp * .31 - cleft * .08) * float(spec[4])
        relief = maxf(relief, height)
    var front: float = [-29., -44., -74.][layer]
    var shoulder: float = [6.1, 7.4, 9.2][layer]
    relief *= smoothstep(0.0, shoulder, front - p.y)
    return -1.8 + relief + (scarp * .47 + sin(p.x * .15) * .15) * smoothstep(0.0, 5.2, relief)


func _path_distance(p: Vector2, points: Array) -> float:
    var distance := INF
    for i in range(1, points.size()):
        var a: Vector2 = points[i - 1]
        var b: Vector2 = points[i]
        distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
    return distance


func _road_dist(p: Vector2) -> float:
    return minf(_path_distance(p, MAIN), minf(_path_distance(p, GARDEN_BRANCH) + 0.4, _path_distance(p, POND_BRANCH) + 0.45))


func _pond_math(p: Vector2) -> float:
    return ((p - POND) / POND_RADIUS + Vector2(sin(p.y * .34), sin(p.x * .61)) * .08).length()


func _water() -> void:
    var material := ShaderMaterial.new()
    material.shader = WATER
    var plane := PlaneMesh.new()
    plane.size = POND_RADIUS * 2.32
    plane.subdivide_width = 4
    plane.subdivide_depth = 6
    _mesh(plane, material, Vector3(POND.x, -0.17, POND.y)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var stone := _rock_mesh(Vector3(1.0, 0.48, 0.82), 43)
    var submerged := _stone(Color("979f79"), 4.5, .006)
    var shoals := [[Vector2(4.18, 2.82), 7], [Vector2(7.53, 5.91), 5], [Vector2(12.52, -5.09), 6],
        [Vector2(4.71, -5.43), 6], [Vector2(11.56, 3.78), 5]]
    var silt := RandomNumberGenerator.new()
    silt.seed = 49518
    for shoal in shoals:
        for i in range(shoal[1]):
            var p: Vector2 = shoal[0] + Vector2(silt.randf_range(-.95, .95), silt.randf_range(-.83, .83))
            if _pond_math(p) > .94:
                continue
            var piece := _mesh(stone, submerged, Vector3(p.x, minf(-.33, _height(p) + .16), p.y))
            piece.scale = Vector3.ONE * silt.randf_range(.43, 1.25)
            piece.rotation.y = silt.randf() * TAU
    var pad_mat := _solid(Color("657b37"), 0.83)
    var small_pad := CylinderMesh.new()
    small_pad.top_radius = .24
    small_pad.bottom_radius = .22
    small_pad.height = .027
    small_pad.radial_segments = 10
    var flower_mat := _solid(Color("eed4c5"), .78)
    var flower := SphereMesh.new()
    flower.radial_segments = 7
    flower.rings = 3
    flower.radius = .10
    flower.height = .14
    for bed in [Vector2(4.4, 1.6), Vector2(12.3, -3.6), Vector2(9.3, -7.9), Vector2(11.3, 5.)]:
        for i in range(8):
            var point: Vector2 = bed + _jitter(0.96)
            if _pond_math(point) > .94:
                continue
            var pad := _mesh(small_pad, pad_mat, Vector3(point.x, -.143, point.y))
            pad.rotation.y = rng.randf() * TAU
            pad.scale = Vector3.ONE * rng.randf_range(.6, 1.45)
            if i % 3 == 0:
                _mesh(flower, flower_mat, Vector3(point.x - .09, -.055, point.y))


func _architecture() -> void:
    var gate := ORRERY.instantiate() as Node3D
    gate.position = ORRERY_POSITION
    gate.rotation.y = deg_to_rad(8.0)
    add_child(gate)
    _box(Vector3(-7.8, -0.12, -11.4), Vector3(7.48, 0.61, 4.6), foundation)
    _collision(Vector3(-7.85, 1.15, -11.7), Vector3(6.94, 2.4, 2.85))
    for i in range(3):
        _box(Vector3(-7.83, -0.18 + i * .115, -8.58 - i * .26), Vector3(6.72 - i * .16, .23, .56), limestone)
    for wing in [[-13.0, -12.6, .20], [-2.76, -12.6, -.07]]:
        var origin := Vector3(wing[0], 0, wing[1])
        for row in range(2):
            for i in range(5):
                var x := float(i - 2) * .71 + (row * .17)
                var point := origin + Vector3(x, -.08 + row * .32, x * wing[2])
                var brick := _box(point, Vector3(.68, .31, .72), limestone if (i + row) % 3 else foundation)
                brick.rotation.y = -wing[2]
        _column(origin + Vector3(1.39, 0, 0.38), 1.22)
    for anchor in [Vector2(-4.4, 7.7), Vector2(2.42, 5.7), Vector2(-5.22, -6.4), Vector2(2.54, -10.56), Vector2(13.75, -7.9)]:
        _brazier(anchor)
    for point in [Vector2(-8.1, 6.3), Vector2(-10.5, -6.2), Vector2(13.0, 7.3), Vector2(-.74, -15.9)]:
        _garden_bench(point)


func _court_inlay() -> void:
    var at := Vector2(-.05, 6.55)
    var tarnish := _solid(Color("8f8157"), .86, .13)
    var bedding := _stone(Color("bca57b"), 2.8, .003)
    var stone_ring := SurfaceTool.new()
    var brass_ring := SurfaceTool.new()
    stone_ring.begin(Mesh.PRIMITIVE_TRIANGLES)
    brass_ring.begin(Mesh.PRIMITIVE_TRIANGLES)
    for sector in range(36):
        var center := TAU * float(sector) / 36.0
        var width := TAU / 36.0
        if sector not in [1, 2, 11, 19, 20, 25, 31]:
            _inlay_panel(stone_ring, at, center - width * .48, center + width * .50, 1.35, 1.59)
        if sector not in [0, 1, 6, 15, 16, 27, 29, 30]:
            _inlay_panel(brass_ring, at, center - width * .50, center + width * .51, 1.30, 1.34)
        if sector % 6 in [0, 1] and sector != 30:
            _inlay_panel(brass_ring, at, center - width * .24, center + width * .22, 1.08, 1.22)
    for mark in range(7):
        var from_angle := TAU * mark / 7.0
        var to_angle := TAU * (mark + 1.0) / 7.0
        _inlay_panel(stone_ring, at, from_angle + .018, to_angle - .018, .30, .46)
        if mark in [0, 1, 3, 4]:
            var bearing := (from_angle + to_angle) * .5
            _inlay_panel(brass_ring, at, bearing - .035, bearing + .035, .58, 1.01)
    for pair: Array in [[stone_ring, bedding], [brass_ring, tarnish]]:
        pair[0].generate_normals()
        _mesh(pair[0].commit(), pair[1], Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _inlay_panel(layer: SurfaceTool, at: Vector2, left: float, right: float, inner: float, outer: float) -> void:
    var a := Vector2(cos(left), sin(left))
    var b := Vector2(cos(right), sin(right))
    var corners := [at + a * inner, at + a * outer, at + b * outer, at + b * inner]
    for index in [0, 1, 2, 0, 2, 3]:
        var p: Vector2 = corners[index]
        layer.add_vertex(Vector3(p.x, _height(p) + .015, p.y))


func _upper_gardens() -> void:
    var cuts := ShaderMaterial.new()
    cuts.shader = STRATA
    var local := RandomNumberGenerator.new()
    local.seed = 280142
    # Staggered horizontal beds build a recognizable ridge silhouette behind the water garden.
    var outcrops := [
        [Vector2(-19.40, -10.2), Vector3(5.9, 3.5, 4.6), -.17],
        [Vector2(-20.20, -13.5), Vector3(6.5, 4.6, 5.5), -.27],
        [Vector2(-17.40, -16.4), Vector3(6.3, 3.8, 5.1), -.24],
        [Vector2(-19.50, -4.3), Vector3(6.0, 2.5, 4.8), .08],
        [Vector2(-21.25, 1.9), Vector3(6.8, 2.8, 5.3), -.26],
        [Vector2(-18.20, 6.2), Vector3(4.5, 1.7, 3.3), .07],
        [Vector2(15.90, -22.15), Vector3(9.7, 4.5, 4.2), .08],
        [Vector2(19.3, -19.3), Vector3(7.1, 4.0, 4.7), -.13],
        [Vector2(23.7, -17.2), Vector3(8.2, 4.0, 5.0), -.43],
        [Vector2(7.30, -23.8), Vector3(9.0, 3.3, 3.8), -.06],
        [Vector2(-1.0, -23.3), Vector3(6.9, 2.7, 3.7), .08],
        [Vector2(-8.4, -22.7), Vector3(8.4, 2.5, 4.1), -.10],
    ]
    for index in range(outcrops.size()):
        var record: Array = outcrops[index]
        var p: Vector2 = record[0]
        var dimensions: Vector3 = record[1]
        var facing: float = record[2]
        var rock := _mesh(_strata_mesh(dimensions, local), cuts, Vector3(p.x, _height(p) - .4, p.y))
        rock.rotation.y = facing
        _collision(rock.position + Vector3(0, dimensions.y * .26, 0), dimensions * Vector3(.70, .71, .58))
        if index in [1, 2, 4, 6, 8, 9, 11]:
            var root := rock.position + Vector3(-.12, dimensions.y * .92, -.22)
            _tree(root, 2.4 + .6 * float(index % 3), 0 if index != 6 else 2)

    var trim := _stone(Color("beae89"), 4.4, .009)
    var old_tiles := _solid(Color("4e796c"), .67)
    var arcade_origin := Vector3(3.3, 0, -18.8)
    for index in range(3):
        var bay := arcade_origin + Vector3(4.03 * index, 0, -.20 * index)
        _viaduct_bay(bay, index, trim, old_tiles, local)
    var end := arcade_origin + Vector3(10.12, 0, -.48)
    for i in range(5):
        var offset := Vector3(.47 * i, -.35 + .35 * i, -.08 * i)
        var abutment := _worn_block(end + offset, Vector3(1.30, 1.25, 1.95), .14, local)
        abutment.material_override = trim
    _collision(end + Vector3(.72, .80, 0), Vector3(2.82, 2.70, 1.96))

    _plant_terrace_pockets(local)


func _lower_orchard() -> void:
    var local := RandomNumberGenerator.new()
    local.seed = 463918
    var old_base := _stone(Color("969673"), 3.4, .007)
    var mortar := _stone(Color("797d5e"), 3.0, .007)
    var warm_cap := _stone(Color("c6b996"), 4.1, .008)
    var sod := _plant(Vector2(0, 0), Color("91a773"))
    var flower := _plant(Vector2(1, 0), Color("e1c7ae"))
    var fern := QuadMesh.new()
    fern.size = Vector2.ONE
    var borders := [
        [Vector2(-17.88, 4.1), Vector2(-17.11, 6.3), Vector2(-16.36, 7.86), Vector2(-15.5, 8.85),
            Vector2(-14.2, 9.71), Vector2(-12.66, 9.85), Vector2(-11.40, 9.25)],
        [Vector2(-21.4, 5.3), Vector2(-19.6, 8.3), Vector2(-18.05, 10.30), Vector2(-16.72, 11.55),
            Vector2(-14.87, 12.76), Vector2(-12.87, 13.24), Vector2(-10.8, 12.79), Vector2(-9.45, 12.05)],
        [Vector2(-20.60, 10.15), Vector2(-19.10, 12.1), Vector2(-16.97, 13.82), Vector2(-14.9, 15.22),
            Vector2(-13.12, 15.62), Vector2(-11.34, 15.41), Vector2(-10.20, 14.67)],
    ]
    for tier in range(borders.size()):
        var border: Array = borders[tier]
        for section in range(border.size() - 1):
            var first: Vector2 = border[section]
            var second: Vector2 = border[section + 1]
            var axis := (second - first).normalized()
            var facing := Vector2(axis.y, -axis.x)
            var bearing := atan2(-axis.y, axis.x)
            var count := maxi(2, roundi(first.distance_to(second) / .78))
            var span := first.distance_to(second) / float(count)
            for block in range(count):
                var p := first.lerp(second, (block + .5) / count)
                var path := _path_distance(p, ORCHARD_BRANCH)
                if path < .91 or _road_dist(p) < 2.0:
                    continue
                var y := _height(p)
                var height := local.randf_range(.36, .65) * (1.19 if tier == 1 else .91)
                var center := Vector3(p.x, y, p.y)
                var base := _worn_block(center + Vector3.UP * height * .20, Vector3(span + .06, height, .83), .11, local)
                base.material_override = mortar if (section + block * 2) % 4 == 1 else old_base
                base.rotation.y = bearing + local.randf_range(-.045, .045)
                var cap_at := p + facing * .066
                var cap := _worn_block(Vector3(cap_at.x, y + height * .79, cap_at.y), Vector3(span * .98, .18, .99), .08, local)
                cap.material_override = warm_cap if (section + block) % 4 != 0 else old_base
                cap.rotation.y = base.rotation.y
                if block == 0 and tier != 2:
                    _collision(center + Vector3.UP * .16, Vector3(.68, .49, .66))
                if (section + block * 3) % 4 == 1:
                    var foot := p + facing * .64
                    var h := local.randf_range(.61, 1.09)
                    for plant in range(5):
                        var spot := foot + axis * local.randf_range(-.46, .47) + facing * local.randf_range(-.16, .36)
                        if _path_distance(spot, ORCHARD_BRANCH) < .74:
                            continue
                        var tuft := _mesh(fern, flower if plant == 1 else sod, Vector3(spot.x, _height(spot) + h * .36, spot.y))
                        tuft.rotation.y = local.randf_range(-PI, PI)
                        tuft.scale = Vector3(h * 1.34, h, 1)
                        tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    for entry: Array in [[Vector2(-15.73, 6.03), 3.04, 2], [Vector2(-17.24, 9.55), 3.68, 1],
        [Vector2(-18.68, 7.44), 3.46, 0], [Vector2(-19.3, 10.4), 2.92, 0],
        [Vector2(-14.42, 14.19), 3.56, 1], [Vector2(-12.72, 14.21), 3.18, 2],
        [Vector2(-9.62, 12.36), 3.05, 0]]:
        var point: Vector2 = entry[0]
        _tree(Vector3(point.x, _height(point), point.y), entry[1], entry[2])
    _orchard_stones(local, warm_cap)


func _orchard_stones(local: RandomNumberGenerator, cap: Material) -> void:
    for segment in range(ORCHARD_BRANCH.size() - 1):
        var from: Vector2 = ORCHARD_BRANCH[segment]
        var to: Vector2 = ORCHARD_BRANCH[segment + 1]
        var direction := (to - from).normalized()
        var facing := Vector2(-direction.y, direction.x)
        var joints := maxi(2, roundi(from.distance_to(to) / .84))
        for i in range(joints):
            if (segment + i) % 5 == 2:
                continue
            var p := from.lerp(to, (i + .5) / joints) + facing * local.randf_range(-.31, .31)
            var stone := _worn_block(Vector3(p.x, _height(p) - .018, p.y), Vector3(.58, .088, .81), .19, local)
            stone.rotation.y = atan2(-direction.y, direction.x) + local.randf_range(-.23, .23)
            stone.material_override = cap
    # Exposed tread edges around the entrance keep the main court finish on the same stone family.
    var turn := Vector2(-.35, 9.2)
    var ward := Vector2(-1.35, 1.5)
    for index in range(35):
        var at := turn.lerp(ward, local.randf())
        at.x += local.randf_range(-3.02, -.74)
        at.y += local.randf_range(-.45, .56)
        if _road_dist(at) > 3.01:
            continue
        var stone := _worn_block(Vector3(at.x, _height(at) - .025, at.y),
            Vector3(local.randf_range(.40, .69), .080, local.randf_range(.29, .72)), .19, local)
        stone.rotation.y = local.randf_range(-.29, .64)
        stone.material_override = cap


func _strata_mesh(size: Vector3, local: RandomNumberGenerator) -> ArrayMesh:
    var profile := PackedVector2Array([Vector2(-.50, -.19), Vector2(-.36,-.47), Vector2(.04,-.50),
        Vector2(.37,-.43), Vector2(.50,-.11), Vector2(.43,.29), Vector2(.12,.49),
        Vector2(-.24,.45), Vector2(-.54,.24)])
    var levels: Array[PackedVector3Array] = []
    var whorls := [[-.19, 1.13, .02], [.19, 1.03, -.05], [.36, .97, -.02],
        [.42, 1.04, -.065], [.67, .94, .065], [.73, .87, .055], [.90, .72, .13]]
    for band in whorls:
        var ring := PackedVector3Array()
        for corner in profile:
            var x: float = corner.x * band[1] + band[2] + local.randf_range(-.073, .073)
            var z: float = corner.y * band[1] + local.randf_range(-.065, .065)
            var y: float = band[0] + x * .085 + z * .072 + local.randf_range(-.027, .027)
            ring.append(Vector3(x, y, z) * size)
        levels.append(ring)
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_smooth_group(-1)
    for layer in range(levels.size() - 1):
        for i in range(profile.size()):
            var next := (i + 1) % profile.size()
            for point in [levels[layer][i], levels[layer][next], levels[layer + 1][next],
                levels[layer][i], levels[layer + 1][next], levels[layer + 1][i]]:
                surface.add_vertex(point)
    var cap := levels[-1]
    var crest := Vector3(.05 * size.x, size.y, -.08 * size.z)
    for i in range(profile.size()):
        for point in [cap[i], cap[(i + 1) % profile.size()], crest]:
            surface.add_vertex(point)
    surface.generate_normals()
    return surface.commit()


func _viaduct_bay(at: Vector3, index: int, trim: Material, old_tiles: Material, local: RandomNumberGenerator) -> void:
    var spring := at + Vector3(0, 1.83, .03)
    var sides := [-1.0, 1.0] if index == 0 else [1.0]
    for side: float in sides:
        var post := at + Vector3(side * 2.015, 0, -.06)
        var base := _height(Vector2(post.x, post.z))
        var bottom := minf(base - .18, .05)
        _box(post + Vector3(0, bottom + .11, 0), Vector3(.89, .32, 1.38), foundation)
        for course in range(4):
            var center := Vector3(post.x, lerpf(bottom + .27, 1.62, course / 3.0), post.z)
            var stone := _worn_block(center, Vector3(.72, .53, .92), .085, local)
            stone.material_override = trim if course in [0, 2] else limestone
        _box(post + Vector3(0, 1.82, 0), Vector3(.92, .16, 1.20), limestone)
        _collision(post + Vector3(0, 1.02, 0), Vector3(.77, 2.12, .97))
    var segments := 13
    for i in range(segments):
        var first := PI * float(i) / float(segments) + .007
        var last := PI * float(i + 1) / float(segments) - .007
        var top_rail := 3.53 - at.y
        var arch := _arch_stone(first, last, Vector2(1.56, 1.31), Vector2(1.94, 1.62), .119)
        _mesh(arch, trim if i % 4 == 1 else limestone, spring + Vector3(0, 0, .54))
        var wall := _arch_stone(first - .009, last + .009, Vector2(1.60, 1.36), Vector2(1.98, 1.67), .89, top_rail - spring.y)
        _mesh(wall, foundation if i % 4 == 2 else trim, spring + Vector3(0, 0, -.05))
    _box(at + Vector3(0, 3.59, 0), Vector3(4.045, .16, 1.31), limestone)
    _box(at + Vector3(0, 3.77, -.015), Vector3(4.045, .085, 1.06), old_tiles)
    _box(at + Vector3(0, 3.90, -.09), Vector3(4.045, .16, .86), trim)
    for offset: float in [-.82, .82]:
        _cylinder(at + Vector3(offset, 3.1, .565), .105, .105, .035, copper, 8).rotation.x = PI * .5
    _collision(at + Vector3(0, 3.51, 0), Vector3(4.00, .9, 1.2))


func _arch_stone(first: float, last: float, inside: Vector2, outside: Vector2, depth: float, to_coping := -1.0) -> ArrayMesh:
    var points := PackedVector3Array()
    for z: float in [depth / 2.0, -depth / 2.0]:
        for coordinate in [Vector2(cos(last), sin(last)) * inside, Vector2(cos(last), sin(last)) * outside,
            Vector2(cos(first), sin(first)) * outside, Vector2(cos(first), sin(first)) * inside]:
            var p: Vector2 = coordinate
            if to_coping > 0.0 and points.size() % 4 in [1, 2]:
                p.y = to_coping
            points.append(Vector3(p.x, p.y, z))
    var band := SurfaceTool.new()
    band.begin(Mesh.PRIMITIVE_TRIANGLES)
    band.set_smooth_group(-1)
    for face in [[1, 0, 3, 2], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [2, 3, 7, 6], [1, 5, 4, 0]]:
        for corner: int in [face[0], face[2], face[1], face[0], face[3], face[2]]:
            band.add_vertex(points[corner])
    band.generate_normals()
    return band.commit()


func _plant_terrace_pockets(local: RandomNumberGenerator) -> void:
    var beds := [
        [Vector2(-15.2, 5.2), Vector2(1.54, .77), -1.0], [Vector2(-14.2, -3.0), Vector2(1.81, .96), -.6],
        [Vector2(-10.3, -8.5), Vector2(.72, .85), .4], [Vector2(-8.1, 8.55), Vector2(1.20, .58), .44],
        [Vector2(-3.56, 5.52), Vector2(.70, .92), -.48], [Vector2(3.01, 4.13), Vector2(.83, 1.04), -.27],
        [Vector2(1.08, -16.76), Vector2(1.30, .52), -.22], [Vector2(5.22, -17.42), Vector2(1.45, .76), .24],
        [Vector2(12.63, -15.65), Vector2(1.31, .72), .18], [Vector2(-18.0, -12.2), Vector2(1.72, .80), -.18],
    ]
    var fronds := _solid(Color("657f46"), .75)
    var pale := _solid(Color("8a9b60"), .79)
    var petal := _solid(Color("c78070"), .82)
    var centers := _solid(Color("b69949"), .78)
    var test_mesh := QuadMesh.new()
    test_mesh.size = Vector2.ONE
    var low := _plant(Vector2(0, 0), Color("7f9a6d"))
    for bed: Array in beds:
        var fronds_geo := SurfaceTool.new()
        fronds_geo.begin(Mesh.PRIMITIVE_TRIANGLES)
        fronds_geo.set_smooth_group(-1)
        for place in range(20):
            var offset := Vector2(local.randf_range(-1., 1.), local.randf_range(-1., 1.))
            var p: Vector2 = bed[0] + (offset * (bed[1] as Vector2)).rotated(bed[2])
            if _road_dist(p) < 2.17 or _pond_math(p) < 1.03:
                continue
            var y := _height(p)
            var source := Vector3(p.x, y + .01, p.y)
            var length := local.randf_range(.24, .60)
            for leaf in range(4):
                var phase := float(leaf) * TAU / 4.0 + local.randf_range(-.4, .4)
                var bearing := Vector3(cos(phase), 0, sin(phase))
                var cross := Vector3(-bearing.z, 0, bearing.x)
                var lift := length * local.randf_range(.35, .67)
                var elbow := source + bearing * length * .43 + Vector3.UP * lift
                var far := source + bearing * length + Vector3.UP * lift * .68
                var root := source + Vector3.UP * .09
                var bias := cross * length * .128
                var vein := elbow + Vector3.UP * length * .08
                for v: Vector3 in [root, elbow - bias, vein, root, vein, elbow + bias,
                    far, vein, elbow - bias, far, elbow + bias, vein]:
                    fronds_geo.add_vertex(v)
            if place % 4 == 1:
                var at := source + Vector3.UP * length * 1.15
                _taper(source, at, .012, .006, pale)
                for q in range(4):
                    var theta := q * PI / 2.0 + .31
                    var bloom := _cylinder(at + Vector3(cos(theta), .008, sin(theta)) * .080, .072, .040, .039, petal, 7)
                    bloom.rotation.z = cos(theta) * .31
                    bloom.rotation.x = sin(theta) * -.31
                _cylinder(at + Vector3.UP * .028, .034, .038, .027, centers, 7)
            var under := _mesh(test_mesh, low, source + Vector3.UP * length * .24)
            under.scale = Vector3(length * 1.8, length * .65, 1)
            under.rotation.y = PI * offset.x
            under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        fronds_geo.generate_normals()
        _mesh(fronds_geo.commit(), fronds, Vector3.ZERO)


func _shore_treatment() -> void:
    var spans := [
        [2.40, 3.13, 0.11],
        [3.30, 3.68, 0.14],
        [4.36, 4.67, 0.17],
        [5.38, 5.66, 0.16],
        [0.49, 0.83, 0.18],
    ]
    for span in spans:
        var first: float = span[0]
        var end: float = span[1]
        var interval: float = span[2]
        var count := floori((end - first) / interval) + 1
        for index in range(count):
            var a := first + index * interval
            var out := Vector2(cos(a), sin(a))
            var p := POND + POND_RADIUS * out * (1.053 + sin(a * 11.4) * .020)
            var y := _height(p)
            var span_size := rng.randf_range(.56, .78)
            var block := _box(Vector3(p.x, y + .035, p.y), Vector3(span_size, .28, .38), foundation)
            block.rotation.y = atan2(out.x, out.y) + rng.randf_range(-.15, .15)
            if index % 3 != 2:
                var coping := _box(Vector3(p.x, y + .17, p.y), Vector3(span_size * .92, .093, .44), limestone)
                coping.rotation.y = block.rotation.y
    # One ruined observation point across the garden, midway between the far trees.
    var court := Vector3(7.95, -0.07, -16.64)
    _box(court, Vector3(3.3, .25, 2.20), foundation)
    _box(court + Vector3(0, .155, .08), Vector3(3.06, .14, 1.94), limestone)
    for i in [-1, 1]:
        _column(court + Vector3(i * 1.18, .22, -.58), 1.2 if i == -1 else 2.14)
    var dial_at := court + Vector3(.07, .34, -.225)
    _cylinder(dial_at, .63, .72, .29, limestone, 13)
    _cylinder(dial_at + Vector3(0, .19, 0), .54, .55, .13, jade, 13)
    _taper(dial_at + Vector3(0, .24, .11), dial_at + Vector3(.19, .91, -.30), .073, .025, copper)
    for index in range(8):
        var phase := TAU * float(index) / 8.0
        var mark := _box(dial_at + Vector3(cos(phase) * .44, .266, sin(phase) * .44), Vector3(.094, .032, .035), copper)
        mark.rotation.y = -phase


func _garden_edges() -> void:
    var slab_rng := RandomNumberGenerator.new()
    slab_rng.seed = 6598
    var ledges := [
        [Vector2(-11.7, 9.5), Vector2(-10.5, 7.1), Vector2(-9.9, 4.5), Vector2(-10.4, 2.45), Vector2(-11.35, 0.45)],
        [Vector2(-13.4, 8.5), Vector2(-12.4, 6.4), Vector2(-12.0, 4.7), Vector2(-12.6, 2.9)],
    ]
    var moss := _stone(Color("89946e"), 2.9, 0.010)
    for row in range(ledges.size()):
        var wall: Array = ledges[row]
        for section in range(wall.size() - 1):
            var from: Vector2 = wall[section]
            var to: Vector2 = wall[section + 1]
            var count := maxi(2, roundi(from.distance_to(to) / .73))
            var yaw := atan2(-(to - from).y, (to - from).x)
            for index in range(count):
                var p := from.lerp(to, (float(index) + .5) / count)
                var y := _height(p)
                var height := slab_rng.randf_range(.33, .55) * (1.05 if row == 0 else .82)
                var base := Vector3(p.x, y + height * .26, p.y)
                var width := from.distance_to(to) / count
                var stone := _worn_block(base, Vector3(width * .98, height, .82), .15, slab_rng)
                stone.material_override = moss if (section + index) % 4 == 0 else foundation
                stone.rotation.y = yaw + slab_rng.randf_range(-.075, .075)
                if (section + index * 2 + row) % 5 != 2:
                    var lip := _worn_block(base + Vector3(0, height * .56, 0), Vector3(width * .97, .145, .91), .13, slab_rng)
                    lip.material_override = limestone if index % 3 == 0 else foundation
                    lip.rotation.y = stone.rotation.y
    var bank := Vector2(-.38, .925).normalized()
    var outward := Vector2(bank.x, bank.y).normalized()
    var bearing := atan2(outward.x, outward.y)
    for later in range(5):
        var distance := 1.16 - float(later) * .053
        var p := POND + POND_RADIUS * bank * distance
        var y := maxf(-.46, _height(p)) + .026
        var step := _worn_block(Vector3(p.x, y, p.y), Vector3(1.81 - later * .072, .15, .58), .14, slab_rng)
        step.rotation.y = bearing
        step.material_override = limestone if later < 2 else moss
        for side: float in [-1.0, 1.0]:
            var shoulder := p + Vector2(outward.y, -outward.x) * side * .96
            var trim := _worn_block(Vector3(shoulder.x, maxf(-.40, _height(shoulder)) + .09, shoulder.y),
                Vector3(.40, .38, .64), .19, slab_rng)
            trim.rotation.y = bearing + side * .13
            trim.material_override = foundation
    # Fragments and clumps follow sheltered wall feet and the water level.
    var grasses := _plant(Vector2(0, 0), Color("adb68b"))
    var flowers := _plant(Vector2(1, 0), Color("dcd1a7"))
    var tuft := QuadMesh.new()
    tuft.size = Vector2.ONE
    for center: Vector2 in [Vector2(-10.2, 6.8), Vector2(-9.7, 4.6), Vector2(-10.5, 2.0), Vector2(6.7, 8.1),
        Vector2(5.45, 6.7), Vector2(4.32, 4.05), Vector2(3.04, .81), Vector2(13.5,-5.1)]:
        for index in range(8):
            var shift := Vector2(slab_rng.randf_range(-.82, .82), slab_rng.randf_range(-.70, .70))
            var p := center + shift
            if _road_dist(p) < 1.42 or _pond_math(p) < .97:
                continue
            var height := slab_rng.randf_range(.44, .96)
            var at := Vector3(p.x, _height(p), p.y)
            var angle := slab_rng.randf_range(-PI, PI)
            for facing: float in [angle, angle + 1.30]:
                var forest := _mesh(tuft, flowers if index % 4 == 0 else grasses, at + Vector3.UP * height * .43)
                forest.scale = Vector3(height * 1.28, height, 1.0)
                forest.rotation.y = facing
                forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            if index % 3 == 1:
                var fragment := _worn_block(at + Vector3(.22, .035, -.22), Vector3(.28, .13, .32), .18, slab_rng)
                fragment.rotation.y = angle
                fragment.material_override = moss


func _worn_block(origin: Vector3, size: Vector3, irregularity: float, local_rng: RandomNumberGenerator) -> MeshInstance3D:
    var xs := [-.5, -.35, .34, .5, .5, .34, -.35, -.5]
    var zs := [-.31, -.5, -.5, -.33, .31, .5, .5, .32]
    var geometry := SurfaceTool.new()
    geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
    var levels: Array[PackedVector3Array] = []
    var offsets := PackedVector2Array()
    for i in range(8):
        offsets.append(Vector2(local_rng.randf_range(-irregularity, irregularity),
            local_rng.randf_range(-irregularity, irregularity)) * .30)
    for layer in range(4):
        var bevel := .83 if layer % 3 == 0 else 1.0
        var height: float = [-.5, -.31, .26, .50][layer]
        var ring := PackedVector3Array()
        for i in range(8):
            ring.append(Vector3((float(xs[i]) + offsets[i].x) * bevel, height + local_rng.randf_range(-.045, .045),
                (float(zs[i]) + offsets[i].y) * bevel) * size)
        levels.append(ring)
    for layer in range(3):
        for i in range(8):
            var next := (i + 1) % 8
            for vertex in [levels[layer][i], levels[layer][next], levels[layer+1][next],
                levels[layer][i], levels[layer+1][next], levels[layer+1][i]]:
                geometry.add_vertex(vertex)
    for i in range(1, 7):
        geometry.add_vertex(levels[3][0])
        geometry.add_vertex(levels[3][i])
        geometry.add_vertex(levels[3][i+1])
    geometry.generate_normals()
    return _mesh(geometry.commit(), foundation, origin)


func _forecourt() -> void:
    var tools := RandomNumberGenerator.new()
    tools.seed = 14619
    var mottled_stone := _stone(Color("9d9a7a"), 2.94, .008)
    var damp := _stone(Color("797c5b"), 3.22, .010)
    for tier in range(2):
        var z := -.4 if tier == 0 else 2.2
        var last := 12.7 if tier == 0 else 10.6
        while z < last:
            var span := tools.randf_range(.68, 1.66)
            var next := minf(z + span, last)
            var first := Vector2(_terrace_line(z) - 2.1 * tier, z)
            var second := Vector2(_terrace_line(next) - 2.1 * tier, next)
            var point := (first + second) * .5
            var height := tools.randf_range(.34, .53)
            var bearing := atan2(-(second - first).y, (second - first).x)
            if tools.randf() > .11 and span > .34:
                var wall := _worn_block(Vector3(point.x, _height(point + Vector2(.16, 0)) + height * .19, point.y),
                    Vector3(span * .97, height, .66 if tier == 0 else .54), .14, tools)
                wall.rotation.y = bearing + tools.randf_range(-.07, .08)
                wall.material_override = mottled_stone if tools.randf() > .27 else damp
                if tools.randf() > .28:
                    var cap := _worn_block(wall.position + Vector3(0, height * .48, 0),
                        Vector3(span * .92, .136, .77), .13, tools)
                    cap.rotation.y = wall.rotation.y
                    cap.material_override = limestone if tools.randf() < .45 else mottled_stone
            z = next

    var rill := [
        Vector2(-9.16, 4.19), Vector2(-9.38, 5.17), Vector2(-9.79, 5.57),
        Vector2(-10.09, 6.11), Vector2(-10.24, 7.18),
    ]
    var dark_water := _solid(Color("315f53"), .63, .10)
    for index in range(rill.size() - 1):
        var first: Vector2 = rill[index]
        var second: Vector2 = rill[index + 1]
        _rill_section(first, second, mottled_stone, dark_water, tools)
    _meter(Vector2(-9.16, 3.23), mottled_stone, damp, dark_water, tools)
    # A low cistern terminal overlaps the rill mouth and the lower terrace at the foot of the green tree.
    var terminal := rill[-1] as Vector2
    var terminal_base := Vector3(terminal.x, _height(terminal), terminal.y + .30)
    var base_plinth := _worn_block(terminal_base + Vector3(0, .04, 0), Vector3(1.58, .24, 1.23), .14, tools)
    base_plinth.material_override = damp
    _box(terminal_base + Vector3(0, .18, .09), Vector3(1.13, .035, .76), dark_water)
    for bank: float in [-1., 1.]:
        _box(terminal_base + Vector3(bank * .65, .20, .10), Vector3(.16, .22, .89), limestone)
    _box(terminal_base + Vector3(0, .21, .56), Vector3(1.35, .20, .17), mottled_stone)

    # Turn the curved shelf ends into planting areas and keep the old branch clear.
    var clover := _plant(Vector2(0, 0), Color("95ac79"))
    var petals := _plant(Vector2(1, 0), Color("e4bdb7"))
    var blade := QuadMesh.new()
    blade.size = Vector2.ONE
    for guide: Vector2 in [Vector2(-12.72, .62), Vector2(-12.91, 4.1), Vector2(-14.29, 6.4),
        Vector2(-14.58, 8.14), Vector2(-13.84, 10.25), Vector2(-11.64, 7.52),
        Vector2(-12.35, -2.4), Vector2(-9.51, 2.67)]:
        for i in range(5):
            var p := guide + Vector2(tools.randf_range(-.76, .62), tools.randf_range(-.63, .66))
            if _road_dist(p) < 1.8:
                continue
            var y := _height(p)
            var bearing := tools.randf_range(-PI, PI)
            var scale := tools.randf_range(.64, 1.26)
            for yaw: float in [bearing, bearing + 1.34]:
                var tuft := _mesh(blade, petals if i == 1 else clover, Vector3(p.x, y + scale * .44, p.y))
                tuft.rotation.y = yaw
                tuft.scale = Vector3(scale * 1.1, scale, 1)
                tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _rill_section(first: Vector2, second: Vector2, stone: Material, water: Material, tools: RandomNumberGenerator) -> void:
    var difference := second - first
    var normal := Vector2(-difference.y, difference.x).normalized()
    var yaw := atan2(-difference.y, difference.x)
    var channels := PackedVector3Array()
    for p: Vector2 in [first - normal * .16, second - normal * .16,
        second + normal * .16, first + normal * .16]:
        channels.append(Vector3(p.x, _height(p) + .034, p.y))
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for vertex in [channels[0], channels[1], channels[2], channels[0], channels[2], channels[3]]:
        surface.set_normal(Vector3.UP)
        surface.add_vertex(vertex)
    _mesh(surface.commit(), water, Vector3.ZERO)
    var center := (first + second) * .5
    for side: float in [-1.0, 1.0]:
        var pick := center + normal * side * .255
        var curb := _worn_block(Vector3(pick.x, _height(pick) + .071, pick.y),
            Vector3(difference.length() + .046, .21, .22), .075, tools)
        curb.rotation.y = yaw
        curb.material_override = stone


func _meter(point: Vector2, stone: Material, damp: Material, water: Material, tools: RandomNumberGenerator) -> void:
    var base := Vector3(point.x, _height(point), point.y)
    var inset := _worn_block(base + Vector3(0, -.07, 0), Vector3(3.02, .42, 2.12), .09, tools)
    inset.material_override = damp
    var plinth := _worn_block(base + Vector3(0, .19, 0), Vector3(2.72, .25, 1.88), .06, tools)
    plinth.material_override = stone
    # A shallow receiving tray, checked stone joints and inlet.
    _box(base + Vector3(0, .345, .36), Vector3(1.80, .05, 1.02), water)
    for side: float in [-1., 1.]:
        _box(base + Vector3(side * .96, .37, .34), Vector3(.15, .18, 1.07), limestone)
        _box(base + Vector3(side * .61, .38, .93), Vector3(.62, .17, .14), stone)
    for side: float in [-1., 1.]:
        var position := base + Vector3(side * .76, .315, -.44)
        _box(position + Vector3(0, .11, 0), Vector3(.57, .23, .60), stone)
        _cylinder(position + Vector3(0, .73, 0), .136, .212, 1.06, limestone, 8)
        _box(position + Vector3(0, 1.31, 0), Vector3(.45, .19, .52), limestone)
        _box(position + Vector3(0, 1.40, 0), Vector3(.37, .082, .46), jade)
    var curve := base + Vector3(0, 1.59, -.44)
    for i in range(9):
        var theta := PI * (float(i) + .50) / 9.0
        var block := _worn_block(curve + Vector3(.77 * cos(theta), .52 * sin(theta), 0),
            Vector3(.33, .26, .43), .054, tools)
        block.rotation.z = atan2(.52 * cos(theta), -.77 * sin(theta))
        block.material_override = limestone if i % 4 != 2 else stone
    _box(base + Vector3(0, 1.52, -.23), Vector3(.128, .57, .086), copper)
    _box(base + Vector3(0, .86, -.23), Vector3(.49, .41, .145), jade)
    for level in range(5):
        _box(base + Vector3(.09, .72 + float(level) * .059, -.139), Vector3(.127, .012, .018), copper)
    _taper(base + Vector3(.06, .91, -.125), base + Vector3(-.142, .85, -.125), .021, .009, copper)
    _collision(base + Vector3(0, .63, -.24), Vector3(2.65, 1.40, 1.46))


func _garden_bench(p: Vector2) -> void:
    var y := _height(p)
    _box(Vector3(p.x, y + .35, p.y), Vector3(1.54, .15, .54), limestone)
    for sign_x in [-1.0, 1.0]:
        _box(Vector3(p.x + sign_x * .53, y + .12, p.y), Vector3(.24, .42, .39), foundation)


func _column(at: Vector3, height: float) -> void:
    _box(at + Vector3(0, .12, 0), Vector3(.82, .26, .82), foundation)
    _cylinder(at + Vector3(0, height * .47, 0), .28, .34, height * .87, limestone, 10)
    _box(at + Vector3(0, height, 0), Vector3(.67, .17, .67), limestone)
    _cylinder(at + Vector3(0, height + .15, 0), .20, .29, .16, jade, 8)


func _brazier(p: Vector2) -> void:
    var y := _paving_stage_height(p)
    var at := Vector3(p.x, y, p.y)
    _column(at, .79)
    _cylinder(at + Vector3(0, .96, 0), .30, .19, .17, copper, 8)
    _cylinder(at + Vector3(0, 1.065, 0), .28, .30, .072, jade, 8)
    _cylinder(at + Vector3(0, 1.095, 0), .225, .225, .024, timber, 8)
    _cylinder(at + Vector3(0, 1.40, 0), .12, .30, .13, jade, 8)
    _cylinder(at + Vector3(0, 1.335, 0), .30, .30, .041, copper, 8)
    _cylinder(at + Vector3(0, 1.491, 0), .056, .12, .078, copper, 8)
    var center := _solid(Color("b88144"), .51, .15)
    center.emission_enabled = true
    center.emission = Color("d2ae72")
    center.emission_energy_multiplier = .32
    _cylinder(at + Vector3(0, 1.212, 0), .133, .105, .224, center, 8)
    for angle in range(8):
        var d := TAU * angle / 8.0
        var rim := Vector3(cos(d) * .252, 0.0, sin(d) * .252)
        _taper(at + rim + Vector3.UP * 1.075, at + rim * .95 + Vector3.UP * 1.34, .018, .018, copper)
        if angle % 2 == 0:
            var panel := _box(at + rim * 1.05 + Vector3.UP * 1.15, Vector3(.10, .057, .024), jade)
            panel.rotation.y = PI * .50 - d


func _boulder_groups() -> void:
    var rocks := [
        [Vector2(-13.3, -6.9), 2.0, 1.42, 2.3], [Vector2(-14.7, -7.0), 2.3, 2.6, 2.2],
        [Vector2(-15.8, -10.4), 3.8, 3.5, 2.5], [Vector2(-17.4, -8.1), 2.7, 3.3, 2.6],
        [Vector2(-13.1, 6.5), 2.6, 1.9, 2.9], [Vector2(-9.5, 9.0), 1.9, 1.15, 1.7],
        [Vector2(17.9, 1.7), 2.6, 2.8, 2.3], [Vector2(17.3, -8.9), 2.9, 1.9, 2.8],
        [Vector2(19.8, -8.1), 2.3, 3.3, 2.6], [Vector2(20.1, -11.4), 3.5, 4.2, 2.9],
        [Vector2(12.2, -10.0), 1.5, .75, 1.2], [Vector2(5.3, -7.25), 1.3, .69, 1.4],
    ]
    for i in range(rocks.size()):
        var entry: Array = rocks[i]
        var point: Vector2 = entry[0]
        var rock := _rock_mesh(Vector3(entry[1], entry[2], entry[3]), i + 36)
        var piece := _mesh(rock, driftstone if i % 3 == 0 else foundation, Vector3(point.x, _height(point) + entry[2] * .24, point.y))
        piece.rotation.y = rng.randf() * TAU
    var pebbles := _rock_mesh(Vector3(.53, .37, .44), 42)
    for i in range(85):
        var a := rng.randf() * TAU
        var p := POND + Vector2(cos(a), sin(a)) * POND_RADIUS * rng.randf_range(.93, 1.11)
        if _road_dist(p) < 1.7:
            continue
        var size := rng.randf_range(.65, 1.63)
        var small := _mesh(pebbles, foundation, Vector3(p.x, _height(p) + .04, p.y))
        small.scale = Vector3.ONE * size
        small.rotation.y = a


func _rock_mesh(dimensions: Vector3, variation: int) -> ArrayMesh:
    var base := SphereMesh.new()
    base.radial_segments = 21
    base.rings = 12
    var arrays := base.surface_get_arrays(0)
    var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var detail := FastNoiseLite.new()
    detail.seed = variation
    detail.frequency = 2.8
    for i in range(points.size()):
        var p := points[i]
        var noise := detail.get_noise_3dv(p * 6.75)
        var mineral := sin(p.y * 15.5 + p.z * 5.1 + noise * 2.25) * .088
        p.x += p.y * .39
        p *= 1.0 + noise * .30 + mineral
        p.y = maxf(p.y, -.30)
        points[i] = p * dimensions
    arrays[Mesh.ARRAY_VERTEX] = points
    var out := ArrayMesh.new()
    out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return out


func _leaf_mesh(shadow: Color, bright: Color, variation: int) -> ArrayMesh:
    var base := SphereMesh.new()
    base.radial_segments = 21
    base.rings = 13
    var arrays := base.surface_get_arrays(0)
    var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var detail := FastNoiseLite.new()
    detail.seed = variation
    detail.frequency = 2.4
    var paint := PackedColorArray()
    for i in range(points.size()):
        var p := points[i]
        var broad := detail.get_noise_3dv(p * 3.1)
        var fine := detail.get_noise_3dv(p * 7.4)
        p *= 1.0 + broad * .41 + fine * .11
        points[i] = p
        var illumination := smoothstep(-.32, .44, p.y + broad * .52)
        paint.append(shadow.lerp(bright, illumination))
    arrays[Mesh.ARRAY_VERTEX] = points
    arrays[Mesh.ARRAY_COLOR] = paint
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return result


func _trees() -> void:
    var locations := [
        [Vector2(-9.8, 8.4), 4.8, 0], [Vector2(-12.8, 3.2), 5.5, 0],
        [Vector2(-11.0, -2.5), 5.7, 1], [Vector2(-5.4, 4.7), 4.2, 1],
        [Vector2(-16.5, -3.4), 6.8, 0], [Vector2(-14.7, -13.7), 5.9, 1],
        [Vector2(-6.2, -16), 4.9, 0], [Vector2(1.8, -15.9), 5.2, 2],
        [Vector2(9.9, 12.8), 4.1, 2], [Vector2(13.0, 10.6), 4.0, 0],
        [Vector2(15.2, 7.7), 6.5, 0], [Vector2(18.0, -1.35), 4.8, 2],
        [Vector2(16.85, -14.5), 6.2, 1], [Vector2(11.5, -16.0), 5.4, 0],
        [Vector2(21.5, -12), 6.8, 0], [Vector2(20.0, .6), 6.6, 0],
    ]
    for entry in locations:
        var p: Vector2 = entry[0]
        _tree(Vector3(p.x, _height(p), p.y), entry[1], entry[2])
    for i in range(19):
        var p := Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(-29.0, -19.5))
        if p.x > -9.5 and p.x < 5.3:
            continue
        var y := _mountain(p) if p.y < -23.0 else _height(p)
        _tree(Vector3(p.x, y, p.y), rng.randf_range(2.4, 4.6), 0 if i % 4 != 0 else 2)


func _tree(at: Vector3, height: float, species: int) -> void:
    var wind := Vector3(cos(at.x * .18 + .8), 0, sin(at.x * .18 + .8))
    var across := Vector3(-wind.z, 0, wind.x)
    var windlean: float = [.16, .21, .08][species]
    var branch_base := at + Vector3.UP * height * .46 - wind * height * .045
    var elbow := at + Vector3.UP * height * .69 + across * height * .052
    var top := at + Vector3.UP * height * .92 + wind * height * windlean
    _taper(at - Vector3(0, .08, 0), branch_base, height * .052, height * .028, timber)
    _taper(branch_base, elbow, height * .029, height * .019, timber)
    _taper(elbow, top, height * .019, height * .0035, timber)
    var close := at.z > -17.5
    if close:
        for root_index in range(4):
            var root_angle := TAU * root_index / 4.0 + at.x * .4
            var point := (at + Vector3(cos(root_angle), 0, sin(root_angle)) * height * (.12 + .018 * (root_index % 2)))
            point.y = _height(Vector2(point.x, point.z)) - .075
            var rise := at.lerp(point, .38) + Vector3.UP * height * .063
            _taper(point, rise, height * .004, height * .019, timber)
            _taper(rise, at + Vector3.UP * height * .14, height * .019, height * .036, timber)
    var mesh := evergreen if species == 0 else cherry if species == 1 else golden
    var silhouette: Vector3 = [Vector3(1.33, .46, .92), Vector3(.95, .76, .90), Vector3(.76, 1.09, .71)][species]
    var branches: Array = [
        [[-.27,.68,.15],[-.13,.83,-.27],[.33,.91,-.16],[.45,.75,.12],[.13,1.10,.09],[.11,.93,.35]],
        [[-.36,.78,.21],[-.14,.66,-.29],[.26,1.02,-.24],[.41,.82,.22],[.12,1.08,.075],[.23,.72,-.37]],
        [[-.20,.67,.11],[-.12,.84,-.23],[.18,1.09,-.09],[.24,.77,.19],[.12,1.21,.05],[.10,.93,.24]],
    ][species]
    var foliage := SurfaceTool.new()
    foliage.begin(Mesh.PRIMITIVE_TRIANGLES)
    var leaf_rng := RandomNumberGenerator.new()
    leaf_rng.seed = roundi(at.x * 93679.0 + at.z * 58125.0) + 1273
    for i in range(branches.size()):
        var design := Vector3(branches[i][0], branches[i][1], branches[i][2])
        var reach := rng.randf_range(.91, 1.12)
        var rise := rng.randf_range(-.046, .042)
        var cut := rng.randf_range(.06, .58)
        var size := height * rng.randf_range(.38, .50)
        var direction := (wind * design.x + across * design.z)
        var tip := at + Vector3.UP * height * (design.y + rise) + direction * height * reach
        var root := branch_base.lerp(elbow, cut if i < 4 else .80)
        var fork := root.lerp(tip, .53) - Vector3.UP * height * (.032 if species == 1 else .015)
        var bearing := atan2(direction.x, direction.z)
        _taper(root, fork, height * (.016 if i < 4 else .011), height * .009, timber)
        _taper(fork, tip, height * .009, height * .003, timber)
        var shape := _mesh(mesh, leaves, tip + Vector3.UP * size * .09)
        shape.scale = silhouette * size * (1.12 if i == 2 else .88 if i == 5 else 1.0)
        shape.rotation_degrees = Vector3(12.0 if i % 2 == 0 else -8.0, rad_to_deg(bearing), (-1.0 if i % 2 == 0 else 1.0) * (15.0 if species == 1 else 7.0))
        if close:
            var outward := direction.normalized()
            var split := tip + ((outward + across * (.36 if i % 2 == 0 else -.42)).normalized() + Vector3.DOWN * (.41 if species == 1 else .26)) * size * .51
            _taper(fork, split, height * .005, height * .0016, timber)
            var satellite := _mesh(mesh, leaves, split)
            satellite.scale = silhouette * size * Vector3(.53, .58, .60)
            satellite.rotation = shape.rotation + Vector3(.19, .41, -.10)
            _canopy_sprays(foliage, leaf_rng, tip, outward, shape.scale, species, 22 if i % 2 == 0 else 17)
            _canopy_sprays(foliage, leaf_rng, split, outward, satellite.scale, species, 9)
    if close:
        foliage.generate_normals()
        var fringes := _mesh(foliage.commit(), leaves, Vector3.ZERO)
        fringes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if _road_dist(Vector2(at.x, at.z)) > 1.55 and at.y < .95:
        _collision(at + Vector3(.10, .78, 0), Vector3(height * .120, 1.7, height * .120))


func _canopy_sprays(surface: SurfaceTool, local_rng: RandomNumberGenerator, origin: Vector3, direction: Vector3, ellipsoid: Vector3, species: int, count: int) -> void:
    var underside: Color = [Color("415630"), Color("8d5748"), Color("857034")][species]
    var bright: Color = [Color("a3b652"), Color("e6a182"), Color("d0a54e")][species]
    var cross := Vector3(-direction.z, 0, direction.x)
    for i in range(count):
        var turn := local_rng.randf() * TAU
        var axis := direction * cos(turn) + cross * sin(turn)
        var rim := clampf(.40 + local_rng.randf() * .10, .40, .50)
        var stalk := origin + Vector3(axis.x * ellipsoid.x, 0, axis.z * ellipsoid.z) * rim
        stalk.y += local_rng.randf_range(-.20, .33) * ellipsoid.y
        var stem := (axis + Vector3.UP * local_rng.randf_range(-.34, .37)).normalized()
        var length := local_rng.randf_range(.079, .165) * ellipsoid.x
        var wing := Vector3(-stem.z, local_rng.randf_range(-.42, .35), stem.x).normalized() * length * (.31 if species == 0 else .48 if species == 1 else .25)
        var tip := stalk + stem * length
        var mid := stalk.lerp(tip, .43)
        var ridge := mid + Vector3.UP * length * .18
        var pale := underside.lerp(bright, local_rng.randf_range(.48, .98))
        for geometry in [[stalk, mid + wing, ridge], [mid + wing, tip, ridge], [stalk, ridge, mid - wing], [mid - wing, ridge, tip]]:
            surface.set_color(pale)
            surface.add_vertex(geometry[0])
            surface.add_vertex(geometry[1])
            surface.add_vertex(geometry[2])
            surface.set_color(pale.lerp(underside, .38))
            surface.add_vertex(geometry[2])
            surface.add_vertex(geometry[1])
            surface.add_vertex(geometry[0])

func _understory() -> void:
    var mats := [_plant(Vector2(0, 0), Color("bdcb98")), _plant(Vector2(1, 0), Color("eed2b7"))]
    var card := QuadMesh.new()
    card.size = Vector2.ONE
    var clusters := [
        Vector2(-4, 10.8), Vector2(-2.2, 7.7), Vector2(-4.2, 3.25), Vector2(-5.5, 3.4),
        Vector2(-8.1, .8), Vector2(-4.8,-4.2), Vector2(-10.45,-5), Vector2(-6.3,-6),
        Vector2(-2.9, -10.8), Vector2(-5.5,-13.3), Vector2(2.9,-14.9), Vector2(0.8,-11.8),
        Vector2(1.9, -5), Vector2(3.1, .9), Vector2(5.2, 5.5), Vector2(8.9, 7.75),
        Vector2(13, 6.5), Vector2(14, 2.3), Vector2(15.3,-2.05), Vector2(13.3,-6.9),
        Vector2(9.8,-10), Vector2(12.25,-14.6), Vector2(17.4,-10.4), Vector2(-10.9, 13.9),
    ]
    for index in range(clusters.size()):
        for i in range(7):
            var p: Vector2 = clusters[index] + _jitter(1.62)
            if _road_dist(p) < 1.41 or _pond_math(p) < 1.00:
                continue
            var height := rng.randf_range(.32, .88)
            var bearing := rng.randf_range(-.47, .63)
            var material: Material = mats[int((i + index) % 5 == 0)]
            for angle in [bearing, bearing + 1.36]:
                var plant := _mesh(card, material, Vector3(p.x, _height(p) + height * .48, p.y))
                plant.scale = Vector3(height * 1.16, height, 1.0)
                plant.rotation.y = angle
                plant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _grass_batches()


func _garden_flowers() -> void:
    var targets := [
        Vector2(-3.84, 8.1), Vector2(-3.45, 4.94), Vector2(-6.19, 1.97),
        Vector2(-5.22, -4.43), Vector2(-3.3, -9.9), Vector2(-5.06, -7.08),
        Vector2(1.63, 6.15), Vector2(2.14, .44), Vector2(2.50, -4.22), Vector2(2.33, -9.77),
        Vector2(5.6, -14.1), Vector2(9.32, -11.04), Vector2(15.05, -4.0),
    ]
    var blossom := SphereMesh.new()
    blossom.radial_segments = 8
    blossom.rings = 4
    blossom.radius = .12
    blossom.height = .18
    var stem := _solid(Color("556b3a"), .88)
    var coral := _solid(Color("dc8155"), .88)
    var cream := _solid(Color("fbdbad"), .88)
    var dark := _solid(Color("daaa4d"), .92)
    for bed in range(targets.size()):
        for index in range(8):
            var p: Vector2 = targets[bed] + _jitter(.76)
            if _road_dist(p) < 1.54 or _pond_math(p) < 1.03:
                continue
            var at := Vector3(p.x, _height(p), p.y)
            var height := rng.randf_range(.17, .52)
            var lift := Vector3(rng.randf_range(-.06, .06), height, rng.randf_range(-.06, .06))
            _taper(at, at + lift, .014, .008, stem)
            var bloom := _mesh(blossom, coral if bed % 3 == 0 else cream, at + lift)
            bloom.scale = Vector3(1, .38, 1) * rng.randf_range(.47, .86)
            var center := _mesh(blossom, dark, at + lift + Vector3(0, .021, 0))
            center.scale = Vector3(.29, .15, .29)


func _grass_batches() -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for blade in range(7):
        var a := TAU * float(blade) / 7.0
        var side := Vector3(cos(a), 0, sin(a))
        var front := Vector3(-side.z, 0, side.x)
        var root := front * rng.randf_range(.03, .16)
        var height := rng.randf_range(.16, .44)
        surface.set_color(Color("485d37"))
        surface.add_vertex(root - side * .029)
        surface.add_vertex(root + side * .027)
        surface.set_color(Color("afc067"))
        surface.add_vertex(root + Vector3.UP * height + front * .14)
    surface.generate_normals()
    var mesh := surface.commit()
    var material := _solid(Color.WHITE, .94)
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.vertex_color_use_as_albedo = true
    material.vertex_color_is_srgb = true
    var instances: Array[Transform3D] = []
    for n in range(1470):
        var x := rng.randf_range(-18, 18)
        var z := rng.randf_range(-18.5, 16.5)
        var point := Vector2(x, z)
        var dist := _road_dist(point)
        if dist < 1.55 or _pond_math(point) < 1.02:
            continue
        if absf(hills.get_noise_2dv(point * 2.6)) < .15:
            continue
        var size := rng.randf_range(.57, 1.45)
        var basis := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * size)
        instances.append(Transform3D(basis, Vector3(x, _height(point) - .015, z)))
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = mesh
    batch.instance_count = instances.size()
    for index in range(instances.size()):
        batch.set_instance_transform(index, instances[index])
    var tuft := MultiMeshInstance3D.new()
    tuft.multimesh = batch
    tuft.material_override = material
    tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(tuft)


func _stone(tint: Color, scale: float, relief: float) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader = STONE
    mat.set_shader_parameter("stone_atlas", STONE_ATLAS)
    mat.set_shader_parameter("tint", tint)
    mat.set_shader_parameter("texture_scale", scale)
    mat.set_shader_parameter("micro_relief", relief)
    return mat


func _plant(quadrant: Vector2, tint: Color) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader = PLANT
    mat.set_shader_parameter("plant_atlas", PLANT_ATLAS)
    mat.set_shader_parameter("quadrant", quadrant)
    mat.set_shader_parameter("foliage_tint", tint)
    return mat


func _solid(tint: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = roughness
    mat.metallic = metallic
    return mat


func _taper(from: Vector3, to: Vector3, lower: float, upper: float, material: Material) -> void:
    var node := _cylinder((from + to) / 2., upper, lower, from.distance_to(to), material, 8)
    node.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


func _cylinder(at: Vector3, top: float, bottom: float, height: float, material: Material, segments: int) -> MeshInstance3D:
    var geometry := CylinderMesh.new()
    geometry.radial_segments = segments
    geometry.rings = 1
    geometry.top_radius = top
    geometry.bottom_radius = bottom
    geometry.height = height
    return _mesh(geometry, material, at)


func _box(at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
    var geometry := BoxMesh.new()
    geometry.size = dimensions
    return _mesh(geometry, material, at)


func _collision(at: Vector3, dimensions: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = at
    var geometry := BoxShape3D.new()
    geometry.size = dimensions
    var hit := CollisionShape3D.new()
    hit.shape = geometry
    body.add_child(hit)
    add_child(body)


func _mesh(geometry: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = geometry
    instance.material_override = material
    instance.position = at
    add_child(instance)
    return instance


func _jitter(radius: float) -> Vector2:
    return Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))

