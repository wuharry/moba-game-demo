"""Check a recorded visual review against the current Godot release candidate."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct


THRESHOLD = 90
RUBRIC = {
    "terrain": 20,
    "materials": 20,
    "assets": 20,
    "dressing": 15,
    "light_water": 15,
    "readability": 10,
}
FRAME_SIZE = (1120, 630)
REVIEW_PATH = Path("review/refinement/release_review.json")
VIEWS = ("ground", "overhead")
INITIAL_SCENES = {"basin", "tide", "sunvine", "grove"}
TEXT_SUFFIXES = {
    ".godot", ".gd", ".gdshader", ".gdshaderinc", ".cs", ".tscn", ".tres",
    ".gltf", ".obj", ".mtl", ".svg", ".json", ".csv",
}
ASSET_SUFFIXES = {
    ".scn", ".res", ".glb", ".blend", ".fbx", ".dae", ".bin", ".mesh", ".anim",
    ".png", ".jpg", ".jpeg", ".webp", ".hdr", ".exr", ".tga", ".dds", ".ktx",
    ".wav", ".ogg", ".mp3", ".otf", ".ttf",
}
IGNORED_DIRS = {"authoring", "references", "review", "tools", "export_templates", "feature_profiles", "script_templates", "text_editor_themes"}
EXTRACTED_TEXTURE_PREFIXES = ("fog_runner_", "garden_hero_Painted_Stone_Atlas.", "ridge_hero_Painted_Stone_Atlas.")
ROUTE = re.compile(r"^ROUTE \| ([a-z][a-z0-9_]*) \| (\d+)/(\d+) \| (\d+(?:\.\d+)?) m \| PASS\s*$", re.MULTILINE)


def source_sha256(project):
    paths = []
    for folder, dirs, files in os.walk(project):
        dirs[:] = [name for name in dirs if not name.startswith(".") and name not in IGNORED_DIRS]
        for name in files:
            path = Path(folder) / name
            if path.suffix.lower() not in TEXT_SUFFIXES | ASSET_SUFFIXES:
                continue
            # Godot extracts these copies from the three embedded GLBs during import.
            if path.parent == project / "models" and name.startswith(EXTRACTED_TEXTURE_PREFIXES):
                continue
            paths.append(path.relative_to(project))

    if Path("project.godot") not in paths:
        raise ValueError(f"No project.godot under {project}.")

    digest = hashlib.sha256()
    for path in sorted(paths, key=lambda item: item.as_posix()):
        data = (project / path).read_bytes()
        if path.suffix.lower() in TEXT_SUFFIXES:
            data = data.replace(b"\r\n", b"\n")
        digest.update(path.as_posix().encode("utf-8") + b"\0")
        digest.update(hashlib.sha256(data).digest())
    return digest.hexdigest()


def matches_sha256(expected, data):
    return isinstance(expected, str) and expected.lower() == hashlib.sha256(data).hexdigest()


def gallery_scenes(project):
    script = (project / "refinement_gallery.gd").read_text(encoding="utf-8-sig")
    locations = re.search(r"^const LOCATIONS := \[\n(.*?)^\]", script, re.MULTILINE | re.DOTALL)
    if not locations:
        raise ValueError("Could not read the gallery's LOCATIONS list.")
    rows = [line.strip() for line in locations[1].splitlines() if line.strip()]
    scenes = re.findall(r'^\["[^"\n]+", "([a-z][a-z0-9_]*)", "res://[^"\n]+"\],?$', "\n".join(rows), re.MULTILINE)
    if len(set(scenes)) != len(rows) or not INITIAL_SCENES.issubset(scenes):
        raise ValueError("Gallery LOCATIONS must contain unique scene IDs and all four original scenes.")
    return scenes


def check_route(capture_dir, expected_sha256, scenes, issues):
    try:
        data = (capture_dir / "route_verification.txt").read_bytes()
    except OSError as error:
        issues.append(f"Route evidence: {error}")
        return
    # Accept normal Git line-ending conversion of the same route log.
    lf = data.replace(b"\r\n", b"\n")
    if not any(matches_sha256(expected_sha256, variant) for variant in (data, lf, lf.replace(b"\n", b"\r\n"))):
        issues.append("Route evidence SHA-256 does not match review.")
    passed = set()
    for scene, reached, count, distance in ROUTE.findall(data.decode("utf-8-sig")):
        if int(reached) == int(count) and int(count) > 0 and float(distance) > 0:
            passed.add(scene)
    for scene in scenes:
        if scene not in passed:
            issues.append(f"{scene}: successful gameplay route is missing.")


def check_frame(path, expected_sha256, issues):
    try:
        data = path.read_bytes()
    except OSError as error:
        issues.append(f"{path.name}: {error}")
        return
    if not matches_sha256(expected_sha256, data):
        issues.append(f"{path.name}: SHA-256 does not match the reviewed image.")
    if not data.startswith(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR") or len(data) < 33:
        issues.append(f"{path.name}: expected a PNG screenshot.")
    elif struct.unpack_from(">II", data, 16) != FRAME_SIZE:
        issues.append(f"{path.name}: expected {FRAME_SIZE[0]} x {FRAME_SIZE[1]}.")


def check_score(label, entry, issues):
    score = entry.get("score")
    if type(score) not in (int, float) or not 0 <= score <= 100:
        issues.append(f"{label}: expected a score between 0 and 100.")
        return
    if score < THRESHOLD:
        issues.append(f"{label}: {score:g} < {THRESHOLD}.")
        return

    grades = entry.get("grades")
    if not isinstance(grades, dict) or grades.keys() != RUBRIC.keys() or any(
        type(grade) is not int or not 0 <= grade <= 5 for grade in grades.values()
    ):
        issues.append(f"{label}: expected all six rubric grades as integers from 0 to 5.")
        return
    weighted_score = sum(grades[name] * (weight // 5) for name, weight in RUBRIC.items())
    if weighted_score != score:
        issues.append(f"{label}: rubric gives {weighted_score}, recorded score is {score:g}.")


def check_review(project):
    review = json.loads((project / REVIEW_PATH).read_text(encoding="utf-8-sig"))
    capture_dir = (project / review["capture_dir"]).resolve()
    if not capture_dir.is_relative_to(project / "review/refinement"):
        raise ValueError("The recording directory must be inside review/refinement/.")

    issues = []
    if str(review["source_sha256"]).lower() != source_sha256(project):
        issues.append("Godot source/assets differ from the reviewed candidate.")
    scenes = gallery_scenes(project)
    scene_reviews = review["scenes"]
    if set(scene_reviews) != set(scenes):
        issues.append("Review must cover exactly the scenes listed in the Godot gallery.")
    check_route(capture_dir, review["route_sha256"], scenes, issues)
    for scene in scenes:
        details = scene_reviews.get(scene, {})
        version = details.get("version")
        if not isinstance(version, str) or not version.strip():
            issues.append(f"{scene}: missing review version.")
        for view in VIEWS:
            entry = details.get(view, {})
            check_score(f"{scene} {view}", entry, issues)
            check_frame(capture_dir / f"{scene}_{view}.png", entry.get("sha256"), issues)
    return issues


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--print-source-sha256", action="store_true")
    arguments = parser.parse_args()
    project = arguments.project_root.resolve()
    try:
        if arguments.print_source_sha256:
            print(source_sha256(project))
            return 0
        issues = check_review(project)
    except (AttributeError, KeyError, OSError, TypeError, ValueError) as error:
        issues = [str(error)]
    if issues:
        print("Release blocked:")
        for issue in issues:
            print(f"- {issue}")
        return 1
    print(f"Release review validated. Every recorded view is at least {THRESHOLD}/100 and every route passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
