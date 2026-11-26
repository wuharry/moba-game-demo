"""Local, fully allocated talent pages from the verified 3.6.5a catalog.

TalentGroupInfo owns a vector of 12-byte TalentInfo records. Preserve the
original containers so both the editor and solo match consume the same data.
"""
from pathlib import Path
import struct

from offline_native import add_x, adr, mov_w, str_w
from offline_inventory import assemble, cmp_imm, ldr_w, ldr_x, mov_x, str_b

ROOT = Path(__file__).resolve().parent
MAP_TALENTS = '_ZNSt6__ndk13mapIi15TalentGroupInfoNS_4lessIiEENS_9allocatorINS_4pairIKiS1_EEEEEixEOi'
TALENTS_RESIZE = '_ZNSt6__ndk16vectorI10TalentInfoNS_9allocatorIS1_EEE6resizeEm'


def talent_catalog():
    data = (ROOT / 'analysis/unpacked/tables.bin/tables/talent_hoc.tbl').read_bytes()
    assert data[:8] == b'FTABLE\0\0'
    version, count, fields, _, fmt, start, size, strings, _ = struct.unpack_from('<9I', data, 8)
    assert version == 0x100000 and count == 52 and fields == 13 and size == 54
    assert data[fmt:fmt + fields] == b'usuuuuuuuuuuu'
    rows = []
    for index in range(count):
        at = start + index * size
        talent_id, name_offset, name_length = struct.unpack_from('<IIH', data, at)
        assert strings <= name_offset < name_offset + name_length <= len(data)
        values = struct.unpack_from('<11I', data, at + 10)
        style, layer, position, _, prerequisite, maximum, *spells = values
        assert style < 4 and layer < 5 and position < 3 and 1 <= maximum <= 5
        assert all(spells[:maximum]) and not any(spells[maximum:])
        rows.append({'id': talent_id, 'maximum': maximum, 'style': style,
                     'layer': layer, 'position': position, 'prerequisite': prerequisite,
                     'spell': spells[maximum - 1]})
    assert len({row['id'] for row in rows}) == count
    assert all(row['prerequisite'] == 0 or any(p['id'] == row['prerequisite'] for p in rows) for row in rows)
    # SpellStorage stores IDs in a 16-bit field. Validate the complete preset
    # against the actual spell catalog before emitting a larger local storage.
    spells = (ROOT / 'analysis/unpacked/tables.bin/tables/spell_prototype_hoc.tbl').read_bytes()
    assert spells[:8] == b'FTABLE\0\0'
    _, spell_count, _, _, _, spell_start, spell_size, _, _ = struct.unpack_from('<9I', spells, 8)
    spell_ids = {struct.unpack_from('<I', spells, spell_start + i * spell_size)[0]
                 for i in range(spell_count)}
    assert len({row['spell'] for row in rows}) == count
    assert all(0 < row['spell'] < 65536 and row['spell'] in spell_ids for row in rows)
    return rows


def select_battle_talents(base, data_address, count):
    """Hook contract: x19=Player; return x20=0, x21=IDs, x22=count.

    Both Player::InitSpell and its two ReLearnAllSpell loops save these
    registers. Keep their original Add/Learn/UnLearn calls and slot-state
    checks, including death/respawn behavior. Only the human player's source
    array changes; AI keeps its original 40-slot array. Never read beyond
    Player's embedded array or write beyond allocated SpellStorage capacity.
    """
    words = assemble([
        0xa9bf7bfd, 0x910003fd,
        '_ZN9SingletonI9ObjectMgrE8instanceEv', '_ZN9ObjectMgr7GetHeroEv',
        0xf100001f, ('b.eq', 'original'),  # cmp x0,#0
        '_ZN4Hero9GetPlayerEv',
        0xeb13001f, ('b.ne', 'original'),  # cmp x0,x19
        ldr_x(8, 19, 0xb38), 0xf100011f, ('b.eq', 'original'),
        ldr_w(8, 8, 0x10), cmp_imm(8, count), ('b.lt', 'original'),
        0,  # ADR x21 to the separate, immutable max-rank spell list.
        mov_w(22, count), ('b', 'done'),
        ('label', 'original'), add_x(21, 19, 0x9f8), mov_w(22, 40),
        ('label', 'done'), mov_x(20, 31), 0xa8c17bfd, 0xd65f03c0,
    ], base)
    assert words[15] == 0
    words[15] = adr(21, base + 15 * 4, data_address)
    return words


def show_fixed_talent_page():
    """Keep full talent pages readable; disable the server-only reset button.

    DlgLgmMainMenuUserTalent::Init binds btn_reset to CharacterHandle +0x2a0.
    Its reset callback sends SendResetTalents and waits for a server reply.
    The offline preset is immutable, so expose a disabled button instead.
    """
    return [
        0xa9be7bfd, 0x910003fd, 0xa90153f3, mov_x(19, 0),
        '_ZN24DlgLgmMainMenuUserTalent14ShowTalentPageEv',
        add_x(0, 19, 0x2a0), mov_w(1, 0),
        '_ZN7gameswf15CharacterHandle10setEnabledEb',
        add_x(0, 19, 0x2a0), mov_w(1, 2),
        '_ZN7gameswf15CharacterHandle11gotoAndStopEi',
        0xa94153f3, 0xa8c27bfd, 0xd65f03c0,
    ]


def initialize_talents(base, rows):
    return assemble([
        0xa9bb7bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5,
        '_Z7GetGamev', '_ZN4Game11GetUserInfoEv', mov_x(19, 0), mov_w(20, 1),
        ('label', 'page'),
        str_w(20, 31, 0x30), mov_w(8, 0x10c8), 0x8b080260,
        add_x(1, 31, 0x30), MAP_TALENTS, mov_x(21, 0),
        # No unallocated points: every catalog talent is already at its cap.
        # This flag is isLocked (GetUnlockedTalentPageCount tests it == 0).
        str_w(31, 21), str_b(31, 21, 0x20),
        mov_w(8, 5), str_w(8, 21, 0x24), str_w(8, 21, 0x28),
        str_w(8, 21, 0x2c), str_w(8, 21, 0x30),
        add_x(0, 21, 8), mov_w(1, len(rows)), TALENTS_RESIZE,
        ldr_x(21, 21, 8), ('adr', 22, 'catalog'), mov_w(10, 0),
        ('label', 'talent'),
        0x794002c8,  # ldrh w8,[x22]: catalog talent ID
        0x794006c9,  # ldrh w9,[x22,#2]: exact catalog maximum
        str_w(8, 21), str_w(9, 21, 4), str_w(31, 21, 8),
        add_x(21, 21, 12), add_x(22, 22, 4), 0x1100054a,
        cmp_imm(10, len(rows)), ('b.ne', 'talent'),
        0x11000694, cmp_imm(20, 8), ('b.ne', 'page'),
        0xa9425bf5, 0xa94153f3, 0xa8c57bfd, 0xd65f03c0,
        ('label', 'catalog'),
        *[row['id'] | (row['maximum'] << 16) for row in rows],
    ], base)
