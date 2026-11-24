"""Merge the exported hero meshes while retaining UVs and materials."""
from pathlib import Path
import sys

import bpy


out = Path(sys.argv[sys.argv.index('--') + 1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out / 'Basin_Relay_Textured.glb'))

meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
merged = bpy.context.object
merged.name = 'Basin Relay'
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.export_scene.gltf(filepath=str(out / 'Basin_Relay_Game.glb'), use_selection=True,
    export_format='GLB', export_materials='EXPORT')
