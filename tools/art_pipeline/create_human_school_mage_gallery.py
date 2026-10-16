"""Static local gallery and usage notes for the six editable mage assets."""
import html,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/human_school_mages_review'
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
cards=[]
descriptions={
 'sacred':'Vestes marfim e douradas, mitra e cajado solar.',
 'infernal':'Capuz bordô, túnica escura e braseiro de duas hastes.',
 'necromancy':'Capuz violeta, amuletos de osso e cajado de caveira.',
 'druidism':'Túnica verde, lã, coroa de folhas e cajado de galhos.',
 'arcanism':'Chapéu angular azul, runas e cristal arcano.',
 'elementalism':'Túnica azul-petróleo e focos de fogo, água, terra e ar.',
}
for row in manifest['assets']:
    stem=row['stem']; rel='../../assets/generated/humans/'+stem+'/'
    row.update(blend='assets/generated/humans/'+stem+'/'+stem+'.blend',glb='assets/generated/humans/'+stem+'/'+stem+'.glb',texture='assets/generated/humans/'+stem+'/'+stem+'_albedo.png')
    cards.append(f'''<article><h2>{html.escape(row['name'])}</h2><p>{descriptions[row['school']]}</p>
<a href="{rel}previews/three_quarter.png"><img loading="lazy" src="{rel}previews/three_quarter.png" alt="{html.escape(row['name'])}"></a>
<div class="angles"><a href="{rel}previews/front.png">Frente</a><a href="{rel}previews/three_quarter.png">Perspectiva</a><a href="{rel}previews/back.png">Costas</a></div>
<p class="spec">{row['geometry']['triangles']} triângulos · 1 malha · 1 material · 64 px/m</p>
<div class="angles"><a href="{rel}{stem}.blend">Modelo Blender</a><a href="{rel}{stem}.glb">Modelo GLB</a><a href="{rel}{stem}_albedo.png">Textura</a></div></article>''')
    usage=f'''# {row['name']}

Modelo humano idoso em estilo blocky/pixel art, criado via MCP do Blender.
{descriptions[row['school']]}

- `{stem}.blend`: fonte editável, {row['geometry']['editable_parts']} peças separadas com metadados para futura rigagem.
- `{stem}.glb`: exportação estática, 1 malha, 1 superfície, 1 material, {row['geometry']['triangles']} triângulos.
- Albedo e emissão: atlas PNG 512×512, UVs em 64 px/m, margem de 3 px. Texturas também incorporadas no GLB e empacotadas no Blender.
- Escala nativa em metros; multiplicador 1.0. Pivô nos pés (0,0,0); frente -Y no Blender e +Z no Godot.
- Postura: tronco inclinado {row['elderly_posture']['torso_forward_degrees']}°, ombros baixos, barba grisalha.
- Revisão de estilo 3: cabeça e rosto originais do humano, no tamanho original; cabelo branco pintado, barba pintada com pequena extensão abaixo do queixo. Capuzes pintados na cabeça. Mitra e chapéu azul em 3D. Corpo, roupas e postura preservados.
- Sem rig/animações nesta etapa. O cadastro de unidades do jogo não foi alterado.
- Importador Godot exclusivo mantém nearest com mipmaps. Preserve o arquivo `.glb.import`.
- Fonte corporal: humano colonizador aprovado; arquivo original preservado.
- Revisão: nenhum par exposto de faces coplanares; cajado encosta na mão e não cruza o antebraço.

As vistas de frente, perspectiva e costas estão em `previews/`.
'''
    (ROOT/'assets/generated/humans'/stem/'README.md').write_text(usage,encoding='utf-8')
