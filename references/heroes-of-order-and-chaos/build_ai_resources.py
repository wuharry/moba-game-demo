"""Build reversible AI-only resources; preserve the localized tables and APK."""
from copy import copy
import hashlib
import io
import json
from pathlib import Path
import zipfile

from localize_resources import open_archive

ROOT = Path(__file__).resolve().parent
COMMON = 'script/AI/Action/Action_AIHero_Common.lua'
PLAYERS = 'script/AI/Player/Temp_AIPlayers.lua'
DECISIONS = 'script/AI/Action/Offline_Hero_Decisions.lua'


def replace_once(data, before, after):
    assert data.count(before) == 1, before
    return data.replace(before, after, 1)


def replacements(archive):
    common = archive.read(COMMON)
    common = replace_once(common, b'function Action_Hero_Common_Update()',
                          b'function Legacy_Hero_Common_Update()')
    common = replace_once(common, b'if GetSelfGuid() ~= 0 then',
                          b'LoadScript("AI/Action/Offline_Hero_Decisions.lua")\n\nif GetSelfGuid() ~= 0 then')
    players = archive.read(PLAYERS)
    players = replace_once(players,
        b'factor = (6-t_factor)*6 + 1.2*(hp_percentage-20) + mob_amount*12 - enemy_amount*1.5',
        b'factor = factor + (6-t_factor)*6 + 1.2*(hp_percentage-20) + mob_amount*12 - enemy_amount*1.5')
    players = replace_once(players,
        b'GetUnitParameters(target) ~= GetUnitParameters(guid)',
        b'GetUnitParameters(target, 4) ~= GetUnitParameters(guid, 4)')
    players = replace_once(players,
        b'GetUnitType(target, 0) <= GetUnitType(guid, 0)',
        b'GetUnitParameters(target, 0) <= GetUnitParameters(guid, 0)')
    players = replace_once(players,
        b'and hp_percentage > 25 and mob_amount >= 3 then',
        b'and hp_percentage >= 50 and mob_amount >= 3 and OfflineHeroAI.CanResume(guid) then')
    return {COMMON: common, PLAYERS: players,
            DECISIONS: (ROOT / 'offline_ai/hero_decisions.lua').read_bytes()}


def main():
    source = (ROOT / 'original/assets/script.bin').read_bytes()
    original_manifest = json.loads((ROOT / 'trial/verified-resource-hashes.json').read_text())
    source_hash = hashlib.sha256(source).hexdigest()
    assert source_hash == original_manifest['script.bin']
    out = ROOT / 'trial/ai-assets'
    out.mkdir(exist_ok=True)
    with open_archive(source) as archive:
        changed = replacements(archive)
        assert DECISIONS not in archive.namelist()
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as target:
            target.comment = archive.comment
            for entry in archive.infolist():
                target.writestr(copy(entry), changed.get(entry.filename, archive.read(entry)))
            entry = zipfile.ZipInfo(DECISIONS, (2026, 11, 20, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            target.writestr(entry, changed[DECISIONS])
        packed = bytearray(buffer.getvalue())
        with zipfile.ZipFile(io.BytesIO(packed)) as verify:
            assert verify.testzip() is None
            assert verify.namelist() == archive.namelist() + [DECISIONS]
            entries = verify.infolist()
            for name in archive.namelist():
                assert verify.read(name) == changed.get(name, archive.read(name)), name
            assert verify.read(DECISIONS) == changed[DECISIONS]
        for entry in entries:
            pos = entry.header_offset
            assert packed[pos:pos+4] == b'PK\x03\x04'
            packed[pos:pos+4] = b'GBMP'
        with open_archive(packed) as verify:
            assert verify.testzip() is None
            for name, data in changed.items():
                assert verify.read(name) == data
                path = ROOT / 'trial/ai-unpacked' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
        count = len(archive.namelist())
    (out / 'script.bin').write_bytes(packed)
    digest = hashlib.sha256(packed).hexdigest()
    manifest = json.loads((ROOT / 'trial/localized-resource-hashes.json').read_text())
    assert manifest['script.bin'] == source_hash
    manifest['script.bin'] = digest
    (ROOT / 'trial/ai-resource-hashes.json').write_text(json.dumps(manifest, indent=2) + '\n')
    report = {'source_sha256': source_hash, 'output_sha256': digest,
              'original_entries': count, 'unchanged_entries': count-2,
              'modified_entries': [COMMON, PLAYERS], 'added_entries': [DECISIONS],
              'apk_changed': False, 'tables_changed': False, 'crc_check': 'PASS',
              'custom_archive_markers': 'PASS', 'scope': 'Both AI factions; tutorial uses legacy update.'}
    (ROOT / 'trial/ai-resource-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
