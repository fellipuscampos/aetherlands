"""Set authored idle/walk looping during the standard Godot scene import."""
from orc_siege_assets import ROOT, OUT, SIEGE_ASSETS


def configure():
    template = (ROOT / 'assets/generated/humans/catapult_v1/catapult_v1.glb.import').read_text(encoding='utf-8')
    params = '[params]\n' + template.split('[params]\n', 1)[1]
    for row in SIEGE_ASSETS:
        folder = OUT / row['stem']; filename = row['stem'] + '_import.gd'
        script = '''@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
    for node in scene.find_children("*", "AnimationPlayer", true, false):
        var player := node as AnimationPlayer
        for name in player.get_animation_list():
            var loops := String(name).ends_with("_Idle") or String(name).ends_with("_Walk")
            player.get_animation(name).loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
    return scene
'''
        (folder / filename).write_text(script, encoding='utf-8')
        path = folder / (row['stem'] + '.glb.import')
        script_path = 'res://assets/generated/orcs/' + row['stem'] + '/' + filename
        if path.exists():
            text = path.read_text(encoding='utf-8')
            import re
            text = re.sub(r'import_script/path="[^"]*"', 'import_script/path="' + script_path + '"', text)
            text = text.replace('animation/import=false', 'animation/import=true')
        else:
            source = row['path']
            header = '[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\nsource_file="' + source + '"\n\n'
            text = header + params.replace('res://assets/generated/humans/catapult_v1/catapult_v1_import.gd', script_path)
        path.write_text(text, encoding='utf-8')


if __name__ == '__main__': configure()
