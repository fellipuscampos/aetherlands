"""Real Godot import and native skill review verification in isolation."""
import shutil
import subprocess
from dwarf_troop_assets import ASSETS
from dwarf_skill_contract import ROOT, OUT, WORK

godot='C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
project=WORK/'godot';project.mkdir(parents=True,exist_ok=True)
(project/'project.godot').write_text('''config_version=5
[application]
config/name="Dwarf native skills review"
[filesystem]
import/blender/enabled=false
[rendering]
renderer/rendering_method="gl_compatibility"
''',encoding='utf-8')
target=project/'assets/generated/dwarves';target.mkdir(parents=True,exist_ok=True)
shutil.copy2(OUT/'dwarf_troops_manifest.json',target/'dwarf_troops_manifest.json')
for row in ASSETS:
    folder=target/row['stem'];folder.mkdir(exist_ok=True)
    for suffix in ('.glb','.glb.import','_import.gd','_report.json'):
        shutil.copy2(OUT/row['stem']/(row['stem']+suffix),folder/(row['stem']+suffix))
for filename in ('_dwarf_troop_models_review.gd','_dwarf_troop_models_review.tscn'):
    shutil.copy2(ROOT/filename,project/filename)
shutil.copy2(ROOT/'tools/art_pipeline/verify_dwarf_skills_import.gd',project/'verify.gd')
(project/'smoke.gd').write_text('''extends SceneTree
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    var scene := (load("res://_dwarf_troop_models_review.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    await process_frame
    for family in 6:
        scene._select(family)
        await process_frame
        assert(scene.players.size() == 4)
        for clip in scene.SKILLS[family]:
            scene._play(clip)
            for index in 4:
                var player: AnimationPlayer = scene.players[index]
                assert(player.is_playing())
                assert(player.current_animation == clip if player.has_animation(clip) else player.current_animation == "idle")
                player.seek(player.current_animation_length*0.45, true)
        scene.paused = true
        scene._play("attack")
        for player in scene.players: assert(player.speed_scale == 0.0)
        scene.paused = false
    print("DWARF_SKILL_REVIEW_PASS: 24 native libraries, evolved-only second skills, pause and all classes")
    scene.queue_free()
    await process_frame
    quit()
''',encoding='utf-8')
for label,command in [('import',[godot,'--headless','--editor','--path',str(project),'--import']),
                      ('validation',[godot,'--headless','--path',str(project),'--script','verify.gd','--',str(ROOT/'docs/dwarf_skills_godot_validation.json')]),
                      ('review',[godot,'--headless','--path',str(project),'--script','smoke.gd'])]:
    done=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',timeout=180)
    (WORK/('godot_'+label+'.log')).write_text(done.stdout+'\n'+done.stderr,encoding='utf-8')
    print(label,done.returncode,done.stdout[-1200:],done.stderr[-1200:],flush=True)
    assert done.returncode==0 and 'SCRIPT ERROR' not in done.stderr and 'ERROR:' not in done.stderr
