# Fog runner wardrobe study

The head, body, skinning, facial target geometry, and underlying textured clothing derive from Sakurada Fumiriya by pixiv Inc. The model is CC0. The Blender-authored changes include a woven asymmetrical cloak, brass clasp, strap, collar, skinned bracers, hair and clothing tint, and a two-second idle pose.

- [Pixiv source and CC0](https://vroid.pixiv.help/hc/en-us/articles/360014788554-Sakurada-Fumiriya)
- [Downloaded model data](https://file-in-abyss.soga-web.studio/download/vrm/05-sakurada-fumiriya.vrm)
- Source VRM SHA-256: d8fb05f33e377df028cb6b9d58c441ce68326c41fa23f6c735d40c65ae3dc710

`fog-runner-authored.glb` imports as glTF 2.0 with 107 skeleton bones and the `Scout idle` clip. The character faces -Z and is approximately 1.92 m tall. The embedded maps are included. Importing via ordinary glTF preserves authored textures and morph geometry. VRM-only expression presets and spring-bone behavior require separate rig logic.

Run `make_fog_runner.py` in Blender 5.1 background mode with the validated `fumiriya.glb` input in the same directory. The Godot 4.7.2 review scene captured full, face and back views on the RTX 4080 Laptop GPU.
