"""Restore exported inherited UVs; keep all other GLB bytes and source art intact."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct

import numpy as np
from PIL import Image

from glb_pose_math import accessor
from human_texture_glb import image_bytes, read_glb

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets/generated/orcs"
BACKUP = ROOT / "art_source/orc_face_uv_repair/before"


def part_mask(uv, boxes):
    mask = np.zeros(len(uv), dtype=bool)
    for x0, y0, x1, y1 in boxes:
        mask |= ((uv[:, 0] >= x0 - 1e-6) & (uv[:, 0] <= x1 + 1e-6)
                 & (uv[:, 1] >= 1-y1-1e-6) & (uv[:, 1] <= 1-y0+1e-6))
    return mask


def sample(rgb, uv):
    height, width = rgb.shape[:2]
    return rgb[np.clip((uv[:, 1]*height).astype(int), 0, height-1),
               np.clip((uv[:, 0]*width).astype(int), 0, width-1), :3]


def repair(path, apply):
    raw = path.read_bytes()
    doc, binary = read_glb(raw)
    primitives = [p for mesh in doc.get("meshes", []) for p in mesh["primitives"]]
    if not any("TEXCOORD_1" in p["attributes"] for p in primitives):
        return {"stem": path.stem, "status": "UNCHANGED", "reason": "single rendered UV layer"}
    assert len(primitives) == 1, path
    primitive = primitives[0]
    attrs = primitive["attributes"]
    current = accessor(doc, binary, attrs["TEXCOORD_0"])
    original = accessor(doc, binary, attrs["TEXCOORD_1"])
    inherited = np.max(np.abs(original - [0., 1.]), axis=1) > 1e-6
    changed = inherited & (np.max(np.abs(original-current), axis=1) > 1e-6)
    if changed.any():
        assert len(np.unique(current[changed], axis=0)) == 1, (path, "unexpected primary UVs")
    repaired = current.copy()
    repaired[inherited] = original[inherited]
    material = doc["materials"][primitive["material"]]
    texture = material["pbrMetallicRoughness"]["baseColorTexture"]
    assert texture.get("texCoord", 0) == 0
    image = doc["images"][doc["textures"][texture["index"]]["source"]]
    rgb = np.array(Image.open(io.BytesIO(image_bytes(doc, binary, image))))
    report = json.loads(path.with_name(path.stem + "_report.json").read_text(encoding="utf-8"))
    boxes = report["clothing_refinement"]["source_part_uv_boxes"]
    face = []
    for name, rectangles in boxes.items():
        if not name.startswith(("ElfEar", "Brow")):
            continue
        mask = part_mask(original, rectangles) & inherited
        # Four helmeted forms omit the original brow meshes entirely.
        if not mask.any() and name.startswith("Brow") and report["clothing_refinement"]["skull_helmet"]:
            continue
        assert mask.sum() == 24, (path.stem, name, mask.sum())
        assert np.array_equal(repaired[mask], original[mask])
        color = sample(rgb, repaired[mask]).mean(axis=0)
        if name.startswith("ElfEar"):
            assert color[1] > color[0] and color[1] > color[2], (path.stem, name, color)
        else:
            assert max(color) < 70, (path.stem, name, color)
        face.append({"part": name, "vertices": int(mask.sum()),
                     "before_rgb": sample(rgb, current[mask]).mean(axis=0).tolist(),
                     "after_rgb": color.tolist()})
    assert len(face) in (6, 8), (path.stem, face)
    info = doc["accessors"][attrs["TEXCOORD_0"]]
    view = doc["bufferViews"][info["bufferView"]]
    assert info["componentType"] == 5126 and info["type"] == "VEC2"
    # Patch the existing accessor in place, without re-exporting animated meshes.
    binary_start = 20 + struct.unpack_from("<I", raw, 12)[0] + 8
    start = binary_start + view.get("byteOffset", 0) + info.get("byteOffset", 0)
    stride = view.get("byteStride", 8)
    result = bytearray(raw)
    allowed = np.zeros(len(raw), dtype=bool)
    for index in np.flatnonzero(changed):
        offset = start + int(index)*stride
        struct.pack_into("<ff", result, offset, *original[index])
        allowed[offset:offset+8] = True
    result = bytes(result)
    actual_diff = np.frombuffer(raw, dtype=np.uint8) != np.frombuffer(result, dtype=np.uint8)
    assert not actual_diff[~allowed].any(), "Bytes outside repaired UV coordinates changed"
    after_doc, after_binary = read_glb(result)
    assert doc == after_doc
    assert np.array_equal(accessor(after_doc, after_binary, attrs["TEXCOORD_0"]), repaired)
    if apply and changed.any():
        BACKUP.mkdir(parents=True, exist_ok=True)
        backup = BACKUP / path.name
        if not backup.exists():
            backup.write_bytes(raw)
        path.write_bytes(result)
    return {"stem": path.stem, "status": "PASS", "changed_vertices": int(changed.sum()),
            "inherited_vertices": int(inherited.sum()), "face": face,
            "only_uv0_bytes_changed": True, "geometry_rig_animations_textures_identical": True,
            "before_sha256": hashlib.sha256(raw).hexdigest(),
            "after_sha256": hashlib.sha256(result).hexdigest()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    rows = [repair(folder/(folder.name+".glb"), args.apply)
            for folder in sorted(ASSETS.iterdir()) if folder.is_dir()
            and (folder/(folder.name+".glb")).exists()]
    output = {"status": "PASS", "applied": args.apply,
              "repaired_models": sum(row["status"] == "PASS" for row in rows), "assets": rows}
    destination = ROOT / "docs/orc_face_uv_repair_validation.json"
    destination.write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in output.items() if key != "assets"}))
