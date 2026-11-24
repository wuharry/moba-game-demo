"""Build the original Terrace Orrery, export editable project and game mesh."""
import argparse
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


TAU = 2 * math.pi
ROOT = None
RNG = random.Random(61073)
ATLAS_SAND = set()
ATLAS_SHALE = set()


def linear(srgb):
    return srgb / 12.92 if srgb <= 0.04045 else ((srgb + 0.055) / 1.055) ** 2.4


def material(name, tint, roughness, metal=0, emission=0):
    rgba = tuple(linear(int(tint.strip("#")[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)
    result = bpy.data.materials.new(name)
    result.diffuse_color = rgba
    result.use_nodes = True
    bsdf = result.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metal
    if emission:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emission
    return result


def finish(obj, name, mat, bevel=0):
    obj.name = name
    if mat:
        obj.data.materials.append(mat)
    obj.parent = ROOT
    if bevel:
        detail = obj.modifiers.new("Polished chamfer", "BEVEL")
        detail.width = bevel
        detail.segments = 3
        detail.limit_method = "ANGLE"
        normal = obj.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
    return obj


def box(name, pos, dims, mat, bevel=0.025, turn=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    for vertex in obj.data.vertices:
        for axis in range(3):
            vertex.co[axis] *= dims[axis]
    obj.rotation_euler[2] = turn
    return finish(obj, name, mat, bevel)


def mesh(name, verts, faces, mat, bevel=0):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, bevel)


def extrusion(name, coords, front, back, mat, bevel=0):
    count = len(coords)
    verts = [(x, y, z) for y in (front, back) for x, z in coords]
    faces = [tuple(range(count)), tuple(reversed(range(count, 2 * count)))]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, i + count, j + count, j))
    return mesh(name, verts, faces, mat, bevel)


def pipe(name, points, radius, mat):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.bevel_depth = radius
    data.bevel_resolution = 2
    data.resolution_u = 14
    strand = data.splines.new("POLY")
    strand.points.add(len(points) - 1)
    for node, point in zip(strand.points, points):
        node.co = (*point, 1)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat)


def ellipse(name, x, y, z, rx, rz, radius, mat, start=0, end=TAU):
    return pipe(name, [
        (x + math.cos(a) * rx, y, z + math.sin(a) * rz)
        for a in (start + i * (end - start) / 72 for i in range(73))
    ], radius, mat)


def lozenge(name, x, y, z, rx, rz, mat, depth=0.05):
    return extrusion(name, [(x - rx, z), (x, z - rz), (x + rx, z), (x, z + rz)], y, y + depth, mat, 0.012)


def barrel(name, at, radius, height, mat, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=height, location=at)
    obj = bpy.context.object
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    return finish(obj, name, mat, min(height / 5, radius / 8, 0.035))


