"""Package the individual forest kit and build a real-render review gallery."""
from collections import Counter
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/generated/nature/temperate_forest_v1'
REVIEW=ROOT/'art_source/temperate_forest_review'
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
if 'previous_scenes' in manifest:
    (REVIEW/'source_scenes_before.json').write_text(json.dumps(manifest.pop('previous_scenes'),ensure_ascii=False,indent=2),encoding='utf-8')
for report in manifest['assets']:
    name=report['asset']
    report['blend']='models/'+name+'/'+name+'.blend'
    report['glb']='models/'+name+'/'+name+'.glb'
    report['preview']='models/'+name+'/previews/three_quarter.png'
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
assert all(json.loads((ROOT/'docs'/name).read_text(encoding='utf-8'))['status']=='PASS' for name in ('temperate_forest_validation.json','temperate_forest_source_validation.json','temperate_forest_godot_validation.json'))
categories={'main_tree':'Árvore principal','small_tree':'Árvore menor','shrub':'Arbusto','fallen_log':'Tronco caído','decoration':'Decoração'}
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',21)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',15)
canvas=Image.new('RGB',(1800,824),(24,31,39)); draw=ImageDraw.Draw(canvas)
assets=[]
for index,report in enumerate(manifest['assets']):
    name=report['asset']; col,row=index%5,index//5
    folder=OUT/'models'/name
    image=ImageOps.contain(Image.open(folder/'previews/three_quarter.png').convert('RGB'),(354,350))
    canvas.paste(image,(col*360,row*412))
    draw.text((col*360+10,row*412+356),report['display_name'],font=font,fill='white')
    draw.text((col*360+10,row*412+384),str(report['triangles'])+' triângulos · altura '+f'{report["dimensions"][2]:.2f}',font=small,fill='#bac9d6')
    assets.append({'id':name,'name':report['display_name'],'category':report['category'],'triangles':report['triangles'],'height':round(report['dimensions'][2],2),'path':'../../assets/generated/nature/temperate_forest_v1/models/'+name+'/','scene':'../../assets/generated/nature/temperate_forest_v1/godot/'+name+'.tscn'})
