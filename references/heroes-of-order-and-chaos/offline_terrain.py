"""Bounded edge sampling for HOC 3.6.5a's ARM64 heightfield fast path.

The stock function accepts floor(z)==height, then fetches row height+1
for interpolation. Border Skirmish reproducibly faults at 0xe5240c in
both the pre-talent and full-talent APKs. Keep interior interpolation,
normal-output sampling, and water-info processing in the original code.
"""
from offline_inventory import assemble
from offline_native import branch


def sample_heightfield_edge(base):
    """Tail hook at e523d4; no stack changes, calls, or callee-saved writes.

    x8 packs maximum x/z vertex indices; w10 is maximum z; x9 is the
    height array; w23/w22 are floor(x/z); s10/s9 are their fractions.
    s8 already contains the game's out-of-range sentinel. Preserve the
    integer coordinates for the original water-info lookup.
    """
    instructions = [
        0x1e220102,  # scvtf s2,w8
        0x1e222000,  # fcmp s0,s2
        ('b.hi', 'outside'),  # Also rejects unordered (NaN) coordinates.
        0x1e220142,  # scvtf s2,w10
        0x1e222020,  # fcmp s1,s2
        ('b.hi', 'outside'),
        0x6b0802ff, ('b.eq', 'x_edge'),  # cmp w23,w8
        0x6b0a02df, ('b.eq', 'z_edge'),  # cmp w22,w10
        0x1e202148,  # Original fcmp s10,#0; its flags feed cset at e523e0.
        ('jump', 0xe523d8),
        ('label', 'x_edge'),
        0x1100050b,  # add w11,w8,#1: vertex row stride
        0x1b165d6c,  # madd w12,w11,w22,w23: current vertex index
        0xbc6cd928,  # ldr s8,[x9,w12,sxtw #2]
        0x6b0a02df, ('b.eq', 'water'),  # Corner needs no neighbor.
        0x0b0b018c,  # add w12,w12,w11: next row, same final column
        0xbc6cd920,  # ldr s0,[x9,w12,sxtw #2]
        0x1e283800,  # fsub s0,s0,s8
        0x1f092008,  # fmadd s8,s0,s9,s8: interpolate along z only
        ('b', 'water'),
        ('label', 'z_edge'),
        0x1100050b, 0x1b165d6c, 0xbc6cd928,
        0x1100058c,  # add w12,w12,#1: next column in the final row
        0xbc6cd920, 0x1e283800,
        0x1f0a2008,  # fmadd s8,s0,s10,s8: interpolate along x only
        ('label', 'water'), ('jump', 0xe5262c),
        ('label', 'outside'), ('jump', 0xe5282c),
    ]
    pc = base
    resolved = []
    for instruction in instructions:
        if isinstance(instruction, tuple) and instruction[0] == 'jump':
            instruction = branch(pc, instruction[1])
        resolved.append(instruction)
        if not (isinstance(instruction, tuple) and instruction[0] == 'label'):
            pc += 4
    return assemble(resolved, base)
