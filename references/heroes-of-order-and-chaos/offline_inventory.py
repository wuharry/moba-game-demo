"""Construct real local inventory objects from this APK's own item catalog.

Uses the existing libc++ map/vector constructors. Never replaces pointer-returning
queries with booleans. Addresses and field layouts are specific to 3.6.5a ARM64.
"""
from pathlib import Path
import struct

from offline_native import add_x, adr, constant_w, mov_w, str_w, RESOURCE_CAP

ROOT = Path(__file__).resolve().parent
MAP_GRADE = '_ZNSt6__ndk13mapIiNS0_Ii15InscriptionInfoNS_4lessIiEENS_9allocatorINS_4pairIKiS1_EEEEEES3_NS4_INS5_IS6_S9_EEEEEixERS6_'
MAP_INSCRIPTION = '_ZNSt6__ndk13mapIi15InscriptionInfoNS_4lessIiEENS_9allocatorINS_4pairIKiS1_EEEEEixERS6_'
MAP_SLOT = '_ZNSt6__ndk13mapIi15InscriptionSlotNS_4lessIiEENS_9allocatorINS_4pairIKiS1_EEEEEixERS6_'
MAP_GROUP = '_ZNSt6__ndk13mapIi15TabletSlotGroupNS_4lessIiEENS_9allocatorINS_4pairIKiS1_EEEEEixEOi'
TABLETS_RESIZE = '_ZNSt6__ndk16vectorI10TabletInfoNS_9allocatorIS1_EEE6resizeEm'
SLOTS_RESIZE = '_ZNSt6__ndk16vectorI10TabletSlotNS_9allocatorIS1_EEE6resizeEm'
SLOTS_ASSIGN = '_ZNSt6__ndk16vectorI10TabletSlotNS_9allocatorIS1_EEE6assignIPS1_EENS_9enable_ifIXaasr21__is_forward_iteratorIT_EE5valuesr16is_constructibleIS1_NS_15iterator_traitsIS8_E9referenceEEE5valueEvE4typeES8_S8_'


def item_catalog():
    data = (ROOT / 'analysis/unpacked/tables.bin/tables/item_prototype_hoc.tbl').read_bytes()
    assert data[:8] == b'FTABLE\0\0'
    version, count, fields, index, fmt, start, size, strings, _ = struct.unpack_from('<9I', data, 8)
    assert version == 0x100000 and fields == 45 and size == 184
    format_ = data[fmt:fmt + fields].decode('ascii')
    rows = []
    for row in range(count):
        at = start + row * size
        end = at + size
        values = []
        for kind in format_:
            if kind == 'u':
                value, = struct.unpack_from('<I', data, at)
                at += 4
            elif kind == 's':
                offset, length = struct.unpack_from('<IH', data, at)
                assert strings <= offset and offset + length <= len(data)
                value = data[offset:offset + length].decode('utf-8').rstrip('\0')
                at += 6
            else:
                raise ValueError(kind)
            values.append(value)
        assert at == end
        rows.append(values)
    gold = [row for row in rows if row[2] == 14 and row[3] == 3]
    tablets = [row for row in rows if row[2] == 13]
    assert len(gold) == 22 and len(tablets) == 52
    assert max(row[3] for row in rows if row[2] == 14) == 3
    for row in tablets:
        red = red_slots(row)
        assert 1 <= red <= 3 and (4 - red) * 5 >= (row[36] or 8)
    return gold, tablets


def red_slots(row):
    # ComputeTabletEnergy uses 8 when the catalog requirement is zero
    # (the original Common Tablet).
    return ((row[35] or 8) + 4) // 5


def mov_x(dst, src):
    return 0xaa0003e0 | (src << 16) | dst


