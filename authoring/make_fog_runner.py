"""Wardrobe study built upon the pixiv CC0 Sakurada Fumiriya rig."""

import math
import json
import struct
from array import array
from pathlib import Path
from mathutils import Quaternion, Vector
import bpy
import bmesh

ROOT = Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "fumiriya.glb"))
rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
body = bpy.data.objects["Body"]
head = bpy.data.objects["Face"]
body_parts = [
    obj for obj in bpy.context.scene.objects
    if obj.type == "MESH" and any(mod.type == "ARMATURE" for mod in obj.modifiers)
]

def linear(color):
    return tuple(
        channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
        for channel in (int(color[index:index + 2], 16) / 255 for index in (0, 2, 4))
    )

def material(name, tint, roughness, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    surface = mat.node_tree.nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = (*linear(tint), 1)
    surface.inputs["Roughness"].default_value = roughness
    surface.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = (*linear(tint), 1)
    return mat

canvas = material("Juniper waxed linen", "40534c", 0.91)
edge = material("Oat binding", "b9a67e", 0.82)
dark = material("Umber glove leather", "3d3229", 0.75)
oxidized = material("Oxidized bronze", "987750", 0.48, 0.55)
enamel = material("Oxide enamel", "ae5334", 0.48, 0.2)
underlining = material("Dark lining", "283c38", 0.93)
bone_key = "J_Bip_C_UpperChest"

# A subdued woven albedo preserves the painted body textures and gives the
# new fabric a readable grain at the character-review camera distance.
fabric = bpy.data.images.new("Waxed linen woven albedo", 128, 128)
fabric.pixels.foreach_set(array("f", (
    channel for y in range(128) for x in range(128)
    for channel in (*[
        value * (0.96 + 0.06 * math.sin(x * 0.39) * math.cos(y * 0.22)
                 + 0.035 * math.sin(x * math.pi / 2) + 0.026 * math.cos(y * math.pi / 2))
        for value in (0.081, 0.114, 0.086)
    ], 1.0)
)))
fabric.pack()
weave = canvas.node_tree.nodes.new("ShaderNodeTexImage")
weave.image = fabric
canvas.node_tree.links.new(weave.outputs["Color"], canvas.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])

# The stock school tie was authored as a separate material primitive.
tie_index = next(i for i, mat in enumerate(body.data.materials) if "AccessoryNeck" in mat.name)
work = bmesh.new()
work.from_mesh(body.data)
tie_faces = [face for face in work.faces if face.material_index == tie_index]
bmesh.ops.delete(work, geom=tie_faces, context="FACES")
work.to_mesh(body.data)
work.free()
body.data.update()

