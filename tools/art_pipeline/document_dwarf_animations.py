"""Small local gallery of the Blender animation renders."""
import json
from pathlib import Path
from dwarf_troop_assets import ROOT, OUT, FAMILIES

folder = ROOT/'docs/previews/dwarf_troops/animations'
(folder/'.gdignore').touch() # Animated WebP previews are browser documents.
data = []
for family, (title, _) in FAMILIES.items():
    manifest = json.loads((OUT/'animations'/(family+'_manifest.json')).read_text(encoding='utf-8'))
    data.append(dict(key=family, title=title, clips=manifest['clips']))
html = '''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Anões — revisão das animações</title>
<style>
body{margin:0;background:#1d2326;color:#eee8da;font:16px system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:28px}
h1{font-size:27px;margin:0 0 12px}p{color:#c6c6bb;line-height:1.6}nav{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0}
button{border:1px solid #555f62;background:#2d363a;color:inherit;border-radius:6px;padding:10px 18px;font:inherit;cursor:pointer}
button[aria-pressed=true]{background:#916a40;border-color:#c09666}article{display:grid;grid-template-columns:1fr 1fr;gap:24px;align-items:center}
img{display:block;width:100%;max-width:560px;border-radius:8px}a{color:#dfba7e}h2{font-size:23px}footer{margin-top:30px;color:#aeb4b5}
@media(max-width:700px){article{grid-template-columns:1fr}main{padding:16px}}
</style><main><h1>Anões — animações</h1>
<p>Seis classes, quatro evoluções em cada uma. Cada classe compartilha um conjunto de idle, walk e attack.
No Godot, abra <strong>_dwarf_troop_models_review.tscn</strong> com F6 para ver as quatro evoluções juntas.</p>
<nav id="families" aria-label="Classe"></nav><nav id="clips" aria-label="Animação"></nav>
<article><img id="preview" alt="Animação da tropa"><div><h2 id="title"></h2><p id="description"></p>
<p><a id="contact" target="_blank">Ver poses principais</a></p><p>Os ataques repetem nesta galeria para facilitar a revisão.</p></div></article>
<footer>Prévia do Blender a 24 fps. Clipes e vídeos MP4 entregues a 48 fps. Idle e walk em loop; attack toca uma vez e recupera a pose.</footer>
<script>
const data=DATA; let family=0, clip='idle';
const families=document.getElementById('families'), clips=document.getElementById('clips');
data.forEach((item,index)=>{const b=document.createElement('button');b.textContent=item.title;b.onclick=()=>{family=index;show()};families.append(b)});
['idle','walk','attack'].forEach(key=>{const b=document.createElement('button');b.textContent=key[0].toUpperCase()+key.slice(1);b.onclick=()=>{clip=key;show()};clips.append(b)});
function show(){const item=data[family];document.getElementById('preview').src=item.key+'_'+clip+'.webp';
document.getElementById('preview').alt=item.title+' — '+clip;document.getElementById('title').textContent=item.title+' — '+clip;
document.getElementById('description').textContent=item.clips[clip].description;
document.getElementById('contact').href=item.key+'_'+clip+'_contact.jpg';
[...families.children].forEach((b,i)=>b.setAttribute('aria-pressed',i===family));
[...clips.children].forEach((b,i)=>b.setAttribute('aria-pressed',['idle','walk','attack'][i]===clip));}show();
</script></main></html>'''
(folder/'index.html').write_text(html.replace('DATA', json.dumps(data, ensure_ascii=False)), encoding='utf-8')
print('DWARF_ANIMATION_GALLERY_DONE')
