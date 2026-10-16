"""Review gallery and game usage notes for the six independent dwarf elders."""
import html,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/dwarf_school_mages_review'
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
descriptions={
 'sacred':'Marfim e dourado, mitra baixa e cajado com lanterna de cobre e luz solar.',
 'infernal':'Vermelho e bordô, capuz pintado e cajado com braseiro de forja.',
 'necromancy':'Roxo, capuz pintado e relicário de pedra com inscrição violeta.',
 'druidism':'Verde, faixa de couro e cajado com raízes, pedra e folhas em blocos.',
 'arcanism':'Azul, chapéu angular com faixa de cobre e cajado com pedra rúnica.',
 'elementalism':'Azul-petróleo, faixa de aço e cajado de cobre com quatro focos elementais.',
}
cards=[]
for a in manifest['assets']:
    stem=a['stem']; rel='../../assets/generated/dwarves/'+stem+'/'
    cards.append(f'''<article><h2>{html.escape(a['name'])}</h2><p>{descriptions[a['school']]}</p>
<a href="{rel}previews/three_quarter.png"><img src="{rel}previews/three_quarter.png" alt="{html.escape(a['name'])}" loading="lazy"></a>
<div class="links"><a href="{rel}previews/front.png">Frente</a><a href="{rel}previews/back.png">Costas</a><a href="{rel}{stem}.blend">Blender</a><a href="{rel}{stem}.glb">GLB</a><a href="{rel}{stem}_albedo.png">Textura</a></div>
<p>{a['geometry']['triangles']} triângulos · 1 malha · 1 material · 64 px/m</p></article>''')
    (ROOT/'assets/generated/dwarves'/stem/'README.md').write_text(f'''# {a['name']}

{descriptions[a['school']]}

Criado via MCP do Blender com a anatomia do anão aprovado. Cabeça, nariz, barba em dezoito mechas, bigode e proporções nativas preservados. Cabelos, barba e sobrancelhas grisalhos; postura levemente curvada; vestes simples nas cores humanas das escolas. Couro, cobre, aço e pedra da paleta anã. Antebraços largos originais, mão livre relaxada, sem livros ou ornamentos geométricos aplicados às roupas.

- `{stem}.blend`: fonte editável com {a['geometry']['editable_parts']} peças separadas.
- `{stem}.glb`: uma malha, uma superfície, um material e {a['geometry']['triangles']} triângulos.
- Albedo e emissão 512×512, 64 px/m, margem de 3 pixels, nearest. Atlases incorporados no GLB e empacotados no Blender.
- Metros, escala 1.0, pivô nos pés. Frente -Y no Blender e +Z no Godot.
- Cajado em contato com a mão, separado do antebraço; sem faces coplanares expostas sobrepostas.
- Modelo estático para conferência, ainda sem rig ou animações. Banco de unidades inalterado.
- Fonte: `{a['source']}`. Os personagens já aprovados foram preservados.

Prévias de frente, perspectiva e costas em `previews/`.
''',encoding='utf-8')
native=''
if (WORK/'godot_dwarf_mages_three_quarter.png').exists():
    native='''<h2>No Godot</h2><p>Escala em metros, terreno e iluminação do jogo. O colonizador anão aprovado aparece à esquerda.</p><a href="godot_dwarf_mages_three_quarter.png"><img class="wide" src="godot_dwarf_mages_three_quarter.png" alt="Seis magos anões no Godot"></a><a href="godot_original_heads_comparison.png"><img class="wide" src="godot_original_heads_comparison.png" alt="Cabeça anã original, bruxo e mestre rúnico"></a>'''
if (WORK/'godot_dwarf_mages_game_view.png').exists():
    native+='''<p>Inclinação da câmera atual do jogo.</p><a href="godot_dwarf_mages_game_view.png"><img class="wide" src="godot_dwarf_mages_game_view.png" alt="Magos anões vistos pela inclinação da câmera de jogo"></a>'''
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Magos anões — seis escolas</title>
<style>body{margin:0;background:#1e2429;color:#eee9d8;font:16px/1.5 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:32px}h1{font-size:32px}h2{font-size:20px}p{color:#d4cbbd}a{color:#deb583}img{display:block;width:100%;border-radius:8px}.wide{margin:20px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:22px}article{background:#30383f;padding:20px;border-radius:12px}.links{display:flex;gap:16px;flex-wrap:wrap;margin:18px 0}</style>
<main><h1>Magos anões · seis escolas</h1><p>Anatomia anã original, barbas grisalhas em blocos e vestes simples nas cores das escolas: marfim, vermelho, roxo, verde, azul e azul-petróleo. Cobre, aço, couro, madeira escura e pedra nos adereços.</p>
<div class="links"><a href="dwarf_school_mages_six_schools_review.blend">Cena Blender com os seis lado a lado</a><a href="dwarf_mages_front.png">Frente</a><a href="dwarf_mages_back.png">Costas</a><a href="../human_school_mages_review/index.html">Humanos</a><a href="../elf_school_mages_review/index.html">Elfos</a><a href="../orc_school_mages_review/index.html">Orcs</a></div>
<a href="dwarf_mages_three_quarter.png"><img class="wide" src="dwarf_mages_three_quarter.png" alt="Seis magos anões lado a lado"></a>'''+native+'<div class="grid">'+''.join(cards)+'''</div><p>Assets independentes, fontes editáveis, metros e pivô nos pés. Modelos estáticos para conferência.</p></main></html>'''
(WORK/'index.html').write_text(page,encoding='utf-8')
(WORK/'README.md').write_text('''# Magos anões das seis escolas

Abra `dwarf_school_mages_six_schools_review.blend` para conferir os seis lado a lado ou `index.html` para acessar as prévias e arquivos individuais.

Sagrada: sacerdote. Infernal: bruxo da forja. Necromancia: guardião das criptas. Druidismo: druida. Arcanismo: mestre rúnico. Elementalismo: geomante.

Anatomia do colonizador anão aprovado, incluindo cabeça, nariz, dezoito mechas da barba, bigode, ombros largos, antebraços e pernas curtas. Cabelos e barba grisalhos; postura levemente curvada; vestes simples nas cores das escolas humanas. Cobre, aço, couro e pedra próprios dos anões nos cajados e adereços de cabeça.

Assets em `assets/generated/dwarves/dwarf_*_v1/`, listados em `manifest.json`. Fontes Blender editáveis com peças separadas, GLBs com uma malha e um material. Metros, pés na origem, escala 1.0. Albedo e emissão 512×512, 64 px/m, nearest com mipmaps. Modelos estáticos para revisão, ainda sem rig ou animações. Banco de unidades inalterado.

Criação, renders e exportação via MCP do Blender aberto. Validações em `docs/dwarf_school_mages_*_validation.json`: geometria, proporções, rosto e barba, UVs, texturas incorporadas, fontes preservadas, faces coplanares, mão/cajado e importação no Godot.
''',encoding='utf-8')
print('Dwarf review gallery and six usage notes saved.')
