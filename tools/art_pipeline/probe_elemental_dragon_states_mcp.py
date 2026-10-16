from pathlib import Path
source=Path(r'C:/Users/felipe campos/Documents/jogo/tools/art_pipeline/probe_elemental_dragon_path_mcp.py')
setup=source.read_text(encoding='utf-8').split('worst=(100.')[0]
setup=setup.replace("bpy.data.scenes['Elemental_Dragon_V9_Animated']","bpy.app.driver_namespace['elemental_dragon_v9_animated']['scene']")
setup=setup.replace('elemental_dragon_path_motion.py.inc','elemental_dragon_states_motion.py.inc')
exec(compile(setup,str(source),'exec'),globals())
results={}
for clip,duration in [('idle',6.),('walk',4.),('attack',2.4),('spell',8.)]:
    worst=(100.,None,None); ground=(100.,None,None)
    for sample in range(121):
        pose=frame_pose(clip,duration*sample/120,duration)
        transforms={name:matrix@rest[name].inverted() for name,matrix in pose.items()}
        center=pose['core'].translation; scale=pose['core'].to_scale().x
        for label,vertices,faces in rows:
            points=[sum(((transforms[n]@v)*w for n,w in influences),Vector()) for v,influences in vertices]
            distance=BVHTree.FromPolygons(points,faces).find_nearest(center)[3]-radius*scale
            if distance<worst[0]: worst=(distance,sample,label)
            low=min(p.z for p in points)
            if low<ground[0]: ground=(low,sample,label)
    results[clip]={'core_clearance':worst,'ground_clearance':ground}
result=results
