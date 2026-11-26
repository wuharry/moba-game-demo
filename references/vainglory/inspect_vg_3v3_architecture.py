"""Read-only forensic architecture analyzer for Vainglory 4.13.4 (E.V.I.L. Engine).

Focuses on the 5 reverse-engineering dimensions requested for mobile MOBA R&D:
  1. 3v3 Map Design (Halcyon Fold / 海希安峽谷: CFF0 level/visuals + 200x80m lightprobe grid)
  2. Scene Art & Rendering (RSC0 GLSL ES shaders: CloudShadows, FogOfWar, Shadowing, SH probes)
  3. Resource Allocation (48,443 OBB entries + APK native/asset split by binary magic)
  4. Main Menu UI Design (KindredMenu* CFF0 nodes, MenuMeshCamera, composite .font routing)
  5. Battle HUD UI Design (KindredHUD*, MinimapIconActor_*, Shop/QuickBuy, Tap vs Joystick)

Strictly read-only: never unpacks or writes proprietary game payloads to disk.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path
import re
import struct
import zipfile


def classify_obb(obb_path: Path) -> dict:
    categories: dict[str, list[int]] = defaultdict(lambda: [0, 0, 0])
    shader_features: dict[str, int] = defaultdict(int)
    shader_samples: dict[str, dict] = {}
    hf_3v3_nodes: list[dict] = []
    ui_nodes: list[dict] = []
    hf_grid_meta: dict = {}

    with zipfile.ZipFile(obb_path, "r") as archive:
        infos = archive.infolist()
        for info in infos:
            with archive.open(info) as handle:
                hdr = handle.read(64)
            m4 = hdr[:4]
            u0 = struct.unpack_from("<I", hdr, 0)[0] if len(hdr) >= 4 else -1

            if m4 == b"RSC0":
                cat = "RSC0 (Compiled Mesh/Shader/Anim/FX)"
                if 300 < info.file_size < 32_768:
                    raw = archive.read(info)
                    if b"gl_Position" in raw or b"gl_FragColor" in raw:
                        cat = "RSC0:GLSL_Shader"
                        for feat in (
                            b"CloudShadows",
                            b"FogOfWar",
                            b"Shadowing.mMap",
                            b"MenuMesh",
                            b"_Bones[",
                            b"World.Time",
                        ):
                            if feat in raw:
                                key = feat.decode("ascii")
                                shader_features[key] += 1
                                if key not in shader_samples:
                                    bindings = [
                                        m.group().decode("ascii")
                                        for m in re.finditer(rb"[A-Za-z][A-Za-z0-9_.]{5,48}", raw[:768])
                                    ][:12]
                                    decls = [
                                        ln.strip()
                                        for ln in raw.decode("ascii", errors="ignore").splitlines()
                                        if ln.strip().startswith(("uniform ", "attribute ", "varying "))
                                    ][:14]
                                    shader_samples[key] = {
                                        "obb_path": info.filename,
                                        "bytes": info.file_size,
                                        "bindings": bindings,
                                        "declarations": decls,
                                    }
            elif m4 == b"CFF0":
                cat = "CFF0 (Scene/Level/Prefab/UI Graph)"
                if info.file_size <= 600_000:
                    raw = archive.read(info)
                    tags = [
                        m.group().decode("ascii")
                        for m in re.finditer(rb"\*[A-Za-z0-9_.-]+\*", raw)
                    ]
                    uniq_tags = list(dict.fromkeys(tags))
                    if any(
                        k in t
                        for t in uniq_tags
                        for k in ("HalcyonFold", "HF_", "GoldMiner", "CrystalMiner", "Kraken", "VainTurret", "OuterTurret")
                    ) and not any("5v5" in t or "Blitz" in t for t in uniq_tags):
                        hf_3v3_nodes.append(
                            {"obb_path": info.filename, "bytes": info.file_size, "symbols": uniq_tags[:8]}
                        )
                    if any(
                        k in t
                        for t in uniq_tags
                        for k in ("KindredMenu", "KindredHUD", "HUDQuickMessage", "MinimapIconActor")
                    ) and not any("5v5" in t or "Ghostwing" in t or "Blackclaw" in t for t in uniq_tags):
                        ui_nodes.append(
                            {"obb_path": info.filename, "bytes": info.file_size, "symbols": uniq_tags[:8]}
                        )
            elif m4[:3] == b"ID3" or (len(m4) >= 2 and m4[0] == 0xFF and (m4[1] & 0xE0) == 0xE0):
                cat = "MP3 Audio (Voice/Music/SFX)"
            elif m4 in (b"OggS", b"RIFF", b"FSB5"):
                cat = f"Audio ({m4.decode('ascii', errors='ignore')})"
            elif m4 in (b"\x00\x01\x00\x00", b"OTTO", b"ttcf"):
                cat = "TTF/OTF Font Face"
            elif info.file_size in (52, 718, 829) and u0 in (1, 6, 7):
                cat = "Kindred Font Descriptor (.font)"
            elif u0 in (0x002AAAD4, 0x000AAAF8, 0x000AAAD4, 0x0002AAD4, 0x0000AAD4, 0x0002ABE8, 0x000AAB40):
                cat = "EVIL Mipmapped GPU Texture (ETC/PVR/ASTC)"
            elif len(hdr) >= 16 and all(32 <= b <= 126 or b in (9, 10, 13) for b in hdr[:16]):
                cat = "ASCII / Base64 Strings / Lightprobe Grid"
            elif u0 in (0, 1):
                cat = f"Binary Data Block (u0={u0})"
            else:
                cat = "Other Compiled Binary / Large Texture"

            categories[cat][0] += 1
            categories[cat][1] += info.compress_size
            categories[cat][2] += info.file_size

        # Extract 3v3 Halcyon Fold baked lightprobe grid metadata
        hf_grid_path = "4C/4C4CC7477231BA630E24828C7A1B8093"
        if hf_grid_path in archive.namelist():
            lines = archive.read(hf_grid_path).decode("ascii", errors="replace").splitlines()
            bounds = [float(x) for x in lines[0].split()]
            dims = [int(x) for x in lines[2].split()]
            first_probe = [float(x) for x in lines[4].split()]
            hf_grid_meta = {
                "obb_path": hf_grid_path,
                "bounds_xz_meters": {"min_x": bounds[0], "min_z": bounds[1], "max_x": bounds[2], "max_z": bounds[3]},
                "span_meters": {"width_x": bounds[2] - bounds[0], "depth_z": bounds[3] - bounds[1]},
                "grid_cells": {"nx": dims[0], "nz": dims[1], "cell_size_m": (bounds[2] - bounds[0]) / dims[0]},
                "probe_count": dims[0] * dims[1],
                "floats_per_probe": len(first_probe),
            }

    hf_3v3_nodes.sort(key=lambda x: -x["bytes"])
    ui_nodes.sort(key=lambda x: -x["bytes"])
    return {
        "obb_entries": len(infos),
        "compressed_mib": round(sum(v[1] for v in categories.values()) / 1048576, 2),
        "uncompressed_mib": round(sum(v[2] for v in categories.values()) / 1048576, 2),
        "categories": {
            k: {
                "files": v[0],
                "compressed_mib": round(v[1] / 1048576, 2),
                "uncompressed_mib": round(v[2] / 1048576, 2),
            }
            for k, v in sorted(categories.items(), key=lambda item: -item[1][2])
        },
        "halcyon_fold_3v3_lightprobe_grid": hf_grid_meta,
        "halcyon_fold_3v3_cff0_nodes": hf_3v3_nodes[:30],
        "shader_feature_counts": dict(shader_features),
        "shader_samples": shader_samples,
        "ui_cff0_nodes": ui_nodes[:25],
    }


def scan_kindred_so(so_path: Path) -> dict:
    data = so_path.read_bytes()
    strings = sorted({m.group().decode("ascii") for m in re.finditer(rb"[\x20-\x7e]{5,120}", data)})

    def pick(pattern: str, exclude: str = "5v5|Blitz|Aral|Ghostwing|Blackclaw") -> list[str]:
        rx = re.compile(pattern, re.I)
        ex = re.compile(exclude, re.I) if exclude else None
        return [s for s in strings if rx.search(s) and (not ex or not ex.search(s))][:40]

    return {
        "so_size_mib": round(len(data) / 1048576, 2),
        "total_ascii_strings": len(strings),
        "halcyon_fold_3v3_symbols": pick(r"HalcyonFold|HF_|GoldMiner|CrystalMiner|Kraken|JungleShop|VainCrystal|IdleBrushShadow|Standard3v3"),
        "scene_rendering_symbols": pick(r"CloudShadows\.|FogOfWar\.|FogOfWarSettings|ShadowGenerator|Shadowing\.|CameraSettings|CameraOrientation|MenuMeshShaderParam", ""),
        "main_menu_symbols": pick(r"KindredMainMenu|KindredMenu|MenuMeshCamera|MAIN_MENU_|DraftLobby_", ""),
        "battle_hud_symbols": pick(r"KindredHUD|HUD_Ability|HUDJoystickChoice|hud_store|hud_plaque|hud_scoreboard|Effect_Ping_", ""),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--vg-dir",
        type=Path,
        default=Path(r"C:\Users\whw88\Downloads\Vainglory-zhTW-EnglishVoice-20261119"),
        help="Path to local Vainglory workspace containing original OBB and SO",
    )
    parser.add_argument("--json-out", type=Path, help="Optional path to save JSON summary")
    args = parser.parse_args()

    obb = args.vg_dir / "main.147219.original.obb"
    so = args.vg_dir / "libGameKindred.arm64.original.so"
    report = {
        "game": "Vainglory Community Edition 4.13.4 (147219)",
        "engine": "Super Evil Megacorp E.V.I.L. Engine (libGameKindred.so)",
        "focus_scope": "3v3 Halcyon Fold + Scene Rendering + Resource Allocation + Main Menu & Battle HUD",
        "obb_analysis": classify_obb(obb),
        "engine_binary_analysis": scan_kindred_so(so),
    }
    if args.json_out:
        args.json_out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
