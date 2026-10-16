"""Check actual GLB clips, contacts, opaque atlases and metric character sizes."""
import hashlib,json,re
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from orc_troop_assets import ROOT,OUT,WORK,ASSETS,FAMILIES
from human_texture_glb import read_glb,image_bytes
from audit_elf_troops import accessor,animation_channels


def verify():
    baseline=json.loads((WORK/'protected_sources.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in baseline.items())
    base_report=json.loads((OUT/'orc_squire_v1/orc_squire_v1_report.json').read_text(encoding='utf-8'))
    base_pixels=np.array(Image.open(OUT/'orc_squire_v1/orc_squire_v1_albedo.png').convert('RGBA'))[::-1]
    results=[]
    for row in ASSETS:
        folder=OUT/row['stem']; report=json.loads((folder/(row['stem']+'_report.json')).read_text(encoding='utf-8'))
        doc,binary=read_glb((folder/(row['stem']+'.glb')).read_bytes())
        ref,rbin=read_glb((ROOT/'assets/generated/elves'/row['source_stem']/(row['source_stem']+'.glb')).read_bytes())
        assert len(doc['meshes'])==len(doc['skins'])==len(doc['materials'])==1
        clips={a['name']:max(doc['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in doc['animations']}
        expected={a['name']:max(ref['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in ref['animations']}
        assert clips.keys()==expected.keys()==report['clips'].keys()
        assert all(abs(clips[n]-expected[n])<.00001 for n in clips)
        root=doc['nodes'][doc['scenes'][doc.get('scene',0)]['nodes'][0]]
        scale=root['scale']; assert max(scale)-min(scale)<.00001
        bones=[doc['nodes'][index]['name'] for index in doc['skins'][0]['joints']]
        assert len(bones)==len(report['rig']['bones'])
        by_bone={}; triangles=0
        for primitive in doc['meshes'][0]['primitives']:
            attrs=primitive['attributes']; pos=accessor(doc,binary,attrs['POSITION'])
            uv=accessor(doc,binary,attrs['TEXCOORD_0']); w=accessor(doc,binary,attrs['WEIGHTS_0'])
            joints=accessor(doc,binary,attrs['JOINTS_0'])
            assert np.isfinite(pos).all() and np.isfinite(uv).all()
            assert np.allclose(w.sum(axis=1),1) and ((w>.0001).sum(axis=1)==1).all()
            assert (uv>=0).all() and (uv<=1).all()
            ids=joints[np.arange(len(joints)),np.argmax(w,axis=1)]
            for index,bone in enumerate(bones):
                mask=ids==index
                if row['key']!='squire': mask&=uv[:,0]<.5
                if mask.any(): by_bone.setdefault(bone,[]).append(pos[mask])
            triangles+=accessor(doc,binary,primitive['indices']).size//3
        by_bone={n:np.concatenate(v) for n,v in by_bone.items()}
        if row['family']=='cavalry':
            matrices=accessor(doc,binary,doc['skins'][0]['inverseBindMatrices'])
            rest={bone:np.linalg.inv(m.reshape(4,4).T)[:3,3] for bone,m in zip(bones,matrices)}
            metric=(by_bone['head'][:,1].max()-rest['thigh_l'][1]
                +np.linalg.norm(rest['shin_l']-rest['thigh_l'])
                +np.linalg.norm(rest['foot_l']-rest['shin_l'])
                +rest['foot_l'][1]-by_bone['foot_l'][:,1].min())*scale[0]
        else:
            metric=(by_bone['head'][:,1].max()-min(by_bone['foot_l'][:,1].min(),by_bone['foot_r'][:,1].min()))*scale[0]
        assert abs(float(metric)-row['character_height_m'])<.003,(row['stem'],metric)
        assert len(report['geometry']['body_parts'])==18 and report['geometry']['head_blocks']==1
        eyebrows=0 if report.get('open_skull_revision')=='jawless_skull_v1' else 2
        assert report['geometry']['ear_cuboids']==6 and report['geometry']['eyebrow_cuboids']==eyebrows
        png=(folder/(row['stem']+'_albedo.png')).read_bytes()
        assert len(doc['images'])==1 and image_bytes(doc,binary,doc['images'][0])==png
        assert all(s['magFilter']==9728 for s in doc['samplers'])
        pixels=np.array(Image.open(folder/(row['stem']+'_albedo.png')).convert('RGBA'))[::-1]
        assert (pixels[...,3]==255).all()
        left,right=base_report['texture']['head_audit']['eye_atlas_pixels']
        assert all(np.array_equal(pixels[y,x],pixels[b,a]) for (x,y),(a,b) in zip(left,right))
        if row['key']!='squire':
            x0,y0,x1,y1=base_report['texture']['head_audit']['uv_bounds']
            if not report.get('clothing_refinement',{}).get('skull_helmet') and not report.get('finishing_refinement',{}).get('hood_painted_on_head'):
                assert np.array_equal(pixels[y0:y1,x0:x1],base_pixels[y0:y1,x0:x1])
            if report.get('revision')!='anatomy_v2':
                assert report['base_blend_sha256']==hashlib.sha256((OUT/'orc_squire_v1/orc_squire_v1.blend').read_bytes()).hexdigest()
        if report.get('revision')=='anatomy_v2':
            anatomy=ROOT/report['anatomy_source']
            assert hashlib.sha256(anatomy.read_bytes()).hexdigest()==report['anatomy_source_sha256']
            frozen=WORK/'pose_correction/before_assets'/row['stem']/(row['stem']+'_albedo.png')
            if report.get('equipment_revision')=='tribal_v1':
                from audit_orc_tribal_equipment import verify as verify_equipment
                max_error=verify_equipment(row)['animation_max_error']
            else:
                assert png==frozen.read_bytes()
                max_error=None
        elif row['key']!='squire':
            old,new=animation_channels(ref,rbin),animation_channels(doc,binary)
            max_error=0.
            for clip in old:
                for key,values in old[clip].items():
                    if key[0] not in ('hand_l','hand_r','string_u','string_d','arrow'): continue
                    assert key in new[clip]
                    for value_index,(a,b) in enumerate(zip(values,new[clip][key])):
                        assert a.shape==b.shape
                        if value_index==1 and key[1]=='rotation':
                            # q and -q encode exactly the same physical rotation.
                            error=float(np.max(np.minimum(np.max(np.abs(a-b),axis=1),np.max(np.abs(a+b),axis=1))))
                        else: error=float(np.max(np.abs(a-b)))
                        max_error=max(max_error,error)
                        assert error<.00005,(row['stem'],clip,key,error)
        else: max_error=0.
        results.append(dict(stem=row['stem'],status='PASS',character_height_m=float(metric),
            mounted=row['family']=='cavalry',body_cuboids=18,eyebrow_cuboids=eyebrows,triangles=triangles,
            clips=len(clips),hand_and_string_animation_max_error=max_error,atlas_embedded=True,eyes_mirrored=True))
    output=dict(status='PASS',models=20,classes=5,legendary_models=5,normal_height_m=2.,legendary_height_m=2.2,
        clips=sum(r['clips'] for r in results),protected_files=len(baseline),assets=results)
    (ROOT/'docs/orc_troops_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in output.items() if k!='assets'}))


def galleries():
    dest=ROOT/'docs/previews/orc_troops'; dest.mkdir(parents=True,exist_ok=True)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',15)
    for view in ('three_quarter','front','back','game_top'):
        gallery=Image.new('RGB',(4*320,5*370),(34,40,37)); draw=ImageDraw.Draw(gallery)
        for index,row in enumerate(ASSETS):
            frame=Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB').resize((316,316),Image.Resampling.LANCZOS)
            x=row['tier']*320+2; y=index//4*370+2; gallery.paste(frame,(x,y))
            draw.text((x+7,y+318),row['name'],font=font,fill=(235,227,200))
            draw.text((x+7,y+345),row['family_name']+' • '+('Supremo 2,20 m' if row['tier']==3 else '2 m'),font=small,fill=(175,189,164))
        gallery.save(dest/('roster_'+view+'.jpg'),quality=94)
    (ROOT/'docs/ORC_TROOPS_CATALOG.md').write_text('''# Tropas orcs

20 personagens derivados diretamente do arquivo editável do escudeiro orc aprovado. Cinco classes com quatro evoluções: guardião, guerreiro, patrulheiro, cavalaria e ladino. Os comuns têm 2 m; a quarta evolução de cada classe é suprema lendária e tem 2,20 m. Na cavalaria, a altura é a do cavaleiro com as pernas estendidas, medida pelos pivôs e segmentos do corpo; inclui-se separadamente a montaria no tamanho total do modelo.

O escudeiro ganhou escudo 18% maior e braço sem escudo com 24 graus a menos de dobra, incluindo a adaptação das cinco animações. Essa versão serviu de fonte real para todos os outros corpos: 18 blocos rígidos, cabeça única, as mesmas seis peças das orelhas, duas sobrancelhas 3D e duas presas em degraus. O rosto aprovado e o couro com acabamento continuam no atlas.

Os equipamentos foram atualizados em `tribal_v1`, mantendo as empunhaduras, os esqueletos e todas as curvas das 93 animações da versão aprovada. O escudo inicial continua idêntico. Guardiões ganharam reforços de osso nos escudos de madeira; guerreiros usam machado com encaixe de osso e lâminas brutas com guardas de osso; patrulheiros usam arcos de madeira com reforços de osso amarrados e pontas de flecha de osso; ladinos usam facas de osso ou ferro bruto com guardas e pomo de osso. Os cavaleiros receberam lanças com pontas de presa e armadura de osso presa sobre couro, pintada nos mesmos blocos corporais. As duas evoluções mais altas da cavalaria incluem proteção de osso na montaria. Não foram criadas animações novas.

A revisão `anatomy_v2` corrige as posições usando a distância entre peito e cabeça do escudeiro aprovado. A cabeça acompanha a orientação do tronco com espaço para o rosto e as presas. Braços e pernas têm posições adaptadas à largura do orc. Essa anatomia permanece intacta na revisão tribal: os 18 blocos, os movimentos e a geometria das empunhaduras são comparados aos arquivos aprovados. Rosto, olhos, cabelo, pele exposta e roupas fora das proteções de osso mantêm a textura aprovada. As principais proteções continuam pintadas no corpo; reforços de arma e pequenos acessórios usam peças extras com pesos nos ossos já existentes.

- Modelos `.blend`, `.glb`, atlas e relatórios: `assets/generated/orcs/`.
- Manifesto completo: `assets/generated/orcs/orc_troops_manifest.json`.
- Godot: abra `res://_orc_troop_models_review.tscn` e pressione F6. Há botões para as cinco classes, animações e técnicas, pausa, velocidade, giro e zoom.
- [Galeria das 20 tropas](previews/orc_troops/roster_three_quarter.jpg), [frente](previews/orc_troops/roster_front.jpg), [costas](previews/orc_troops/roster_back.jpg).
- [Posições antes e depois](previews/orc_troops/anatomy_before_after.jpg).
- [Equipamentos antes e depois](previews/orc_troops/tribal_equipment_before_after.jpg).
- Blender: `assets/generated/orcs/orc_troops_review.blend` contém o conjunto para revisão.
- `orc_troops_validation.json`: GLBs reais, alturas, 93 clips, atlas embutidos e fontes humanas/élficas/anãs preservadas.
- `orc_troops_anatomy_validation.json`: geometria animada dos 20 GLBs, articulações, cabeça fora do peito e mãos fora do rosto e do tronco.
- `orc_tribal_equipment_validation.json`: curvas das 93 animações, empunhaduras, esqueleto e geometria corporal comparados com a versão aprovada; rosto e texturas protegidas conferidos.
- `orc_troops_blender_validation.json`: cubos, pesos, articulações e arquivos editáveis.
- `orc_troops_godot_validation.json`: importação, animações, dimensões e navegação da revisão por classe.

Para reaplicar os equipamentos pelo MCP do Blender aberto: `python tools/art_pipeline/run_orc_tribal_equipment_mcp.py`. A fonte aprovada, antes dos equipamentos tribais, está em `art_source/orc_troops/tribal_equipment/before_assets/`. Cerco não faz parte deste lote.
''',encoding='utf-8')
    catalog=ROOT/'docs/ORC_TROOPS_CATALOG.md'
    table=['\n| Classe | Inicial | Evolução 2 | Evolução 3 | Supremo (2,20 m) |','|---|---|---|---|---|']
    for start in range(0,len(ASSETS),4):
        rows=ASSETS[start:start+4]
        links=['[%s](../assets/generated/orcs/%s/%s.blend)' % (r['name'],r['stem'],r['stem']) for r in rows]
        table.append('| '+rows[0]['family_name']+' | '+' | '.join(links)+' |')
    catalog.write_text(catalog.read_text(encoding='utf-8')+'\n'.join(table)+'\n',encoding='utf-8')


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--verify-only',action='store_true');args=parser.parse_args()
    verify()
    if not args.verify_only:galleries()
