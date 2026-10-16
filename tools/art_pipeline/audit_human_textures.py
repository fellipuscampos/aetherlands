"""Read-only inspection of editable human atlases in an isolated Blender process."""
import bpy
import hashlib
import json
import shutil
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art_source/human_texture_repair'
EXCLUDED = {'buildings', 'bombard_v1', 'catapult_v1', 'trebuchet_v1', 'siege_colossus_v1'}
rows = []
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').touch()
baseline = {}
for folder in sorted((ROOT / 'assets/generated/humans').iterdir()):
    if not folder.is_dir() or folder.name == 'buildings':
        continue
    files = {}
    for file in folder.iterdir():
        if not file.is_file() or file.suffix not in ('.png', '.glb', '.blend', '.json'):
            continue
        files[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
        if folder.name not in EXCLUDED:
            backup = OUT / 'before' / folder.name / file.name
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                shutil.copy2(file, backup)
    baseline[folder.name] = files
if not (OUT / 'baseline.json').exists():
    (OUT / 'baseline.json').write_text(json.dumps(baseline, indent=2), encoding='utf-8')
for folder in sorted((ROOT / 'assets/generated/humans').iterdir()):
    if not folder.is_dir() or folder.name in EXCLUDED:
        continue
    source = folder / (folder.name + '.blend')
    if not source.exists():
        rows.append({'unit': folder.name, 'legacy': True})
        continue
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    parts = [o for o in scene.objects if o.type == 'MESH' and 'region' in o and o.get('region') != 'studio']
    images = [{'name': im.name, 'size': list(im.size), 'filepath': im.filepath,
               'packed_sha256': hashlib.sha256(bytes(im.packed_file.data)).hexdigest() if im.packed_file else None}
              for im in bpy.data.images if im.type == 'IMAGE' and im.name != 'Render Result']
    row = {'unit': folder.name, 'scene': scene.name, 'regions': dict(Counter(o['region'] for o in parts)),
           'images': images, 'parts': [{'name': o.name, 'part': o.get('part'), 'region': o['region'],
                                      'paint_up': list(o.get('paint_up', [])),
                                      'uv': o.data.uv_layers.active.name if o.data.uv_layers.active else None,
                                      'faces': [[list(o.data.uv_layers.active.data[i].uv) for i in p.loop_indices]
                                                for p in o.data.polygons]}
                                     for o in parts]}
    rows.append(row)
    print(folder.name, row['regions'], flush=True)
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').touch()
(OUT / 'native_audit.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
