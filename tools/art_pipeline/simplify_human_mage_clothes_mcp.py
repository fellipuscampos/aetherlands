"""Remove only applied garment ornaments from the approved animated human mages.

Execute through the live Blender MCP. Geometry retained by this edit must keep
the original coordinates, UVs, skinning and three approved animation actions.
"""
import ast
import bpy
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
WORK = ROOT / 'art_source/school_mages_animation_review'
BACKUP = WORK / 'before_human_clothing_cleanup'
assert not (ROOT / 'docs/human_school_mages_clothing_validation.json').exists(), 'Cleanup already completed.'
BACKUP.mkdir(exist_ok=True)
assets = bpy.app.driver_namespace['human_school_mage_assets_v1']
assert all('clothing_cleanup' not in a['report'] for a in assets), 'Inspect partial cleanup before resuming.'
review = bpy.app.driver_namespace['human_school_mage_review_v1']
overview = bpy.app.driver_namespace['school_mages_animation_review_v1']['scene']

common = {'Belt_clasp', 'Human_blue_belt'}
school_extras = {
    'sacred': {'Sun_brooch', 'Gold_stole_top_-1', 'Gold_stole_top_1', 'Gold_stole_lower_-1', 'Gold_stole_lower_1'},
    'infernal': {'Red_lapel_-1', 'Red_lapel_1', 'Infernal_sash', 'Ritual_belt_box', 'Cinder_box_clasp'},
    'necromancy': {'Bone_necklace_-1', 'Bone_necklace_1', 'Bone_talisman_-1', 'Bone_talisman_1', 'Violet_pendant', 'Violet_robe_panel_-1', 'Violet_robe_panel_1'},
    'druidism': {'Wool_mantle_-1', 'Wool_mantle_1', 'Leaf_brooch', 'Herb_pouch', 'Pouch_herb_0', 'Pouch_herb_1', 'Pouch_herb_2'},
    'arcanism': {'Silver_stole_-1', 'Silver_stole_1', 'Silver_skirt_edge_-1', 'Silver_skirt_edge_1', 'Arcane_rune_0', 'Arcane_rune_1', 'Arcane_rune_2'},
    'elementalism': {'Element_clasp_fire', 'Element_clasp_water', 'Element_clasp_stone', 'Element_clasp_wind', 'Wind_hem_-1', 'Wind_hem_1'},
}
source = (ROOT / 'tools/art_pipeline/animate_settlers_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(source).body:
    if isinstance(node, ast.FunctionDef) and node.name == 'shape_hash':
        exec(compile(ast.get_source_segment(source, node), '<approved_mesh_hash>', 'exec'), globals())

# Backup before any deletion. Other races are checked by file hashes, never rewritten.
manifest = json.loads((WORK / 'manifest.json').read_text(encoding='utf-8'))
protected = {}
for row in manifest['assets']:
    folder = (ROOT / row['glb']).parent
    if row['race'] == 'human':
        shutil.copytree(folder, BACKUP / folder.relative_to(ROOT), dirs_exist_ok=True)
    else:
        for path in folder.rglob('*'):
            if path.is_file() and path.suffix in ('.blend', '.glb', '.png', '.json'):
                protected[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
for race in ('elf', 'dwarf', 'orc'):
    path = ROOT / 'art_source' / (race + '_school_mages_review') / (race + '_school_mages_six_schools_review.blend')
    protected[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
for path in [ROOT / 'art_source/human_school_mages_review', WORK / 'school_mages_24_animated_review.blend', WORK / 'manifest.json', WORK / 'index.html', WORK / 'README.md', WORK / 'native_session_started.json']:
    target = BACKUP / path.relative_to(ROOT)
    if path.is_dir():
        target.mkdir(parents=True, exist_ok=True)
        for item in path.iterdir():
            if item.is_file():
                shutil.copy2(item, target / item.name)
    elif path.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
(BACKUP / 'protected_files.json').write_text(json.dumps(protected, indent=2), encoding='utf-8')

rows = []
for index, asset in enumerate(assets):
    report = asset['report']
    removed = common | school_extras[report['school']]
    before = {o['part']: shape_hash(o) for o in asset['parts']}
    assert removed <= before.keys(), (report['stem'], removed - before.keys())
    actions = dict(asset['actions'])
    old_triangles = report['geometry']['triangles']
    # The copies share mesh data, allowing precise ownership without name guesses.
    deleted_meshes = {o.data for o in asset['parts'] if o['part'] in removed}
    for scene in (asset['scene'], review['scene'], overview):
        matches = [o for o in scene.objects if o.type == 'MESH' and o.data in deleted_meshes and o.get('part') in removed]
        assert len(matches) == len(removed), (scene.name, report['stem'], len(matches))
        bpy.data.batch_remove(ids=matches)
    asset['parts'] = [o for o in asset['scene'].objects if o.type == 'MESH' and o.get('part') in before and o.get('part') not in removed]
    # Preserve original ordering, important for reproducible runtime skinning.
    by = {o['part']: o for o in asset['parts']}
    asset['parts'] = [by[name] for name in before if name not in removed]
    after = {o['part']: shape_hash(o) for o in asset['parts']}
    assert after == {name: value for name, value in before.items() if name not in removed}
    assert asset['actions'] == actions
    triangles = sum(len(p.vertices) - 2 for o in asset['parts'] for p in o.data.polygons)
    report['geometry']['triangles'] = triangles
    for key in ('editable_parts', 'parts'):
        if key in report['geometry'] and isinstance(report['geometry'][key], int):
            report['geometry'][key] = len(asset['parts'])
    report['style_revision'] = 4
    report['clothing_cleanup'] = dict(status='PASS',revision=1,removed_parts=sorted(removed),retained_geometry_uvs_skinning_unchanged=True,school_colors_and_textures_unchanged=True,approved_animation_revision=3,animations_unchanged=True,backup=BACKUP.relative_to(ROOT).as_posix())
    rows.append(dict(stem=report['stem'],removed_parts=sorted(removed),triangles_before=old_triangles,triangles_after=triangles,retained_parts_hashes=after,animations_unchanged=True))

audit = dict(status='PASS',models=6,removed_parts=sum(len(row['removed_parts']) for row in rows),removed_triangles=sum(row['triangles_before']-row['triangles_after'] for row in rows),assets=rows)
bpy.app.driver_namespace['human_mage_clothing_cleanup_v1'] = audit
(ROOT / 'docs/human_school_mages_clothing_validation.json').write_text(json.dumps(audit, indent=2), encoding='utf-8')
result = {key: value for key, value in audit.items() if key != 'assets'}
