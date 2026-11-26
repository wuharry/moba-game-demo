"""Use the local hero/skin catalog without requesting shop inventory."""
from offline_native import add_x, mov_w, str_w
from offline_inventory import assemble, cmp_imm, mov_x

GOODS_MAKE = '_ZN5boost11make_sharedINSt6__ndk16vectorINS_10shared_ptrI12LgmShopGoodsEENS1_9allocatorIS5_EEEEEENS_6detail15sp_if_not_arrayIT_E4typeEv'
GOODS_ASSIGN = '_ZN5boost10shared_ptrINSt6__ndk16vectorINS0_I12LgmShopGoodsEENS1_9allocatorIS4_EEEEEaSERKS8_'
GOODS_DESTROY = '_ZN5boost10shared_ptrINSt6__ndk16vectorINS0_I12LgmShopGoodsEENS1_9allocatorIS4_EEEEED2Ev'
MODEL_APPEND = '_ZNSt6__ndk16vectorI9modelInfoNS_9allocatorIS1_EEE21__push_back_slow_pathIRKS1_EEvOT_'


def prepare_hero_picker(base):
    # x0: DlgChooseHero. Real empty shop vectors let the original GetHeros
    # enumerate locally owned heroes and skins, preserving filters/previews.
    return assemble([
        0xa9bc7bfd, 0x910003fd, 0xa90153f3, mov_x(19, 0),
        add_x(8, 31, 0x20), GOODS_MAKE,
        mov_w(8, 0x1360), 0x8b080260, add_x(1, 31, 0x20), GOODS_ASSIGN,
        mov_w(8, 0x1378), 0x8b080260, add_x(1, 31, 0x20), GOODS_ASSIGN,
        add_x(0, 31, 0x20), GOODS_DESTROY,
        mov_w(8, 0x1358), mov_w(9, 1), 0x38286a69,
        mov_w(8, 0x1370), 0x38286a69,
        add_x(0, 19, 0x378), mov_w(1, 1), '_ZN7gameswf15CharacterHandle10setVisibleEb',
        add_x(0, 19, 0x3b8), mov_w(1, 0), '_ZN7gameswf15CharacterHandle10setVisibleEb',
        mov_x(0, 19), mov_w(1, 0), '_ZN13DlgChooseHero8GetHerosEi',
        mov_x(0, 19), mov_w(1, 0), '_ZN13DlgChooseHero11select_heroEi',
        0xa94153f3, 0xa8c47bfd, 0xd65f03c0,
    ], base)


def fill_hero_skins(base):
    # x0: freshly constructed UserHero, w1: hero ID. The ownership API uses
    # skin indices 1..6, not the model IDs returned by the creature catalog.
    return assemble([
        0xa9b87bfd, 0x910003fd, 0xa90153f3, 0xa9025bf5,
        mov_x(19, 0), mov_x(20, 1), mov_w(21, 1),
        ('label', 'skin'),
        mov_x(0, 20), mov_x(1, 21), '_ZN15HeroInfoUtility24GetCreatureSkinIdByIndexEji',
        cmp_imm(0, 0), ('b.eq', 'next'),
        add_x(0, 31, 0x40), '_ZN9modelInfoC2Ev',
        str_w(21, 31, 0x40), mov_w(8, 4), str_w(8, 31, 0x68),
        add_x(0, 19, 0x38), add_x(1, 31, 0x40), MODEL_APPEND,
        add_x(0, 31, 0x40), '_ZN9modelInfoD2Ev',
        ('label', 'next'),
        0x110006b5, cmp_imm(21, 7), ('b.ne', 'skin'),
        0xa9425bf5, 0xa94153f3, 0xa8c87bfd, 0xd65f03c0,
    ], base)
