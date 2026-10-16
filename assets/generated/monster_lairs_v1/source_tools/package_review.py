"""Validate the actual binary GLBs and assemble an offline art review. No Godot invocation."""
import json
import math
import hashlib
import struct
import html
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
OUT=ROOT/'assets/generated/monster_lairs_v1'
KINDS=['goblin','skeleton','worg','giant_spider','troll','wyvern','minotaur','basilisk',
       'colossal_worm','arboreal_ancient','mana_devourer','corrupted_hero']

def read_glb(path):
    data=path.read_bytes(); magic,version,length=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and length==len(data)
    offset=12; chunks={}
    while offset<len(data):
        n,kind=struct.unpack_from('<II',data,offset); offset+=8
        chunks[kind]=data[offset:offset+n]; offset+=n
    return json.loads(chunks[0x4e4f534a]),chunks[0x004e4942]

def accessor(doc,blob,index):
    a=doc['accessors'][index]; v=doc['bufferViews'][a['bufferView']]
    fmt,size={5126:('f',4),5125:('I',4),5123:('H',2),5121:('B',1)}[a['componentType']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    stride=v.get('byteStride',size*n); offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*n,blob,offset+i*stride) for i in range(a['count'])]

def validate():
    reports=[]; audit=[]
    assert (OUT/'.gdignore').exists()
    for kind in KINDS:
        stem=kind+'_lair_v1'; folder=OUT/stem
        report=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
        glb=folder/(stem+'.glb'); doc,blob=read_glb(glb)
        assert len(doc['meshes'])==1 and len(doc['materials'])==1
        assert not doc.get('animations') and not doc.get('skins') and not doc.get('cameras')
        assert all('STUDIO' not in n.get('name','') for n in doc['nodes'])
        assert 'KHR_lights_punctual' not in doc.get('extensions',{})
        mesh=doc['meshes'][0]; assert len(mesh['primitives'])==1
        prim=mesh['primitives'][0]; assert prim.get('mode',4)==4
        pos=accessor(doc,blob,prim['attributes']['POSITION'])
        normals=accessor(doc,blob,prim['attributes']['NORMAL'])
        uvs=accessor(doc,blob,prim['attributes']['TEXCOORD_0'])
        indices=[v[0] for v in accessor(doc,blob,prim['indices'])]
        assert len(indices)//3==report['triangles']
        assert all(0<=i<len(pos) for i in indices)
        assert all(math.isfinite(c) for v in pos+normals+uvs for c in v)
        assert all(abs(sum(c*c for c in n)-1)<1e-4 for n in normals)
        assert all(0<=c<=1 for uv in uvs for c in uv)
        # Check the GLB itself, after the Blender Z-up -> glTF Y-up conversion.
        ground=min(v[1] for v in pos); height=max(v[1] for v in pos)
        radius=max(math.hypot(v[0],v[2]) for v in pos)
        assert abs(ground)<1e-5 and abs(height-report['height'])<1e-5
        assert radius<=.78001
        for i in range(0,len(indices),3):
            a,b,c=[pos[j] for j in indices[i:i+3]]
            ab=[b[j]-a[j] for j in range(3)]; ac=[c[j]-a[j] for j in range(3)]
            cross=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
            assert sum(v*v for v in cross)>1e-18
        assert len(doc['images'])==2
        assert all('bufferView' in im and 'uri' not in im for im in doc['images'])
        assert all(s.get('magFilter')==9728 and s.get('minFilter') in (9728,9984,9986) for s in doc['samplers'])
        assert doc['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE'
        for view in ('three_quarter','game_top','back'):
            image=Image.open(folder/'previews'/(view+'.png')); image.verify()
        assert (folder/(stem+'.blend')).stat().st_size>10000
        audit.append(dict(kind=kind,result='PASS',glb_bytes=glb.stat().st_size,
                          glb_sha256=hashlib.sha256(glb.read_bytes()).hexdigest(),
                          triangles=len(indices)//3,radius=radius,height=height,ground_y=ground,
                          meshes=1,primitives=1,materials=1,embedded_images=2,filter='nearest',
                          finite_values=True,unit_normals=True,nonzero_triangle_areas=True))
        reports.append(report)
    baseline=json.loads((WORK/'protected_monster_models.json').read_text())
    changed=[p for p,sha in baseline.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=sha]
    assert not changed,changed
    (OUT/'validation.json').write_text(json.dumps(dict(status='PASS',assets=audit,
        original_monster_files_checked=len(baseline),original_monster_files_changed=changed,
        validation='Binary GLB inspection; no Godot process launched or interrupted.'),indent=2),encoding='utf-8')
    (OUT/'manifest.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
    return reports

def review(reports):
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',21)
    bold=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',24)
    title=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',34)
    for view,label in [('three_quarter','Covis de monstros — modelos finais'),('game_top','Covis de monstros — câmera alta')]:
        sheet=Image.new('RGB',(1600,1440),'#161f27'); d=ImageDraw.Draw(sheet)
        d.text((30,18),label,font=title,fill='#f2e6c8')
        d.text((30,65),'De cima para baixo: básicos, intermediários e avançados',font=font,fill='#9daeb9')
        # Each row is one tier; four species side by side.
        for i,r in enumerate(reports):
            x=(i%4)*400+10; y=(i//4)*440+108
            # Use contain instead of cropping: no parts or silhouette can be hidden by the review.
            picture=ImageOps.contain(Image.open(OUT/r['stem']/'previews'/(view+'.png')).convert('RGB'),(380,380))
            sheet.paste(picture,(x+(380-picture.width)//2,y))
            d.text((x+8,y+382),r['name'],font=bold,fill='#f2e6c8')
            d.text((x+8,y+412),r['kind']+' · '+str(r['triangles'])+' tri',font=font,fill='#a8bac5')
        sheet.save(OUT/('catalog_'+view+'.jpg'),quality=94)
    cards=[]
    for r in reports:
        stem=r['stem']; name=html.escape(r['name']); concept=html.escape(r['concept'])
        links=' · '.join(f'<a href="{stem}/{stem}.{ext}">{ext.upper()}</a>' for ext in ('blend','glb'))
        cards.append(f'''<article><a href="{stem}/previews/three_quarter.png"><img src="{stem}/previews/three_quarter.png" alt="{name}"></a>
<div><small>{r['tier']} · {r['kind']}</small><h2>{name}</h2><p>{concept}</p>
<p>{r['triangles']} triângulos · {r['editable_parts']} peças editáveis · {r['height']:.2f} m de altura</p>
<p>{links} · <a href="{stem}/previews/game_top.png">Câmera alta</a> · <a href="{stem}/previews/back.png">Traseira</a></p></div></article>''')
    page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Aetherlands — Covis de monstros</title><style>
*{box-sizing:border-box}body{margin:0;background:#151e25;color:#e4e8e9;font:16px/1.5 system-ui,sans-serif}header,main{max-width:1450px;margin:auto;padding:30px}h1{font-size:38px;color:#f1dfb7;margin:0 0 8px}header p{max-width:900px;color:#b4c3ce}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:22px;padding-top:0}article{background:#202e38;border:1px solid #354854;border-radius:12px;overflow:hidden}article img{display:block;width:100%;aspect-ratio:1;object-fit:contain}article div{padding:20px}h2{font-size:22px;margin:7px 0}small{color:#d5ba81}p{margin:9px 0}a{color:#91cddd}nav{display:flex;gap:24px;flex-wrap:wrap;margin-top:22px}
</style><header><h1>Covis de monstros</h1><p>12 locais de origem para o bestiário ecológico. Modelados no Blender via MCP, com volumes blocky e texturas em pixels. Fontes editáveis, GLBs e três vistas por espécie.</p><p>Arte isolada da importação automática do Godot. Nenhuma alteração no código, combate ou spawn. Origem no chão, frente +Z no glTF e raio máximo de 0,78 m para o hex de raio 1 m.</p><nav><a href="catalog_three_quarter.jpg">Prancha geral</a><a href="catalog_game_top.jpg">Prancha da câmera alta</a><a href="validation.json">Validação dos GLBs</a><a href="README.md">Entrega e integração</a></nav></header><main>'''+''.join(cards)+'</main></html>'
    page=page.replace('<a href="catalog_three_quarter.jpg">Prancha geral</a>',
        '<a href="monster_lairs_v1_catalog.blend">Todos no Blender</a><a href="catalog_three_quarter.jpg">Prancha geral</a>')
    (OUT/'index.html').write_text(page,encoding='utf-8')
    concepts='\n'.join('- **'+r['name']+'** (`'+r['kind']+'`): '+r['concept'] for r in reports)
    (OUT/'README.md').write_text('''# Covis de monstros — Aetherlands V1

12 modelos originais criados no Blender aberto, exclusivamente pelo MCP `localhost:9876`.
Abra `index.html` para conferir a galeria ou as pranchas `catalog_three_quarter.jpg` e `catalog_game_top.jpg`.
`monster_lairs_v1_catalog.blend` reúne os 12 covis numa cena, na mesma escala, organizados por espécie.

## Conceitos

'''+concepts+'''

## Arquivos e escala

Cada subpasta contém a fonte `.blend` com as peças separadas e materiais empacotados,
um `.glb` com uma malha / um material, `manifest.json`, README e três renders:
`three_quarter`, `game_top` e `back`. O cenário de estúdio e os anchors de referência
existem somente no Blender e não estão nos arquivos GLB.

Todos os modelos têm origem no chão, escala aplicada, frente -Y no Blender / +Z no glTF.
Raio horizontal máximo de 0,78 m: cabe no hex de raio 1 m, cuja meia largura é 0,866 m.
Albedo e emissão 1024×1024 estão embutidos; amostragem nearest, densidade de 64 px/m.
A emissão discreta só aparece nos vestígios de mana e de pedra viva.
As cavidades são geometria com fundo acima do chão: não exigem cortar o terreno.
As peças são volumes fechados; junções entre pedras, raízes e estrutura podem se intersectar.

## Integração posterior

Esta entrega é exclusivamente de arte. Não modifica `LairStructure.gd`, bancos de monstros,
cenas, importadores, HP, líder, spawn ou lógica de destruição. A estrutura visual pode ser
removida junto com a entidade do covil quando o jogo resolver o golpe de destruição.
Não há colisão, animação nem scripts de runtime no GLB.

A raiz desta pasta tem `.gdignore` de propósito: enquanto ele existir, Godot não importa
nem monitora os novos modelos. Isso evita interferir na sessão e no trabalho paralelo.
Quando a integração for autorizada, remova esse marcador, importe os GLBs e faça o
mapeamento `kind -> <kind>_lair_v1/<kind>_lair_v1.glb` no consumidor visual apropriado.
As prévias, fontes Blender e o atlas de referência podem permanecer fora do runtime.
Siga então a auditoria de texturas BC7 já documentada em `docs/ASSET_FACTORY_GUIDE.md`.

## Verificações

`validation.json` inspeciona o binário de cada GLB: malha e material únicos, texturas
embutidas, nearest, bounds, origem no chão, área dos triângulos, normais, UVs e ausência
de câmeras/luzes de estúdio. `blender_validation.json` registra a reimportação no Blender
e a abertura isolada das fontes. Os 25 arquivos `.blend`/`.glb` dos monstros existentes
são comparados por SHA-256 antes/depois. Nenhum processo Godot é lançado ou interrompido.

Scripts de reprodução e logs: `art_source/monster_lairs_v1/`. Para reproduzir, use
`python art_source/monster_lairs_v1/run_mcp.py --only <kind> --rebuild` com o MCP ativo.
Os scripts também estão copiados em `source_tools/` nesta entrega; preserve a estrutura
original do projeto ao reproduzir. `--rebuild` sobrescreve somente a nova arte desta versão.
''',encoding='utf-8')
    sources=OUT/'source_tools'; sources.mkdir(exist_ok=True)
    for name in ('build_lairs.py','run_mcp.py','package_review.py','validate_blender.py','create_catalog_blend.py','protected_monster_models.json'):
        if (WORK/name).exists(): shutil.copy2(WORK/name,sources/name)

if __name__=='__main__':
    reports=validate(); review(reports)
    print('PASS:',len(reports),'GLBs;',sum(r['triangles'] for r in reports),'triangles total')
