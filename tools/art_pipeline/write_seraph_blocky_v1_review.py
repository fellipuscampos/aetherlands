"""Local static model gallery; no generated animation or gameplay changes."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'assets/generated/grand_manifestations/seraph_blocky_v1'
OUT = ROOT / 'art_source/seraph_blocky_v1_review'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').write_text('', encoding='utf-8')
report = json.loads((ASSET / 'seraph_blocky_v1_report.json').read_text(encoding='utf-8'))
validation = json.loads((ASSET / 'godot_validation.json').read_text(encoding='utf-8'))
prefix = '../../assets/generated/grand_manifestations/seraph_blocky_v1/'
views = [('three_quarter', 'Blender · três quartos'), ('front', 'Godot · frente'),
         ('godot_three_quarter', 'Godot · três quartos'), ('back', 'Godot · costas'),
         ('side', 'Godot · perfil'), ('godot_game_view', 'Godot · câmera do jogo')]
buttons = '\n'.join(f'<button type="button" data-view="{name}" aria-pressed="{str(i == 0).lower()}"><img src="{prefix}previews/{name}.png" alt=""><span>{title}</span></button>' for i, (name, title) in enumerate(views))
html = '''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Serafim · Grande manifestação sagrada</title>
<style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#10151d;color:#ece9dd}
*{box-sizing:border-box}body{max-width:1180px;margin:auto;padding:32px}header{margin-bottom:24px}
.eyebrow{font-size:12px;letter-spacing:.15em;color:#e3c071;text-transform:uppercase}h1{font-size:clamp(28px,5vw,44px);margin:10px 0 12px}
p{line-height:1.6;color:#bbc5d2;max-width:780px}.tags{display:flex;gap:10px;flex-wrap:wrap}.tags span{border:1px solid #46515e;padding:7px 12px;border-radius:6px;font-size:13px}
main{display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:24px}.viewer{background:#1b242f;border:1px solid #354150;border-radius:10px;overflow:hidden}
#hero{width:100%;height:auto;display:block;aspect-ratio:1;object-fit:contain}figcaption{padding:16px;color:#d6dbe3}figure{margin:0}
.views{display:grid;grid-template-columns:1fr 1fr;gap:10px}button{padding:0;border:1px solid #354150;border-radius:6px;background:#1b242f;color:#d6dbe3;cursor:pointer;overflow:hidden;text-align:left}
button[aria-pressed="true"]{border-color:#e3c071;box-shadow:0 0 0 1px #e3c071}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;font-size:12px;padding:9px}
aside h2{font-size:16px;margin:24px 0 8px}aside p{font-size:14px}a{color:#f0d48d}aside a{display:block;margin:12px 0}.status{color:#a0d2b4;font-size:13px}
footer{font-size:13px;color:#8795a6;margin-top:24px;line-height:1.6}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}.views{grid-template-columns:repeat(3,1fr)}}
</style>
<header><div class="eyebrow">Escola sagrada · Grande manifestação</div><h1>Serafim</h1>
<p>Seis asas em degraus envolvem um relicário dourado suspenso. A luz sagrada ocupa o centro; uma auréola angular e fragmentos de luz completam a presença da entidade.</p>
<div class="tags"><span>3 metros</span><span>Comum às civilizações</span><span>Blocky / voxel</span><span>Modelo estático</span></div></header>
<main><figure class="viewer"><img id="hero" src="PREFIXpreviews/three_quarter.png" alt="Modelo blocky do Serafim, seis asas de marfim, relicário dourado e núcleo luminoso."><figcaption id="caption">Blender · três quartos</figcaption></figure>
<aside><div class="views">BUTTONS</div><h2>Arquivos do modelo</h2>
<a href="PREFIXseraph_blocky_v1.glb">Modelo para o Godot · GLB</a>
<a href="PREFIXseraph_blocky_v1.blend">Fonte editável · Blender</a>
<a href="PREFIXseraph_blocky_v1_report.json">Dados do modelo</a>
<a href="PREFIXgodot_validation.json">Validação nativa no Godot</a>
<p class="status">Godot: importação, escala, materiais e esqueleto conferidos.</p>
<p>1.008 triângulos · 1 malha · 1 material · Texturas de 512 px. Pivôs preparados para a etapa de animação.</p>
<h2>Revisão no editor</h2><p>Abra <code>scenes/art_review/SeraphModelReview.tscn</code> e pressione F6. Use as setas para girar o modelo.</p></aside></main>
<footer>Esta entrega contém somente o modelo. As animações e a integração da unidade ficam para a próxima etapa.</footer>
<script>
const hero=document.querySelector('#hero'),caption=document.querySelector('#caption');
document.querySelectorAll('button[data-view]').forEach(button=>button.addEventListener('click',()=>{
 document.querySelectorAll('button[data-view]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));
 hero.src='PREFIXpreviews/'+button.dataset.view+'.png';caption.textContent=button.textContent;
}));
</script></html>'''.replace('PREFIX', prefix).replace('BUTTONS', buttons)
(OUT / 'index.html').write_text(html, encoding='utf-8')
(ASSET / 'README.md').write_text('''# Serafim — grande manifestação sagrada

Modelo compartilhado entre todas as civilizações. Entidade sem anatomia humana, com seis asas blocky, relicário e auréola dourados, luz sagrada e cauda fragmentada de luz. Paleta inspirada nos clérigos sagrados do jogo.

- `seraph_blocky_v1.glb`: malha única, material único, texturas embutidas e esqueleto preparado. **Sem animações.**
- `seraph_blocky_v1.blend`: cena isolada, 84 blocos editáveis, iluminação de apresentação e câmera. Os objetos do estúdio não entram no GLB.
- Altura geométrica: 3,00 m; menor ponto a 0,22 m do solo; origem no plano do terreno. Escala de importação 1. Frente: Godot +Z / Blender -Y.
- 1.008 triângulos, 11 ossos com pesos rígidos, atlas de 512 px com filtro NEAREST e emissão concentrada na luz.
- Pivôs separados para corpo, núcleo, auréola, cauda e cada uma das seis asas. Não existem ações, keyframes ou clipes.
- `previews`: vistas do Blender e do Godot. `godot_validation.json`: dimensões e verificação nativa da malha, skin e materiais.
- Revisão: `scenes/art_review/SeraphModelReview.tscn` (F6 e setas para girar).

O caminho de unidade provisório em UnitDatabase não foi alterado nesta etapa; a integração e as animações serão feitas após a revisão do modelo.
''', encoding='utf-8')
assert validation['status'] == 'PASS' and report['animations'] == 0
assert all((ASSET / 'previews' / (name+'.png')).exists() for name, _ in views)
print(OUT / 'index.html')
