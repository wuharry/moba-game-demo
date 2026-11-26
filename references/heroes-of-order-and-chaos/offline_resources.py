"""Real local consumables and replenishment for the isolated HOC prototype.

This fixed-resource preset uses catalog items, not arbitrary item IDs. Event,
lottery, guild and talent consumables are excluded until their local flows exist.
"""
from offline_native import add_x, constant_w, mov_w, str_w, RESOURCE_CAP
from offline_inventory import assemble, cmp_imm, ldr_w, ldr_x, mov_x, str_b

# Energy is filled directly in UserInfo. Catalog rows 874/875 are internal
# refill/expansion operations without bag icons or complete descriptions.
CONSUMABLES = (141, 146, 151)
ITEMS_PUSH = '_ZNSt6__ndk14listI8UserItemNS_9allocatorIS1_EEE9push_backERKS1_'
TIMERS_RESIZE = '_ZNSt6__ndk16vectorI11TimingEventNS_9allocatorIS1_EEE6resizeEm'


def str_x(src, base, offset=0):
    assert offset % 8 == 0 and 0 <= offset // 8 < 4096
    return 0xf9000000 | ((offset // 8) << 10) | (base << 5) | src


def initialize_consumables(base):
    return assemble([
        0xa9ba7bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5,
        '_Z7GetGamev', '_ZN4Game11GetUserInfoEv', mov_x(19, 0),
        mov_w(8, 0x1bb0), 0x8b080274,  # add x20,x19,x8
        mov_x(0, 20), '_ZNSt6__ndk110__list_impI8UserItemNS_9allocatorIS1_EEE5clearEv',
        ('adr', 21, 'items'), mov_w(22, len(CONSUMABLES)),
        ('label', 'item'),
        add_x(0, 31, 0x30), '_ZN8UserItemC2Ev',
        ldr_w(8, 21), str_w(8, 31, 0x30),
        *constant_w(8, RESOURCE_CAP), str_w(8, 31, 0x50), str_w(31, 31, 0x54),
        mov_x(0, 20), add_x(1, 31, 0x30), ITEMS_PUSH,
        add_x(0, 31, 0x30), '_ZN8UserItemD2Ev',
        add_x(21, 21, 4), 0x510006d6, cmp_imm(22, 0), ('b.ne', 'item'),
        mov_x(0, 19), 'Offline.ReplenishResources',
        0xa9425bf5, 0xa94153f3, 0xa8c67bfd, 0xd65f03c0,
        ('label', 'items'), *CONSUMABLES,
    ], base)


def replenish_resources(base):
    # x0 UserInfo. Caps are this local preset, not claimed official limits.
    # The game's item descriptions define 146/151 as +100% for 24 hours.
    return assemble([
        0xa9bc7bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5, mov_x(19, 0),
        add_x(0, 19, 0x1ec), *constant_w(1, RESOURCE_CAP), '_ZN12ProtectedInt3setEi',
        add_x(0, 19, 0x1f4), *constant_w(1, RESOURCE_CAP), '_ZN12ProtectedInt3setEi',
        *constant_w(8, RESOURCE_CAP), str_w(8, 19, 0x3a0),
        # The menu reads current/capacity directly at 828/82c. The separate
        # getMaxLimitation vector entry governs capacity expansion, not this UI.
        mov_w(8, 999), str_w(8, 19, 0x828), str_w(8, 19, 0x82c),
        add_x(0, 19, 0x828), mov_w(1, 999), '_ZN12EnergyPoints16setMaxLimitationEi',
        mov_w(8, 146), str_w(8, 19, 0x29c),
        mov_w(8, 151), str_w(8, 19, 0x2a0),
        mov_w(8, 100), str_w(8, 19, 0x2a4), str_w(8, 19, 0x2a8),
        mov_w(8, 3), str_w(8, 19, 0x2ac), str_w(8, 19, 0x2b0),
        mov_w(8, 0x1170), 0x8b080260, mov_w(1, 2), TIMERS_RESIZE,
        ldr_x(22, 19, 0x1170), mov_x(0, 31), 'LibC.time', mov_x(20, 0),
        # Give the offline clock the same real-time base used by getServerTime.
        str_x(20, 19, 0x1c40), str_x(20, 19, 0x1c48),
        mov_w(8, 0x1c50), 0x8b080269, mov_w(8, 1), str_b(8, 9),
        *constant_w(8, 86400), 0x8b080295,  # add x21,x20,x8
        mov_w(8, 146), str_w(8, 22), str_w(31, 22, 4),
        str_x(20, 22, 8), str_x(21, 22, 16),
        mov_w(8, 151), str_w(8, 22, 24), str_w(31, 22, 28),
        str_x(20, 22, 32), str_x(21, 22, 40),
        0xa9425bf5, 0xa94153f3, 0xa8c47bfd, 0xd65f03c0,
    ], base)


def use_local_resource(base):
    # Same UserInfo::SendUseItem ABI. Revival is carried into battle; its
    # original catalog flag already prevents use from the profile bag.
    words = [0xa9be7bfd, 0x910003fd, 0xa90153f3, mov_x(19, 2)]
    for item in CONSUMABLES:
        words += [cmp_imm(19, item), ('b.eq', 'use')]
    words += [0x12800000, ('b', 'done'),  # unsupported ID: -1
        ('label', 'use'), 'Offline.ReplenishResources',
        '_ZN9SingletonI12CGameSessionE8instanceEv',
        mov_w(1, 0), mov_w(2, 0), mov_x(3, 19), mov_w(4, 6),
        '_ZN12CGameSession9onUseItemEiiii', mov_w(0, 0),
        ('label', 'done'), 0xa94153f3, 0xa8c27bfd, 0xd65f03c0,
    ]
    return assemble(words, base)