def ldr_w(dst, base, offset=0):
    assert offset % 4 == 0
    return 0xb9400000 | ((offset // 4) << 10) | (base << 5) | dst


def ldr_x(dst, base, offset=0):
    assert offset % 8 == 0
    return 0xf9400000 | ((offset // 8) << 10) | (base << 5) | dst


def str_b(src, base, offset=0):
    return 0x39000000 | (offset << 10) | (base << 5) | src


def cmp_imm(reg, value):
    return 0x7100001f | (value << 10) | (reg << 5)


def assemble(words, base):
    labels, pc = {}, 0
    for word in words:
        if isinstance(word, tuple) and word[0] == 'label':
            labels[word[1]] = base + pc
        else:
            pc += 4
    result = []
    for word in words:
        if isinstance(word, tuple):
            kind, *args = word
            if kind == 'label':
                continue
            pc = base + len(result) * 4
            target = labels[args[-1]]
            if kind == 'adr':
                word = adr(args[0], pc, target)
            else:
                delta = (target - pc) // 4
                conditions = {'b.eq': 0, 'b.ne': 1, 'b.hs': 2, 'b.hi': 8, 'b.lt': 11}
                if kind == 'b':
                    word = 0x14000000 | (delta & 0x3ffffff)
                else:
                    word = 0x54000000 | ((delta & 0x7ffff) << 5) | conditions[kind]
        result.append(word)
    return result


def fill_tablet(base):
    # x0: TabletInfo; w1: number of red-energy inscriptions. Four distinct
    # gold inscriptions provide enough red/blue energy for each tablet.
    return assemble([
        0xa9bb7bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5,
        mov_x(19, 0), mov_x(22, 1), mov_w(20, 0),
        ('label', 'slot'),
        str_w(20, 31, 0x30), add_x(0, 19, 8), add_x(1, 31, 0x30), MAP_SLOT,
        mov_w(8, 1), str_b(8, 0), str_w(8, 0, 0x30),
        mov_w(8, 3), str_w(8, 0, 0xc),
        0x6b16029f, ('b.lt', 'red'),  # cmp w20,w22
        0x4b160288, ('adr', 9, 'blue_ids'), ('b', 'load'),
        ('label', 'red'), mov_x(8, 20), ('adr', 9, 'red_ids'),
        ('label', 'load'),
        0xd37ef508, 0x8b080129, ldr_w(8, 9), str_w(8, 0, 8),
        0x11000694, cmp_imm(20, 4), ('b.ne', 'slot'),
        mov_w(8, 2), str_w(8, 19, 0x38),  # awake tablet state
        0xa9425bf5, 0xa94153f3, 0xa8c57bfd, 0xd65f03c0,
        ('label', 'red_ids'), 481, 485, 493,
        ('label', 'blue_ids'), 483, 487, 489,
    ], base)


def initialize_tablets(base, tablets):
    words = [
        0xa9bc7bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5,
        '_Z7GetGamev', '_ZN4Game11GetUserInfoEv', mov_x(19, 0),
        mov_w(8, 0x11e8), 0x8b080260, mov_w(1, len(tablets)), TABLETS_RESIZE,
        ldr_x(20, 19, 0x11e8), ('adr', 21, 'tablets'), mov_w(22, 0),
        ('label', 'tablet'),
        ldr_w(8, 21), str_w(8, 20), ldr_w(1, 21, 4),
        mov_x(0, 20), 'Offline.FillTablet',
        mov_x(0, 20), mov_x(1, 22), 'Offline.LoadInscriptions',
        add_x(20, 20, 0x70), add_x(21, 21, 8), 0x110006d6,
        cmp_imm(22, len(tablets)), ('b.ne', 'tablet'),
        0xa9425bf5, 0xa94153f3, 0xa8c47bfd, 0xd65f03c0,
        ('label', 'tablets'),
    ]
    for row in tablets:
        words += [row[0], red_slots(row)]
    return assemble(words, base)


def initialize_inventory(base, gold):
    return assemble([
        0xa9b97bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5, 0xa90363f7,
        '_Z7GetGamev', '_ZN4Game11GetUserInfoEv', mov_x(19, 0),
        mov_w(8, 999), str_w(8, 19, 0x914), str_w(8, 19, 0x918),
        # EnergyPoints current points; its limit lives in a managed int vector.
        str_w(8, 19, 0x828), add_x(0, 19, 0x828), mov_w(1, 999),
        '_ZN12EnergyPoints16setMaxLimitationEi',
        mov_w(8, 3), str_w(8, 31, 0x40),
        mov_w(8, 0x1200), 0x8b080260, add_x(1, 31, 0x40), MAP_GRADE,
        mov_x(22, 0), ('adr', 20, 'gold'), mov_w(21, 0),
        ('label', 'inscription'),
        ldr_w(8, 20), str_w(8, 31, 0x44), mov_x(0, 22), add_x(1, 31, 0x44), MAP_INSCRIPTION,
        ldr_w(8, 20), str_w(8, 0, 0), mov_w(8, 3), str_w(8, 0, 4),
        *constant_w(8, RESOURCE_CAP), str_w(8, 0, 0x28),
        add_x(20, 20, 4), 0x110006b5, cmp_imm(21, len(gold)), ('b.ne', 'inscription'),
        'Offline.InitializeTablets',
        # Seven UI pages, with real three-slot arrays. Restore each saved
        # selection, defaulting to the first three fully awakened tablets.
        mov_w(20, 1), str_w(20, 19, 0x810),
        ('label', 'group'),
        str_w(20, 31, 0x40), add_x(0, 19, 0x790), add_x(1, 31, 0x40), MAP_GROUP,
        mov_x(24, 0), mov_w(8, 1), str_b(8, 24),
        add_x(0, 24, 0x40), mov_w(1, 3), SLOTS_RESIZE,
        ldr_x(21, 24, 0x40), ldr_x(22, 19, 0x11e8), mov_w(23, 0),
        ('label', 'equipped'),
        mov_x(0, 20), mov_x(1, 23), 'Offline.LoadTabletSelection',
        str_w(0, 31, 0x48), mov_w(8, 0x70), 0x9b085801,  # madd x1,x0,x8,x22
        mov_x(0, 21), '_ZN10TabletInfoaSERKS_', str_w(31, 21, 0x70),
        mov_x(0, 21), ldr_w(1, 31, 0x48), '_ZN10TabletSlot18setIndexIDInPacketEi',
        add_x(21, 21, 0x98), 0x110006f7,
        cmp_imm(23, 3), ('b.ne', 'equipped'),
        0x11000694, cmp_imm(20, 8), ('b.ne', 'group'),
        # Legacy consumers use the selected page's separate slot vector.
        mov_w(8, 1), str_w(8, 31, 0x40), add_x(0, 19, 0x790), add_x(1, 31, 0x40), MAP_GROUP,
        mov_x(24, 0),
        mov_w(8, 0x11d0), 0x8b080260, ldr_x(1, 24, 0x40), ldr_x(2, 24, 0x48), SLOTS_ASSIGN,
        0xa94363f7, 0xa9425bf5, 0xa94153f3, 0xa8c77bfd, 0xd65f03c0,
        ('label', 'gold'), *[row[0] for row in gold],
    ], base)


def text_words(value):
    raw = value.encode('ascii') + b'\0'
    raw += b'\0' * (-len(raw) % 4)
    return list(struct.unpack('<' + 'I' * (len(raw) // 4), raw))


def load_tablet_selection(base):
    # Static LGM config methods use only this clone's local config.
    # Key: page + slot; value: validated catalog index. No account keys used.
    return assemble([
        0xa9b37bfd, 0x910003fd, 0xa90153f3, mov_x(19, 1),
        mov_x(3, 0), mov_x(4, 1), add_x(0, 31, 0x30), mov_w(1, 32),
        ('adr', 2, 'key'), 'LibC.snprintf',
        add_x(0, 31, 0x30), add_x(1, 31, 0x50), '_ZN3LGM14GetLocalConfigEPKcPc',
        cmp_imm(0, 0), ('b.eq', 'default'),
        add_x(0, 31, 0x50), 'LibC.atoi', cmp_imm(0, 52), ('b.hs', 'default'),
        ('b', 'done'), ('label', 'default'), mov_x(0, 19),
        ('label', 'done'), 0xa94153f3, 0xa8cd7bfd, 0xd65f03c0,
        ('label', 'key'), *text_words('offline_tablet_%d_%d'),
    ], base)


def save_tablet_selection(base):
    return assemble([
        0xa9b77bfd, 0x910003fd, 0xa90153f3, mov_x(19, 2),
        mov_x(3, 0), mov_x(4, 1), add_x(0, 31, 0x30), mov_w(1, 32),
        ('adr', 2, 'key'), 'LibC.snprintf',
        add_x(0, 31, 0x50), mov_w(1, 16), ('adr', 2, 'number'), mov_x(3, 19), 'LibC.snprintf',
        add_x(0, 31, 0x30), add_x(1, 31, 0x50), '_ZN3LGM14SetLocalConfigEPKcS1_',
        '_ZN3LGM15SaveLocalConfigEv',
        0xa94153f3, 0xa8c97bfd, 0xd65f03c0,
        ('label', 'key'), *text_words('offline_tablet_%d_%d'),
        ('label', 'number'), *text_words('%d'),
    ], base)


def equip_tablet(base):
    # UserInfo::SendFillTabletSlotRequest(this, unused account string,
    # slot index, inventory index, page 1..7). All mutation remains local.
    return assemble([
        0xa9ba7bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5, 0xa90363f7,
        mov_x(19, 0), mov_x(20, 2), mov_x(21, 3), mov_x(22, 4),
        cmp_imm(20, 3), ('b.hs', 'bad'), cmp_imm(21, 52), ('b.hs', 'bad'),
        0x510006c8, cmp_imm(8, 7), ('b.hs', 'bad'),  # sub w8,w22,#1
        str_w(22, 31, 0x40), add_x(0, 19, 0x790), add_x(1, 31, 0x40), MAP_GROUP,
        mov_x(23, 0), ldr_x(9, 23, 0x40), mov_w(8, 0x98),
        0x9b082698,  # madd x24,x20,x8,x9
        ldr_x(9, 19, 0x11e8), mov_w(8, 0x70), 0x9b0826a1,
        mov_x(0, 24), '_ZN10TabletInfoaSERKS_', str_w(31, 24, 0x70),
        mov_x(0, 24), mov_x(1, 21), '_ZN10TabletSlot18setIndexIDInPacketEi',
        ldr_w(8, 19, 0x810), 0x6b16011f, ('b.ne', 'save'),
        mov_w(8, 0x11d0), 0x8b080260, ldr_x(1, 23, 0x40), ldr_x(2, 23, 0x48), SLOTS_ASSIGN,
        ('label', 'save'),
        mov_x(0, 22), mov_x(1, 20), mov_x(2, 21), 'Offline.SaveTabletSelection',
        '_ZN9SingletonI12CGameSessionE8instanceEv', mov_w(1, 0), mov_w(2, 0),
        '_ZN12CGameSession24onFillTabletSlotResponseEii', mov_w(0, 0), ('b', 'done'),
        ('label', 'bad'), 0x12800020,
        ('label', 'done'),
        0xa94363f7, 0xa9425bf5, 0xa94153f3, 0xa8c67bfd, 0xd65f03c0,
    ], base)