canvas.save(REVIEW/'kit_overview.jpg',quality=95)
template='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Kit modular de floresta temperada</title><style>
*{box-sizing:border-box}body{margin:0;background:#171e26;color:#edf2f6;font:16px system-ui,sans-serif}main{max-width:1700px;padding:28px;margin:auto}h1{font-size:clamp(25px,3vw,38px);margin:0}p{line-height:1.6;color:#bac9d6}a{color:#a8d6ff}.controls{display:flex;gap:20px;flex-wrap:wrap;margin:24px 0}label{display:grid;gap:8px}select{font:inherit;padding:12px;background:#293745;color:white;border:1px solid #50677b;border-radius:8px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}article{background:#222e3a;border-radius:12px;overflow:hidden}h2{font-size:20px;margin:16px}img{display:block;width:100%;aspect-ratio:1;object-fit:contain}article p{margin:10px 16px;font-size:14px}.files{display:flex;gap:14px;flex-wrap:wrap;padding:0 16px 18px}footer{margin-top:24px;color:#bac9d6}@media(max-width:1100px){.grid{grid-template-columns:repeat(3,1fr)}}@media(max-width:800px){.grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:500px){.grid{grid-template-columns:1fr}main{padding:16px}}
</style><main><h1>Kit modular de floresta temperada</h1><p>4 árvores principais, 2 árvores jovens, 2 arbustos, um tronco caído e uma pedra com musgo e raiz. Peças independentes para compor o mapa. 1.202 triângulos no kit inteiro, uma malha por asset e um material compartilhado com atlas pixelizado de 512 × 512.</p><div class="controls"><label>Categoria<select id="category"><option value="all">Todos os assets</option><option value="main_tree">Árvores principais</option><option value="small_tree">Árvores menores</option><option value="shrub">Arbustos</option><option value="details">Tronco e decoração</option></select></label><label>Vista<select id="view"><option value="three_quarter">Detalhe em três quartos</option><option value="game_top">Mapa — mesma escala entre os assets</option><option value="top">Topo</option><option value="back">Traseira</option></select></label></div><div class="grid" id="grid"></div><footer><a href="kit_overview.jpg">Visão geral</a> · <a href="../../assets/generated/nature/temperate_forest_v1/README.md">Arquivos e guia para Godot</a> · <a href="../../docs/temperate_forest_validation.json">Validação dos GLBs</a></footer></main><script>
const assets=__ASSETS__,category=document.querySelector('#category'),view=document.querySelector('#view'),grid=document.querySelector('#grid');
function show(){grid.replaceChildren();for(const asset of assets.filter(a=>category.value==='all'||a.category===category.value||(category.value==='details'&&['fallen_log','decoration'].includes(a.category)))){const card=document.createElement('article'),title=document.createElement('h2'),preview=document.createElement('a'),img=document.createElement('img'),text=document.createElement('p'),files=document.createElement('div');title.textContent=asset.name;img.src=asset.path+'previews/'+view.value+'.png';img.alt=asset.name;preview.href=img.src;preview.append(img);text.textContent=asset.triangles+' triângulos · altura '+asset.height.toFixed(2)+' · escala base 1.0';files.className='files';for(const [label,path] of [['Blender',asset.path+asset.id+'.blend'],['GLB',asset.path+asset.id+'.glb'],['Cena Godot',asset.scene]]){const link=document.createElement('a');link.textContent=label;link.href=path;files.append(link);}card.append(title,preview,text,files);grid.append(card);}}
category.addEventListener('change',show);view.addEventListener('change',show);show();
</script></html>'''
(REVIEW/'index.html').write_text(template.replace('__ASSETS__',json.dumps(assets,ensure_ascii=False).replace('</',r'<\/')),encoding='utf-8')
body='# Kit modular de floresta temperada\n\n'
body+='Dez assets independentes criados pelo **MCP do Blender**. Estética voxel/blocky, folhas sólidas e textura pixelizada, coerente com as árvores e construções existentes do jogo. O kit contém somente árvores e props separados para composição manual ou procedural.\n\n'
body+='[Galeria com quatro vistas](../../../../art_source/temperate_forest_review/index.html) · [Manifesto dos assets](manifest.json).\n\n'
body+='## Arquivos\n\n'
body+='- `godot/`: cenas `.tscn` para arrastar no mapa e malhas `.res` para MultiMesh; todas usam `forest_pixel_material.tres`.\n- `models/<asset>/`: exportação `.glb`, fonte editável `.blend` com textura empacotada, relatório e quatro prévias.\n- `textures/forest_pixel_atlas.png`: atlas único 512×512, com configuração de importação que gera mipmaps.\n- `manifest.json`: categorias, caminhos, escala, dimensões, raio conservador da copa e contagem de triângulos.\n\n'
body+='## Catálogo\n\n| Asset | Categoria | Dimensões no Blender (X/Y/Z) | Triângulos | Cena pronta |\n|---|---|---|---:|---|\n'
for report in manifest['assets']:
    name=report['asset']; dim=' × '.join(f'{v:.2f}' for v in report['dimensions'])
    body+=f'| `{name}` — {report["display_name"]} | {categories[report["category"]]} | {dim} | {report["triangles"]} | [{name}.tscn](godot/{name}.tscn) |\n'
body+='\n**Total: 1.202 triângulos**, de 54 a 220 por asset. Cada asset tem uma malha e uma superfície de renderização. As superfícies externas foram unidas, com remoção de faces internas; as malhas são fechadas e têm normais planas. Folhas opacas evitam o custo e a ordenação de transparência.\n\n'
body+='## Escala, pivôs e composição\n\n'
body+='Use **escala base 1.0**: as árvores adultas têm altura de 0.92 a 1.16 nas unidades nativas do mapa, cujo hexágono tem raio 1. A altura correspondente é o eixo Y no Godot. Os pivôs ficam no solo, na base do tronco ou no centro de apoio do prop. Nenhuma cena exige correção de rotação ou escala.\n\n'
body+='A variação sugerida é rotação ao redor de Y entre 0 e 360° e escala uniforme entre 0.85 e 1.12. Varie também a espécie e a posição. Evite escalar cada eixo separadamente: a escala uniforme mantém as proporções e o aspecto dos pixels. A densidade é **128 pixels por unidade em todos os modelos**; pequenas variações uniformes de instância alteram a densidade de maneira proporcional.\n\n'
body+='Para manter a copa dentro de um tile pointy-top de raio 1, uma regra conservadora independente da rotação é `distância_do_centro + footprint_radius * escala <= sqrt(3)/2 - margem`. O manifesto informa `footprint_radius` de cada asset. Uma margem de 0.02 funciona para afastar a silhueta da borda. Distribua os centros com espaço entre as copas; árvores jovens e arbustos permitem densidade visual sem repetir árvores grandes.\n\n'
body+='## MultiMesh no Godot\n\nAgrupe instâncias por variante, reutilizando a mesma malha e o material comum. Um MultiMesh por variante e por região do mapa permite variação de rotação, escala e tintura sem criar um nó por árvore. A divisão por regiões mantém o culling útil em mapas grandes. As cenas individuais permanecem disponíveis para edição manual.\n\n'
body+='```gdscript\nconst KIT := "res://assets/generated/nature/temperate_forest_v1"\n\nvar mesh: ArrayMesh = load(KIT + "/godot/tree_oak_a.res")\nvar batch := MultiMesh.new()\nbatch.transform_format = MultiMesh.TRANSFORM_3D\nbatch.use_colors = true\nbatch.mesh = mesh\nbatch.instance_count = placements.size()\n\nfor i in placements.size():\n    var placement: Dictionary = placements[i]\n    var basis := Basis(Vector3.UP, placement.angle).scaled(Vector3.ONE * placement.scale)\n    batch.set_instance_transform(i, Transform3D(basis, placement.position))\n    batch.set_instance_color(i, Color.WHITE)\n\nvar forest_variant := MultiMeshInstance3D.new()\nforest_variant.multimesh = batch\nadd_child(forest_variant)\n```\n\n'
body+='O material compartilhado usa amostragem nearest com mipmaps: pixels definidos de perto e menor cintilação de textura à distância. A textura tem variação em grupos de pixels, fibras da casca, marcas da faia, musgo e anéis no corte do tronco. As UVs são métricas, sem esticar as texturas para caber nas faces.\n\n'
body+='## Validação\n\n'
body+='Os dez GLBs passaram na verificação de malha única, superfície única, material opaco, culling, atlas compartilhado, pivô no solo, escala nativa, ausência de câmeras/luzes/rig/animações e densidade de UVs. Nenhuma sobreposição coplanar com área positiva foi detectada nas superfícies exportadas. As fontes `.blend` são isoladas, com atlas empacotado, volume positivo e malhas fechadas; as 467 cenas anteriores do Blender foram preservadas.\n\n'
body+='O Godot importou os dez modelos e recarregou as cenas e malhas compartilhando o mesmo material. Também foi verificada a configuração de 1.000 instâncias de MultiMesh por variante com transformações e tinturas: um teste de recursos e API em modo headless, sem benchmark de FPS.\n\n'
body+='[GLBs e UVs](../../../../docs/temperate_forest_validation.json) · [Fontes pelo MCP](../../../../docs/temperate_forest_source_validation.json) · [Godot](../../../../docs/temperate_forest_godot_validation.json).\n'
(OUT/'README.md').write_text(body,encoding='utf-8')
(ROOT/'docs/TEMPERATE_FOREST_KIT.md').write_text('# Kit modular de floresta temperada\n\n[Guia de uso e catálogo](../assets/generated/nature/temperate_forest_v1/README.md) · [Galeria](../art_source/temperate_forest_review/index.html).\n\nDez assets criados pelo MCP do Blender. Total de 1.202 triângulos, uma malha por asset e um atlas compartilhado de 512×512. Fontes, GLBs, cenas individuais e malhas para MultiMesh estão no diretório do kit.\n',encoding='utf-8')
old_gallery=ROOT/'art_source/building_architecture_review/index.html'
content=old_gallery.read_text(encoding='utf-8')
if '../temperate_forest_review/index.html' not in content:
    content=content.replace('<footer>','<footer><a href="../temperate_forest_review/index.html">Kit modular de árvores</a> · ',1)
    old_gallery.write_text(content,encoding='utf-8')
print(json.dumps({'assets':10,'triangles':1202,'gallery':str(REVIEW/'index.html'),'kit':str(OUT)}))