def mesh_object(name, verts, faces, mat, joint, smooth=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = rig
    group = obj.vertex_groups.new(name=joint)
    group.add(list(range(len(mesh.vertices))), 1, "REPLACE")
    armature = obj.modifiers.new("Rig weights", 'ARMATURE')
    armature.object = rig
    for polygon in mesh.polygons:
        polygon.use_smooth = smooth
    body_parts.append(obj)
    return obj

def path_surface(name, rows, mat, joint, wrap=False):
    width = len(rows[0])
    faces = []
    for row in range(len(rows) - 1):
        for col in range(width if wrap else width - 1):
            nxt = (col + 1) % width
            faces.append((row * width + col, row * width + nxt,
                          (row + 1) * width + nxt, (row + 1) * width + col))
    obj = mesh_object(name, [point for row in rows for point in row], faces, mat, joint)
    if mat == canvas:
        uv = obj.data.uv_layers.new(name="Linen weave")
        for polygon in obj.data.polygons:
            for loop_index in polygon.loop_indices:
                row, column = divmod(obj.data.loops[loop_index].vertex_index, width)
                uv.data[loop_index].uv = (column / (width - 1), row / (len(rows) - 1))
    return obj

def tube(name, centerline, radius, mat, joint=bone_key, sides=8):
    rows = []
    for i, center in enumerate(centerline):
        vec = Vector(center)
        tangent = (Vector(centerline[min(i + 1, len(centerline) - 1)])
                   - Vector(centerline[max(0, i - 1)])).normalized()
        normal = tangent.cross(Vector((0, 0, 1)))
        if normal.length < 0.01:
            normal = tangent.cross(Vector((0, 1, 0)))
        normal.normalize()
        side = tangent.cross(normal).normalized()
        rows.append([vec + radius * (normal * math.cos(angle) + side * math.sin(angle))
                     for angle in (math.tau * j / sides for j in range(sides))])
    return path_surface(name, rows, mat, joint, True)

def fold(angle):
    return 0.65 * math.cos(angle * 8 + 0.4) + 0.35 * math.sin(angle * 13 - 0.2)

# Curved shoulders, split front and asymmetrical longer back.
span = [-3.65 + 3.98 * i / 44 for i in range(45)]
layers = []
for stage in range(12):
    weight = stage / 11
    rows = []
    for angle in span:
        front = max(math.cos(angle), 0)
        back = max(-math.cos(angle), 0)
        left = max(-math.sin(angle), 0)
        reach = 0.045 + 0.15 * left + 0.063 * back
        widen = math.sin(weight * math.pi * 0.53)
        radial = 0.105 + (reach + 0.016 * fold(angle) * weight) * widen
        depth = 0.091 + (0.032 + 0.100 * back + 0.028 * front) * widen
        x = radial * math.sin(angle)
        y = 0.012 + depth * math.cos(angle)
        z = 1.555 - (0.21 + 0.25 * back + 0.03 * left) * (weight ** 1.5)
        z += 0.009 * fold(angle) * weight + 0.01 * front
        rows.append((x, y, z))
    layers.append(rows)
path_surface("Asymmetrical waxed linen shoulder cloak", layers, canvas, bone_key)
# Surface faces stay visible on the underside, including the open collar.
canvas.use_backface_culling = False
tube("Hemp bound hem", layers[-1], 0.004, edge)
tube("Front slit stitching", [row[-1] for row in layers], 0.0038, edge)
tube("Outer slit binding", [row[0] for row in layers], 0.0038, edge)
top_hem = [(x * 0.97, y, z + 0.006) for x, y, z in layers[0]]
tube("Shoulder facing", top_hem, 0.006, underlining)

# Standing canvas collar, separated at the front for a pin closure.
angles = [0.20 + (math.tau - 0.4) * i / 39 for i in range(40)]
rows = [[(rx * math.sin(a), 0.006 + ry * math.cos(a), z) for a in angles]
        for z, rx, ry in ((1.554, 0.071, 0.073), (1.574, 0.057, 0.060), (1.599, 0.053, 0.054))]
path_surface("Stand collar", rows, underlining, bone_key)
tube("Collar top binding", rows[-1], 0.0042, edge)

# Leather chest strap laid along the torso curvature.
strap = [
    (-0.111, 0.161, 1.512), (-0.074, 0.181, 1.465), (-0.030, 0.186, 1.425),
    (0.014, 0.182, 1.375), (0.070, 0.162, 1.319), (0.115, 0.143, 1.274),
]
for i, material_slot in enumerate((dark, edge)):
    delta = 0.026 if i == 0 else 0.006
    strap_rows = [[(x - delta, y + (0.0025 if i else 0), z - 0.013),
                   (x + delta, y + (0.0025 if i else 0), z + 0.013)] for x, y, z in strap]
    path_surface("Diagonal strap" if i == 0 else "Strap welt", strap_rows, material_slot, bone_key)

def medallion(name, center, radius, depth, mat, side_count=16):
    x, y, z = center
    verts = []
    for ring in (y - depth / 2, y + depth / 2):
        verts.extend([(x + radius * math.cos(math.tau * i / side_count), ring,
                       z + radius * math.sin(math.tau * i / side_count)) for i in range(side_count)])
    faces = [tuple(range(side_count - 1, -1, -1)), tuple(range(side_count, 2 * side_count))]
    for i in range(side_count):
        j = (i + 1) % side_count
        faces.append((i, i + side_count, j + side_count, j))
    return mesh_object(name, verts, faces, mat, bone_key, False)

medallion("Octagonal shoulder clasp", (-0.067, 0.185, 1.467), 0.031, 0.01, oxidized, 8)
medallion("Fired oxide inlay", (-0.067, 0.191, 1.467), 0.019, 0.004, enamel, 8)
medallion("Clasp rivet", (-0.067, 0.195, 1.467), 0.005, 0.003, edge, 8)

# Tailored leather bracers follow the existing forearm joints.
for side, sign in (("L", -1), ("R", 1)):
    bone = f"J_Bip_{side}_LowerArm"
    forearm = []
    segments = 20
    for distance, radius in ((0.05, 0.038), (0.077, 0.039), (0.155, 0.034), (0.176, 0.03)):
        x = sign * (0.365 + distance)
        forearm.append([(x, 0.008 + radius * math.cos(math.tau * i / segments),
                         1.525 + radius * math.sin(math.tau * i / segments)) for i in range(segments)])
    path_surface("Stitched bracer " + side, forearm, dark, bone, True)
    tube("Cuff piping " + side, forearm[-1] + [forearm[-1][0]], 0.004, oxidized, bone)

def set_bone_angle(name, axis, angle):
    bone = rig.pose.bones[name]
    local_axis = (rig.matrix_world @ bone.bone.matrix_local).to_quaternion().inverted() @ Vector(axis)
    bone.rotation_mode = "QUATERNION"
    bone.rotation_quaternion = Quaternion(local_axis, math.radians(angle))
    return bone

# A neutral stance clip preserves the source skeleton and facial morphs.
def pose(frame, idle_amount):
    values = [
        set_bone_angle("J_Bip_L_UpperArm", (0, 1, 0), -69 + idle_amount),
        set_bone_angle("J_Bip_R_UpperArm", (0, 1, 0), 72 - idle_amount),
        set_bone_angle("J_Bip_L_LowerArm", (0, 0, 1), -13),
        set_bone_angle("J_Bip_R_LowerArm", (0, 0, 1), 14),
        set_bone_angle("J_Bip_C_UpperChest", (0, 1, 0), 1.1 * idle_amount),
        set_bone_angle("J_Bip_C_Head", (0, 0, 1), -4 + idle_amount),
    ]
    for pose_bone in values:
        pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=pose_bone.name)

