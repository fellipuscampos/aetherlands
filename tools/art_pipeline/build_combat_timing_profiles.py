"""Bake authored impact frames into a small runtime table; never read JSON during combat.

Reads existing art reports only. Run from the repository root after new animation exports.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]


def build():
    models = {}
    candidates = {}
    for path in sorted((ROOT / "assets/generated").rglob("*report.json")):
        try:
            report = json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, OSError):
            continue
        animations = report.get("animations", {})
        if not isinstance(animations, dict):
            continue
        for clip, data in animations.items():
            if not isinstance(data, dict) or "impact_frame" not in data:
                continue
            start, end = data.get("start", 1), data.get("end", 0)
            if not isinstance(start, (float, int)) or not isinstance(end, (float, int)) or end <= start:
                continue
            impact = data["impact_frame"]
            if not isinstance(impact, (float, int)) or not start <= impact <= end:
                continue
            fraction = round((impact - start) / (end - start), 8)
            models.setdefault(path.parent.name, {})[clip] = fraction
            candidates.setdefault(clip, set()).add(fraction)
    clips = {clip: next(iter(values)) for clip, values in sorted(candidates.items()) if len(values) == 1}
    out = "# Generated from existing art reports by build_combat_timing_profiles.py.\nextends RefCounted\n\n"
    out += "const MODELS := " + json.dumps(models, ensure_ascii=False, indent=2, sort_keys=True) + "\n\n"
    out += "# Shared animation libraries reused by other skins keep the same authored timing.\n"
    out += "const CLIPS := " + json.dumps(clips, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    target = ROOT / "scripts/vfx/CombatTimingProfiles.gd"
    target.write_text(out, encoding="utf-8", newline="\n")
    print(f"{len(models)} models, {sum(map(len, models.values()))} authored impacts, {len(clips)} shared clips -> {target}")


if __name__ == "__main__":
    build()
