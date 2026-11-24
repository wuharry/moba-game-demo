"""Build an original abandoned atmospheric relay and its review shot."""
from pathlib import Path
from math import cos, sin, pi, radians
import random
import sys

import bpy
from mathutils import Vector

out = Path(sys.argv[sys.argv.index('--') + 1])
rng = random.Random(304)
bpy.ops.wm.read_factory_settings(use_empty=True)


def color(hex_code):
    def linear(s):
        return s / 12.92 if s < 0.04045 else ((s + 0.055) / 1.055) ** 2.4
    return tuple(linear(int(hex_code[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


def material(name, hue, roughness, metal=0.0, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color(hue)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = mat.diffuse_color
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Emission Color'].default_value = mat.diffuse_color
    bsdf.inputs['Emission Strength'].default_value = glow
    return mat


stone = [material('Aggregate / ' + i, i, 0.89) for i in ('414743', '4e544d', '545952', '383e3c', '60645b')]
graphite = material('Tool-cut graphite housing', '343f41', 0.57, 0.50)
edge = material('Rubbed graphite edges', '63716d', 0.48, 0.63)
steel = material('Pitted enamel / mineral teal', '496764', 0.47, 0.45)
iron = material('Dark steel inner frame', '273039', 0.50, 0.69)
bronze = material('Oxidized red brass', '8a563e', 0.49, 0.72)
brass = material('Sharp cut brass edge', 'b88054', 0.42, 0.74)
oxide = material('Ferric deposits', '38312b', 0.96)
paper = material('Screen-printed markings', 'd4caab', 0.80)
accent = material('Oxide orange inspection paint', 'a66745', 0.72)
light = material('Aqua phosphor', '73d9c7', 0.26, 0.18, 1.35)
very_dark = material('Vent interior', '161c20', 0.92)


def mark(obj, name, mats, bevel=0.0):
    obj.name = name
    for mat in mats:
        obj.data.materials.append(mat)
    if bevel:
        chamfer = obj.modifiers.new('Tool wear / bevel', 'BEVEL')
        chamfer.width = bevel
        chamfer.segments = 3
        chamfer.affect = 'EDGES'
        chamfer.harden_normals = True
        obj.modifiers.new('Weighted hard-surface normals', 'WEIGHTED_NORMAL')
    return obj


def extrusion(name, points, y_front, y_back, mats, bevel=0.0, random_sides=False):
    size = len(points)
    vertices = [(x, y, z) for y in (y_front, y_back) for x, z in points]
    faces = [tuple(range(size)), tuple(reversed(range(size, size * 2)))]
    faces.extend((i, i + size, (i + 1) % size + size, (i + 1) % size) for i in range(size))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mark(obj, name, mats, bevel)
    if random_sides:
        for face in mesh.polygons[1:]:
            face.material_index = rng.choices(range(len(mats)), [1, 3, 2, 1, 1])[0]
    return obj


def plate(name, x, z, w, h, y_front, y_back, mat, clip=0.08, bevel=0.012):
    left, right, bottom, top = x-w/2, x+w/2, z-h/2, z+h/2
    c = clip
    return extrusion(name, [(left+c, bottom), (right-c, bottom), (right, bottom+c),
        (right, top-c), (right-c, top), (left+c, top), (left, top-c), (left, bottom+c)],
        y_front, y_back, [mat], bevel)


def cube(name, pos, dimensions, mat, bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return mark(obj, name, [mat], bevel)


def cylinder(name, pos, radius, depth, mat, sides=64, bevel=0.012):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth,
        location=pos, rotation=(pi / 2, 0, 0))
    obj = mark(bpy.context.object, name, [mat], bevel)
    for f in obj.data.polygons:
        f.use_smooth = abs(f.normal.z) < 0.25
    return obj


def ring(name, x, z, inner, outer, front, back, start, end, mat, count=64, bevel=0.011):
    angles = [radians(start + (end - start) * i / count) for i in range(count + 1)]
    corners = [(x + r*cos(a), y, z + r*sin(a)) for y in (front, back) for r in (inner, outer) for a in angles]
    stride = count + 1
    faces = []
    for i in range(count):
        a, b, c, d = i, i + stride, i + stride * 2, i + stride * 3
        faces.extend(((a, b, b+1, a+1), (c, c+1, d+1, d), (a, a+1, c+1, c), (b, d, d+1, b+1)))
    faces += [(0, stride*2, stride*3, stride), (count, count+stride, count+stride*3, count+stride*2)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(corners, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return mark(obj, name, [mat], bevel)


def tube(name, path, radius, mat):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 9
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    curve.use_fill_caps = True
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(path) - 1)
    for node, p in zip(spline.bezier_points, path):
        node.co = p
        node.handle_left_type = 'AUTO'
        node.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    return mark(obj, name, [mat])


def label(body, pos, height, hue=paper):
    data = bpy.data.curves.new(body, 'FONT')
    data.body = body
    data.size = height
    data.space_character = 1.14
    obj = bpy.data.objects.new(body, data)
    bpy.context.collection.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = (pi/2, 0, 0)
    mark(obj, body, [hue])


# Collapsed retaining collar. Front outlines account for visible structural chips.
extrusion('Fractured left retaining pier', [(-1.36, -.05), (-.65, -.05), (-.65, .32),
    (-.77, .65), (-.70, 1.00), (-.74, 1.39), (-.65, 1.73), (-.67, 2.34),
    (-.57, 2.76), (-.66, 3.27), (-.81, 3.39), (-.97, 3.37), (-1.03, 3.24),
    (-1.19, 3.29), (-1.31, 3.05), (-1.38, 2.40), (-1.42, 1.59),
    (-1.34, 1.41), (-1.41, 1.19), (-1.45, .71), (-1.39, .61)], -.25, .60, stone, .052, True)
extrusion('Broken right buttress', [(.72, -.05), (1.46, -.05), (1.53, .20), (1.52, .80),
    (1.44, .98), (1.48, 1.15), (1.42, 1.83), (1.36, 1.98), (1.43, 2.14),
    (1.36, 2.69), (1.25, 2.70), (1.14, 2.88), (1.02, 2.75), (.88, 2.80),
    (.77, 2.58), (.79, 2.21), (.69, 1.81), (.77, 1.64), (.68, 1.19), (.69, .41)],
    -.17, .72, stone[::-1], .047, True)
plate('Load spreader / concrete foundation', .02, .12, 3.04, .31, -.54, .78, stone[2], .10, .044)
plate('Central chassis / graphite', -.06, 1.56, 1.92, 2.43, -.62, .49, graphite, .24, .039)
plate('Mounting face / overlapping enamel', -.10, 1.57, 1.66, 2.18, -.70, -.58, steel, .22, .021)
plate('Compression chamber', -.12, 1.53, 1.48, 1.86, -.765, -.69, iron, .20, .021)
plate('Brittle lower cover', -.12, .65, 1.49, .41, -.83, -.73, steel, .11, .024)

# Primary feature: interrupted isotope-gauge bezel, secondary collar and turbine ribs.
x, z = -.15, 1.76
cylinder('Undercut barrel', (x, -.824, z), .713, .25, very_dark)
ring('Five-part brass collar', x, z, .575, .700, -1.019, -.855, 18, 348, bronze, 48, .018)
ring('Worn lip on brass', x, z, .667, .697, -1.027, -.996, 42, 339, brass, 48, .007)
ring('Failed tab / separate ring segment', x, z, .579, .698, -.96, -.845, 351, 374, bronze, 7)
ring('Outer steel offset shield', x, z, .684, .755, -.90, -.77, 53, 154, edge, 18)
ring('Lower partial enclosure', x, z, .674, .769, -.90, -.77, 192, 305, edge, 18)
cylinder('Throat / dark ceramic', (x, -.945, z), .570, .07, very_dark)
ring('Lit reading window', x, z, .425, .449, -1.001, -.984, 54, 134, light, 24, .003)
ring('Lower calibration window', x, z, .425, .449, -1.001, -.984, 224, 313, light, 24, .003)
for i in range(17):
    a = radians(42 + 17.0*i)
    r = .487
    bit = cube('Graduation / inner ring', (x + cos(a)*r, -1.005, z + sin(a)*r),
        (.010, .015, .058 if i % 4 == 0 else .031), brass, .002)
    bit.rotation_euler.y = pi/2 - a
for i in range(7):
    a = 2*pi*i/7 + .37
    poly = []
    for r, skew in ((.14, -.10), (.44, -.17), (.415, .06), (.25, .29), (.14, .23)):
        poly.append((x + r*cos(a+skew), z + r*sin(a+skew)))
    extrusion('Intake gate / overlapping rib', poly, -1.060, -.976, [steel if i % 2 else edge], .013)
cylinder('Center hub retaining cup', (x, -1.097, z), .187, .10, graphite, 12, .015)
cylinder('Center ceramic insulator', (x, -1.161, z), .105, .045, edge, 12)
cylinder('Center warning light', (x, -1.192, z), .073, .026, light, 12, .005)

# Recessed vents, miniature maintenance panels and brass pressure lines.
plate('Upper telemetry panel', -.08, 2.51, 1.36, .21, -.811, -.735, graphite, .045)
label('NORTH BASIN / 04', (-.66, -.821, 2.49), .074)
label('PRESSURE REGULATOR', (-.68, -.838, .695), .048)
label('S.04-192   //   OFFLINE', (-.68, -.840, .581), .041, accent)
for i in range(5):
    plate('Recessed exhaust', .12 + .104*i, .661, .069, .136, -.851, -.829, very_dark, .017, .002)
    plate('Exhaust bevel', .12 + .104*i, .706, .070, .018, -.854, -.833, edge, .008, .003)
for i in range(3):
    start = .764 + i * .103
    tube('Oxidized pressure return', [(start, -.61, .47), (start + .12, -.77, .76),
        (start + .21, -.82, 1.09), (start + .16, -.87, 1.74),
        (start + .25, -.73, 2.17), (start + .19, -.48, 2.35)], .025 if i else .034, bronze)
    cube('Tube clamp', (start + .157, -.832, 1.24), (.12, .085, .12), graphite, .012)
    cube('Damaged clamp / one screw remaining', (start + .207, -.801, 1.92), (.12, .073, .095), edge, .012)
plate('Left utility panel', -.95, 1.30, .22, 1.31, -.62, -.31, graphite, .047)
for i in range(6):
    plate('Left heat sink rib', -.96, .88+i*.145, .21, .035, -.682, -.605, edge, .013, .007)
for bx, bz in ((-.76, 2.42), (.63, 2.42), (-.77, .91), (.59, .95), (-.81, .56), (.58, .53)):
    cylinder('Recessed screw head', (bx, -.792, bz), .034, .042, edge, 6, .004)
    cube('Screw slot', (bx, -.818, bz), (.039, .012, .006), very_dark, .002)

# Broken outer edges, exposed reinforcing rods and concrete weathering on the front.
for i in range(3):
    tube('Sheared reinforcement', [(-1.15+i*.13, -.09+i*.048, 3.12),
        (-1.17+i*.16, -.10+i*.045, 3.29), (-1.26+i*.16, -.12+i*.052, 3.48+.10*(i%2))],
        .014, bronze)
for side, center, front in ((-1, -1.17, -.252), (1, 1.28, -.172)):
    for i in range(18):
        az = rng.uniform(.18, 2.67)
        ax = center + rng.uniform(-.095, .10)
        width = rng.uniform(.013, .071)
        height = rng.uniform(.009, .034)
        extrusion('Detached surface flakes', [(ax-width, az), (ax-width*.9, az+height),
            (ax+width*.35, az+height*.8), (ax+width, az-height*.1), (ax+width*.32, az-height*.5)],
            front-rng.uniform(.003, .015), front+.002, [rng.choice(stone + [oxide])], .0016)
    for start_x, start_z in ((center-.09, .47), (center+.05, 1.60), (center-.08, 2.40)):
        direction = 1 if start_z < 2 else -1
        points = []
        for i in range(5):
            points.append((start_x + (rng.uniform(-.045, .037)+i*.024)*side,
                start_z + direction*i*.069))
        left = [(ax-rng.uniform(.004, .008), az) for ax, az in points]
        right = [(ax+rng.uniform(.004, .012), az) for ax, az in reversed(points)]
        extrusion('Oblique microfracture', left+right, front-.0024, front+.006, [oxide])

# Freeze curve meshes to keep geometry and text portable in the GLB.
for obj in list(bpy.context.scene.objects):
    if obj.type in {'FONT', 'CURVE'}:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target='MESH')

geometry = list(bpy.context.scene.objects)
coords = [obj.matrix_world @ Vector(v) for obj in geometry for v in obj.bound_box]
minimum = [min(v[axis] for v in coords) for axis in range(3)]
maximum = [max(v[axis] for v in coords) for axis in range(3)]
print('Hero bounds in meters X Y Z:', [round(b-a, 3) for a, b in zip(minimum, maximum)])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out/'Basin_Relay.glb'), use_selection=True,
    export_apply=True, export_format='GLB', export_materials='EXPORT')

# Add a baked color atlas on the stone so material texture survives Godot import.
atlas_path = out.parent / 'generated-art' / 'Painted_Stone_Atlas.png'
if atlas_path.exists():
    atlas = bpy.data.images.load(str(atlas_path))
    atlas.name = 'Original painted aggregate atlas'
    atlas.pack()
    for obj in geometry:
        if obj.type != 'MESH' or not any(slot.material in stone for slot in obj.material_slots):
            continue
        uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='Aggregate atlas UV')
        for face in obj.data.polygons:
            normal = obj.matrix_world.to_3x3() @ face.normal
            axis = max(range(3), key=lambda index: abs(normal[index]))
            for loop_id in face.loop_indices:
                vertex = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop_id].vertex_index].co
                projected_u = vertex.y if axis == 0 else vertex.x
                projected_v = vertex.y if axis == 2 else vertex.z
                uv.data[loop_id].uv = (.746 + projected_u * .13, .084 + projected_v * .227)
    for mat in stone:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        texture = nodes.new('ShaderNodeTexImage')
        texture.image = atlas
        texture.extension = 'EXTEND'
        links.new(texture.outputs['Color'], nodes.get('Principled BSDF').inputs['Base Color'])
    bpy.ops.export_scene.gltf(filepath=str(out/'Basin_Relay_Textured.glb'), use_selection=True,
        export_apply=True, export_format='GLB', export_materials='EXPORT')

