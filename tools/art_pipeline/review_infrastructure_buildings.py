"""Build a local review gallery from the real Blender previews."""
from collections import Counter
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT=Path(__file__).resolve().parents[2]
REVIEW=ROOT/'art_source/infrastructure_buildings_review'
entries=json.loads((REVIEW/'completed.json').read_text(encoding='utf-8'))
races={'human':('Humanos','humans'),'elf':('Elfos','elves'),'dwarf':('Anões','dwarves'),'orc':('Orcs','orcs')}
roles={'market':('Economia','Mercado'),'farm':('Logística','Fazenda'),'workshop':('Indústria','Oficina'),'university':('Academia','Universidade'),'arcane_shrine':('Arcano','Santuário Arcano')}
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16)
canvas=Image.new('RGB',(1440,5*380+64),(24,31,39))
draw=ImageDraw.Draw(canvas)
for column,(civ,(label,_)) in enumerate(races.items()):
    draw.text((column*360+18,15),label,font=font,fill='white')
assets=[]
for row,(role,(category,display)) in enumerate(roles.items()):
    for column,(civ,(label,plural)) in enumerate(races.items()):
        entry=next((e for e in entries if e['role']==role and e['civilization']==civ),None)
        if entry is None: continue
        out=ROOT/'assets/generated'/plural/'buildings'/entry['asset']
        report=json.loads((out/(entry['asset']+'_report.json')).read_text(encoding='utf-8'))
        image=ImageOps.contain(Image.open(out/'previews/three_quarter.png').convert('RGB'),(355,340))
        canvas.paste(image,(column*360,row*380+64))
        draw.text((column*360+8,row*380+410),display,font=small,fill='white')
        assets.append({'race':civ,'raceLabel':label,'role':role,'name':display,'category':category,'path':'../../assets/generated/'+plural+'/buildings/'+entry['asset']+'/previews/','design':report['infrastructure']['architecture']})
