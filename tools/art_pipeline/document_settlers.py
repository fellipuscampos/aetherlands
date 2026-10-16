"""Document the four static editable settlers and their Blender review."""
import json,html
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art_source/settlers_review'
validation=json.loads((ROOT/'docs/settlers_blender_validation.json').read_text(encoding='utf-8'))
assert validation['status']=='PASS' and validation['verified']==4
assets=validation['assets']; rows=[]; cards=[]
for asset in assets:
    folder=ROOT/'assets/generated'/dict(human='humans',elf='elves',dwarf='dwarves',orc='orcs')[asset['race']]/asset['stem']
    relative=folder.relative_to(ROOT).as_posix(); prefix='../../'+relative+'/'
    for ext in ('.blend','.glb','_albedo.png','_report.json'): assert (folder/(asset['stem']+ext)).is_file()
    rows.append(dict(stem=asset['stem'],name=asset['name'],race=asset['race'],source=asset['source'],source_sha256=asset['source_sha256'],blend=relative+'/'+asset['stem']+'.blend',glb=relative+'/'+asset['stem']+'.glb',texture=relative+'/'+asset['stem']+'_albedo.png',triangles=asset['geometry']['triangles'],editable_parts=asset['geometry']['editable_parts'],height=round(asset['geometry']['dimensions'][2],3),animations=0,static_glb_meshes=asset['export']['meshes'],static_glb_surfaces=asset['export'].get('surfaces',asset['export']['meshes'])))
    cards.append(f'<article><img src="{prefix}previews/three_quarter.png" alt="{html.escape(asset["name"])}"><h2>{html.escape(asset["name"])}</h2><p>{asset["geometry"]["triangles"]} triângulos · {asset["geometry"]["editable_parts"]} peças editáveis</p><nav><a href="{prefix}{asset["stem"]}.blend">Blender individual</a><a href="{prefix}{asset["stem"]}.glb">GLB estático</a><a href="{prefix}previews/back.png">Costas</a></nav></article>')
