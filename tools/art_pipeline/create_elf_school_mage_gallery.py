"""Local review gallery and usage notes for six independent elven casters."""
import html,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/elf_school_mages_review'
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
descriptions={
 'sacred':'Vestes simples em marfim, gola e cinto verdes, diadema dourado e cajado solar em madeira.',
 'infernal':'Vestes simples em vermelho e bordô, gola e cinto verdes, capuz pintado e cajado de brasa.',
 'necromancy':'Vestes simples em roxo, gola e cinto verdes, capuz pintado e cajado com foco em marfim.',
 'druidism':'Vestes simples em verde, coroa de folhas, bolsa de couro e cajado de galhos vivos.',
 'arcanism':'Vestes simples em azul, gola e cinto verdes, chapéu angular e cajado com cristal arcano.',
 'elementalism':'Vestes simples em azul-petróleo, gola e cinto verdes, diadema e cajado dos quatro elementos.',
}
cards=[]
for a in manifest['assets']:
    stem=a['stem']; rel='../../assets/generated/elves/'+stem+'/'
    cards.append(f'''<article><h2>{html.escape(a['name'])}</h2><p>{descriptions[a['school']]}</p>
<a href="{rel}previews/three_quarter.png"><img src="{rel}previews/three_quarter.png" alt="{html.escape(a['name'])}" loading="lazy"></a>
<div class="links"><a href="{rel}previews/front.png">Frente</a><a href="{rel}previews/back.png">Costas</a><a href="{rel}{stem}.blend">Blender</a><a href="{rel}{stem}.glb">GLB</a><a href="{rel}{stem}_albedo.png">Textura</a></div>
<p>{a['geometry']['triangles']} triângulos · 1 malha · 1 material · 64 px/m</p></article>''')
    text=f'''# {a['name']}

{descriptions[a['school']]}

Criado via MCP do Blender a partir da linguagem aprovada dos magos humanos e da anatomia do elfo do projeto. Cabeça, rosto e orelhas originais preservados, cabelo claro da paleta élfica e vestes simples com gola e cinto verdes. Adornos geométricos sobre as roupas removidos. Capuzes pintados diretamente na cabeça; chapéu e diademas em 3D.

- `{stem}.blend`: fonte editável, {a['geometry']['editable_parts']} peças separadas.
- `{stem}.glb`: modelo estático para revisão, 1 malha, 1 superfície, 1 material, {a['geometry']['triangles']} triângulos.
- Texturas albedo/emissão 512×512, 64 px/m, margem de 3 pixels, nearest; incorporadas no GLB e empacotadas no Blender.
- Metros, escala 1.0, pivô nos pés. Frente -Y no Blender e +Z no Godot.
- Cajado em contato com a mão, separado do antebraço. Nenhuma face coplanar exposta sobreposta.
- Sem rig ou animações nesta etapa de revisão. O cadastro de unidades permanece inalterado.
- Fonte original: `{a['source']}`. Os modelos humanos aprovados também foram preservados.

Vistas de frente, perspectiva e costas em `previews/`.
'''
    (ROOT/'assets/generated/elves'/stem/'README.md').write_text(text,encoding='utf-8')
native=''
if (WORK/'godot_elf_mages_three_quarter.png').exists():
    native='''<h2>No Godot</h2><p>Escala 1:1, terreno e iluminação do jogo. O colonizador élfico aprovado está à esquerda.</p><a href="godot_elf_mages_three_quarter.png"><img class="wide" src="godot_elf_mages_three_quarter.png" alt="Os seis magos élficos no Godot"></a><a href="godot_original_heads_comparison.png"><img class="wide" src="godot_original_heads_comparison.png" alt="Cabeça élfica original, bruxo e arcanista"></a>'''
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Magos élficos — seis escolas</title>
<style>body{margin:0;background:#18241e;color:#eee9d8;font:16px/1.5 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:32px}h1{font-size:32px}h2{font-size:20px}p{color:#c7d2c8}a{color:#acd9be}img{display:block;width:100%;border-radius:8px}.wide{margin:20px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:22px}article{background:#27392e;padding:20px;border-radius:12px}.links{display:flex;gap:16px;flex-wrap:wrap;margin:18px 0}</style>
<main><h1>Magos élficos · seis escolas</h1><p>Vestes simples nas mesmas cores das escolas humanas: marfim, vermelho, roxo, verde, azul e azul-petróleo. Golas e cintos verdes preservam a identidade élfica. Adornos geométricos sobre as roupas removidos; cabeça, rosto, orelhas, cabelo claro, diademas e cajados aprovados preservados.</p>
<div class="links"><a href="elf_school_mages_six_schools_review.blend">Cena Blender com os seis lado a lado</a><a href="elf_mages_front.png">Frente</a><a href="elf_mages_back.png">Costas</a><a href="../human_school_mages_review/index.html">Referência humana aprovada</a></div>
<a href="elf_mages_three_quarter.png"><img class="wide" src="elf_mages_three_quarter.png" alt="Seis magos élficos lado a lado"></a>'''+native+'<div class="grid">'+''.join(cards)+'''</div><p>Modelos independentes, pivô nos pés e escala nativa. UVs com densidade consistente, fontes editáveis e exportações estáticas para conferência.</p></main></html>'''
(WORK/'index.html').write_text(page,encoding='utf-8')
(WORK/'README.md').write_text('''# Magos élficos das seis escolas

Abra `elf_school_mages_six_schools_review.blend` para conferir os seis lado a lado, ou `index.html` para acessar a galeria e os arquivos individuais.

Sagrada: clérigo. Infernal: bruxo. Necromancia: necromante. Druidismo: druida. Arcanismo: arcanista. Elementalismo: elementalista.

Anatomia, cabeça, rosto e orelhas do elfo aprovado. Túnicas, mangas, mantos, capuzes e chapéu usam as cores correspondentes dos magos humanos. Na revisão atual, pingentes, triângulos, runas, faixas sobrepostas e demais adornos das roupas foram removidos. Golas e cintos conservam o verde dos elfos. Cabeças, diademas, chapéu, cajados e texturas aprovados preservados. Capuzes pintados na cabeça, diademas próprios dos elfos e chapéu angular do arcanista.

Arquivos em `assets/generated/elves/elf_*_v1/`, listados em `manifest.json`. Fontes Blender com peças separadas; GLBs com uma malha e um material. Metros, pivô nos pés, frente Godot +Z, escala 1.0. Texturas 512×512, 64 px/m, nearest com mipmaps. Modelos estáticos para revisão, ainda sem rig ou animações. Banco de unidades inalterado.

Criação, revisão, renders e exportação feitos no Blender aberto, através do MCP. Validações em `docs/elf_school_mages_*_validation.json`: geometria, UVs, atlas incorporados, fontes preservadas, faces expostas sobrepostas, mãos/cajados e importação nativa no Godot.
''',encoding='utf-8')
print('Elven gallery and six usage notes saved.')
