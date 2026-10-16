"""Keep authored loop/one-shot flags when importing dwarf skill GLBs."""
import re
from dwarf_troop_assets import ASSETS
from dwarf_skill_contract import OUT

for row in ASSETS:
    stem=row['stem'];folder=OUT/stem;script_name=stem+'_import.gd'
    (folder/script_name).write_text('''@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
    for node in scene.find_children("*", "AnimationPlayer", true, false):
        var player := node as AnimationPlayer
        for name in player.get_animation_list():
            player.get_animation(name).loop_mode = Animation.LOOP_LINEAR if name in ["idle", "walk", "shield_wall_hold"] else Animation.LOOP_NONE
    return scene
''',encoding='utf-8')
    path=folder/(stem+'.glb.import')
    text=path.read_text(encoding='utf-8')
    text=re.sub(r'import_script/path="[^"]*"','import_script/path="res://assets/generated/dwarves/'+stem+'/'+script_name+'"',text)
    path.write_text(text,encoding='utf-8')
print('DWARF_SKILL_IMPORTS_CONFIGURED',len(ASSETS))
