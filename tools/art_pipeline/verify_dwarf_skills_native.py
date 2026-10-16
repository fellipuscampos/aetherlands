"""Read back private actions from the delivered native Blender files."""
import json
import bpy
from dwarf_troop_assets import ASSETS
from dwarf_skill_contract import ROOT,OUT,roles_for

def verify():
    results=[]
    for row in ASSETS:
        path=OUT/row['stem']/(row['stem']+'.blend')
        scene=bpy.data.scenes[row['stem']+'_MCP_Static_V2']
        rig=next(o for o in scene.objects if o.type=='ARMATURE' and o.get('dwarf_animation_owned'))
        tracks={t.name:t for t in rig.animation_data.nla_tracks}
        expected={'idle','walk','attack'}|set(roles_for(row))
        assert set(tracks)==expected,(row['stem'],list(tracks))
        scene.frame_end=max(round(t.strips[0].action.frame_range[1]) for t in tracks.values())
        scene.frame_start=1;scene.frame_set(1)
        bpy.data.libraries.write(str(path),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
        with bpy.data.libraries.load(str(path),link=False) as (source,target):
            assert len(source.actions)==len(expected),(row['stem'],source.actions)
            target.actions=list(source.actions)
        actions=target.actions
        skills=[a for a in actions if a and a.get('dwarf_skill_owned')]
        assert len(skills)==len(roles_for(row)),row['stem']
        for action in skills:
            assert action['asset']==row['stem'],(row['stem'],action.name,dict(action.items()))
        results.append(dict(stem=row['stem'],private_skills=len(skills),total_actions=len(actions),
                            timeline_end=scene.frame_end))
        for action in actions:
            if action and not action.users:bpy.data.actions.remove(action)
    report=dict(status='PASS',models=len(results),new_native_actions=sum(r['private_skills'] for r in results),
                assets=results)
    (ROOT/'docs/dwarf_skills_native_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    return dict(status='PASS',models=len(results),new_native_actions=report['new_native_actions'])
