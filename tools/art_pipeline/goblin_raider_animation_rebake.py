"""Explicitly rebake the three generated clips after editing their choreography."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix, Euler

st=bpy.app.driver_namespace['goblin_animation']
scene=st['scene']; rig=st['rig']; arm=rig.data; parts=st['meshes']; NAME=st['name']
source=Path(st['source']); out=Path(st['out']); S=1.3/3.3
specs={b.name:None for b in arm.bones}
rig.animation_data.action=None
for track in list(rig.animation_data.nla_tracks): rig.animation_data.nla_tracks.remove(track)
for data in st['clips'].values(): bpy.data.actions.remove(data['action'])
for marker in list(scene.timeline_markers):
    if marker.name in st['clips']: scene.timeline_markers.remove(marker)
script=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\goblin_raider_animate.py').read_text(encoding='utf-8')
exec('rest='+script.split('\nrest=',1)[1])
