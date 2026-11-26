"""Local inscription editing using the game's own TabletInfo objects.

Only catalog gold IDs (or empty slots) may be restored. All seven equipped
pages copy the updated inventory object, and the selected legacy page follows.
"""
from offline_native import add_x, mov_w, str_w
from offline_inventory import (MAP_GROUP, MAP_SLOT, SLOTS_ASSIGN, assemble,
                               cmp_imm, ldr_w, ldr_x, mov_x, str_b, text_words)

TABLET_ASSIGN = '_ZN10TabletInfoaSERKS_'


def save_inscriptions(base):
    # x0 TabletInfo, w1 inventory index. The five values are state + four IDs.
    return assemble([
        0xa9b07bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5,
        mov_x(19, 0), mov_x(20, 1), mov_w(21, 0),
        ('label', 'slot'), str_w(21, 31, 0x30),
        add_x(0, 19, 8), add_x(1, 31, 0x30), MAP_SLOT,
        0x39400008, cmp_imm(8, 0), ('b.eq', 'empty'),
        ldr_w(8, 0, 8), ('b', 'value'),
        ('label', 'empty'), mov_w(8, 0),
        ('label', 'value'), add_x(9, 31, 0x34),
        0xb8357928,  # str w8,[x9,x21,lsl #2]
        0x110006b5, cmp_imm(21, 4), ('b.ne', 'slot'),
        add_x(0, 31, 0x50), mov_w(1, 32), ('adr', 2, 'key'), mov_x(3, 20), 'LibC.snprintf',
        add_x(0, 31, 0x80), mov_w(1, 128), ('adr', 2, 'value_format'),
        ldr_w(3, 19, 0x38), ldr_w(4, 31, 0x34), ldr_w(5, 31, 0x38),
        ldr_w(6, 31, 0x3c), ldr_w(7, 31, 0x40), 'LibC.snprintf',
        add_x(0, 31, 0x50), add_x(1, 31, 0x80), '_ZN3LGM14SetLocalConfigEPKcS1_',
        '_ZN3LGM15SaveLocalConfigEv',
        0xa9425bf5, 0xa94153f3, 0xa8d07bfd, 0xd65f03c0,
        ('label', 'key'), *text_words('offline_runes_%d'),
        ('label', 'value_format'), *text_words('%u %u %u %u %u'),
    ], base)


def load_inscriptions(base, gold):
    # x0 freshly filled TabletInfo, w1 index. Invalid/missing saves preserve
    # the fully filled preset; validate the entire save before changing it.
    return assemble([
        0xa9b07bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5,
        mov_x(19, 0), mov_x(3, 1),
        add_x(0, 31, 0x50), mov_w(1, 32), ('adr', 2, 'key'), 'LibC.snprintf',
        add_x(0, 31, 0x50), add_x(1, 31, 0x80), '_ZN3LGM14GetLocalConfigEPKcPc',
        cmp_imm(0, 0), ('b.eq', 'done'),
        add_x(0, 31, 0x80), ('adr', 1, 'value_format'),
        add_x(2, 31, 0x30), add_x(3, 31, 0x34), add_x(4, 31, 0x38),
        add_x(5, 31, 0x3c), add_x(6, 31, 0x40), 'LibC.sscanf',
        cmp_imm(0, 5), ('b.ne', 'done'), ldr_w(8, 31, 0x30),
        cmp_imm(8, 3), ('b.hs', 'done'),
        add_x(20, 31, 0x34), mov_w(21, 0),
        ('label', 'validate'), ldr_w(8, 20), cmp_imm(8, 0), ('b.eq', 'valid'),
        ('adr', 9, 'gold'), mov_w(10, len(gold)),
        ('label', 'lookup'), ldr_w(11, 9), 0x6b0b011f, ('b.eq', 'valid'),
        add_x(9, 9, 4), 0x5100054a, cmp_imm(10, 0), ('b.ne', 'lookup'), ('b', 'done'),
        ('label', 'valid'), add_x(20, 20, 4), 0x110006b5,
        cmp_imm(21, 4), ('b.ne', 'validate'),
        ldr_w(8, 31, 0x30), str_w(8, 19, 0x38),
        add_x(20, 31, 0x34), mov_w(21, 0),
        ('label', 'restore'), str_w(21, 31, 0x48),
        add_x(0, 19, 8), add_x(1, 31, 0x48), MAP_SLOT,
        ldr_w(8, 20), cmp_imm(8, 0), ('b.eq', 'empty'),
        mov_w(9, 1), str_b(9, 0), str_w(9, 0, 0x30),
        str_w(8, 0, 8), mov_w(9, 3), str_w(9, 0, 0xc), ('b', 'next'),
        ('label', 'empty'), '_ZN15InscriptionSlot5resetEv',
        ('label', 'next'), add_x(20, 20, 4), 0x110006b5,
        cmp_imm(21, 4), ('b.ne', 'restore'),
        ('label', 'done'), 0xa9425bf5, 0xa94153f3, 0xa8d07bfd, 0xd65f03c0,
        ('label', 'key'), *text_words('offline_runes_%d'),
        ('label', 'value_format'), *text_words('%u %u %u %u %u'),
        ('label', 'gold'), *[row[0] for row in gold],
    ], base)


