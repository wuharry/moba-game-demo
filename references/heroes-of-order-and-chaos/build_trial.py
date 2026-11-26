"""Build a separately installed HOC offline feasibility prototype.

Never overwrites the original APK or modifies the installed original app.
The native edits only select local menu flow; this is not a validated release.
"""
from pathlib import Path
import hashlib
import json
import os
import struct
import subprocess
import zipfile

import capstone
import native_probe as native
from dex_probe import Dex
from offline_native import adr, branch, initialize_profile, mov_w
from offline_inventory import (equip_tablet, fill_tablet, initialize_inventory,
                               initialize_tablets, item_catalog,
                               load_tablet_selection, save_tablet_selection)
from offline_resources import (CONSUMABLES, initialize_consumables,
                               replenish_resources, use_local_resource)
from offline_inscriptions import (load_inscriptions, save_edited_tablet,
                                  save_inscriptions, set_tablet_awake,
                                  sync_tablet_pages)
from offline_talents import (initialize_talents, select_battle_talents,
                             show_fixed_talent_page, talent_catalog)
from offline_heroes import fill_hero_skins, prepare_hero_picker
from offline_terrain import sample_heightfield_edge

ROOT = Path(__file__).resolve().parent
ORIGINAL = ROOT / 'original/HeroesOfOrderAndChaos-3.6.5a-36523.apk'
OLD = 'com.gameloft.android.ANMP.GloftHOHM'
NEW = 'com.gameloft.android.ANMP.GloftHOHO'
SDK = Path('E:/06_Apps/Android-SDK/build-tools/36.0.0')
BUILD = ROOT / 'trial'
BUILD.mkdir(exist_ok=True)


def u16(data, off):
    return struct.unpack_from('<H', data, off)[0]


def u32(data, off):
    return struct.unpack_from('<I', data, off)[0]


