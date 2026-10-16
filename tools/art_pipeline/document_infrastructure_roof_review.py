"""Compare actual saved renders before/after and document architectural choices."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps

ROOT=Path(__file__).resolve().parents[2]
REVIEW=ROOT/'art_source/infrastructure_roof_review'
entries=json.loads((REVIEW/'source_before.json').read_text(encoding='utf-8'))
races={'human':('Humanos','humans'),'elf':('Elfos','elves'),'dwarf':('Anões','dwarves'),'orc':('Orcs','orcs')}
roles={'market':'Mercado','farm':'Fazenda','workshop':'Oficina','university':'Universidade','arcane_shrine':'Santuário Arcano'}
assets=[]
canvas=Image.new('RGB',(1760,1340),(24,31,39))
draw=ImageDraw.Draw(canvas)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',21)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',15)
for col,(civ,(label,plural)) in enumerate(races.items()):
    draw.text((col*440+12,12),label,font=font,fill='white')
    draw.text((col*440+12,42),'Antes',font=small,fill='#bac9d6')
    draw.text((col*440+232,42),'Depois',font=small,fill='#bac9d6')
    for row,(role,title) in enumerate(roles.items()):
        entry=next(e for e in entries if e['civilization']==civ and e['role']==role)
        folder=entry['asset']
        old=ROOT/'art_source/infrastructure_before_roof_review'/plural/folder
        new=ROOT/'assets/generated'/plural/'buildings'/folder
        for offset,path in ((0,old),(220,new)):
            image=ImageOps.contain(Image.open(path/'previews/three_quarter.png').convert('RGB'),(215,215))
            canvas.paste(image,(col*440+offset,row*252+72))
        draw.text((col*440+12,row*252+290),title,font=small,fill='white')
        assets.append({'civ':civ,'label':label,'role':role,'name':title,'before':'../infrastructure_before_roof_review/'+plural+'/'+folder+'/previews/','after':'../../assets/generated/'+plural+'/buildings/'+folder+'/previews/','changed':bool(entry['roofs'])})
canvas.save(REVIEW/'before_after.jpg',quality=94)
payload=json.dumps(assets,ensure_ascii=False).replace('</',r'<\/')
html='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Revisão dos telhados de infraestrutura</title><style>
*{box-sizing:border-box}body{margin:0;background:#171e26;color:#edf2f6;font:16px system-ui,sans-serif}main{max-width:1800px;padding:28px;margin:auto}h1{font-size:clamp(24px,3vw,38px);margin:0}p{line-height:1.6;color:#bac9d6}a{color:#a8d6ff}.controls{display:flex;gap:20px;flex-wrap:wrap;margin:24px 0}label{display:grid;gap:8px}select{font:inherit;padding:10px;background:#293745;color:white;border:1px solid #50677b;border-radius:7px}.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:20px}article{background:#222e3a;border-radius:12px;padding:16px}h2{font-size:20px;margin:0 0 12px}.pair{display:grid;grid-template-columns:repeat(2,1fr);gap:10px}figure{margin:0}img{display:block;width:100%;aspect-ratio:1;object-fit:contain}figcaption{margin-bottom:8px;color:#bac9d6}.references{display:grid;grid-template-columns:repeat(4,1fr);gap:14px}.references article{padding:12px}.references h2{font-size:17px}footer{margin-top:24px}@media(max-width:850px){.grid{grid-template-columns:1fr}.references{grid-template-columns:repeat(2,1fr)}}@media(max-width:500px){main{padding:16px}}
</style><main><h1>Revisão dos telhados e apoios</h1><p>20 prédios conferidos com as construções anteriores. 23 telhados retangulares corrigidos em 19 modelos: beirais retos e cantos definidos. Oficina e universidade élficas agora usam duas águas. A universidade orc e os telhados hexagonais das torres e do silo foram preservados. Travessas acrescentadas nas bancas humana e élficas.</p><div class="controls"><label>Categoria<select id="role"><option value="market">Mercado</option><option value="farm">Fazenda</option><option value="workshop">Oficina</option><option value="university">Universidade</option><option value="arcane_shrine">Santuário Arcano</option></select></label><label>Vista<select id="view"><option value="three_quarter">Três quartos</option><option value="game_top">Mapa</option><option value="top">Topo</option><option value="back">Traseira</option></select></label></div><div class="grid" id="grid"></div><h2 style="margin-top:30px">Referências anteriores do jogo</h2><p>As cidades demonstram as coberturas de quatro águas; os salões militares demonstram as duas águas. As superfícies continuam planas e os degraus das telhas seguem o estilo existente.</p><div class="references" id="references"></div><footer><a href="before_after.jpg">Comparação dos vinte prédios</a> · <a href="../infrastructure_buildings_review/index.html">Catálogo atualizado</a> · <a href="../../docs/INFRASTRUCTURE_ROOF_REVIEW.md">Alterações e validação</a></footer></main><script>
const assets=__ASSETS__,role=document.querySelector('#role'),view=document.querySelector('#view'),grid=document.querySelector('#grid');
function show(){grid.replaceChildren();for(const asset of assets.filter(a=>a.role===role.value)){const card=document.createElement('article'),title=document.createElement('h2'),pair=document.createElement('div');title.textContent=asset.label+(asset.changed?'':' — preservado');pair.className='pair';for(const [key,label] of [['before','Antes'],['after','Depois']]){const figure=document.createElement('figure'),caption=document.createElement('figcaption'),link=document.createElement('a'),img=document.createElement('img');caption.textContent=label;img.src=asset[key]+view.value+'.png';img.alt=asset.name+' — '+asset.label+' — '+label;link.href=img.src;link.append(img);figure.append(caption,link);pair.append(figure);}card.append(title,pair);grid.append(card);}}
const races=[['human','Humanos','humans',''],['elf','Elfos','elves','elf_'],['dwarf','Anões','dwarves','dwarf_'],['orc','Orcs','orcs','orc_']];
for(const [civ,label,plural,prefix] of races){const card=document.createElement('article'),title=document.createElement('h2');title.textContent=label;card.append(title);for(const stem of ['city_level_1_hex_v1','warrior_hall_hex_v1']){const link=document.createElement('a'),img=document.createElement('img');img.src='../../assets/generated/'+plural+'/buildings/'+prefix+stem+'/previews/three_quarter.png';img.alt=label+' — referência '+stem;link.href=img.src;link.append(img);card.append(link);}document.querySelector('#references').append(card);}
role.addEventListener('change',show);view.addEventListener('change',show);show();
</script></html>'''
html=html.replace('Travessas acrescentadas nas bancas humana e élficas.','Travessas acrescentadas nas bancas humana e élficas; eixo e mancal acrescentados no regulador do santuário anão.')
html=html.replace('Revisão dos telhados e apoios','Revisão dos telhados, apoios e faces')
html=html.replace('A universidade orc e os telhados hexagonais','O telhado da universidade orc e os telhados hexagonais')
html=html.replace('— preservado','— telhado preservado')
html=html.replace('<div class="controls">','<p>Também foram corrigidas faces coplanares expostas em 18 modelos, incluindo copas, molduras, canteiros, bancos, pilares e detalhes de ferro. A auditoria final não detectou sobreposições expostas nas vistas verificadas; a geometria exportada é comparada com a fonte auditada.</p><div class="controls">',1)
(REVIEW/'index.html').write_text(html.replace('__ASSETS__',payload),encoding='utf-8')
validation=json.loads((ROOT/'docs/infrastructure_roof_review_validation.json').read_text(encoding='utf-8'))
body='# Revisão de telhados e apoios da infraestrutura\n\n'
body+='[Comparação antes/depois e referências anteriores](../art_source/infrastructure_roof_review/index.html). Revisão realizada no Blender aberto, pelo MCP.\n\n'
body+='Os modelos anteriores usam tanto telhados de duas águas quanto coberturas piramidais e hexagonais. O problema específico da infraestrutura era o chanfro aplicado a todos os cantos de cada fiada, inclusive nas coberturas retangulares. Esse recorte dava uma silhueta arredondada e repetia o mesmo detalhe entre civilizações.\n\n'
body+='Foram corrigidos **23 telhados em 19 modelos**, mantendo as fiadas planas do estilo existente, a altura da cobertura, os materiais e as construções aprovadas. A oficina e a universidade élficas receberam coberturas de duas águas para aproximá-las dos salões élficos. As demais coberturas de quatro águas mantêm sua função de pavilhão. A cobertura da universidade orc, de planta hexagonal, foi revisada e preservada. O silo humano e as pequenas torres também mantêm suas coberturas hexagonais.\n\n'
body+='Foram acrescentadas três travessas: uma na banca lateral do mercado humano e duas nos quiosques do mercado élfico. Elas fecham as pequenas folgas entre os pilares e os telhados. Os layouts e materiais foram preservados. Além dos telhados, apenas as peças identificadas na revisão de junções receberam ajustes de geometria.\n\n'
body+='As alturas e proporções seguem cada civilização: ardósia azul e alvenaria humana; verde alto e madeira esbelta élfica; ardósia escura baixa, granito e cobre anões; telhados ferrugem, madeira grossa e ferro orcs.\n\n'
body+='[Validação específica](infrastructure_roof_review_validation.json): '+str(validation['reviewed_assets'])+' modelos, peças aprovadas preservadas, beirais sem chanfros artificiais, continuidade das fiadas, contato dos apoios e backup íntegro.\n\n'
body+='[Arquivos e texturas](infrastructure_buildings_validation.json), [fontes editáveis](infrastructure_buildings_source_validation.json), [importação Godot](infrastructure_buildings_godot_validation.json) e [testes do jogo](infrastructure_buildings_game_validation.json). Todos os IDs e o modelo único por categoria permanecem preservados.\n\n'
body+='Também foram acrescentados o eixo e o mancal do regulador no santuário anão, conectando a roda à base de pedra. As verificações conferem o contato da roda, do cubo, do eixo, do mancal e da base.\n\n'
repairs=json.loads((REVIEW/'face_repairs.json').read_text(encoding='utf-8'))
surface_audit=json.loads((REVIEW/'after_face_repairs.json').read_text(encoding='utf-8'))
assert surface_audit['exposed_overlap_faces']==0
body+=f'## Faces que causavam cintilação\n\nForam ajustadas **{sum(len(r["parts"]) for r in repairs)} peças em {len(repairs)} modelos**, corrigindo {sum(r["exposed_overlap_faces_before"] for r in repairs)} pares de faces coplanares expostos detectados nas duas passagens. A auditoria cruza triângulos em planos coincidentes e testa pontos interiores e próximos aos cantos contra uma BVH de toda a geometria do prédio, nas vistas de jogo e direções laterais. Faces internas de contato entre sólidos não são tratadas como defeitos visuais.\n\n'
body+='As copas agora diminuem em largura e profundidade; molduras e canteiros usam juntas sem sobreposição; os encostos dos bancos recuam em relação aos assentos; fustes terminam dentro dos capitéis; detalhes de ferro e o canal de mana recebem encaixes que evitam faces no mesmo plano.\n\n'
body+='[Auditoria inicial](../art_source/infrastructure_roof_review/before_face_repairs.json), [segunda passagem](../art_source/infrastructure_roof_review/after_face_repairs_pass1.json), [peças corrigidas](../art_source/infrastructure_roof_review/face_repairs.json) e [auditoria final](../art_source/infrastructure_roof_review/after_face_repairs.json): **zero sobreposições expostas detectadas** nos vinte modelos. A verificação dos arquivos compara a geometria real do GLB com a fonte nativa auditada.\n\n'
body+='Backup: `art_source/infrastructure_before_roof_review`, com os vinte modelos anteriores, quatro vistas por modelo e manifesto SHA256.\n'
(ROOT/'docs/INFRASTRUCTURE_ROOF_REVIEW.md').write_text(body,encoding='utf-8')
for path in (ROOT/'art_source/building_architecture_review/index.html',ROOT/'art_source/infrastructure_buildings_review/index.html'):
    content=path.read_text(encoding='utf-8')
    marker='href="../infrastructure_roof_review/index.html"'
    if marker not in content:
        link='<a '+marker+'>Revisão da infraestrutura: telhados e faces, antes e depois</a>'
        if '<footer>' in content: content=content.replace('<footer>','<footer>'+link+' · ',1)
        else: content=content.replace('</main>','<p>'+link+'</p></main>',1)
        path.write_text(content,encoding='utf-8')
print(json.dumps({'reviewed':len(entries),'corrected':validation['corrected_assets'],'gallery':str(REVIEW/'index.html')}))
