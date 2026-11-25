"""Generate sculpted Genshin-style planar-faceted boulders in Blender 5.1 -> models/sunvine_boulders.glb.
Uses bmesh planar bisection cuts + chamfer Bevel + Weighted Normals + baked vertex colors:
  R = bevel/ridge curvature highlight (0.35..1.0)
  G = top moss suitability (0.3..1.0)
  B = variation
  A = BlendStone ground skirt weight (1.0 at bottom -> 0.0 above y=0.35)
"""

import math
import random
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector


OUT_GLB = Path(__file__).resolve().parents[1] / "models" / "sunvine_boulders.glb"


def build_planar_boulder(name: str, seed: int, scale_xyz: tuple, cuts: int, offset_x: float) -> bpy.types.Object:
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)

    # Stretch into bold anime rock mass before planar slicing
    for v in bm.verts:
        v.co.x *= scale_xyz[0]
        v.co.y *= scale_xyz[1]
        v.co.z *= scale_xyz[2]
        # Slight upward taper (wider stable base, chiselled crest)
        taper = max(0.55, 1.0 - 0.22 * max(0.0, v.co.z / scale_xyz[2]))
        v.co.x *= taper
        v.co.y *= taper

    # Slice flat bottom so it sits firmly in terrain
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(
        bm,
        geom=geom,
        plane_co=Vector((0.0, 0.0, -scale_xyz[2] * 0.42)),
        plane_no=Vector((0.0, 0.0, -1.0)),
        clear_outer=True,
    )
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary])

    # Apply bold Blur-Slope / ZBrush TrimDynamic style planar cuts!
    for i in range(cuts):
        az = (i / float(cuts)) * math.tau + rng.uniform(-0.28, 0.28)
        # Bias plane normals slightly upward/diagonal for stepped sedimentary anime facets
        el = rng.uniform(-0.15, 0.72)
        nx = math.cos(az) * math.cos(el)
        ny = math.sin(az) * math.cos(el)
        nz = math.sin(el)
        n = Vector((nx, ny, nz)).normalized()
        dist = rng.uniform(0.58, 0.86)
        p_co = Vector((n.x * scale_xyz[0] * dist, n.y * scale_xyz[1] * dist, n.z * scale_xyz[2] * dist))
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=p_co, plane_no=n, clear_outer=True)
        boundary = [e for e in bm.edges if e.is_boundary]
        if boundary:
            bmesh.ops.holes_fill(bm, edges=boundary)

    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = (offset_x, 0.0, 0.0)

    # Crisp anime rock chamfer + weighted face normals
    bev = obj.modifiers.new("Chamfer", "BEVEL")
    bev.width = 0.045
    bev.segments = 2
    bev.limit_method = "ANGLE"
    bev.angle_limit = math.radians(22.0)

    wn = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=bev.name)
    bpy.ops.object.modifier_apply(modifier=wn.name)

    # Bake curvature / height / BlendStone skirt into Vertex Color ("Col")!
    m = obj.data
    z_vals = [v.co.z for v in m.vertices]
    z_min, z_max = min(z_vals), max(z_vals)
    z_span = max(0.01, z_max - z_min)

    # Estimate vertex convexity from neighbor normal divergence
    v_curv = [0.5] * len(m.vertices)
    adj_normals = [[] for _ in range(len(m.vertices))]
    for poly in m.polygons:
        for vi in poly.vertices:
            adj_normals[vi].append(poly.normal.copy())
    for vi, nlist in enumerate(adj_normals):
        if len(nlist) > 1:
            avg_n = sum(nlist, Vector((0, 0, 0))) / len(nlist)
            # Lower avg_n.length = sharper ridge/corner!
            sharp = 1.0 - max(0.0, min(1.0, avg_n.length))
            v_curv[vi] = min(1.0, 0.48 + sharp * 2.4)

    col_attr = m.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
    for poly in m.polygons:
        for li in poly.loop_indices:
            vi = m.loops[li].vertex_index
            vz = m.vertices[vi].co.z
            h_norm = (vz - z_min) / z_span
            # BlendStone skirt: 1.0 at bottom 28% of boulder -> 0.0 above
            skirt = max(0.0, min(1.0, 1.0 - (h_norm / 0.30)))
            moss = max(0.0, min(1.0, 0.35 + 0.65 * h_norm))
            col_attr.data[li].color = (v_curv[vi], moss, h_norm, skirt)

    # Reset location to origin so each named mesh in GLB has centered pivot at base!
    for v in m.vertices:
        v.co.z -= z_min + 0.08 * z_span
    obj.location = (0.0, 0.0, 0.0)
    obj.select_set(False)
    return obj


def main() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    specs = [
        ("Boulder_Slab_A", 101, (1.15, 0.92, 0.78), 16),
        ("Boulder_Spire_B", 202, (0.88, 0.85, 1.18), 18),
        ("Boulder_Step_C", 303, (1.28, 1.05, 0.62), 15),
        ("Boulder_Shore_D", 404, (0.95, 0.78, 0.52), 14),
    ]
    objs = []
    for idx, (name, seed, sc, cuts) in enumerate(specs):
        objs.append(build_planar_boulder(name, seed, sc, cuts, idx * 3.0))

    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

    OUT_GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_attributes=True,
    )
    print(f"Exported {OUT_GLB} with {len(objs)} sculpted planar boulders.")


if __name__ == "__main__":
    main()