def sync_tablet_pages(base):
    # x0 UserInfo, w1 inventory index. The caller already validated the index.
    return assemble([
        0xa9b97bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5, 0xa90363f7,
        mov_x(19, 0), mov_x(20, 1), ldr_x(9, 19, 0x11e8),
        mov_w(8, 0x70), 0x9b082695,  # madd x21,x20,x8,x9
        mov_x(0, 21), mov_x(1, 20), 'Offline.SaveInscriptions',
        mov_w(22, 1),
        ('label', 'page'), str_w(22, 31, 0x40),
        add_x(0, 19, 0x790), add_x(1, 31, 0x40), MAP_GROUP,
        ldr_x(23, 0, 0x40), mov_w(24, 0),
        ('label', 'slot'), mov_x(0, 23), '_ZN10TabletSlot18getIndexIDInPacketEv',
        0x6b14001f, ('b.ne', 'next'),
        mov_x(0, 23), mov_x(1, 21), TABLET_ASSIGN,
        ('label', 'next'), add_x(23, 23, 0x98), 0x11000718,
        cmp_imm(24, 3), ('b.ne', 'slot'),
        0x110006d6, cmp_imm(22, 8), ('b.ne', 'page'),
        ldr_w(8, 19, 0x810), str_w(8, 31, 0x40),
        add_x(0, 19, 0x790), add_x(1, 31, 0x40), MAP_GROUP,
        ldr_x(1, 0, 0x40), ldr_x(2, 0, 0x48),
        mov_w(8, 0x11d0), 0x8b080260, SLOTS_ASSIGN,
        0xa94363f7, 0xa9425bf5, 0xa94153f3, 0xa8c77bfd, 0xd65f03c0,
    ], base)


def set_tablet_awake(base, awake):
    # SendSleepTablet / SendWakeTablet: w3 inventory index, not an item ID.
    callback = '_ZN12CGameSession20onWakeTabletResponseEii' if awake else '_ZN12CGameSession21onSleepTabletResponseEiiii'
    return assemble([
        0xa9be7bfd, 0x910003fd, 0xa90153f3,
        mov_x(19, 0), mov_x(20, 3), cmp_imm(20, 52), ('b.hs', 'bad'),
        ldr_x(9, 19, 0x11e8), mov_w(8, 0x70), 0x9b082689,
        mov_w(8, 2 if awake else 0), str_w(8, 9, 0x38),
        mov_x(0, 19), mov_x(1, 20), 'Offline.SyncTabletPages',
        '_ZN9SingletonI12CGameSessionE8instanceEv',
        mov_w(1, 0), mov_w(2, 0), mov_w(3, 1), mov_x(4, 20), callback,
        mov_w(0, 0), ('b', 'done'), ('label', 'bad'), 0x12800020,
        ('label', 'done'), 0xa94153f3, 0xa8c27bfd, 0xd65f03c0,
    ], base)


def save_edited_tablet(base):
    # UserInfo::SendFillInscriptionSlotRequest. x4 is a real TabletInfo copy;
    # w5 indicates the UI's validated activation choice. w6 is page 1..7.
    return assemble([
        0xa9bd7bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5,
        mov_x(19, 0), mov_x(20, 3), mov_x(21, 4), mov_x(22, 5),
        cmp_imm(20, 52), ('b.hs', 'bad'),
        0x510004c8, cmp_imm(8, 7), ('b.hs', 'bad'),
        cmp_imm(22, 2), ('b.hs', 'bad'),
        ldr_x(9, 19, 0x11e8), mov_w(8, 0x70), 0x9b082680,
        mov_x(1, 21), TABLET_ASSIGN,
        ldr_x(9, 19, 0x11e8), mov_w(8, 0x70), 0x9b082689,
        0x0b1602c8, str_w(8, 9, 0x38),  # w8 = w22 * 2: awake or editable
        mov_x(0, 19), mov_x(1, 20), 'Offline.SyncTabletPages',
        '_ZN9SingletonI12CGameSessionE8instanceEv',
        mov_w(1, 0), mov_w(2, 0), mov_x(3, 22),
        '_ZN12CGameSession29onFillInscriptionSlotResponseEiii',
        mov_w(0, 0), ('b', 'done'), ('label', 'bad'), 0x12800020,
        ('label', 'done'), 0xa9425bf5, 0xa94153f3, 0xa8c37bfd, 0xd65f03c0,
    ], base)
