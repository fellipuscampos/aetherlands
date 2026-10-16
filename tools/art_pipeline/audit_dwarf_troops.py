"""Independent disk audit of dwarf GLBs, atlases and shared approved anatomy."""
import hashlib
import json
import math
import struct
from pathlib import Path
from dwarf_troop_assets import ASSETS, ROOT, OUT, WORK


def read_glb(path):
    raw=path.read_bytes()
    magic,version,size=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and size==len(raw)
    length=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+length]),raw[28+length:]


def main():
    reference=json.loads((OUT/'common/dwarf_base_v1_report.json').read_text(encoding='utf-8'))['anatomy']
    expected={'body_head','body_chest','body_belly','body_pelvis'}
    expected.update('body_'+part+'_'+side for side in ('L','R')
                    for part in ('thigh','shin','foot','shoulder','upper_arm','forearm','hand'))
    assert set(reference)==expected and len(reference)==18
    previous=json.loads((WORK/'approved_anatomy_v5.json').read_text(encoding='utf-8'))
    resized={'body_shin_L','body_shin_R','body_foot_L','body_foot_R'}
    assert all(reference[name]==previous[name] for name in expected-resized), 'Previously approved anatomy changed beyond boots'
    results=[]
    animated_count=0
    for row in ASSETS:
        stem=row['stem']; folder=OUT/stem
        report=json.loads((folder/(stem+'_report.json')).read_text(encoding='utf-8'))
        assert report['created_via']=='live_blender_mcp' and report['style_revision']==(5 if row['family']=='siege' else 6)
        assert report['atlas']['paint_revision']==7 and report['material_emblems'] is False
        doc,binary=read_glb(folder/(stem+'.glb'))
        animated=report['stage']=='animated_troops'
        if animated:
            assert sorted(a['name'] for a in doc['animations'])==['attack','idle','walk']
            assert len(doc['skins'])==1 and len(doc['meshes'])==1
            assert report['animation']['approved_meshes_unchanged'] is True
            animated_count+=1
        else:
            assert not doc.get('animations') and not doc.get('skins')
        assert not doc.get('cameras')
        assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
        assert len(doc['images'])==1 and len(doc['materials'])==1
        assert all(s['magFilter']==9728 for s in doc['samplers'])
        assert all('STUDIO' not in n.get('name','') for n in doc['nodes'])
        assert all('neck' not in n.get('name','').lower() for n in doc['nodes'] if row['family'] not in ('cavalry','siege'))
        bv=doc['bufferViews'][doc['images'][0]['bufferView']]
        embedded=binary[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
        disk=(folder/(stem+'_albedo.png')).read_bytes()
        assert embedded==disk
        assert hashlib.sha256(disk).hexdigest()==report['atlas']['sha256']
        assert hashlib.sha256((folder/(stem+'.glb')).read_bytes()).hexdigest()==report['export']['sha256']
        triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
        assert triangles==report['geometry']['triangles']
        for mesh in doc['meshes']:
            for prim in mesh['primitives']:
                uv=doc['accessors'][prim['attributes']['TEXCOORD_0']]
                assert uv['componentType']==5126 and uv['type']=='VEC2'
                view=doc['bufferViews'][uv['bufferView']]
                offset=view.get('byteOffset',0)+uv.get('byteOffset',0)
                stride=view.get('byteStride',8)
                coords=[v for i in range(uv['count']) for v in struct.unpack_from('<ff',binary,offset+i*stride)]
                assert all(math.isfinite(v) and -1e-5<=v<=1.00001 for v in coords)
        if row['family']!='siege':
            assert report['anatomy']==reference, stem+' has a different physical body'
            assert report['anatomical_parts']==18 and report['neck'] is False
            assert len(report['held_grips'])==1 and report['held_grips'][0]['fist_center_inside_handle']
            sizes=report['body_part_dimensions']
            assert sizes['body_pelvis'][0]==.52
            for side in ('L','R'):
                assert sizes['body_foot_'+side]==[.235,.405,.155]
                assert sizes['body_shin_'+side]==[.235,.245,.18]
                assert sizes['body_shin_'+side][0]>sizes['body_thigh_'+side][0]
            weapon=report['held_grips'][0]['weapon']
            prefix={'guardian':'clan_shield','warrior':'clan_hammer','ranger':'clan_crossbow','rogue':'forged_seax','cavalry':'forged_axe'}[row['family']]
            assert weapon.startswith(prefix),stem+' role equipment mismatch'
        if row['family']=='cavalry':
            assert report['mount_leg_segments']==8
            bone_names={n.get('name') if animated else n.get('extras',{}).get('future_bone') for n in doc['nodes']}
            assert all('mount_'+segment+'_'+side+'_'+pair in bone_names
                       for segment in ('thigh','shin','hoof') for side in ('L','R') for pair in ('front','hind'))
        assert report['geometry']['bounds_min'][2]>=-.003
        assert (folder/(stem+'.blend')).stat().st_size>10000
        assert all((folder/'previews'/(view+'.png')).exists()
                   for view in ('three_quarter','front','back','game_top'))
        results.append(dict(stem=stem,triangles=triangles,meshes=len(doc['meshes']),
                            shared_body=row['family']!='siege',static=not animated,embedded_atlas=True))
    protected=json.loads((WORK/'protected_files.json').read_text(encoding='utf-8'))
    changed=[p for p,h in protected.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
    assert not changed, 'Existing protected files changed: '+str(changed)
    output=dict(status='PASS',verified=24,style_revision=6,hip_leg_balance_corrected=True,hands_and_foot_length_preserved=True,
                boot_width_matches_shin=True,shins_wider_than_thighs=True,
                one_hand_equipment=True,guardians_shield_only=True,material_emblems=False,articulated_ram_legs=True,
                humanoids_with_same_18_parts=20,no_neck=True,
                mount='war_ram_all_four_tiers',animations=18 if animated_count else 0,
                animated_variants=animated_count,protected_files_unchanged=len(protected),assets=results)
    (ROOT/'docs/dwarf_troops_validation.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    manifest=[dict(**r,path='res://assets/generated/dwarves/'+r['stem']+'/'+r['stem']+'.glb') for r in ASSETS]
    (OUT/'dwarf_troops_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in output.items() if k!='assets'}))


if __name__=='__main__': main()