# Additional close-up material treatment for the editable Blender lookdev file.
for mat in stone + [graphite, steel, bronze, edge, brass]:
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 22.0
    noise.inputs['Detail'].default_value = 4.0
    noise.inputs['Roughness'].default_value = .68
    texcoord = nodes.new('ShaderNodeTexCoord')
    links.new(texcoord.outputs['Object'], noise.inputs['Vector'])
    mult = nodes.new('ShaderNodeMixRGB')
    mult.blend_type = 'MULTIPLY'
    mult.inputs[0].default_value = .30 if mat in stone else .24
    mult.inputs[1].default_value = mat.diffuse_color
    prior_color = bsdf.inputs['Base Color'].links
    if prior_color:
        links.new(prior_color[0].from_socket, mult.inputs[1])
    links.new(noise.outputs['Fac'], mult.inputs[2])
    links.new(mult.outputs[0], bsdf.inputs['Base Color'])
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .25 if mat in stone else .10
    bump.inputs['Distance'].default_value = .032 if mat in stone else .016
    links.new(noise.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs[0], bsdf.inputs['Normal'])

stage_mat = material('Damp stage concrete', '383a3b', .86)
cube('Backdrop (excluded from GLB)', (0, 0, -.115), (200, 200, .13), stage_mat, 0.0)
scene = bpy.context.scene


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def area(name, pos, target, hue, strength, size):
    data = bpy.data.lights.new(name, 'AREA')
    data.color = color(hue)[:3]
    data.energy = strength
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = pos
    aim(obj, target)


area('Warm softbox / key', (-3.5, -5.8, 6.8), (0, 0, 1.8), 'ffe0bd', 880, 5.0)
area('Sky bounce / fill', (4.8, -3.1, 4.1), (0, 0, 1.85), 'd9f4ff', 490, 4.8)
area('Rim / cloud break', (2.7, 2.7, 5.8), (.0, .0, 1.6), 'c6ecff', 1160, 3.15)
world = bpy.data.worlds.new('Twilight atmosphere')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = color('78818e')
world.node_tree.nodes['Background'].inputs[1].default_value = .23
scene.world = world
camera = bpy.data.objects.new('Review / close three-quarter', bpy.data.cameras.new('Review camera'))
bpy.context.collection.objects.link(camera)
camera.location = (3.93, -8.55, 3.13)
camera.data.lens = 53
aim(camera, (0, -.1, 1.61))
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 20
scene.cycles.use_denoising = True
scene.render.resolution_x = 1080
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
scene.render.filepath = str(out/'Basin_Relay_Textured.png')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Basin_Relay_Textured.blend'))
bpy.ops.render.render(write_still=True)
