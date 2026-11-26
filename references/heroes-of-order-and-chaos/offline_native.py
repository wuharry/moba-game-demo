"""ARM64 initialization of a separate, local-only HOC profile.

All offsets below are from disassembly of the backed-up 3.6.5a library.
No authentication flag or online account data is modified.
"""
import struct

RESOURCE_CAP = 999_999_999
ACCOUNT_LEVEL = 40
EXPERIENCE_FULL = 100_000


def branch(pc, target, link=False):
    delta = target - pc
    assert delta % 4 == 0 and -(1 << 27) <= delta < (1 << 27)
    return (0x94000000 if link else 0x14000000) | ((delta >> 2) & 0x3ffffff)


def adr(reg, pc, target):
    delta = target - pc
    assert -(1 << 20) <= delta < (1 << 20)
    return 0x10000000 | ((delta & 3) << 29) | (((delta >> 2) & 0x7ffff) << 5) | reg


def constant_w(reg, value):
    assert 0 <= value <= 0x7fffffff
    return [mov_w(reg, value & 65535), 0x72a00000 | ((value >> 16) << 5) | reg]


def mov_w(reg, value):
    assert 0 <= value <= 65535
    return 0x52800000 | (value << 5) | reg


def add_x(dst, src, value):
    assert 0 <= value < 4096
    return 0x91000000 | (value << 10) | (src << 5) | dst


def str_w(src, base, offset=0):
    assert offset % 4 == 0 and 0 <= offset // 4 < 4096
    return 0xb9000000 | ((offset // 4) << 10) | (base << 5) | src


def str_h(src, base, offset):
    assert offset % 2 == 0 and 0 <= offset // 2 < 4096
    return 0x79000000 | ((offset // 2) << 10) | (base << 5) | src


def initialize_profile():
    words = [
        0xa9b77bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5,
        '_Z7GetGamev', '_ZN4Game11GetUserInfoEv', 0xaa0003f3,
        # Permit only the three solo maps. Other server mode masks stay zero.
        mov_w(8, 7), str_h(8, 19, 0x11a),
        # UserInfo::setUserInfo establishes these scalar/ProtectedInt fields.
        mov_w(8, ACCOUNT_LEVEL), str_w(8, 19, 0x1e4),
        *constant_w(8, EXPERIENCE_FULL), str_w(8, 19, 0x1e8), str_w(8, 19, 0x300),
        add_x(0, 19, 0x1ec), *constant_w(1, RESOURCE_CAP), '_ZN12ProtectedInt3setEi',
        add_x(0, 19, 0x1f4), *constant_w(1, RESOURCE_CAP), '_ZN12ProtectedInt3setEi',
        *constant_w(8, RESOURCE_CAP), str_w(8, 19, 0x3a0),
        # The list owns real UserHero objects; do not fabricate pointer results.
        0xf94dee68,  # ldr x8,[x19,#0x1bd8]: owned-hero list length
        ('cbnz', 8, 'done'),
        '_ZN15HeroInfoUtility14GetAllHeroesIdEv',
        '_ZN15HeroInfoUtility12GetHeroCountEv',
        0x2a0003f5, 0x2a1f03f4,
        ('label', 'loop'),
        0x6b15029f, ('b.ge', 'done'),
        0x2a1403e0, '_ZN15HeroInfoUtility9GetHeroIDEi', 0x2a0003f6,
        add_x(0, 31, 0x30), '_ZN8UserHeroC2Ev',
        str_w(22, 31, 0x30), mov_w(8, 4), str_w(8, 31, 0x60),
        add_x(0, 31, 0x30), 0x2a1603e1, 'Offline.FillHeroSkins',
        mov_w(8, 0x1bc8), 0x8b080260, add_x(1, 31, 0x30),
        '_ZNSt6__ndk14listI8UserHeroNS_9allocatorIS1_EEE9push_backERKS1_',
        add_x(0, 31, 0x30), '_ZN8UserHeroD2Ev',
        0x11000694, ('b', 'loop'),
        ('label', 'done'),
        0xa9425bf5, 0xa94153f3, 0xa8c97bfd, 0xd65f03c0,
    ]
    labels, pc = {}, 0
    for word in words:
        if isinstance(word, tuple) and word[0] == 'label':
            labels[word[1]] = pc
        else:
            pc += 4
    result = []
    for word in words:
        if isinstance(word, tuple):
            kind, *args = word
            if kind == 'label':
                continue
            delta = (labels[args[-1]] - len(result) * 4) // 4
            if kind == 'b':
                word = 0x14000000 | (delta & 0x3ffffff)
            elif kind == 'b.ge':
                word = 0x5400000a | ((delta & 0x7ffff) << 5)
            elif kind == 'cbnz':
                word = 0xb5000000 | ((delta & 0x7ffff) << 5) | args[0]
            else:
                raise ValueError(kind)
        result.append(word)
    return result