native=''
if (WORK/'godot_mages_three_quarter.png').exists():
    native='<h2>No Godot</h2><p>Iluminação e terreno do projeto, escala 1:1. O colonizador humano original está à esquerda como referência.</p><a href="godot_mages_three_quarter.png"><img class="wide" src="godot_mages_three_quarter.png" alt="Magos no Godot"></a>'
    if (WORK/'godot_human_style_comparison.png').exists():
        native+='<p>Comparação direta com o colonizador aprovado: rosto em pixel art, volumes simples e o mesmo couro nas botas e no cinto.</p><a href="godot_human_style_comparison.png"><img class="wide" src="godot_human_style_comparison.png" alt="Colonizador humano e clérigo com o mesmo estilo no Godot"></a>'
    if (WORK/'godot_original_heads_comparison.png').exists():
        native+='<p>Detalhe no Godot: humano original, bruxo com capuz pintado e arcanista com chapéu 3D.</p><a href="godot_original_heads_comparison.png"><img class="wide" src="godot_original_heads_comparison.png" alt="Cabeças originais e restauradas no Godot"></a>'
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Magos humanos — seis escolas</title>
<style>body{margin:0;background:#171f27;color:#ece6d4;font:16px/1.5 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:32px}h1{font-size:32px;margin-bottom:8px}h2{font-size:20px}p{color:#c3c9cc}a{color:#a5cff7}img{display:block;width:100%;border-radius:8px}.wide{margin:18px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:22px}article{background:#24303a;padding:20px;border-radius:12px}.angles{display:flex;gap:18px;flex-wrap:wrap}.spec{font-size:14px}nav{display:flex;gap:20px;margin:20px 0}</style>
<main><h1>Magos humanos · seis escolas · revisão 3</h1><p>Cabeças e rostos originais dos humanos, com cabelo branco e barba. Olhos, sobrancelhas, nariz e boca preservados na posição original. Capuzes pintados na cabeça; mitra e chapéu azul em 3D. Mantidos o corpo, as roupas e a postura idosa.</p>
<h2>Cabeça original e cabeças restauradas</h2><p>Da esquerda para a direita: cabeça original do humano, clérigo, bruxo, necromante, druida, arcanista e elementalista. Mesma escala e mesmos traços do rosto.</p><a href="original_head_restoration_comparison.png"><img class="wide" src="original_head_restoration_comparison.png" alt="Comparação das cabeças originais restauradas"></a><nav><a href="human_school_mages_six_schools_review.blend">Cena Blender com os seis lado a lado</a><a href="human_mages_back.png">Vista de costas</a><a href="arcanist_side_inspection.png">Postura e mãos de lado</a></nav>
<a href="human_mages_three_quarter.png"><img class="wide" src="human_mages_three_quarter.png" alt="Seis magos humanos idosos lado a lado"></a>'''+native+'<div class="grid">'+''.join(cards)+'''</div><p>Validação: tamanho e geometria originais das cabeças, traços do rosto preservados, cabelo branco e capuzes na textura; UVs sem esticamento; nenhuma face exposta sobreposta; cajados em contato com as mãos, separados dos antebraços. Fontes e GLBs independentes, ainda sem animações.</p></main></html>'''
(WORK/'index.html').write_text(page,encoding='utf-8')
(WORK/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(WORK/'README.md').write_text('''# Magos humanos das seis escolas

Abra `human_school_mages_six_schools_review.blend` para conferir os seis lado a lado, em escala 1:1. Abra `index.html` para ver a galeria e acessar os modelos individuais.

Sagrada: clérigo. Infernal: bruxo. Necromancia: necromante. Druidismo: druida. Arcanismo: arcanista. Elementalismo: elementalista.

Os modelos usam a anatomia do colonizador humano aprovado, com postura idosa, barbas/cabelos grisalhos, roupas e acessórios próprios de cada escola. Todos foram modelados, corrigidos, renderizados e exportados via MCP do Blender.

Revisão 3: cabeça original restaurada no tamanho original, com os traços do rosto preservados pixel a pixel. Cabelo branco na textura; barba pintada e pequena extensão abaixo do queixo. Capuzes do bruxo, necromante e elementalista pintados na própria cabeça; mitra e chapéu azul continuam em 3D. Corpo, roupas, cajados e postura preservados. As revisões anteriores estão em `before_style_revision/` e `before_original_head_restoration/`. Comparação de perto em `original_head_restoration_comparison.png`.

Arquivos individuais: `assets/generated/humans/human_*_v1/`, listados em `manifest.json`. GLBs com uma malha e um material; fontes Blender mantêm as peças editáveis. Pivôs nos pés, metros, frente Godot +Z, multiplicador 1.0. Albedo e emissão 512×512, 64 px/m, filtro nearest com mipmaps no Godot. Sem rig/animações nesta etapa; o banco de unidades permanece como estava.

Validações em `docs/human_school_mages_*_validation.json`: geometria fechada, normais planas, UVs, atlas incorporados, fonte original preservada, ausência de faces coplanares expostas e contato dos cajados com as mãos sem atravessar antebraços. A revisão de estilo confere a geometria e o tamanho originais das cabeças, a preservação dos traços do rosto, o cabelo branco e os capuzes pintados. Capturas nativas mostram os modelos na iluminação e no terreno do projeto.

`previous_blender_review.blend` é o checkpoint da cena anterior, preservado antes da criação dos magos.
''',encoding='utf-8')
print('Six human mage cards and asset usage notes created.')
