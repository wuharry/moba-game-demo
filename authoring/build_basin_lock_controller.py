"""Build the original Basin side-lock controller in Blender and export glTF."""

from math import pi, sin, cos
from pathlib import Path

import bpy
from mathutils import Vector


def linear(channel):
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def finish(name, rgb, roughness, metallic, emission=0.0):
    shade = bpy.data.materials.new(name)
    shade.use_nodes = True
    shader = shade.node_tree.nodes.get("Principled BSDF")
    color = tuple(linear(int(rgb[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Emission Color"].default_value = color
    shader.inputs["Emission Strength"].default_value = emission
    shade.diffuse_color = color
    return shade


def soften(obj, amount, segments=3):
    profile = obj.modifiers.new("Cast edge radius", "BEVEL")
    profile.width = amount
    profile.segments = segments
    # Keep the broad faces planar under the inspection light.
    normals = obj.modifiers.new("Weighted casting normals", "WEIGHTED_NORMAL")
    normals.keep_sharp = True
    return obj


def plate(name, outline, front, back, material, bevel):
    vertices = [(x, y, z) for y in (front, back) for x, z in outline]
    width = len(outline)
    faces = [tuple(range(width)), tuple(reversed(range(width, 2 * width)))]
    faces.extend((i, width + i, width + (i + 1) % width, (i + 1) % width) for i in range(width))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return soften(obj, bevel)


def block(name, center, size, material, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return soften(obj, bevel)


def cylinder(name, start, end, radius, material, facets=20):
    direction = Vector(end) - Vector(start)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=facets, radius=radius, depth=direction.length, location=(Vector(start) + Vector(end)) * 0.5
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    return soften(obj, min(0.009, radius * 0.15), 2)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

cast_iron = finish("Blue graphite iron", "48565a", 0.73, 0.21)
casting_high = finish("Rubbed blue grey edges", "738284", 0.65, 0.29)
patina = finish("Weathered iron oxide marking", "7d543d", 0.80, 0.17)
inset = finish("Graphite recess", "2b3839", 0.82, 0.18)
copper = finish("Burnished valve alloy", "a67b4a", 0.58, 0.31)
seal = finish("Water dark support", "3d4640", 0.91, 0.02)
guide = finish("Faint frosted status glass", "608d86", 0.53, 0.06, 0.14)

block("Bolt-down curb", (0, 0.025, 0.085), (1.34, 0.78, 0.18), seal, 0.065)
block("Drainage shoulder", (0.02, 0.051, 0.21), (1.16, 0.66, 0.18), cast_iron, 0.047)
plate("Slightly raked cast pressure case", [
    (-0.52, 0.22), (0.43, 0.22), (0.54, 0.47), (0.54, 1.18),
    (0.41, 1.47), (0.23, 1.59), (-0.31, 1.59), (-0.52, 1.40), (-0.57, 0.73),
], -0.26, 0.27, cast_iron, 0.067)
plate("Water diversion lip", [
    (-0.56, 1.43), (0.47, 1.43), (0.49, 1.51), (0.28, 1.68), (-0.31, 1.68), (-0.57, 1.51),
], -0.36, 0.26, casting_high, 0.029)
plate("Recessed valve face gasket", [
    (-0.41, 0.73), (0.36, 0.73), (0.42, 0.88), (0.38, 1.34),
    (0.27, 1.45), (-0.33, 1.43), (-0.45, 1.28),
], -0.295, -0.25, inset, 0.022)
plate("Trapezoidal hinge plate", [
    (-0.43, 0.36), (0.31, 0.36), (0.37, 0.50), (0.36, 0.66), (-0.39, 0.65),
], -0.288, -0.25, casting_high, 0.023)
block("Punched hinge opening", (-0.16, -0.312, 0.55), (0.44, 0.058, 0.095), inset, 0.018)
block("Replaceable hinge insert", (-0.16, -0.349, 0.55), (0.35, 0.066, 0.051), patina, 0.016)
cylinder("Front valve bushing", (-0.044, -0.304, 1.101), (-0.044, -0.379, 1.101), 0.239, casting_high)
cylinder("Valve face shadow", (-0.044, -0.38, 1.101), (-0.044, -0.397, 1.101), 0.208, inset)
bpy.ops.mesh.primitive_torus_add(
    major_segments=28, minor_segments=10, location=(-0.044, -0.425, 1.101),
    rotation=(pi / 2.0, 0, 0), major_radius=0.169, minor_radius=0.022,
)
bpy.context.object.name = "Lock pressure handwheel"
bpy.context.object.data.materials.append(copper)
for angle in (0.16, 0.16 + 2 * pi / 3, 0.16 + 4 * pi / 3):
    tip = (-0.044 + 0.168 * cos(angle), -0.425, 1.101 + 0.168 * sin(angle))
    cylinder("Swept handwheel spoke", (-0.044, -0.425, 1.101), tip, 0.014, copper, 10)
cylinder("Keyed valve hub", (-0.044, -0.416, 1.101), (-0.044, -0.456, 1.101), 0.041, casting_high, 10)
block("Status glass rail", (0.28, -0.335, 1.104), (0.073, 0.063, 0.33), cast_iron, 0.018)
for z in (1.005, 1.095, 1.184):
    block("Status slit", (0.28, -0.369, z), (0.042, 0.012, 0.045), guide, 0.011)
for x in (-0.49, 0.46):
    for y in (-0.21, 0.28):
        cylinder("Foot anchor", (x, y, 0.12), (x, y, 0.21), 0.047, casting_high, 6)
for x in (-0.375, 0.286):
    for z in (0.80, 1.36):
        cylinder("Inspection fastener", (x, -0.295, z), (x, -0.323, z), 0.029, patina, 6)
for z in (0.78, 0.88, 0.98, 1.08, 1.18):
    block("Right-side cooling louvre", (0.533, 0.036, z), (0.042, 0.29, 0.047), casting_high, 0.012)
for x in (-0.22, -0.066, 0.088):
    cylinder("Downward cable sleeve", (x, 0.20, 0.27), (x, 0.20, 0.51), 0.043, copper, 12)
    cylinder("Cable strain relief", (x, 0.20, 0.45), (x, 0.20, 0.50), 0.059, inset, 12)

project = Path(__file__).resolve().parents[1]
bpy.ops.export_scene.gltf(
    filepath=str(project / "models" / "basin_lock_controller.glb"),
    export_format="GLB",
    export_apply=True,
    export_cameras=False,
    export_lights=False,
)