def patch_manifest(data: bytes) -> bytes:
    """Append new AXML strings and update selected attributes only."""
    chunks = []
    pos = u16(data, 2)
    while pos < len(data):
        size = u32(data, pos + 4)
        assert size >= 8
        chunks.append(bytearray(data[pos:pos + size]))
        pos += size
    pool = next(c for c in chunks if u16(c, 0) == 1)
    header = u16(pool, 2)
    count, style_count, flags, string_start, style_start = struct.unpack_from('<IIIII', pool, 8)
    assert style_count == 0, 'Unexpected styled manifest strings'
    utf8 = bool(flags & 0x100)

    def length_at(buffer, where):
        if utf8:
            value = buffer[where]
            return (((value & 127) << 8) | buffer[where + 1], where + 2) if value & 128 else (value, where + 1)
        value = u16(buffer, where)
        return (((value & 32767) << 16) | u16(buffer, where + 2), where + 4) if value & 32768 else (value, where + 2)

    values = []
    for i in range(count):
        at = string_start + u32(pool, header + i * 4)
        length, at = length_at(pool, at)
        if utf8:
            length, at = length_at(pool, at)
        values.append(bytes(pool[at:at + length * (1 if utf8 else 2)]).decode('utf-8' if utf8 else 'utf-16-le'))

    def add(value):
        if value not in values:
            values.append(value)
        return values.index(value)

    edits = []
    drop_chunks = set()
    for chunk_index, chunk in enumerate(chunks):
        if u16(chunk, 0) != 0x102:
            continue
        tag = values[u32(chunk, 20)]
        attr_start, attr_size, attr_count = struct.unpack_from('<HHH', chunk, 24)
        for i in range(attr_count):
            off = 16 + attr_start + i * attr_size
            name = values[u32(chunk, off + 4)]
            raw = u32(chunk, off + 8)
            typ = chunk[off + 15]
            value = values[u32(chunk, off + 16)] if typ == 3 else None
            replacement = None
            if tag == 'uses-permission' and name == 'name' and value == 'android.permission.INTERNET':
                assert u16(chunks[chunk_index + 1], 0) == 0x103
                assert values[u32(chunks[chunk_index + 1], 20)] == 'uses-permission'
                drop_chunks.update((chunk_index, chunk_index + 1))
                edits.append({'tag': tag, 'removed': value})
            if tag == 'manifest' and name == 'package':
                assert value == OLD
                replacement = NEW
            elif tag == 'application' and name == 'label':
                replacement = 'HOC 離線測試'
            elif name == 'authorities' and value and OLD in value:
                replacement = value.replace(OLD, NEW)
            elif tag in ('permission', 'uses-permission') and name == 'name' and value and value.startswith(OLD + '.'):
                replacement = value.replace(OLD, NEW)
            elif value == 'glshare.permission.ACCESS_SHARED_DATA':
                replacement = NEW + '.permission.ACCESS_SHARED_DATA'
            elif tag == 'application' and name == 'debuggable':
                struct.pack_into('<I', chunk, off + 16, 0xffffffff)
            if replacement is not None:
                idx = add(replacement)
                struct.pack_into('<I', chunk, off + 8, idx)
                chunk[off + 15] = 3
                struct.pack_into('<I', chunk, off + 16, idx)
                edits.append({'tag': tag, 'attribute': name, 'value': replacement})

    def encode_length(value):
        if utf8:
            return bytes([value]) if value < 128 else bytes([0x80 | (value >> 8), value & 255])
        return struct.pack('<H', value) if value < 32768 else struct.pack('<HH', 0x8000 | (value >> 16), value & 65535)

    encoded = bytearray()
    offsets = []
    for value in values:
        offsets.append(len(encoded))
        if utf8:
            raw = value.encode('utf-8')
            encoded += encode_length(len(value.encode('utf-16-le')) // 2) + encode_length(len(raw)) + raw + b'\0'
        else:
            raw = value.encode('utf-16-le')
            encoded += encode_length(len(raw) // 2) + raw + b'\0\0'
    encoded += b'\0' * (-len(encoded) % 4)
    start = header + len(values) * 4
    new_pool = bytearray(pool[:header])
    struct.pack_into('<I', new_pool, 4, start + len(encoded))
    struct.pack_into('<IIIII', new_pool, 8, len(values), 0, flags & ~1, start, 0)
    new_pool += struct.pack('<' + 'I' * len(offsets), *offsets) + encoded
    chunks[chunks.index(pool)] = new_pool
    chunks = [chunk for index, chunk in enumerate(chunks) if index not in drop_chunks]
    result = bytearray(data[:u16(data, 2)]) + b''.join(chunks)
    struct.pack_into('<I', result, 4, len(result))
    (BUILD / 'manifest-edits.json').write_text(json.dumps(edits, ensure_ascii=False, indent=2), encoding='utf-8')
    return bytes(result)


def patch_native() -> bytes:
    data = bytearray(native.DATA)
    symbols = {s['name']: s for s in native.SYMBOLS}
    native.load_relocations()
    for name in ('snprintf', 'atoi', 'time', 'sscanf'):
        va = next(va for va, symbol in native.NAMES.items() if symbol == name + '@plt')
        symbols['LibC.' + name] = {'name': name, 'address': hex(va), 'size': 16}
    symbols['Offline.InitializeProfile'] = {
        'name': 'Offline.InitializeProfile', 'address': '0xe180ac', 'size': 596,
    }
    symbols['Offline.FullLevelText'] = {
        'name': 'Offline.FullLevelText', 'address': '0xe18300', 'size': 8,
    }
    # These spans are reachable only from the new local initializer. Their
    # original splash/multiplayer entry points have been disabled below.
    for name, va, size in (
        ('Offline.FillTablet', 0xe18360, 396),
        ('Offline.InitializeInventory', 0xf9ffc8, 536),
        ('Offline.InitializeTablets', 0xfa030c, 564),
        ('Offline.LoadTabletSelection', 0xfa0540, 408),
        ('Offline.SaveTabletSelection', 0xe18a80, 468),
        ('Offline.InitializeConsumables', 0xfa0aa0, 224),
        ('Offline.ReplenishResources', 0xfa0b80, 448),
        ('Offline.MultiplayerLabel', 0xfa0d40, 8),
        ('Offline.SaveInscriptions', 0xe185c0, 432),
        ('Offline.LoadInscriptions', 0xc8e120, 768),
        ('Offline.SyncTabletPages', 0xfa01e0, 296),
        ('Offline.InitializeTalents', 0xdb700c, 388),
        ('Offline.FillHeroSkins', 0xdb7190, 204),
        ('Offline.PrepareHeroPicker', 0xc897d8, 416),
        # Unused tails of disabled StartTeam/StartCoop, after existing helpers.
        ('Offline.SelectBattleTalents', 0xfa0df8, 200),
        ('Offline.BattleTalentSpells', 0xfa05c0, 208),
        # Unused tail of the disabled freemium callback, after LoadInscriptions.
        ('Offline.SampleHeightfieldEdge', 0xc8e2c4, 360),
        ('Offline.ShowFixedTalentPage', 0xfa0e54, 108),
    ):
        symbols[name] = {'name': name, 'address': hex(va), 'size': size}
    patches = []

    def apply(name, instructions):
        symbol = symbols[name]
        va = int(symbol['address'], 16)
        code = bytearray()
        for instruction in instructions:
            if isinstance(instruction, str):
                dest = int(symbols[instruction]['address'], 16)
                delta = dest - (va + len(code))
                assert delta % 4 == 0 and -(1 << 27) <= delta < (1 << 27)
                word = 0x94000000 | ((delta >> 2) & 0x3ffffff)
            else:
                word = instruction
            code += struct.pack('<I', word)
        assert len(code) <= symbol['size']
        at = native.offset(va)
        old = bytes(data[at:at + len(code)])
        data[at:at + len(code)] = code
        patches.append({'symbol': name, 'address': hex(va), 'before': old.hex(), 'after': code.hex()})
        dis = capstone.Cs(capstone.CS_ARCH_ARM64, capstone.CS_MODE_LITTLE_ENDIAN)
        (BUILD / (name + '.asm.txt')).write_text('\n'.join(hex(i.address) + ': ' + i.mnemonic + ' ' + i.op_str for i in dis.disasm(code, va)))

    def edit_word(label, va, expected, word):
        at = native.offset(va)
        old = struct.unpack_from('<I', data, at)[0]
        assert old == expected, (label, hex(old), hex(expected))
        struct.pack_into('<I', data, at, word)
        patches.append({'symbol': label, 'address': hex(va),
                        'before': struct.pack('<I', old).hex(),
                        'after': struct.pack('<I', word).hex()})

    # On splash opening, close its animated screen. Its normal close callback
    # invokes EnterGame. The server-selection countdown must remain inactive.
    apply('_ZN9DlgSplash18OnOpenAnimEndEventEv', [
        0xA9BF7BFD, 0x910003FD, 0x52800001,
        '_ZN9DlgSplash5CloseEi', 0xA8C17BFD, 0xD65F03C0,
    ])
    apply('_ZN9DlgSplash6UpdateEi', [0xD65F03C0])
    apply('Offline.InitializeProfile', initialize_profile())
    apply('Offline.SampleHeightfieldEdge', sample_heightfield_edge(0xc8e2c4))
    edit_word('Bound heightfield edge interpolation', 0xe523d4, 0x1e202148,
              branch(0xe523d4, 0xc8e2c4))
    gold, tablets = item_catalog()
    apply('Offline.FillTablet', fill_tablet(0xe18360))
    apply('Offline.InitializeInventory', initialize_inventory(0xf9ffc8, gold))
    apply('Offline.InitializeTablets', initialize_tablets(0xfa030c, tablets))
    apply('Offline.LoadTabletSelection', load_tablet_selection(0xfa0540))
    apply('Offline.SaveTabletSelection', save_tablet_selection(0xe18a80))
    apply('Offline.InitializeConsumables', initialize_consumables(0xfa0aa0))
    apply('Offline.ReplenishResources', replenish_resources(0xfa0b80))
    apply('Offline.SaveInscriptions', save_inscriptions(0xe185c0))
    apply('Offline.LoadInscriptions', load_inscriptions(0xc8e120, gold))
    apply('Offline.SyncTabletPages', sync_tablet_pages(0xfa01e0))
    talents = talent_catalog()
    apply('_ZN24DlgLgmMainMenuUserTalent13OnClickUnlockEv', [0xd65f03c0])
    apply('Offline.InitializeTalents', initialize_talents(0xdb700c, talents))
    apply('Offline.SelectBattleTalents', select_battle_talents(0xfa0df8, 0xfa05c0, len(talents)))
    apply('Offline.BattleTalentSpells', [row['spell'] for row in talents])
    apply('Offline.ShowFixedTalentPage', show_fixed_talent_page())
    edit_word('Fixed full-talent preset disables server reset', 0xdb5d58,
              branch(0xdb5d58, 0xa2cb00, link=True),
              branch(0xdb5d58, 0xfa0e54, link=True))
    edit_word('Talent storage fits the complete local preset', 0xb8c978,
              mov_w(2, 40), mov_w(2, len(talents)))
    # Player's inline IDs remain 40 words. Only the local player reads the
    # separate 52-word list, and both relearn phases use the same source/count.
    for start, compare in ((0xb8c9f0, 0xb8ca20), (0xb8d4e4, 0xb8d520),
                           (0xb8d5b8, 0xb8d5f4)):
        edit_word('Select real battle talents', start, 0xaa1f03f4,
                  branch(start, 0xfa0df8, link=True))
        edit_word('Use selected battle talent array', start + 4, 0x9127e275, 0xd503201f)
        edit_word('Use selected battle talent count', compare, 0xf100a29f, 0xeb16029f)
    apply('Offline.FillHeroSkins', fill_hero_skins(0xdb7190))
    apply('_ZN13DlgChooseHero30on_event_done_get_item_requestE13SIMFilterTypeN5boost10shared_ptrINSt6__ndk16vectorINS2_I12LgmShopGoodsEENS3_9allocatorIS6_EEEEEE25ShopItemManagerReturnCodeNS2_I15ShopItemManagerEE', [0xd65f03c0])
    apply('Offline.PrepareHeroPicker', prepare_hero_picker(0xc897d8))
    (BUILD / 'local-talents.json').write_text(json.dumps({
        'pages': 7, 'talents_per_page': len(talents),
        'allocated_points_per_page': sum(row['maximum'] for row in talents),
        'talents': talents,
    }, indent=2), encoding='utf-8')
    apply('_ZN8UserInfo22SendSleepTabletRequestERKNSt6__ndk112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEEiiii',
          set_tablet_awake(0xb1ec34, False))
    apply('_ZN8UserInfo21SendWakeTabletRequestERKNSt6__ndk112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEEiii',
          set_tablet_awake(0xb1ea60, True))
    apply('_ZN8UserInfo30SendFillInscriptionSlotRequestERKNSt6__ndk112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEEii10TabletInfoii',
          save_edited_tablet(0xb1ee28))
    apply('_ZN8UserInfo11SendUseItemENSt6__ndk112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEEii',
          use_local_resource(0xb16df4))
    apply('_ZN8UserInfo25SendFillTabletSlotRequestERKNSt6__ndk112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEEiii',
          equip_tablet(0xb1e6a4))
    (BUILD / 'local-inventory.json').write_text(json.dumps({
        'gold_inscriptions': [{'id': row[0], 'name': row[33]} for row in gold],
        'tablets': [{'id': row[0], 'name': row[33], 'red_energy': row[35], 'blue_energy': row[36]} for row in tablets],
        'pages': 7, 'slots_per_page': 3, 'gold_per_tablet': 4,
        'consumables': list(CONSUMABLES),
    }, ensure_ascii=False, indent=2), encoding='utf-8')
    # Keep the actual full XP bar; show a short label inside its fixed-width UI.
    apply('Offline.FullLevelText', [
        adr(1, 0xe18300, 0xe18340), branch(0xe18304, 0xa14c20),
    ])
    full_level_text = '已滿級'.encode('utf-8') + b'\0'
    at = native.offset(0xe18340)
    old = bytes(data[at:at + len(full_level_text)])
    data[at:at + len(full_level_text)] = full_level_text
    patches.append({'symbol': 'Offline.FullLevelLabel', 'address': '0xe18340',
                    'before': old.hex(), 'after': full_level_text.hex()})
    edit_word('Freemium XP label', 0xc8ce7c,
              branch(0xc8ce7c, 0xa14c20, link=True),
              branch(0xc8ce7c, 0xe18300, link=True))
    # Offline play has no voice chat; do not launch the original package's
    # microphone-permission Activity from the separately installed prototype.
    apply('_ZN4Game26PermissionMicrophoneRunnerEPv', [0xaa1f03e0, 0xd65f03c0])
    for name in (
        '_ZN21DlgLgmMainMenuPlayNew9StartRankEv',
        '_ZN21DlgLgmMainMenuPlayNew9StartCoopEv',
        '_ZN21DlgLgmMainMenuPlayNew11StartCustomEv',
        '_ZN21DlgLgmMainMenuPlayNew12StartFunModeEv',
        '_ZN21DlgLgmMainMenuPlayNew9StartTeamENSt6__ndk112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEE13GameModeParam12GamePlayModeb',
    ):
        apply(name, [0xd65f03c0])
    # Display the existing local menu without changing server authentication.
    # id 5 is main menu; id 0 is the shop tutorial.
    edit_word('MainMenu.Show local visibility', 0xca805c, 0x370000a8, 0x14000005)
    # Initialize the local profile subpage before routing clicks to it.
    edit_word('User.Show local visibility', 0xd94000, 0x36000768, 0xd503201f)
    edit_word('Talent.Show uses local pages', 0xdb5d44, 0x36000288, 0xd503201f)
    edit_word('Talent match setup uses local pages', 0xdb59c0, 0x36000668, 0xd503201f)
    edit_word('Current room talent selector uses local pages', 0x102fc60, 0x360006e8, 0xd503201f)
    edit_word('Hero picker skips shop wait and requests', 0xc89334,
              mov_w(0, 0x353), branch(0xc89334, 0xc89384))
    edit_word('Hero picker passes the local dialog', 0xc89384, 0x9102c3e8, 0xaa1303e0)
    edit_word('Hero picker prepares local catalog', 0xc89388,
              branch(0xc89388, 0xa18a40, link=True), branch(0xc89388, 0xc897d8, link=True))
    edit_word('Hero picker resumes normal display', 0xc8938c, 0x9102c3e0,
              branch(0xc8938c, 0xc894b0))
    edit_word('Tablet.Show uses local inventory', 0x103e1c8,
              branch(0x103e1c8, 0xa56f20, link=True), 0x52800020)
    edit_word('Tablet equip uses local selection', 0x104678c, 0x54000701, 0xd503201f)
    edit_word('Tablet equip does not wait for server', 0x10467d4,
              mov_w(0, 0x353), branch(0x10467d4, 0x1046068))
    # The practice room has its own picker. Its local equip handler saves the
    # slot and notifies the visible picker synchronously. Return after it runs.
    edit_word('Practice room equips via the local inventory', 0x1003278,
              branch(0x1003278, 0xa385d0, link=True), branch(0x1003278, 0x1003288))
    edit_word('Practice room returns after local equip', 0x10032c4,
              mov_w(0, 0x353), branch(0x10032c4, 0x1003358))
    edit_word('Inscription unlock uses local data', 0x1048568, 0x54000421, 0xd503201f)
    edit_word('Inscription unlock does not wait for server', 0x10485b0,
              mov_w(0, 0x353), branch(0x10485b0, 0x10485d0))
    edit_word('Inscription save uses local data', 0x104f8b8, 0x540006e1, 0xd503201f)
    edit_word('Inscription save does not wait for server', 0x104fa4c,
              mov_w(0, 0x353), branch(0x104fa4c, 0x104fa6c))
    edit_word('Local resource use does not wait for server', 0xdabdc8,
              branch(0xdabdc8, 0xdabdfc), branch(0xdabdc8, 0xdabe1c))
    # This bag is a fixed, replenished resource preset: discarding is disabled.
    edit_word('Resource preset cannot be discarded', 0xdac820, 0x320003e1, mov_w(1, 0))
    edit_word('Resource discard disabled appearance', 0xdac82c, 0x2a1f03e1, mov_w(1, 2))
    edit_word('Freemium.refresh_money local resources', 0xc8d204, 0x36000ea0, 0xd503201f)
    # Raising the local account level must not enable multiplayer controls.
    # Frame 2 is the existing locked appearance. Practice remains enabled.
    for va in (0xfa2814, 0xfa2830, 0xfa284c, 0xfa2884):
        edit_word('Multiplayer button locked appearance', va, 0x2a1f03e1, 0x52800041)
    for va in (0xfa2820, 0xfa283c, 0xfa2858, 0xfa2890):
        edit_word('Multiplayer button disabled', va, 0x320003e1, 0x2a1f03e1)
    # Reuse the original text controls, with an accurate local-mode explanation.
    apply('Offline.MultiplayerLabel', [
        adr(1, 0xfa0d40, 0xfa0d50), branch(0xfa0d44, 0xa14c20),
    ])
    label = '離線版已停用'.encode('utf-8') + b'\0'
    at = native.offset(0xfa0d50)
    old = bytes(data[at:at + len(label)])
    data[at:at + len(label)] = label
    patches.append({'symbol': 'Offline.MultiplayerLabelText', 'address': '0xfa0d50',
                    'before': old.hex(), 'after': label.hex()})
    for pc, dest in ((0xfa289c, 0xfa28d8), (0xfa2930, 0xfa296c)):
        edit_word('Bypass online unlock condition and format', pc,
                  branch(pc, 0xa550b0, link=True), branch(pc, dest))
    for pc in (0xfa2904, 0xfa2998):
        edit_word('Explain offline multiplayer lock', pc,
                  branch(pc, 0xa14c20, link=True), branch(pc, 0xfa0d40, link=True))
    # No cash store, external login, or purchase entry points in local mode.
    apply('_ZN11DlgFreemium9onClickedEPcN7gameswf15CharacterHandleEiRKNS1_8RenderFX6CursorE', [0xd65f03c0])
    apply('_ZN3LGM25SetDlgLoginAccountVisibleEv', [
        0xa9bf7bfd, 0x910003fd,
        '_ZN3LGM21SetDlgMainMenuVisibleEv', 0xa8c17bfd, 0xd65f03c0,
    ])
    # Enter the existing main-menu dialog directly (id 5), without credentials.
    # Preserve the splash-over flag needed by other menu update paths.
    apply('_ZN9DlgSplash9EnterGameEv', [
        0xA9BF7BFD, 0x910003FD,
        # Re-encode ADRP to the actual GOT page for g_slpashIsOver below.
        0xD503201F, 0xF940D108, 0x52800029, 0x39000109,
        'Offline.InitializeProfile', 'Offline.InitializeInventory', 'Offline.InitializeConsumables',
        'Offline.InitializeTalents',
        '_Z7GetGamev', '_ZN4Game6GetLGMEv',
        0x528000a1, 0x52800022,
        '_ZN3LGM13SetDlgVisibleENS_8DLG_TYPEEb',
        0xA8C17BFD, 0xD65F03C0,
    ])
    last = patches[-1]
    pc = int(last['address'], 16) + 8
    delta = (0x23e2000 - (pc & ~0xfff)) >> 12
    adrp = 0x90000008 | ((delta & 3) << 29) | (((delta >> 2) & 0x7ffff) << 5)
    at = native.offset(pc)
    struct.pack_into('<I', data, at, adrp)
    last['after'] = bytes(data[native.offset(int(last['address'], 16)):native.offset(int(last['address'], 16)) + len(bytes.fromhex(last['after']))]).hex()
    spans = sorted((int(p['address'], 16), int(p['address'], 16) + len(bytes.fromhex(p['after'])), p['symbol']) for p in patches)
    for left, right in zip(spans, spans[1:]):
        assert left[1] <= right[0], ('Overlapping native edits', left, right)
    (BUILD / 'native-patches.json').write_text(json.dumps(patches, indent=2))
    return bytes(data)


def patch_resources(data: bytes) -> bytes:
    result = bytearray(data)
    off = u16(data, 2)
    edited = 0
    while off < len(data):
        kind, _, size = struct.unpack_from('<HHI', data, off)
        if kind == 0x200:
            raw = data[off + 12:off + 268].decode('utf-16-le').split('\0', 1)[0]
            assert raw == OLD, raw
            encoded = NEW.encode('utf-16-le')
            result[off + 12:off + 268] = encoded + b'\0' * (256 - len(encoded))
            edited += 1
        off += size
    assert edited == 1
    return bytes(result)


def run(args):
    subprocess.run([str(x) for x in args], check=True)


def main():
    assert hashlib.sha256(ORIGINAL.read_bytes()).hexdigest() == '5d6299f60f09f5e34e9bd4fb5301a74b4b4b9c81c6ce458fe71930c2b8c1d40b'
    unsigned = BUILD / 'hoc-offline-trial-unsigned.apk'
    with zipfile.ZipFile(ORIGINAL) as src, zipfile.ZipFile(unsigned, 'w') as dst:
        for info in src.infolist():
            if info.filename.startswith('META-INF/'):
                continue
            content = src.read(info)
            if info.filename == 'AndroidManifest.xml':
                content = patch_manifest(content)
            elif info.filename == 'classes.dex':
                content = Dex(content).patch_installer_class_name(OLD)
                content = Dex(content).patch_preverified_resources(OLD)
            elif info.filename == 'resources.arsc':
                content = patch_resources(content)
            elif info.filename == 'lib/arm64-v8a/libAndroid.so':
                content = patch_native()
            dst.writestr(info, content)
    aligned = BUILD / 'hoc-offline-trial-aligned.apk'
    run([SDK / 'zipalign.exe', '-f', '-p', '4', unsigned, aligned])
    key = BUILD / 'local-test-signing.p12'
    # A new disposable local testing key, never reads existing signing secrets.
    if not key.exists():
        run(['C:/Program Files/Java/jdk-21/bin/keytool.exe', '-genkeypair', '-keystore', key,
             '-storetype', 'PKCS12', '-storepass', 'local-test-only', '-keypass', 'local-test-only',
             '-alias', 'hoc-offline-test', '-dname', 'CN=Local HOC Offline Test',
             '-keyalg', 'RSA', '-keysize', '2048', '-validity', '3650'])
    signed = BUILD / 'HOC-Offline-Prototype.apk'
    run(['C:/Program Files/Java/jdk-21/bin/java.exe', '-jar', SDK / 'lib/apksigner.jar', 'sign',
         '--ks', key, '--ks-pass', 'pass:local-test-only', '--out', signed, aligned])
    run(['C:/Program Files/Java/jdk-21/bin/java.exe', '-jar', SDK / 'lib/apksigner.jar', 'verify', signed])
    print('Signed experimental clone:', signed)


if __name__ == '__main__':
    main()
