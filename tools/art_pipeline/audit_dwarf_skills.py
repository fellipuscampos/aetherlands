"""Check new skills, unchanged basic channels, bind geometry and references."""
import hashlib
import json
import numpy as np
from dwarf_troop_assets import ASSETS
from dwarf_skill_contract import ROOT, OUT, WORK, roles_for
from human_texture_glb import read_glb, image_bytes
from audit_dwarf_animations import triangle_corners, animated_channels, accessor


def corners(doc,binary):
    rows=[]
    names=[doc['nodes'][i]['name'] for i in doc['skins'][0]['joints']]
    for primitive in doc['meshes'][0]['primitives']:
        attrs=primitive['attributes'];indices=accessor(doc,binary,primitive['indices']).ravel()
        positions=accessor(doc,binary,attrs['POSITION'])
        normals=accessor(doc,binary,attrs['NORMAL']);uv=accessor(doc,binary,attrs['TEXCOORD_0'])
        groups=accessor(doc,binary,attrs['JOINTS_0']);weights=accessor(doc,binary,attrs['WEIGHTS_0'])
        joint=np.array([sorted(names).index(names[int(group[np.argmax(weight)])]) for group,weight in zip(groups,weights)])[:,None]
        rows.append(np.concatenate((positions,normals,uv,joint),axis=1)[indices])
    rows=np.concatenate(rows)
    # Stable corner matching; native mesh transforms and rebuilt face normals
    # can differ in their final float32 rounding during consolidation.
    key=np.round(rows[:,[0,1,2,6,7,8]],4)
    return rows[np.lexsort(tuple(key[:,i] for i in range(key.shape[1]-1,-1,-1)))]


def verify(rows=ASSETS):
    results=[]
    for row in rows:
        stem=row['stem'];folder=OUT/stem;path=folder/(stem+'.glb')
        old_path=WORK/'before_skills/assets/generated/dwarves'/stem/(stem+'.glb')
        old,old_binary=read_glb(old_path.read_bytes());doc,binary=read_glb(path.read_bytes())
        assert len(doc['meshes'])==len(doc['skins'])==len(doc['materials'])==len(doc['images'])==1
        before,after=corners(old,old_binary),corners(doc,binary)
        assert before.shape==after.shape,(stem,'topology changed')
        assert np.allclose(before[:,:3],after[:,:3],atol=.000001,rtol=0),(stem,'positions changed')
        assert np.allclose(before[:,3:6],after[:,3:6],atol=.0001,rtol=0),(stem,'normals changed')
        assert np.allclose(before[:,6:],after[:,6:],atol=.000001,rtol=0),(stem,'UV/rigid joint bindings changed')
        old_clips=animated_channels(old,old_binary);new_clips=animated_channels(doc,binary)
        assert set(new_clips)=={'idle','walk','attack'}|set(roles_for(row)),(stem,new_clips.keys())
        for role in ('idle','walk','attack'):
            assert old_clips[role].keys()==new_clips[role].keys(),(stem,role,'channels changed')
            for name,(times,values) in old_clips[role].items():
                nt,nv=new_clips[role][name]
                assert times.shape==nt.shape and values.shape==nv.shape,(stem,role,name,'samples changed')
                assert np.allclose(times,nt,atol=1e-6) and np.allclose(values,nv,atol=1e-6),(stem,role,name,'basic motion changed')
        joints=[doc['nodes'][i]['name'] for i in doc['skins'][0]['joints']]
        old_joints=[old['nodes'][i]['name'] for i in old['skins'][0]['joints']]
        assert set(joints)==set(old_joints)
        old_bind=accessor(old,old_binary,old['skins'][0]['inverseBindMatrices'])
        bind=accessor(doc,binary,doc['skins'][0]['inverseBindMatrices'])
        for name in joints:assert np.allclose(bind[joints.index(name)],old_bind[old_joints.index(name)],atol=.00001),(stem,name,'bind changed')
        atlas=image_bytes(doc,binary,doc['images'][0]);assert atlas==image_bytes(old,old_binary,old['images'][0])
        assert all(s['magFilter']==9728 for s in doc['samplers'])
        for primitive in doc['meshes'][0]['primitives']:
            weights=accessor(doc,binary,primitive['attributes']['WEIGHTS_0'])
            assert np.allclose(weights.sum(axis=1),1) and np.all((weights>.001).sum(axis=1)==1)
        report=json.loads((folder/(stem+'_report.json')).read_text(encoding='utf-8'))
        assert report['skills']['status']=='PASS' and not report['skills']['foreign_actions_used']
        assert set(report['skills']['clips'])==set(roles_for(row))
        for role,(seconds,_) in roles_for(row).items():
            exported=next(a for a in doc['animations'] if a['name']==role)
            duration=max(float(accessor(doc,binary,s['input']).max()) for s in exported['samplers'])
            assert abs(duration-seconds)<.00001,(stem,role,duration)
        results.append(dict(stem=stem,status='PASS',new_clips=list(roles_for(row)),clips=len(new_clips),
            approved_geometry_preserved=True,original_basic_channels_preserved=True,
            original_bind_matrices_preserved=True,original_atlas_preserved=True,
            bones=len(joints),foreign_retargeting=False))
    protected=json.loads((WORK/'protected_assets.json').read_text(encoding='utf-8'))
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in protected.items())
    result=dict(status='PASS',models=len(results),new_clips=sum(len(r['new_clips']) for r in results),
        total_clips=sum(r['clips'] for r in results),protected_files=len(protected),assets=results)
    if len(rows)==24:(ROOT/'docs/dwarf_skills_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result


if __name__=='__main__':print(json.dumps(verify(),indent=2))