manifest=dict(version='settlers_v1',pipeline='Live Blender MCP localhost:9876',stage='static_visual_review',animations=0,rigging_deferred=True,pixel_density=64,texture_filter='NEAREST',ground_pivot=True,review_blend='art_source/settlers_review/settlers_four_civilizations_review.blend',assets=rows)
(WORK/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Quatro colonizadores — revisão</title><style>
*{box-sizing:border-box}body{margin:0;padding:28px;background:#172029;color:#e4e3dc;font:16px/1.55 system-ui,sans-serif}main{max-width:1400px;margin:auto}h1{font-size:28px;margin:0 0 8px}h2{font-size:18px;margin:12px 0 4px}a{color:#b9d1e1}nav{display:flex;flex-wrap:wrap;gap:12px}button{border:1px solid #526776;background:#263643;color:#eee;padding:9px 16px;cursor:pointer;border-radius:5px}button[aria-pressed=true]{background:#566e7f}.overview{width:100%;display:block;border-radius:8px;margin:15px 0 24px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:18px}article{background:#25313b;padding:14px;border-radius:8px}article img{width:100%;border-radius:5px}p{color:#c1c7c8}article p{font-size:14px}@media(max-width:900px){.grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:540px){body{padding:16px}.grid{grid-template-columns:1fr}}
</style><main><h1>Quatro colonizadores</h1><p>Humano, elfo, anão e orc — anatomias do projeto, roupas civis, mochilas e ferramentas. Modelos estáticos, sem animações. A cena do Blender reúne os quatro lado a lado na escala original.</p><p><a href="settlers_four_civilizations_review.blend">Abrir cena comparativa no Blender</a> · <a href="README.md">Guia dos arquivos</a></p><nav aria-label="Vistas"><button data-view="three_quarter" aria-pressed="true">Perspectiva</button><button data-view="front" aria-pressed="false">Frente</button><button data-view="back" aria-pressed="false">Costas</button></nav><a id="full" href="settlers_three_quarter.png"><img id="overview" class="overview" src="settlers_three_quarter.png" alt="Os quatro colonizadores lado a lado"></a><section class="grid">'''+''.join(cards)+'''</section><p>Textura pixelizada a 64 px/m, uma textura/material por personagem. Geometria fechada, pivôs no chão e nenhuma sobreposição coplanar exposta na revisão.</p><p><a href="../building_architecture_review/index.html">Voltar às construções</a></p></main><script>document.querySelectorAll('[data-view]').forEach(button=>button.addEventListener('click',()=>{const path='settlers_'+button.dataset.view+'.png';document.querySelector('#overview').src=path;document.querySelector('#full').href=path;document.querySelectorAll('[data-view]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));}));</script></html>'''
(WORK/'index.html').write_text(page,encoding='utf-8')
guide='''# Colonizadores — revisão estática

Quatro modelos criados no Blender aberto via MCP. Sem novas animações e sem rig nesta etapa; os membros e equipamentos continuam separados e nomeados para a próxima etapa de rig/animação.

Abra [settlers_four_civilizations_review.blend](settlers_four_civilizations_review.blend) para ver **humano, elfo, anão e orc**, da esquerda para a direita, na mesma cena. No Blender aberto, a cena ativa chama-se `Settlers_V1_Four_Civilizations_Review`; as quatro coleções têm nomes em português.

- Humano: lã azul, camisa de linho, gorro de viagem, mochila com manta, pá e mapa enrolado.
- Elfo: túnica verde, cabelo claro e orelhas pontudas, mochila de fibras, caixa de sementes e cajado.
- Anão: anatomia robusta e barba da base aprovada, roupa de trabalho, caixa de ferramentas, picareta presa e lanterna.
- Orc: anatomia e presas da base aprovada, couro e cordas, saco de sementes, mochila reforçada e maço de pedra.

## Arquivos individuais

| Civilização | Fonte editável | Exportação estática | Triângulos |
|---|---|---|---:|
'''
for row in rows:
    guide+=f'| {row["name"].replace("Colonizador ","")} | [BLEND](../../{row["blend"]}) | [GLB](../../{row["glb"]}) | {row["triangles"]} |\n'
guide+='''
Cada pasta também contém a textura PNG, o relatório JSON e as prévias de frente, perspectiva e costas. Os arquivos de revisão ficam fora da importação do Godot através de `.gdignore`.

Escala nativa em metros; origem central no chão, frente em −Y no Blender. Após exportação glTF, o eixo vertical é +Y. As anatomias humanas e élficas usam a mesma base humana aprovada; o anão deriva de `dwarf_base_v1`, e o orc da anatomia revisada de `orc_squire_v1`. As fontes existentes foram lidas e preservadas.

Texturas: atlas de 512 × 512 por personagem, filtragem Nearest, 64 px/m em todas as peças, UVs com margem de três pixels. Sem suavização, transparência ou emissão. A luz da lanterna do anão é apenas cor pintada nesta etapa.

Os GLBs estáticos têm uma malha e uma superfície por personagem, com a mesma geometria e textura das fontes. A montagem em peças separadas fica preservada nos arquivos BLEND para rig e animação futuros. Ainda não há animações, skins ou esqueleto nesses GLBs.

Os modelos ainda não foram substituídos no catálogo ou no mapa do jogo. O colonizador humano antigo continua preservado. A próxima etapa pode reutilizar as peças identificadas com `future_bone`, após a revisão visual.

Validação: geometria fechada, volume positivo, normais externas, transformações de objeto aplicadas, pivô no chão, densidade de textura medida, nenhum triângulo degenerado e nenhuma face coplanar sobreposta exposta. Encaixes internos entre peças fechadas foram classificados separadamente. Os GLBs não contêm skins, animações, câmeras ou luzes de estúdio; suas texturas embutidas correspondem aos PNGs.

[Galeria](index.html) · [Manifesto](manifest.json) · [Validação Blender](../../docs/settlers_blender_validation.json)
'''
(WORK/'README.md').write_text(guide,encoding='utf-8')
old=ROOT/'art_source/building_architecture_review/index.html'; text=old.read_text(encoding='utf-8')
if '../settlers_review/index.html' not in text:
    marker='</main>' if '</main>' in text else '</body>'
    assert marker in text
    text=text.replace(marker,'<p><a href="../settlers_review/index.html">Quatro colonizadores — humano, elfo, anão e orc</a></p>'+marker,1)
    old.write_text(text,encoding='utf-8')
print(json.dumps(dict(status='PASS',assets=4,review=str(WORK/'settlers_four_civilizations_review.blend')),ensure_ascii=True))
