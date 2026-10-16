"""Review gallery and usage notes for the six independent orc elders."""
import html,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/orc_school_mages_review'
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
descriptions={
 'sacred':'Marfim e dourado, diadema de osso e cajado solar com âmbar.',
 'infernal':'Vermelho e bordô, capuz pintado e cajado com braseiro de ferro.',
 'necromancy':'Roxo, capuz pintado e cajado de osso com crânio entalhado.',
 'druidism':'Verde, faixa de couro e cajado de madeira com galhos e folhagem em blocos.',
 'arcanism':'Azul, chapéu angular com faixa de couro e cristal protegido por moldura de madeira.',
 'elementalism':'Azul-petróleo, faixa de ferro e cajado com os quatro focos elementais.',
}
cards=[]
for a in manifest['assets']:
    stem=a['stem']; rel='../../assets/generated/orcs/'+stem+'/'
    cards.append(f'''<article><h2>{html.escape(a['name'])}</h2><p>{descriptions[a['school']]}</p>
<a href="{rel}previews/three_quarter.png"><img src="{rel}previews/three_quarter.png" alt="{html.escape(a['name'])}" loading="lazy"></a>
<div class="links"><a href="{rel}previews/front.png">Frente</a><a href="{rel}previews/back.png">Costas</a><a href="{rel}{stem}.blend">Blender</a><a href="{rel}{stem}.glb">GLB</a><a href="{rel}{stem}_albedo.png">Textura</a></div>
<p>{a['geometry']['triangles']} triângulos · 1 malha · 1 material · 64 px/m</p></article>''')
    (ROOT/'assets/generated/orcs'/stem/'README.md').write_text(f'''# {a['name']}

{descriptions[a['school']]}

Criado no Blender aberto, via MCP, com a anatomia do orc aprovado e as cores da escola humana correspondente. Cabeça, rosto, orelhas, presas e proporções nativas preservados. Crista, sobrancelhas e barbas grisalhas, postura levemente curvada, roupas simples, antebraços expostos, couro e madeira da paleta orc. Nenhum adorno geométrico aplicado às roupas.

- `{stem}.blend`: fonte editável com {a['geometry']['editable_parts']} peças separadas.
- `{stem}.glb`: modelo estático com uma malha, uma superfície, um material e {a['geometry']['triangles']} triângulos.
- Albedo e emissão 512×512, 64 px/m, margem de 3 pixels, nearest. Atlases incorporados no GLB e empacotados no Blender.
- Metros, escala 1.0, pivô nos pés. Frente -Y no Blender e +Z no Godot.
- Cajado em contato com a mão, separado do antebraço. Sem faces coplanares expostas sobrepostas.
- Ainda sem rig ou animações nesta etapa de conferência. Cadastro de unidades inalterado.
- Fonte original: `{a['source']}`. Orc base, humanos e elfos aprovados preservados.

Frente, perspectiva e costas em `previews/`.
''',encoding='utf-8')
native=''
if (WORK/'godot_orc_mages_three_quarter.png').exists():
    native='''<h2>No Godot</h2><p>Escala nativa, terreno e iluminação do jogo. O colonizador orc aprovado aparece à esquerda.</p><a href="godot_orc_mages_three_quarter.png"><img class="wide" src="godot_orc_mages_three_quarter.png" alt="Seis magos orcs no Godot"></a><a href="godot_original_heads_comparison.png"><img class="wide" src="godot_original_heads_comparison.png" alt="Cabeça orc original, bruxo e arcanista"></a>'''
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Magos orcs — seis escolas</title>
<style>body{margin:0;background:#231e19;color:#eee9d8;font:16px/1.5 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:32px}h1{font-size:32px}h2{font-size:20px}p{color:#d4cbbd}a{color:#e3c99f}img{display:block;width:100%;border-radius:8px}.wide{margin:20px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:22px}article{background:#393129;padding:20px;border-radius:12px}.links{display:flex;gap:16px;flex-wrap:wrap;margin:18px 0}</style>
<main><h1>Magos orcs · seis escolas</h1><p>Cabeças e presas originais, ombros largos, cabelos e barbas grisalhos e vestes simples nas cores das escolas: marfim, vermelho, roxo, verde, azul e azul-petróleo. Couro, osso, ferro e cajados de madeira pesada dão a identidade orc.</p>
<div class="links"><a href="orc_school_mages_six_schools_review.blend">Cena Blender com os seis lado a lado</a><a href="orc_mages_front.png">Frente</a><a href="orc_mages_back.png">Costas</a><a href="../human_school_mages_review/index.html">Magos humanos</a><a href="../elf_school_mages_review/index.html">Magos élficos</a></div>
<a href="orc_mages_three_quarter.png"><img class="wide" src="orc_mages_three_quarter.png" alt="Os seis magos orcs lado a lado"></a>'''+native+'<div class="grid">'+''.join(cards)+'''</div><p>Modelos independentes e estáticos para conferência, fontes editáveis, escala em metros e pivô nos pés. Sem pingentes, runas ou formas aplicadas às roupas.</p></main></html>'''
(WORK/'index.html').write_text(page,encoding='utf-8')
(WORK/'README.md').write_text('''# Magos orcs das seis escolas

Abra `orc_school_mages_six_schools_review.blend` para conferir os seis lado a lado, ou `index.html` para acessar a galeria e os arquivos individuais.

Sagrada: xamã solar. Infernal: bruxo. Necromancia: necromante. Druidismo: xamã da floresta. Arcanismo: arcanista. Elementalismo: xamã dos elementos.

Anatomia do colonizador orc aprovado: cabeça na escala original, rosto, seis peças de orelhas, quatro peças de presas e duas sobrancelhas preservados. Crista, sobrancelhas e barbas grisalhas, postura levemente curvada, roupas simples sem ornamentos aplicados. Cores das escolas iguais às humanas; couro, madeira, osso e ferro próprios dos orcs. Os cajados e adereços de cabeça diferenciam cada escola.

Modelos em `assets/generated/orcs/orc_*_v1/`, listados em `manifest.json`. Fontes Blender com peças separadas, GLBs com uma malha e um material. Metros, pés na origem, frente Godot +Z, escala 1.0. Texturas 512×512, 64 px/m, nearest com mipmaps. Modelos estáticos para revisão, ainda sem rig ou animações. Banco de unidades inalterado.

Criação, renders e exportação via MCP do Blender aberto. Validações em `docs/orc_school_mages_*_validation.json`: geometria, proporções e pixels do rosto, UVs, atlases incorporados, fontes preservadas, faces coplanares, mãos/cajados e importação no Godot.
''',encoding='utf-8')
print('Orc review gallery and six usage notes saved.')