def carved_stem(name, x, y, levels, mat, lobes=12):
    verts = []
    sides = lobes * 4
    for z, rad in levels:
        for i in range(sides):
            theta = i * TAU / sides
            r = rad * (1 + 0.048 * math.cos(theta * lobes))
            verts.append((x + math.cos(theta) * r, y + math.sin(theta) * r, z))
    faces = [tuple(reversed(range(sides)))]
    for ring in range(len(levels) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((ring * sides + i, ring * sides + j,
                          (ring + 1) * sides + j, (ring + 1) * sides + i))
    faces.append(tuple(range((len(levels) - 1) * sides, len(levels) * sides)))
    obj = mesh(name, verts, faces, mat)
    for face in obj.data.polygons[1:-1]:
        face.use_smooth = True
    return obj


def arch_panel(name, x, y, spring, rx, rz, lower, depth, mat):
    outline = [(x - rx, lower), (x + rx, lower), (x + rx, spring)]
    outline.extend((x + math.cos(i * math.pi / 26) * rx, spring + math.sin(i * math.pi / 26) * rz)
                   for i in range(1, 27))
    return extrusion(name, outline, y, y + depth, mat, 0.014)


def arch_block(name, center, front, depth, rx, rz, thickness, start, end, mat):
    x, z = center
    angles = [start + (end - start) * i / 4 for i in range(5)]
    coords = [(x + math.cos(a) * rx, z + math.sin(a) * rz) for a in reversed(angles)]
    coords += [(x + math.cos(a) * (rx + thickness), z + math.sin(a) * (rz + thickness)) for a in angles]
    return extrusion(name, coords, front, front + depth, mat, 0.023)


def tip_profile(x, z, x_stretch=1, z_stretch=1):
    polygon = [(-.38, 0), (-.31, .20), (-.29, .41), (-.09, .55), (0, .70),
               (.09, .55), (.29, .41), (.31, .20), (.38, 0)]
    return [(x + xx * x_stretch, z + zz * z_stretch) for xx, zz in polygon]


def terrace_orrery():
    ivory = [material(f"Limestone · {i + 1}", c, 0.80) for i, c in enumerate((
        "d4b892", "d9be97", "c7ad88", "dbc7a5", "cdb693", "c7aa85"))]
    base = material("Cool olive foundation", "756c5d", 0.87)
    pale = material("Honey-polished relief", "ead3ab", 0.68)
    dark = material("Deepened carving", "524c43", 0.86)
    oxidized = material("Oxidized bronze", "395b52", .49, .58)
    enamel = [material(f"Viridian glazed enamel · {i + 1}", c, 0.43, .25) for i, c in enumerate((
        "2e514a", "3c6258", "31574e", "527466", "25433f"))]
    gilt = material("Burnished filigree", "b6894f", 0.37, .53)
    glow = material("Amber pressed glass", "e99b57", 0.38, 0, 0.33)
    relief = material("Relief carnelian", "914c37", .65, .1)
    ATLAS_SAND.update(mat.name for mat in [*ivory, pale])
    ATLAS_SHALE.add(base.name)

    # Three physically separate courses, then individually modeled stone caps.
    box("Continuous plinth", (0, .11, .155), (6.72, 3.20, .31), base, .10)
    box("Chamfered sill", (0, .08, .316), (6.61, 3.09, .12), ivory[2], .043)
    for row, (y, z, width) in enumerate(((-1.56, .08, 5.14), (-1.41, .16, 5.35), (-1.24, .25, 5.56))):
        for i in range(13):
            step = width / 13
            box(f"Tread {row + 1}.{i + 1}", ((i - 6) * step, y, z), (step - .016, .52, .15), RNG.choice(ivory), .025)
    box("Rear stone deck", (0, .51, .4), (6.39, 2.1, .18), ivory[4], .048)

    # The rear masonry remains visible diagonally through the column arcade.
    arch_panel("Rear central masonry", 0, .40, 2.64, 1.66, 1.57, .45, .80, ivory[0])
    arch_panel("Tall recessed dark arch", 0, -.075, 2.59, 1.42, 1.42, .50, .27, dark)
    arch_panel("Cascading green shutter", 0, -.124, 2.57, 1.29, 1.26, .55, .072, enamel[4])
    for i in range(27):
        x = (i - 13) * .092
        bottom = .55
        top = 2.57 + 1.23 * math.sqrt(1 - (x / 1.29) ** 2)
        box("Embossed shutter rib", (x, -.186, (top + bottom) / 2), (.085, .084, top - bottom), enamel[i % 5], .015)
    box("Coffer lock rail", (0, -.254, 1.14), (2.55, .16, .14), oxidized, .02)
    box("Coffer jamb", (0, -.275, 2.12), (.077, .12, 3.17), gilt, .02)

    # Repeating blocks with tight joints and a deliberately enlarged keystone.
    for i in range(17):
        angle = math.pi / 17
        thick = .41 if i == 8 else .33
        arch_block(f"Limestone voussoir {i+1}", (0, 2.57), -.45 - (.07 if i == 8 else 0), .80,
                   1.32, 1.265, thick, i * angle + .015, (i + 1) * angle - .015, pale if i == 8 else RNG.choice(ivory))
    ellipse("Inset bronze molding", 0, -.465, 2.57, 1.331, 1.274, .019, gilt, 0, math.pi)
    for i in range(13):
        a = (i + 1) / 14 * math.pi
        lozenge("Arch framing pin", math.cos(a) * 1.50, -.459, 2.57 + math.sin(a) * 1.45,
                .041, .065, oxidized, .025)

    for x in (-2.50, 2.50):
        box("Wing masonry shell", (x, .32, 1.71), (1.71, 1.66, 2.70), ivory[1], .075)
        outside = math.copysign(1, x)
        for course in range(6):
            z = .635 + course * .396
            seam = -.29 + (course % 2) * .36
            span = [(-.47, seam), (seam + .013, .56), (.574, 1.085)]
            for index, (lower, upper) in enumerate(span):
                box("Side ashlar relief", (x + outside * .854, (lower + upper) / 2, z),
                    (.09, upper - lower, .384), ivory[(course + index * 2) % 6], .017)
        for course in range(5):
            z = .69 + course * .47
            box("Rear wall ashlar", (x, 1.176, z), (1.76, .24, .43), ivory[(course + (x > 0)) % 6], .024)
        arch_panel("Wing recessed niche", x, -.60, 1.92, .50, .64, .63, .15, dark)
        arch_panel("Wing enamel inset", x, -.64, 1.92, .37, .48, .75, .10, enamel[3])
        ellipse("Wing bezel", x, -.662, 1.92, .42, .55, .025, gilt, 0, math.pi)
        for offset in [-.43, .43]:
            box("Wing straight molding", (x + offset, -.653, 1.32), (.052, .07, 1.22), gilt, .01)
        for j in range(7):
            dx = (j - 3) * .075
            high = 1.91 + .38 * math.sqrt(1 - (dx / .40) ** 2)
            pipe("Glass slat", [(x + dx, -.705, 1.08), (x + dx, -.705, high)], .021, oxidized)
        for z in (1.18, 1.61, 2.04):
            lozenge("Niche glass marker", x, -.733, z, .19, .11, glow)
        box("Cast window sill", (x, -.655, .86), (1.01, .32, .14), oxidized, .04)
        box("Wing stone cornice", (x, .20, 2.96), (1.86, 1.87, .24), pale, .05)
        box("Wing bronze cornice", (x, .18, 3.095), (1.80, 1.79, .065), gilt, .012)
        box("Wing enamel parapet", (x, .20, 3.195), (1.71, 1.66, .154), oxidized, .028)
        box("Wing limestone parapet cap", (x, .2, 3.30), (1.80, 1.75, .077), ivory[3], .021)
        for direction in (-1, 1):
            for i in range(3):
                xx = x + direction * (.47 + i * .12)
                box("Brush-cut console", (xx, -.58, 2.78 + i * .033), (.11, .32, .20), ivory[(i + 2) % 6], .022)

    for x in (-1.63, 1.63):
        box("Proud column pediment", (x, -.75, .57), (.73, .75, .33), ivory[2], .049)
        box("Foot molding", (x, -.755, .77), (.60, .62, .12), pale, .026)
        carved_stem("Twelve-fluted limestone column", x, -.79, [
            (.80, .206), (.90, .208), (1.00, .181), (1.36, .177), (2.16, .169),
            (2.35, .176), (2.42, .199), (2.48, .204)], ivory[0])
        for z in (.86, 2.37, 2.47):
            barrel("Bronze collar", (x, -.79, z), .215, .065, oxidized)
        for face_index in range(11):
            a = face_index / 10.0 * math.pi + math.pi
            lozenge("Column crown petal", x + math.cos(a) * .245, -.79 + math.sin(a) * .245, 2.52, .017, .073, gilt)
        box("Column capital", (x, -.72, 2.60), (.64, .65, .21), pale, .036)

    # Octagonal conservatory crown above the observatory arch.
    box("Crown bed", (0, .24, 4.04), (3.79, 2.13, .26), ivory[2], .082)
    box("Crown enamel line", (0, .25, 4.212), (3.65, 2.06, .095), oxidized, .033)
    box("Crown warm coping", (0, .26, 4.286), (3.70, 2.08, .072), pale, .025)
    box("Recessed seed frieze", (0, -.704, 4.019), (2.72, .13, .132), enamel[4], .024)
    for j in range(11):
        x = (j - 5) * .232
        lozenge("Inlaid bronze seed inscription", x, -.787, 4.02, .065, .029, gilt, .022)

    # Instead of a dome, overlapping bronze panels taper into a stepped finial.
    for i in range(8):
        a = i * TAU / 8 + math.pi / 8
        b = (i + 1) * TAU / 8 + math.pi / 8
        angles = [a + (b - a) * j / 7 for j in range(8)]
        rings = [(4.32, 1.48, .94), (4.50, 1.51, .96), (4.71, 1.30, .84),
                 (5.10, .88, .65), (5.37, .38, .34), (5.43, .26, .23)]
        verts = [(math.cos(v) * rx, .24 + math.sin(v) * ry, z) for z, rx, ry in rings for v in angles]
        faces = []
        for ring in range(len(rings) - 1):
            for j in range(7):
                ll = ring * len(angles) + j
                faces.append((ll, ll + 1, ll + 9, ll + 8))
        obj = mesh("Bronze crown segment", verts, faces, enamel[(i + (i % 2) * 2) % 5])
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        pipe("Fine warm roof standing seam", [(math.cos(a) * rx, .24 + math.sin(a) * ry, z)
             for z, rx, ry in rings], .027, gilt)
    barrel("Crown neck", (0, .24, 5.51), .25, .16, oxidized)
    barrel("Crown ring", (0, .24, 5.62), .30, .075, gilt)
    carved_stem("Seed-shaped finial", 0, .24, [(5.64, .17), (5.78, .23), (5.97, .18), (6.16, .02)], gilt, 7)

    # A floor-height bronze sun instrument gives the facade an original signature.
    z = 2.07
    ellipse("Orrery outer ring", 0, -.397, z, .80, .80, .044, oxidized)
    ellipse("Orrery polished ring", 0, -.431, z, .736, .736, .019, gilt)
    ellipse("Orrery radial datum", 0, -.426, z, .485, .485, .015, gilt)
    ellipse("Orrery inner seed ring", 0, -.47, z, .229, .229, .026, gilt)
    for i in range(40):
        angle = i * TAU / 40
        x = math.cos(angle)
        zz = math.sin(angle)
        length = .126 if i % 5 == 0 else .057
        pipe("Copper radial graduation", [(x * .725, -.447, z + zz * .725),
             (x * (.725 - length), -.447, z + zz * (.725 - length))], .012, gilt)
        if i % 5 == 0:
            start = .256 + (i % 10 == 0) * .055
            pipe("Orrery radial spoke", [(x * start, -.432, z + zz * start),
                 (x * .455, -.473, z + zz * .455)], .024, oxidized)
    lozenge("Amber center glass", 0, -.509, z, .13, .17, glow, .095)
    for x in (-2.50, 2.50):
        extrusion("Shaped skyline shoulder", tip_profile(x, 3.33), -.41, .325, oxidized, .028)
        extrusion("Shaped shoulder relief", tip_profile(x, 3.39, .69, .77), -.47, -.375, gilt, .017)
        extrusion("Oxidized shoulder leaf", tip_profile(x, 3.41, .42, .57), -.50, -.435, enamel[3], .013)
        lozenge("Small inset terracotta crest", x, -.575, 3.57, .070, .16, relief)
    return base


def map_stone_atlas(atlas_file):
    atlas = bpy.data.images.load(str(atlas_file), check_existing=True)
    atlas.name = "Painted stone color atlas"
    atlas.pack()
    for name in sorted(ATLAS_SAND | ATLAS_SHALE):
        mat = bpy.data.materials[name]
        nodes = mat.node_tree.nodes
        uv_reader = nodes.new("ShaderNodeUVMap")
        uv_reader.uv_map = "PaintedStone"
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = atlas
        tex.extension = "EXTEND"
        mat.node_tree.links.new(uv_reader.outputs["UV"], tex.inputs["Vector"])
        mat.node_tree.links.new(tex.outputs["Color"], nodes.get("Principled BSDF").inputs["Base Color"])
    for obj in ROOT.children:
        if obj.type != "MESH" or not obj.data.materials:
            continue
        name = obj.data.materials[0].name
        if name not in ATLAS_SAND and name not in ATLAS_SHALE:
            continue
        uv = obj.data.uv_layers.new(name="PaintedStone")
        obj.data.uv_layers.active = uv
        offset = .5 if name in ATLAS_SHALE else 0
        for polygon in obj.data.polygons:
            world_normal = obj.matrix_world.to_3x3() @ polygon.normal
            dominant = max(range(3), key=lambda axis: abs(world_normal[axis]))
            for loop_index in polygon.loop_indices:
                point = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
                u, v = ((point.y, point.z), (point.x, point.z), (point.x, point.y))[dominant]
                uv.data[loop_index].uv = (offset + .25 + u * .051, .13 + v * .112)


def export_game_model(path):
    # Preserve individual editable parts in the blend file, merge evaluated
    # render geometry into material surfaces for the engine import.
    bpy.ops.object.select_all(action="DESELECT")
    depsgraph = bpy.context.evaluated_depsgraph_get()
    parts = []
    for obj in ROOT.children:
        evaluated = obj.evaluated_get(depsgraph)
        geometry = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=depsgraph)
        part = bpy.data.objects.new("Export part", geometry)
        bpy.context.collection.objects.link(part)
        part.matrix_world = obj.matrix_world.copy()
        part.select_set(True)
        parts.append(part)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    merged = bpy.context.object
    merged.name = "Terrace Orrery · game mesh"
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    merged.data.calc_loop_triangles()
    print(f"Terrace Orrery game mesh: {len(merged.data.loop_triangles)} triangles, {len(merged.data.materials)} material slots")
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_apply=True, export_image_format="JPEG", export_jpeg_quality=93)
    bpy.data.objects.remove(merged, do_unlink=True)