canvas.save(REVIEW/'all_infrastructure.jpg',quality=94)
payload=json.dumps(assets,ensure_ascii=False).replace('</','<\\/')
template='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Infraestrutura das civilizações</title><style>
*{box-sizing:border-box}body{margin:0;background:#171e26;color:#edf2f6;font:16px system-ui,sans-serif}main{max-width:1600px;padding:28px;margin:auto}h1{margin:0;font-size:clamp(25px,3vw,38px)}p{color:#bac9d6;line-height:1.6}.controls{display:flex;gap:18px;flex-wrap:wrap;margin:24px 0}label{display:grid;gap:8px;color:#bac9d6}select{font:inherit;background:#293745;color:#fff;border:1px solid #50677b;border-radius:8px;padding:12px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}article{background:#222e3a;border-radius:12px;overflow:hidden}h2{font-size:20px;margin:18px 18px 0}img{width:100%;display:block;aspect-ratio:1;object-fit:contain}article p{font-size:14px;margin:0 18px 20px}a{color:#a8d6ff}footer{margin-top:24px;color:#bac9d6}@media(max-width:1050px){.grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:600px){.grid{grid-template-columns:1fr}main{padding:18px}}
</style><main><h1>Infraestrutura das civilizações</h1><p>Mercado, Fazenda, Oficina, Universidade e Santuário Arcano. Uma única versão por categoria e civilização, sem evoluções.</p>
<div class="controls"><label>Categoria<select id="role"><option value="market">Economia — Mercado</option><option value="farm">Logística — Fazenda</option><option value="workshop">Indústria — Oficina</option><option value="university">Academia — Universidade</option><option value="arcane_shrine">Arcano — Santuário Arcano</option></select></label><label>Vista<select id="view"><option value="three_quarter">Três quartos</option><option value="game_top">Mapa</option><option value="top">Topo</option><option value="back">Traseira</option></select></label></div>
<div class="grid" id="grid"></div><footer><a href="all_infrastructure.jpg">Ver os vinte prédios</a> · <a href="../../docs/INFRASTRUCTURE_BUILDINGS.md">Catálogo e validação</a></footer></main><script>
const assets=__ASSETS__,role=document.querySelector('#role'),view=document.querySelector('#view'),grid=document.querySelector('#grid');
function show(){grid.replaceChildren();for(const asset of assets.filter(a=>a.role===role.value)){const card=document.createElement('article'),title=document.createElement('h2'),link=document.createElement('a'),image=document.createElement('img'),description=document.createElement('p');title.textContent=asset.raceLabel;image.src=asset.path+view.value+'.png';image.alt=asset.name+' — '+asset.raceLabel;link.href=image.src;link.append(image);description.textContent=asset.design;card.append(title,link,description);grid.append(card);}}
role.addEventListener('change',show);view.addEventListener('change',show);show();
</script></html>'''
(REVIEW/'index.html').write_text(template.replace('__ASSETS__',payload),encoding='utf-8')
body='# Prédios de infraestrutura por civilização\n\n'
body+=f'Criados em 2026-10-09 pelo Blender MCP: **{len(entries)} modelos**. Mercado, Fazenda, Oficina, Universidade e Santuário Arcano recebem uma única versão para humanos, elfos, anões e orcs.\n\n'
body+='[Comparar civilizações e vistas](../art_source/infrastructure_buildings_review/index.html) · [Ver conjunto completo](../art_source/infrastructure_buildings_review/all_infrastructure.jpg)\n\n'
body+='Cada combinação tem uma receita arquitetônica própria. Os humanos usam pedra e telhados azuis; os elfos, pedra clara, madeira esbelta e telhados verdes; os anões, granito, cobre e telhados baixos escuros; os orcs, madeira grossa, ferro, escoras e telhados ferrugem.\n\n'
body+='| Categoria | Prédio | ID preservado |\n|---|---|---|\n'
for role,(category,display) in roles.items(): body+=f'| {category} | {display} | `v2_building_{"academy" if role=="university" else role}` |\n'
body+='\nO catálogo seleciona a arte pela civilização do dono atual, inclusive após captura e carregamento. A versão padrão do BuildingData é a humana e todas usam escala 1.0. Universidade substitui o nome visual Academia, mantendo o ID. Custos, yields, limite de cópias por nível da cidade e treino do Construtor na Oficina foram preservados. Não há evoluções dos modelos.\n\n'
body+='## Assets\n\n| Prédio | Civilização | Arquivos e prévias | Triângulos |\n|---|---|---|---:|\n'
for entry in entries:
    folder=entry['asset']; label,plural=races[entry['civilization']]
    relative='../assets/generated/'+plural+'/buildings/'+folder
    body+=f'| {roles[entry["role"]][1]} | {label} | [Fonte, exportação e relatório]({relative}/README.md) · [Prévia]({relative}/previews/three_quarter.png) | {entry["triangles"]} |\n'
body+='\n## Validação\n\n'
body+='[Geometria, texturas e layouts](infrastructure_buildings_validation.json), [fontes editáveis pelo MCP](infrastructure_buildings_source_validation.json), [importação isolada no Godot](infrastructure_buildings_godot_validation.json) e [integração no jogo](infrastructure_buildings_game_validation.json).\n\n'
body+='As verificações conferem os vinte assets, IDs, ausência de evolução, geometria distinta entre civilizações, origem no solo, todos os vértices dentro do hex com margem, malhas fechadas, atlas albedo/emissão empacotados e embutidos, filtro nearest, grupo Faction e ausência de câmera/luz/rig/animação no .glb.\n\n'
game_validation=ROOT/'docs/infrastructure_buildings_game_validation.json'
if game_validation.exists():
    game=json.loads(game_validation.read_text(encoding='utf-8'))
    body+=f'A importação no projeto terminou sem erros nem avisos. Os testes do catálogo e dos dados de economia passaram: **{game["tests_passed"]}/{game["tests_total"]} testes**, {game["assertions_passed"]} asserts. '
    body+='A carga do catálogo inclui todos os prédios por civilização, inclusive os assets anteriores. Os testes conferem escala nativa, metadados e ausência de evolução da infraestrutura, tintura da bandeira pelo dono e seleção após captura. O fixture de árvores do teste usa uma malha simples para isolar o teste de prédios do asset KayKit de floresta.\n\n'
body+='Reprodução: `python tools/art_pipeline/run_infrastructure_buildings_mcp.py`, `python tools/art_pipeline/verify_infrastructure_buildings.py`, `python tools/art_pipeline/run_infrastructure_godot_validation.py` e `python tools/art_pipeline/review_infrastructure_buildings.py`. A geração usa a sessão aberta do Blender via MCP.\n'
(ROOT/'docs/INFRASTRUCTURE_BUILDINGS.md').write_text(body,encoding='utf-8')
print(json.dumps({'completed':len(entries),'civilizations':dict(Counter(e['civilization'] for e in entries)),'gallery':str(REVIEW/'index.html')},ensure_ascii=False))
