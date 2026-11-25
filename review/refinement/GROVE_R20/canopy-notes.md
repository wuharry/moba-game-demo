# Grove R20 canopy candidate

- Preserved original tree origins, branch splines, route and cameras.
- Replaced faceted solid diamond leaves with 27–44 domed alpha-tested cards per branch cluster, distributed over three shells. Depth rises to at least 44% of branch radius for visible side volume.
- Reused authored four-quadrant foliage atlas; warm crowns use lower-left leaves and green crowns use upper-left broad leaves.
- Kept manually authored ellipsoidal crown normals and removed generate_normals() on the leaf surface; preserves continuous branch-group lighting.
- Shifted ochre/olive palette toward amber/cool jade; retained separate warm and green species.
- Direct light only in light(); environment remains responsible for ambient light. Moderate internal AO, small wind amplitude, no emission fill.

Validation pending parent render. Inspect both fixed cameras for clock occlusion, bright card backs, silhouette gaps and repeated rosette pattern. No 90% score claimed.
`UV2.x = 1` marks crown cards only. The same shader also serves solid reeds, flowers and lily pads; those retain opaque geometry with no atlas clipping.

## Candidate B after A native render

A exposed round isolated boughs, dark hollow rings and detached perimeter cards. B pulls branch sprays inward, broadens overlapping cushions, flattens the full card geometry vertically, reduces outer shell reach and increases fill to 32–50 cards. Radial normals now remain continuous on both sides rather than flipping each backface; vertex and AO contrast reduced. Same tree origins, limbs, camera and light. B needs native validation.

## Candidate C after B native render

B connected the silhouette but became too flat. C re-applies authored world normal in fragment using VIEW_MATRIX, bypassing card winding/two-sided normal handling. Keeps B shape. Stores crown height in UV2.y for broad cool-under/warm-top hue gradient, restores .82–1.10 height value span and moderate atlas modulation .77–1.09. This is a candidate pending native image comparison, not a claimed fix.
