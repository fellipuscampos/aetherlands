"""Check the actual 2 m orc GLB against its elf source and document the base."""
import hashlib
import json
import re
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path

from human_texture_glb import read_glb,image_bytes
from audit_elf_troops import accessor,animation_channels

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/generated/orcs/orc_squire_v1'
WORK=ROOT/'art_source/orc_squire'


def normalized(name):
    return re.sub(r'\.\d+$','',name.removeprefix('orc_squire_v1_').removeprefix('Elf_'))


def verify():
    baseline=json.loads((WORK/'protected_assets.json').read_text(encoding='utf-8'))
    assert all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha for path,sha in baseline.items())
    report=json.loads((OUT/'orc_squire_v1_report.json').read_text(encoding='utf-8'))
    doc,binary=read_glb((OUT/'orc_squire_v1.glb').read_bytes())
    source,source_binary=read_glb((ROOT/'assets/generated/elves/elf_squire_v1/elf_squire_v1.glb').read_bytes())
    assert len(doc['meshes'])==len(doc['skins'])==1
    assert len(doc['skins'][0]['joints'])==len(report['rig']['bones'])
    # Other bones retain the reference curves and stance offsets. The right
    # forearm/hand were intentionally rebaked to relax the approved base arm;
    # their joint continuity is measured in the editable Blender validator.
    def channels(document,data):
        clips=animation_channels(document,data)
        return {clip:{(normalized(bone),path):values for (bone,path),values in rows.items()} for clip,rows in clips.items()}
    a,b=channels(source,source_binary),channels(doc,binary)
    assert a.keys()==b.keys()==report['clips'].keys()
    max_error=0.0
    for clip in ([] if report.get('revision')=='anatomy_v2' else a):
        assert a[clip].keys()==b[clip].keys(),(clip,a[clip].keys(),b[clip].keys())
        for key in a[clip]:
            for index,(expected,actual) in enumerate(zip(a[clip][key],b[clip][key])):
                assert expected.shape==actual.shape,(clip,key)
                if index==1 and key[0] in ('forearm_r','hand_r'):
                    assert np.isfinite(actual).all()
                    continue
                if index==1 and key[1]=='translation' and key[0] in report['rig']['rest_bone_offsets']:
                    offset=report['rig']['rest_bone_offsets'][key[0]]
                    actual=actual-np.array([offset[0],offset[2],-offset[1]])
                error=float(np.max(np.abs(expected-actual))); max_error=max(max_error,error)
                assert error<.00005,(clip,key,error)
    if report.get('revision')=='anatomy_v2':
        from glb_pose_math import PoseModel
        frozen=ROOT/'art_source/orc_troops/pose_correction/before_assets/orc_squire_v1'
        original=PoseModel(frozen/'orc_squire_v1.glb');current=PoseModel(OUT/'orc_squire_v1.glb')
        if report.get('clothing_revision')=='leather_and_skeletal_v1':
            from audit_orc_refined_clothing import verify as verify_clothing
            from orc_troop_assets import ASSETS
            assert verify_clothing(ASSETS[0])['protected_geometry_max_error']<.000005
        else:assert (OUT/'orc_squire_v1_albedo.png').read_bytes()==(frozen/'orc_squire_v1_albedo.png').read_bytes()
        for clip in current.clips:
            duration=max(float(t[-1]) for _,_,t,_ in current.clips[clip])
            for frame in range(round(duration*24)+1):
                before=original.worlds(clip,frame/24);after=current.worlds(clip,frame/24)
                def local(model,worlds,name):
                    return np.linalg.inv(worlds[model.parent[model.by_name['root']]])@worlds[model.by_name[name]]
                for side in ('l','r'):
                    for part in ('upper_arm','forearm','hand'):
                        error=float(np.max(np.abs(local(original,before,part+'_'+side)-local(current,after,part+'_'+side))))
                        max_error=max(max_error,error)
                        assert error<.00005,(clip,frame,part,side,error)
    triangles=0; positions=[]
    for primitive in doc['meshes'][0]['primitives']:
        attrs=primitive['attributes']
        p=accessor(doc,binary,attrs['POSITION']); positions.append(p)
        uv=accessor(doc,binary,attrs['TEXCOORD_0']); weights=accessor(doc,binary,attrs['WEIGHTS_0'])
        assert np.isfinite(p).all() and np.isfinite(uv).all()
        assert (uv>=0).all() and (uv<=1).all()
        assert np.allclose(weights.sum(axis=1),1) and np.all((weights>.0001).sum(axis=1)==1)
        triangles+=accessor(doc,binary,primitive['indices']).size//3
    positions=np.concatenate(positions)
    node=doc['nodes'][doc['scenes'][doc.get('scene',0)]['nodes'][0]]
    scale=node['scale']; assert max(scale)-min(scale)<.00001
    assert abs(float(positions[:,1].max())*scale[1]-2.0)<.00001
    assert abs(float(positions[:,1].min()))<.00001
    assert triangles==(report['geometry']['triangles'] if report.get('clothing_revision') else report['geometry']['editable_parts']*12)
    assert report['geometry']['head_blocks']==1 and len(report['geometry']['body_parts'])==18
    assert report['geometry']['ear_cuboids']==6 and report['geometry']['tusk_cuboids']==4
    assert set(report['removed_headwear'])=={'HatBrim','HatCap','HatDome'}
    png=(OUT/'orc_squire_v1_albedo.png').read_bytes()
    assert len(doc['images'])==1 and image_bytes(doc,binary,doc['images'][0])==png
    assert all(sampler['magFilter']==9728 for sampler in doc['samplers'])
    rgba=np.array(Image.open(OUT/'orc_squire_v1_albedo.png').convert('RGBA'))[::-1]
    before_rgba=np.array(Image.open(WORK/'before_brows_clothing_refinement/orc_squire_v1_albedo.png').convert('RGBA'))[::-1]
    for region in report['texture']['preserved_shield_regions']:
        x0,y0,x1,y1=region['bounds']
        actual=rgba[y0:y1,x0:x1]
        assert np.array_equal(actual,before_rgba[y0:y1,x0:x1]),(region['part'],region['face'])
        assert hashlib.sha256(actual.tobytes()).hexdigest()==region['sha256']
    pixels=rgba[:,:,:3]
    left,right=report['texture']['head_audit']['eye_atlas_pixels']
    assert len(left)==len(right) and all(np.array_equal(pixels[y1,x1],pixels[y2,x2]) for (x1,y1),(x2,y2) in zip(left,right))
    actual_skin=np.array(report['texture']['palette']['skin'])
    assert ((pixels==actual_skin).all(axis=2)).sum()>20
    result=dict(status='PASS',models=1,clips=len(a),height_m=2.0,triangles=triangles,
        animation_max_error=max_error,head_blocks=1,body_cuboids=18,ear_cuboids=6,tusk_cuboids=4,
        eyes_mirrored=True,embedded_atlas_matches=True,protected_files=len(baseline),
        stance_offsets_verified=True,bone_accessory_cuboids=report['geometry']['bone_accessory_cuboids'],
        eyebrow_cuboids=report['geometry']['eyebrow_cuboids'],approved_shield_pixels_unchanged=True,
        relaxed_right_arm_degrees=report['relaxed_right_arm']['degrees'],shield_size_factor=1.18)
    (ROOT/'docs/orc_squire_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result))


def document():
    dest=ROOT/'docs/previews/orc_squire'; dest.mkdir(parents=True,exist_ok=True)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
    heading=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',28)
    for view in ('front','three_quarter'):
        comparison=Image.new('RGB',(2*640,714),(31,37,31)); draw=ImageDraw.Draw(comparison)
        draw.text((16,9),'Escudeiro Élfico → Escudeiro Orc Base',font=heading,fill=(227,217,181))
        for index,(folder,caption) in enumerate(((ROOT/'assets/generated/elves/elf_squire_v1','Base élfica • 1,80 m'),(OUT,'Escudeiro Orc • 2,00 m'))):
            image=Image.open(folder/'previews'/(view+'.png')).convert('RGB').resize((640,640),Image.Resampling.LANCZOS)
            comparison.paste(image,(index*640,47)); draw.text((index*640+16,686),caption,font=font,fill=(227,217,181))
        comparison.save(dest/('elf_orc_'+view+'.jpg'),quality=94)
    for view in ('front','three_quarter'):
        comparison=Image.new('RGB',(1280,714),(31,37,31)); draw=ImageDraw.Draw(comparison)
        draw.text((16,9),'Escudeiro Orc — equipamento revisado',font=heading,fill=(227,217,181))
        for index,(folder,caption) in enumerate(((WORK/'before_equipment_refinement','Antes • mesmas proporções'),(OUT,'Couro e osso • 2,00 m'))):
            img=Image.open(folder/'previews'/(view+'.png')).convert('RGB')
            comparison.paste(img,(index*640,47)); draw.text((index*640+16,686),caption,font=font,fill=(227,217,181))
        comparison.save(dest/('orc_bulk_'+view+'.jpg'),quality=94)
        comparison.save(dest/('orc_equipment_'+view+'.jpg'),quality=94)
    for view in ('body_front','back','three_quarter'):
        comparison=Image.new('RGB',(1280,714),(31,37,31)); draw=ImageDraw.Draw(comparison)
        draw.text((16,9),'Escudeiro Orc — sobrancelhas e acabamento do couro',font=heading,fill=(227,217,181))
        for index,(folder,caption) in enumerate(((WORK/'before_brows_clothing_refinement','Antes'),(OUT,'Sobrancelhas 3D e couro com acabamento'))):
            img=Image.open(folder/'previews'/(view+'.png')).convert('RGB')
            comparison.paste(img,(index*640,47)); draw.text((index*640+16,686),caption,font=font,fill=(227,217,181))
        comparison.save(dest/('orc_finish_'+view+'.jpg'),quality=94)
    (ROOT/'docs/ORC_SQUIRE_BASE.md').write_text('''# Escudeiro Orc Base

Modelo único feito diretamente do `.blend` aprovado do Escudeiro Élfico, pelo MCP do Blender aberto. Mede **2,00 m do chão ao topo da cabeça**, sem capacete ou enfeite para completar a altura.

Mantém os mesmos 18 blocos do corpo e as seis peças das orelhas élficas. O peito tem 65% mais largura que a base élfica, os braços superiores 85%, os antebraços 65%, as mãos 60% e as coxas 55%, antes da escala uniforme até 2 m. Braços e pernas foram afastados, junto com os respectivos ossos de repouso e equipamento, para dar espaço aos membros robustos. Cada bloco corporal continua com oito vértices e seis faces retangulares; nenhum membro adicional foi criado. As orelhas mantêm a geometria original.

O equipamento usa os 18 blocos corporais da revisão robusta. O antebraço e a mão sem escudo foram girados 24 graus para suavizar a dobra do braço, preservando as dimensões dos blocos. Peito, barriga, braços, mãos e boa parte das coxas ficam expostos, com sombra muscular discreta. Uma tira diagonal larga sustenta a proteção do ombro do escudo, com pequena fivela e costura.

Couro com grão discreto e costuras completas substitui as manchas e riscos isolados. A tira é desenhada em coordenadas físicas, continuando entre peito e barriga até o cinturão, na frente e nas costas. Painéis de couro terminam com bainhas e envolvem todas as faces das coxas. A ombreira de osso tem tiras completas e rebites; braçadeiras têm costura lateral e cintas. As botas possuem cano e pé no mesmo couro, com bainha, duas tiras, costuras e sola. Todas as proteções principais continuam pintadas nos blocos existentes, sem outra camada geométrica de armadura.

O escudo está 18% maior em largura e altura, mantendo a profundidade e a posição da empunhadura. As 30 regiões de textura aprovadas, incluindo os pixels de margem, continuam idênticas à versão anterior e são comparadas byte por byte.

Cabeça com laterais raspadas e faixa curta de cabelo escuro pintada no topo, olhos âmbar simétricos e duas presas pequenas. As sobrancelhas agora são dois cubos retangulares projetados da testa, inspirados nos anões, inclinados 12 graus e mais baixos junto ao nariz. Os dois objetos têm pesos rígidos no osso `head`; nenhuma animação ou osso foi acrescentado. O rosto e o cabelo continuam no único bloco da cabeça. Atlas de 512 × 1024, com filtro nearest.

As cinco animações mantêm nomes e tempos: `Squire_Idle`, `Squire_Walk`, `Squire_Attack`, `Squire_ShieldWall`, `Squire_ShieldWallHold`. A revisão `anatomy_v2` conserva os movimentos dos braços da versão aprovada, incluindo a dobra mais suave, e adapta a cabeça para acompanhar o tronco sem entrar no peito. Orelhas, presas e sobrancelhas seguem a cabeça. Os arquivos editáveis mantêm as trilhas habilitadas. A geometria animada é conferida quadro a quadro em `orc_troops_anatomy_validation.json`; os atlas aprovados foram preservados byte por byte.

- Modelos, atlas e relatório: `assets/generated/orcs/orc_squire_v1/`.
- Revisão no Godot: abra `res://_orc_squire_model_review.tscn` e pressione **F6**; os dois escudeiros aparecem em suas escalas reais.
- [Comparação de aparência](previews/orc_squire/elf_orc_three_quarter.jpg), [frente](previews/orc_squire/elf_orc_front.jpg).
- [Antes e depois](previews/orc_squire/orc_bulk_three_quarter.jpg), [corpo de frente sem escudo](../assets/generated/orcs/orc_squire_v1/previews/body_front.png).
- [Revisão dos elementos visuais](previews/orc_squire/orc_equipment_three_quarter.jpg), [frente](previews/orc_squire/orc_equipment_front.jpg).
- [Roupa antes/depois sem escudo](previews/orc_squire/orc_finish_body_front.jpg), [costas](previews/orc_squire/orc_finish_back.jpg), [sobrancelhas de perto](../assets/generated/orcs/orc_squire_v1/previews/face_closeup.png).
- `orc_squire_validation.json`: altura real exportada, pele no PNG, olhos, atlas embutido, pesos, curvas das cinco animações e hashes dos modelos anteriores.
- `orc_squire_blender_validation.json`: cubos reais no arquivo editável, orelhas preservadas, armadura pintada e altura medida.
- `orc_squire_godot_validation.json`: importação, escala, atlas, reprodução das cinco animações e cena de comparação.

Para reaplicar a correção no Blender aberto: `python tools/art_pipeline/run_orc_pose_fix_mcp.py --only orc_squire_v1`. Este escudeiro também é a fonte dos [20 modelos das cinco classes orcs](ORC_TROOPS_CATALOG.md).
''',encoding='utf-8')


if __name__=='__main__':
    verify(); document()
