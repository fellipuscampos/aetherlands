"""Check unintended surface crossings on the animated weapon, cloth and bag."""
import bpy
from mathutils.bvhtree import BVHTree
st=bpy.app.driver_namespace['goblin_animation']; rig=st['rig']; scene=st['scene']
objects={o['part']:o for o in st['meshes']}
pairs=[]
for p in ['Head','Muzzle_Jaw','Long_Hooked_Nose','Chest','Abdomen','Thigh_l','Thigh_r','Forearm_l','Hand_l']:
    pairs.append(('Dagger_Blade',p))
for p in ['Thigh_l','Thigh_r']:
    pairs.extend([('RagFront',p),('RagBack',p)])
for p in ['Forearm_l','Hand_l']: pairs.append(('Loot_Pouch',p))
hits=[]
for track in rig.animation_data.nla_tracks: track.mute=True
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']
    for frame in range(1,data['end']+1):
        scene.frame_set(frame); deps=bpy.context.evaluated_depsgraph_get(); trees={}
        for p in set(x for pair in pairs for x in pair):
            ev=objects[p].evaluated_get(deps); me=ev.to_mesh()
            trees[p]=BVHTree.FromPolygons([ev.matrix_world@v.co for v in me.vertices],[list(f.vertices) for f in me.polygons])
            ev.to_mesh_clear()
        for a,b in pairs:
            if trees[a].overlap(trees[b]): hits.append((name,frame,a,b))
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1); st['surface_contacts']=hits
result={'crossing_count':len(hits),'pairs':sorted(set((h[0],h[2],h[3]) for h in hits)),'first_crossings':hits[:8]}
