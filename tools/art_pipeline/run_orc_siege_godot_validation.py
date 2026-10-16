"""Validate real animated GLB imports and review without gameplay autoloads."""
import argparse
import shutil
import subprocess
from pathlib import Path
from orc_siege_assets import ROOT, OUT, WORK, SIEGE_ASSETS

parser = argparse.ArgumentParser(); parser.add_argument('--godot', required=True)
args = parser.parse_args()
project = WORK / 'godot_review'; project.mkdir(parents=True, exist_ok=True)
(project / 'project.godot').write_text('''config_version=5
[application]
config/name="Orc animated siege validation"
[filesystem]
import/blender/enabled=false
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
target = project / 'assets/generated/orcs'; target.mkdir(parents=True, exist_ok=True)
shutil.copy2(OUT / 'orc_siege_manifest.json', target / 'orc_siege_manifest.json')
for row in SIEGE_ASSETS:
    folder = target / row['stem']; folder.mkdir(exist_ok=True)
    for suffix in ('.glb', '.glb.import', '_import.gd', '_albedo.png', '_report.json'):
        shutil.copy2(OUT / row['stem'] / (row['stem'] + suffix), folder / (row['stem'] + suffix))
    for race, prefix in [('humans', ''), ('elves', 'elf_'), ('dwarves', 'dwarf_')]:
        stem = prefix + row['source_stem']
        folder = project / 'assets/generated' / race / stem; folder.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'assets/generated' / race / stem / (stem + '.glb'), folder / (stem + '.glb'))
for name in ('_orc_siege_models_review.gd', '_orc_siege_models_review.tscn'):
    shutil.copy2(ROOT / name, project / name)
shutil.copy2(Path(__file__).with_name('verify_orc_siege_import.gd'), project / 'verify.gd')
smoke = project / 'smoke_review.gd'
smoke.write_text('''extends SceneTree
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    var packed := load("res://_orc_siege_models_review.tscn") as PackedScene
    var scene := packed.instantiate()
    root.add_child(scene)
    await process_frame
    assert(scene.models.get_child_count() == 8)
    for race in ["humans", "elves", "dwarves"]:
        scene.comparison = race
        scene._display()
        await process_frame
        assert(scene.models.get_child_count() == 16)
    scene.comparison = ""
    scene._display()
    await process_frame
    for role in ["Idle", "Walk", "Attack", "DemolitionAmmo", "PreparedBombardment"]:
        scene.selected_role = role
        scene._play_role()
        await process_frame
        assert(scene.players.size() == 4)
        for player in scene.players:
            assert(player.is_playing())
            player.seek(0.5, true)
    print("ORC_ANIMATED_SIEGE_REVIEW_PASS: four machines, five roles and three reference races")
    scene.queue_free()
    await process_frame
    quit()
''', encoding='utf-8')
for label, command in [
    ('import', [args.godot, '--headless', '--editor', '--path', str(project), '--import']),
    ('validation', [args.godot, '--headless', '--path', str(project), '--script', 'verify.gd', '--',
                    str(ROOT / 'docs/orc_siege_godot_validation.json')]),
    ('review', [args.godot, '--headless', '--path', str(project), '--script', 'smoke_review.gd'])]:
    done = subprocess.run(command, capture_output=True, text=True, timeout=180)
    (WORK / ('godot_' + label + '.log')).write_text(done.stdout + '\n' + done.stderr, encoding='utf-8')
    print(label, done.returncode, done.stdout[-1800:], done.stderr[-1800:], flush=True)
    assert done.returncode == 0 and 'SCRIPT ERROR' not in done.stderr and 'ERROR:' not in done.stderr
