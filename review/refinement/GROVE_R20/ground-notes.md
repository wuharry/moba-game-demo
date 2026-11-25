# Grove R20 ground cover implementation

Call `preload("res://grove_r20_understory.gd").build(self)` once at the end of the grove's `_ready()` after the existing terrain and dressing. The module owns a separate deterministic RNG and does not change any route, collider, camera, or existing placement seed.

- Original five-blade curved short/middle grass and occasional six-leaf wider rosettes; all geometry is generated locally.
- Twelve asymmetric beds extend around the woodland feet and outside bank. The distribution uses bed density, low-frequency patch breakup, explicit route distance, pond radius, terrain height and slope exclusions.
- Main route center remains empty; grass begins beyond 2.05 m and shortens along the shoulder. Pond interior/island, submerged ground and steep rock slopes excluded.
- Spatial batches use a 5 by 5 grid and three mesh variants. No shadows from tiny blades, no texture alpha/discard overdraw. The taller existing reeds and flowers remain.
- `grove_r20_meadow_shared.gdshaderinc` defines the shared terrain/root pigment. The base combines cool forest green and restrained autumn sage/ochre across broad ground fields, without adding fake ambient light in a custom light function.
- Terrain fine noise reduced from 8.0 to 3.1 world frequency and internal contrast reduced. Soil/path, stone, moisture and underwater masks remain intact.

Limit: grass roots share the meadow pigment exactly before lighting, but a blade at the path/rock/damp blend can still differ from those other surface layers. The placement exclusions avoid most of those transitions. This is not a claim of perfect colour matching everywhere. Parent must validate both native camera views and the physical walk before accepting.

Owned files: `refine_grove_terrain.gdshader`, `grove_r20_meadow_shared.gdshaderinc`, `grove_r20_meadow.gdshader`, `grove_r20_understory.gd`.

## Candidate B correction after actual trial A

Trial A reported 1,458 clumps and left much of the overhead lawn effectively flat. Candidate B raises attempts from 630 to 2,520 per cell (four times the sampling budget), adds four connecting edge beds, and allows a narrow raised dry cove to grow plants while preserving the rest of the island/water exclusions. The actual accepted count must come from the next native engine log, not from multiplying the prior count. Short blades now have wider curved profiles; tall blades are capped lower to keep the majority in roughly 0.18–0.50 m. Route exclusion follows a small irregular noise displacement instead of a straight constant-width boundary. Tip colour is slightly less pale/yellow; shared base pigment is unchanged.

## Candidate C correction after actual trial B

Trial B filled the lawn but read as a pale scratch-brush strip. C retains the same sampling budget, adds three deliberately localized taller/darker grass cores at the left near bank, left rear woodland foot and right raised cove, and cuts three low/open gaps between them. Tall grass no longer appears randomly throughout every bed. Per-instance custom data carries core strength and pigment variation; roots still use the shared meadow pigment, while upper leaves become deeper green in cores instead of uniformly brighter sage. Backlighting is reduced, short grass is lower, and tall-core count is printed separately for review. No camera, route or collision changes.
