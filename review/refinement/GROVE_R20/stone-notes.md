# Grove R20 geology candidate

- Edited only `refine_grove.gd::_build_ridges`, `::_rock_mass` and `refine_grove_strata.gdshader`.
- Original ridge locations, footprints, route, cameras and collision retained. `_rock_mass` is only used by backdrop ridges, so this change adds no route obstacles.
- Replaced 44-segment, 18-ring rounded noisy mass with 20-segment, 10-ring broad shoulder sections. Upper crest keeps width rather than a thin spike. One shared normal per broad quad blends with continuous ridge normals, avoiding individually flat triangular facets.
- Near rock pigments are cleaner restrained limestone/lichen; rear ridge palette is cooler blue-grey. Strata reduces high-frequency grain, repetitive seam contrast and blanket moss. Natural light remains the main source of face contrast.
- No render was run by this sub-agent. Parent must inspect both unchanged fixed cameras, especially overly regular horizontal sections, any broad facet bright seam and foreground rock lightness after lighting integration. No visual score or publication claim assigned.

## Candidate A rejected; B correction

- Parent actual screenshots show A's reduced sections and plane normals produced inflated polygon domes and continuous horizontal belts. This is a silhouette regression, not a successful stylization; discard A geometry.
- B restores baseline 44-section continuous ridge normals and original broad shoulder profile, reduces small vertex wear from 0.085 to 0.038, modestly reinforces broad folded sections, and removes two profile bulges that can create repeated rings.
- Lowered overly pale near-ridge pigments and restored more material weight (low-frequency texture blend 0.36); preserved restrained grain and cool distant layer.
- Parent must render B; no claimed improvement percentage until its actual images are compared.