def aim(obj, at):
    obj.rotation_euler = (Vector(at) - obj.location).to_track_quat("-Z", "Y").to_euler()


def lighting_and_camera(output, floor):
    bpy.ops.mesh.primitive_plane_add(size=200)
    plate = bpy.context.object
    plate.name = "Render only · warm clay ground"
    plate.location.z = -.012
    plate.data.materials.append(floor)
    world = bpy.context.scene.world
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs[0].default_value = (.045, .077, .082, 1)
    world.node_tree.nodes.get("Background").inputs[1].default_value = .38
    lights = [
        ("Sunbox", (-6, -7, 10), (1, .79, .62), 1650, 7.5),
        ("Large cyan fill", (4, -3, 6), (.52, .79, .88), 850, 7.0),
        ("Separating rim", (2, 5, 7), (.91, .69, .45), 1050, 5.0),
    ]
    for name, where, color, power, size in lights:
        light = bpy.data.lights.new(name, "AREA")
        light.color = color
        light.energy = power
        light.shape = "DISK"
        light.size = size
        lamp = bpy.data.objects.new(name, light)
        bpy.context.collection.objects.link(lamp)
        lamp.location = where
        aim(lamp, (0, 0, 2.4))
    bpy.ops.object.camera_add(location=(7.55, -12.8, 6.55))
    camera = bpy.context.object
    aim(camera, (0, -.08, 2.73))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 9.40
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 20
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output)
    scene.view_settings.view_transform = "AgX"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, default=Path.cwd())
    parser.add_argument("--atlas", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    args.directory.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    global ROOT
    ROOT = bpy.data.objects.new("Terrace Orrery", None)
    bpy.context.collection.objects.link(ROOT)
    terrace_orrery()
    bpy.context.view_layer.update()
    atlas = args.atlas or args.directory.parent / "generated-art" / "Painted_Stone_Atlas.png"
    if atlas.is_file():
        map_stone_atlas(atlas)
    export_game_model(args.directory / "terrace_orrery.glb")
    clay = material("Studio plate color", "777368", .9)
    lighting_and_camera(args.directory / "terrace_orrery.png", clay)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(args.directory / "terrace_orrery.blend"))
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
