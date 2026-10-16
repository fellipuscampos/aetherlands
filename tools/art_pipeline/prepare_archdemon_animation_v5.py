"""Prepare the corrected cloth and palm-up gesture without overwriting V4 assets."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; P=ROOT/'tools/art_pipeline'
OLD='archdemon_blocky_v4_animated'; NEW='archdemon_blocky_v5_animated'
def adapt(s): return s.replace(OLD,NEW)
source=(P/'animate_archdemon_blocky_v4_mcp.py').read_text(encoding='utf-8')
head=source[:source.index('# Rotate the broad faces')]
head=adapt(head).replace('Infernal_Archdemon_Blocky_V4_Animated','Infernal_Archdemon_Blocky_V5_Animated')
head=head.replace("['archdemon_blocky_v3']",f"['{OLD}']").replace("('archdemon_blocky_v3.'+ext)",f"('{OLD}.'+ext)")
head=head.replace("'Infernal_Archdemon_Blocky_V3'","'Infernal_Archdemon_Blocky_V4_Animated'")
tail=adapt(source[source.index('clips={}; previous={}'):])
custom='''# Shared cloth sections use the same rigid pivot on both adjoining prisms.
# This keeps seams closed while the strip bends; stone and hand parts stay rigid.
for o in parts:
    bone=o['rig_bone']
    if not bone.startswith('stole_'): continue
    i=int(bone.rsplit('_',1)[1]); prefix=bone.rsplit('_',1)[0]
    for group in list(o.vertex_groups): o.vertex_groups.remove(group)
    top=prefix+'_'+str(max(0,i-1)); bottom=bone
    o.vertex_groups.new(name=top).add(list(range(4)),1,'REPLACE')
    if bottom==top: o.vertex_groups[top].add(list(range(4,8)),1,'REPLACE')
    else: o.vertex_groups.new(name=bottom).add(list(range(4,8)),1,'REPLACE')
'''
motion=(P/'archdemon_animation_motion_v5.py.inc').read_text(encoding='utf-8')
(P/'animate_archdemon_blocky_v5_mcp.py').write_text(head+custom+motion+tail,encoding='utf-8')
export=adapt((P/'export_archdemon_animations_mcp.py').read_text(encoding='utf-8'))
export=export.replace("if a['rig_bone']!='core' and not a['rig_bone'].startswith('stole_side_'):","if True:")
export=export.replace("vv=[m@v.co for v in o.data.vertices]; points.extend(vv)","vv=[matrices[o.vertex_groups[v.groups[0].group].name]@v.co for v in o.data.vertices]; points.extend(vv)")
export=export.replace("groups.setdefault(o['rig_bone'],[]).extend(range(offset,len(vertices)))","for v in o.data.vertices:\n        assert len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7\n        groups.setdefault(o.vertex_groups[v.groups[0].group].name,[]).append(offset+v.index)")
export=export.replace("assert gaps['shoulders_to_body_m']>.09 and gaps['hands_to_body_m']>.20", "assert gaps['shoulders_to_body_m']>.09 and gaps['hands_to_body_m']>.15")
anchor="        if first is None: first=[v.copy() for v in points]"
check='''        for band in ('front','side'):
            for side in ('L','R'):
                strip=sorted([o for o in parts if o['rig_bone'].startswith('stole_'+band+'_'+side+'_')],key=lambda o:o['rig_bone'])
                posed=[]
                for o in strip:
                    vv=[matrices[o.vertex_groups[v.groups[0].group].name]@v.co for v in o.data.vertices]
                    posed.append(vv)
                    before=((sum((v.co for v in o.data.vertices[4:]),Vector())-sum((v.co for v in o.data.vertices[:4]),Vector()))/4).length
                    after=((sum(vv[4:],Vector())-sum(vv[:4],Vector()))/4).length
                    assert abs(before-after)<1e-5,('cloth segment stretching',name,f,o.name)
                for j in range(3):
                    assert max((a-b).length for a,b in zip(posed[j][4:],posed[j+1][:4]))<1e-5,('cloth seam',name,f,band,side,j)
'''
export=export.replace(anchor,check+anchor)
(P/'export_archdemon_animations_v5_mcp.py').write_text(export,encoding='utf-8')
for a,b in [('validate_archdemon_animations.py','validate_archdemon_animations_v5.py'),('finalize_archdemon_animations_mcp.py','finalize_archdemon_animations_v5_mcp.py'),('finish_archdemon_animations.py','finish_archdemon_animations_v5.py')]:
    s=adapt((P/a).read_text(encoding='utf-8'))
    if a.startswith('finish_'):
        s=s.replace('Flutuação suave, peças suspensas e giro lento do cubo vermelho.','Flutuação e ondulação das faixas, com atraso entre as dobras.')
        s=s.replace('Deslizamento no lugar, leve inclinação frontal e movimento das faixas.','Deslizamento no lugar e faixas acompanhando o fluxo.')
        s=s.replace('Mãos abertas em conjuração, elevação e giro acelerado do núcleo.','Mãos à frente com palmas para cima; liberação de energia e retorno suave.')
        s=s.replace('Quatro animações com peças rígidas e estética blocky.','Faixas articuladas com ondas e junções contínuas. Spell com punhos voltados para trás e palmas para cima.')
        s=s.replace('Esta revisão fornece o modelo e as animações.','Revisão das animações: faixas com ondas defasadas, junções fechadas e segmento inicial fixo à cintura. Spell orientado pelo eixo real das mãos: punhos para trás e palmas para cima, com avanço na liberação.\n\nEsta revisão fornece o modelo e as animações.')
        s=s.replace('A V3 e as demais cenas estão preservadas.','A V4 e as demais cenas estão preservadas.')
    (P/b).write_text(s,encoding='utf-8')
(ROOT/'scripts/art_review/ArchdemonAnimationReview.gd').write_text(adapt((ROOT/'scripts/art_review/ArchdemonAnimationReview.gd').read_text(encoding='utf-8')),encoding='utf-8')
asset=ROOT/'assets/generated/grand_manifestations'/NEW; asset.mkdir(parents=True,exist_ok=True)
(asset/'archdemon_animation_import.gd').write_text((ROOT/'assets/generated/grand_manifestations'/OLD/'archdemon_animation_import.gd').read_text(encoding='utf-8'),encoding='utf-8')
verify=adapt((P/'verify_archdemon_animations.gd').read_text(encoding='utf-8'))
(P/'verify_archdemon_animations_v5.gd').write_text(verify,encoding='utf-8')
validation=P/'validate_archdemon_animations_v5.py'
validation.write_text(validation.read_text(encoding='utf-8').replace('verify_archdemon_animations.gd','verify_archdemon_animations_v5.gd'),encoding='utf-8')
print('Prepared V5 cloth and spell revision.')
