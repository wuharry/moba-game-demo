"""Read-only forensic architecture analyzer for Heroes of Order & Chaos 3.6.5a (Glitch Engine).

Focuses on the 5 reverse-engineering dimensions requested for mobile MOBA R&D:
  1. 5v5 Map Design (Sinskaald Rift / 辛斯卡德裂口 map_id=7 world/rift.wld + quests_zones_hoc.tbl)
  2. Scene Art & Rendering (143 GLSL shaders: L2 SH lighting, 24 baked lightmap chunks, WarFog, Water/Fluid, Heightfield)
  3. Resource Allocation (GBMP ZIP archives: res.bin, tables.bin, script.bin, menu.bin + 85-file DLC split)
  4. Main Menu UI Design (world/menu.wld 3D backdrop + Scaleform gameswf LGM*.swf + DlgLgmMainMenu*)
  5. Battle HUD UI Design (IGM*.swf + DlgHUD, DlgMiniMap 3D-to-2D projection, DlgNPCShopNew, DlgBattleStatistics)

Strictly read-only: swaps GBMP -> PK\\x03\\x04 only in RAM and writes zero proprietary game assets.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import io
import json
from pathlib import Path
import re
import struct
import zipfile


def open_gbmp_in_memory(path: Path) -> zipfile.ZipFile:
    buf = bytearray(path.read_bytes())
    with zipfile.ZipFile(io.BytesIO(buf), "r") as z0:
        infos = z0.infolist()
    for info in infos:
        if buf[info.header_offset : info.header_offset + 4] == b"GBMP":
            buf[info.header_offset : info.header_offset + 4] = b"PK\x03\x04"
    return zipfile.ZipFile(io.BytesIO(buf), "r")


def decode_ftable(tb: bytes) -> tuple[str, list[tuple[int, list]]]:
    if tb[:6] != b"FTABLE":
        raise ValueError("Not a Glitch FTABLE resource")
    row_count, col_count, idx_off, fmt_off, data_off, row_stride = struct.unpack_from("<6I", tb, 0x0C)
    fmt = tb[fmt_off : fmt_off + col_count].decode("ascii")
    ids = struct.unpack_from(f"<{row_count}I", tb, idx_off)
    str_pool_off = data_off + row_count * row_stride
    rows = []
    for r in range(row_count):
        pos = data_off + r * row_stride
        vals = []
        for ch in fmt:
            if ch in ("u", "i"):
                vals.append(struct.unpack_from("<I" if ch == "u" else "<i", tb, pos)[0])
            elif ch == "f":
                vals.append(round(struct.unpack_from("<f", tb, pos)[0], 4))
            elif ch == "s":
                soff = struct.unpack_from("<I", tb, pos)[0]
                s_abs = str_pool_off + soff if str_pool_off + soff < len(tb) else soff
                end = tb.find(b"\x00", s_abs)
                vals.append(tb[s_abs:end].decode("utf-8", errors="replace"))
            pos += 4
        rows.append((ids[r], vals))
    return fmt, rows


def analyze_hoc(hoc_dir: Path) -> dict:
    orig_assets = hoc_dir / "original" / "assets"
    apk_path = hoc_dir / "original" / "HeroesOfOrderAndChaos-3.6.5a-36523.apk"

    # 1. Archive & DLC budget
    base_files = {
        p.name: round(p.stat().st_size / 1048576, 3)
        for p in sorted((hoc_dir / "original").rglob("*"))
        if p.is_file()
    }
    dlc_list_path = hoc_dir / "trial" / "asset-copy-list.json"
    dlc_summary = {}
    if dlc_list_path.exists():
        dlc_names = json.loads(dlc_list_path.read_text(encoding="utf-8"))
        dlc_summary = {
            "total_dlc_files": len(dlc_names),
            "hero_archives": len([n for n in dlc_names if n.startswith("hero_")]),
            "map_archives": [n for n in dlc_names if n in ("rift.bin", "vault.bin", "3v3_desert.bin", "menu.bin")],
            "core_archives": [n for n in dlc_names if n in ("res.bin", "res_t.bin", "tables.bin", "script.bin", "sounds.bin", "model_phy.bin")],
            "font_files": [n for n in dlc_names if n.startswith("ui/")],
        }

    # 2. res.bin breakdown + 5v5 Rift lightmap / UI / GLSL shaders
    with open_gbmp_in_memory(orig_assets / "res.bin") as zres:
        infos = [i for i in zres.infolist() if not i.is_dir()]
        by_top = defaultdict(lambda: [0, 0])
        by_ext = defaultdict(lambda: [0, 0])
        rift_lightmaps = []
        rift_minimaps = []
        swf_files = []
        glsl_files = []
        scene_themes = defaultdict(lambda: [0, 0])

        for i in infos:
            top = i.filename.split("/")[0] if "/" in i.filename else "<root_shaders_conf>"
            ext = Path(i.filename).suffix.lower() or "<noext>"
            by_top[top][0] += 1
            by_top[top][1] += i.file_size
            by_ext[ext][0] += 1
            by_ext[ext][1] += i.file_size

            if i.filename.startswith("model/scene/"):
                parts = i.filename.split("/")
                theme = parts[2] if len(parts) > 3 else "<root>"
                scene_themes[theme][0] += 1
                scene_themes[theme][1] += i.file_size
            if i.filename.startswith("model/scene/lightmap/rift/"):
                rift_lightmaps.append({"path": i.filename, "bytes": i.file_size})
            if i.filename.startswith("2d_texture/maps/rift"):
                rift_minimaps.append({"path": i.filename, "bytes": i.file_size})
            if ext == ".swf":
                b = zres.read(i)
                swf_files.append(
                    {
                        "path": i.filename,
                        "bytes": i.file_size,
                        "swf_version": b[3] if len(b) > 4 else None,
                    }
                )
            if ext == ".glsl":
                glsl_files.append(i.filename)

    # 3. 5v5 Map tables (map_info_hoc.tbl & quests_zones_hoc.tbl)
    with open_gbmp_in_memory(orig_assets / "tables.bin") as ztbl:
        _, map_rows = decode_ftable(ztbl.read("tables/map_info_hoc.tbl"))
        _, zone_rows = decode_ftable(ztbl.read("tables/quests_zones_hoc.tbl"))

    maps_5v5 = [
        {"id": rid, "fields": vals}
        for rid, vals in map_rows
        if rid in (7, 12)
    ]
    rift_zones = [
        {
            "zone_id": rid,
            "map_id": vals[1],
            "pos_xyz": vals[2:5],
            "extents_rot": vals[6:10],
        }
        for rid, vals in zone_rows
        if vals[1] == 7
    ]

    # 4. UI Dialog classes from symbol inventory if present
    sym_path = hoc_dir / "analysis" / "libAndroid.so.symbols.json"
    top_ui_dialogs = []
    if sym_path.exists():
        syms = json.loads(sym_path.read_text(encoding="utf-8"))
        counts: Counter[str] = Counter()
        for item in syms:
            m = re.match(r"_ZN(\d+)(Dlg[A-Za-z0-9_]+)", item["name"])
            if m:
                cls = m.group(2)[: int(m.group(1))]
                counts[cls] += 1
        top_ui_dialogs = [{"class": k, "methods": v} for k, v in counts.most_common(25)]

    return {
        "game": "Heroes of Order & Chaos 3.6.5a (36523)",
        "engine": "Gameloft Glitch Engine (libAndroid.so + gameswf Scaleform UI + Lua 5.1 AI)",
        "focus_scope": "5v5 Sinskaald Rift (map_id=7) + Glitch Rendering + Resource Allocation + Main Menu & Battle HUD",
        "original_package_mib": base_files,
        "modular_dlc_architecture": dlc_summary,
        "res_bin_summary": {
            "total_files": len(infos),
            "uncompressed_mib": round(sum(i.file_size for i in infos) / 1048576, 2),
            "by_folder": {
                k: {"files": v[0], "mib": round(v[1] / 1048576, 2)}
                for k, v in sorted(by_top.items(), key=lambda x: -x[1][1])
            },
            "by_extension": {
                k: {"files": v[0], "mib": round(v[1] / 1048576, 2)}
                for k, v in sorted(by_ext.items(), key=lambda x: -x[1][1])
            },
            "scene_model_themes": {
                k: {"files": v[0], "mib": round(v[1] / 1048576, 2)}
                for k, v in sorted(scene_themes.items(), key=lambda x: -x[1][1])
            },
        },
        "map_5v5_rift": {
            "map_table_entries_5v5": maps_5v5,
            "rift_zones_table": rift_zones,
            "rift_baked_lightmap_chunks": {
                "count": len(rift_lightmaps),
                "total_mib": round(sum(x["bytes"] for x in rift_lightmaps) / 1048576, 2),
                "samples": rift_lightmaps[:6],
            },
            "rift_minimap_textures": rift_minimaps,
        },
        "shader_summary": {
            "total_glsl_shaders": len(glsl_files),
            "families": {
                "scene_sh_lightmap": [s for s in glsl_files if "CommonScene" in s or "Lightmap" in s],
                "terrain_heightfield": [s for s in glsl_files if "Terrain" in s],
                "water_lava_fluid": [s for s in glsl_files if any(w in s.lower() for w in ("water", "fluid", "lava", "magma"))],
                "warfog": [s for s in glsl_files if "Warfog" in s or "WarFog" in s],
                "hero_character": [s for s in glsl_files if "Hero" in s or "MainCharacter" in s or "Contour" in s],
                "ui_postprocess": [s for s in glsl_files if "GameSWF" in s or "ColorCorrector" in s or "Blur" in s],
            },
        },
        "ui_swf_and_dialogs": {
            "swf_bundles": swf_files,
            "top_dlg_classes": top_ui_dialogs,
        },
        "apk_present": apk_path.exists(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--hoc-dir",
        type=Path,
        default=Path(r"C:\Users\whw88\Downloads\HeroesOfOrderAndChaos-Offline-20261119"),
        help="Path to local HOC workspace containing original/assets",
    )
    parser.add_argument("--json-out", type=Path, help="Optional path to save JSON summary")
    args = parser.parse_args()

    report = analyze_hoc(args.hoc_dir)
    if args.json_out:
        args.json_out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
