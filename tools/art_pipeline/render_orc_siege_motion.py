"""Render actual rigid animation in the open Blender review scene via MCP."""
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
scene = bpy.context.window.scene
assert scene.name.startswith('Orc_Siege_Four_Evolutions_Animated_Review')
rigs = [obj for obj in scene.objects if obj.type == 'ARMATURE']
assert len(rigs) == 4
dest = ROOT / 'art_source/orc_siege/motion_frames'; dest.mkdir(parents=True, exist_ok=True)
original = (scene.render.resolution_x, scene.render.resolution_y, scene.render.filepath, scene.frame_current)
try:
    scene.render.resolution_x = 1020; scene.render.resolution_y = 408
    for role, start, end in [('walk', 58, 106), ('attack', 115, 163)]:
        folder = dest / role; folder.mkdir(exist_ok=True)
        for i, frame in enumerate(range(start, end, 2)):
            scene.frame_set(frame)
            scene.render.filepath = str(folder / ('%03d.png' % i))
            bpy.ops.render.render(write_still=True)
        print('MOTION_RENDERED', role, 24, flush=True)
    for role, start, samples in [('attack', 115, (0, 19, 22, 31, 39, 48)),
                                  ('demolition', 172, (0, 30, 38, 52, 62, 72)),
                                  ('prepared', 253, (0, 37, 51, 69, 83, 96))]:
        folder = dest / (role + '_stages'); folder.mkdir(exist_ok=True)
        for i, offset in enumerate(samples):
            scene.frame_set(start + offset)
            scene.render.filepath = str(folder / ('%03d.png' % i))
            bpy.ops.render.render(write_still=True)
finally:
    scene.render.resolution_x, scene.render.resolution_y, scene.render.filepath, frame = original
    scene.frame_set(frame)
result = dict(status='PASS', animated_frames=48, technique_stages=18, models=4)
(ROOT / 'docs/orc_siege_motion_preview_validation.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
