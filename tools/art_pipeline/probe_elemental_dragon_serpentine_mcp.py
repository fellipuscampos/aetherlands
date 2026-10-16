import bpy,json
from pathlib import Path
scene=bpy.data.scenes['Elemental_Dragon_V7_Animated']; bpy.context.window.scene=scene
out=Path(r'C:/Users/felipe campos/Documents/jogo/art_source/elemental_dragon_review')
for label,frame in [('serpentine_quarter',23),('serpentine_half',91),('serpentine_late',136)]:
    scene.frame_set(frame); scene.render.filepath=str(out/(label+'.png')); bpy.ops.render.render(write_still=True)
result={'renders':3}