pose(1, 0)
pose(25, 1.5)
pose(49, 0)
rig.animation_data.action.name = "Scout idle"
bpy.context.scene.render.fps = 24
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 49
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
for piece in body_parts:
    piece.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=str(ROOT / "fog-runner-authored.glb"),
    export_format="GLB", use_selection=True, export_animations=True,
    export_frame_range=True, export_force_sampling=True
)
output = ROOT / "fog-runner-authored.glb"
authored = output.read_bytes()
json_size = struct.unpack_from("<I", authored, 12)[0]
glb = json.loads(authored[20:20 + json_size])
for mat in glb["materials"]:
    name = mat.get("name", "")
    pbr = mat.get("pbrMetallicRoughness", {})
    if "HAIR_01" in name:
        pbr["baseColorFactor"] = [0.48, 0.31, 0.20, 1.0]
    elif "HAIR_02" in name or "HairBack" in name:
        pbr["baseColorFactor"] = [0.38, 0.24, 0.16, 1.0]
    elif "Tops_01_CLOTH" in name:
        pbr["baseColorFactor"] = [0.93, 0.84, 0.59, 1.0]
    elif "Bottoms_01_CLOTH" in name:
        pbr["baseColorFactor"] = [0.70, 0.70, 0.58, 1.0]
chunk = json.dumps(glb, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
chunk += b" " * (-len(chunk) % 4)
payload = authored[20 + json_size:]
output.write_bytes(struct.pack("<4s4I", b"glTF", 2, 20 + len(chunk) + len(payload), len(chunk), 0x4e4f534a)
                   + chunk + payload)
print("EXPORTED", output.stat().st_size, "bytes")
