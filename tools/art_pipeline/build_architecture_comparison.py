"""Standalone local before/after viewer using the actual Blender renders."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art_source/building_architecture_review'
completed=json.loads((OUT/'completed.json').read_text(encoding='utf-8'))
labels={'human':('Humanos','humans'),'elf':('Elfos','elves'),'dwarf':('Anões','dwarves'),'orc':('Orcs','orcs')}
assets=[]
for entry in completed:
    race=entry['civilization']; folder=entry['asset']; label,plural=labels[race]
    path=ROOT/'assets/generated'/plural/'buildings'/folder
    report=json.loads((path/(folder+'_report.json')).read_text(encoding='utf-8'))
    assets.append({'race':race,'label':label,'name':report['display_name'],'stem':folder.removeprefix(race+'_'),
        'before':'../buildings_before_architecture_revision/'+plural+'/buildings/'+folder+'/previews/',
        'after':'../../assets/generated/'+plural+'/buildings/'+folder+'/previews/',
        'design':report['architecture_revision']['design']})
payload=json.dumps(assets,ensure_ascii=False).replace('</','<\\/')
template="""<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Arquitetura das civilizações — antes e depois</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#171e26;color:#eaf0f6;font:16px system-ui,sans-serif}
main{max-width:1500px;margin:auto;padding:28px}h1{font-size:clamp(24px,3vw,38px);margin:0 0 10px}
p{line-height:1.6;color:#b8c7d4;max-width:1050px}.controls{display:flex;gap:18px;flex-wrap:wrap;margin:24px 0}
label{display:grid;gap:8px;color:#b8c7d4}select{background:#273542;color:white;border:1px solid #496073;border-radius:8px;padding:12px;font:inherit;max-width:95vw}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0;background:#222d38;border-radius:14px;overflow:hidden}
figcaption{padding:14px 18px;font-weight:600}img{width:100%;display:block;aspect-ratio:1;object-fit:contain}
a{color:#aad8ff}footer{padding:22px 0;color:#b8c7d4}@media(max-width:650px){.pair{grid-template-columns:1fr}main{padding:18px}}
</style>
<main><h1>Arquitetura das civilizações</h1><p id="intro"></p>
<div class="controls">
<label>Civilização<select id="race"><option value="human">Humanos</option><option value="elf">Elfos</option><option value="dwarf">Anões</option><option value="orc">Orcs</option></select></label>
<label>Construção<select id="asset"></select></label>
<label>Vista<select id="view"><option value="three_quarter">Três quartos</option><option value="game_top">Mapa</option><option value="top">Topo</option><option value="back">Traseira</option></select></label>
</div><p id="design"></p><div class="pair">
<figure><figcaption>Antes</figcaption><a id="beforeLink"><img id="before" alt=""></a></figure>
<figure><figcaption>Depois</figcaption><a id="afterLink"><img id="after" alt=""></a></figure>
</div><footer><a href="../../docs/BUILDING_ARCHITECTURE_REVISION.md">Catálogo e verificação</a> · Originais preservados · Blender MCP</footer></main>
<script>
const assets=__ASSETS__;
const race=document.querySelector('#race'),asset=document.querySelector('#asset'),view=document.querySelector('#view');
let selectedStem='war_stable_hex_v1';
document.querySelector('#intro').textContent=assets.length+' prédios revisados. Compare os materiais, a forma das coberturas e os apoios estruturais nas quatro vistas.';
function choices(){const current=assets[Number(asset.value)];if(current)selectedStem=current.stem;asset.replaceChildren();
  assets.forEach((item,index)=>{if(item.race!==race.value)return;const option=document.createElement('option');option.value=index;option.textContent=item.name;asset.append(option);if(item.stem===selectedStem)option.selected=true;});show();}
function show(){const item=assets[Number(asset.value)];if(!item)return;selectedStem=item.stem;document.querySelector('#design').textContent=item.design;
  for(const side of ['before','after']){const src=item[side]+view.value+'.png';const img=document.querySelector('#'+side);img.src=src;img.alt=item.name+' — '+(side==='before'?'antes':'depois');document.querySelector('#'+side+'Link').href=src;}}
race.addEventListener('change',choices);asset.addEventListener('change',show);view.addEventListener('change',show);choices();
</script></html>"""
(OUT/'index.html').write_text(template.replace('__ASSETS__',payload),encoding='utf-8')
print(json.dumps({'viewer':str(OUT/'index.html'),'models':len(assets)},ensure_ascii=False))
