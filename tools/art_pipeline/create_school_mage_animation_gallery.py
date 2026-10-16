"""Build a local animated review from the one native Godot capture session."""
import html,json,re
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/school_mages_animation_review'
RACES={'human':'Humanos','elf':'Elfos','dwarf':'Anões','orc':'Orcs'}

def build():
    manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
    assert manifest['models']==24 and manifest['clips']==72
    native=json.loads((ROOT/'docs/school_mages_animation_godot_native_validation.json').read_text(encoding='utf-8'))
    assert native['status']=='PASS'
    preview_clips=['idle','walk','spell','dwarf_idle_side','dwarf_walk_side','dwarf_spell_side']
    for clip in preview_clips:
        files=sorted((WORK/'native_frames'/clip).glob('*.png'))
        assert len(files)==native['frames'][clip]
        images=[Image.open(p).convert('RGB') for p in files]
        images[0].save(WORK/(clip+'.webp'),format='WEBP',save_all=True,append_images=images[1:],duration=42,loop=0,quality=90,method=4)
        poster=images[round(len(images)*.55)] if 'spell' in clip else images[0]
        poster.save(WORK/(clip+'_poster.png'))
        for image in images: image.close()
    sections=[]
    for race,label in RACES.items():
        assets=[a for a in manifest['assets'] if a['race']==race]; casting=assets[0]['animation']
        folder=WORK/'blender_cast_poses'/race
        sheet=Image.new('RGB',(1200,800))
        for index in range(6):
            with Image.open(folder/(str(index)+'.png')) as im: sheet.paste(im.convert('RGB').resize((400,400)),((index%3)*400,(index//3)*400))
        sheet.save(folder/'contact_sheet.jpg',quality=92)
        blend='../'+race+'_school_mages_review/'+race+'_school_mages_six_schools_review.blend'
        cards=[]
        for row in assets:
            base=(ROOT/row['blend']).parent; spec=row['animation']
            cards.append(f'<article><h3>{html.escape(row["name"])}</h3><img loading="lazy" src="../../{base.relative_to(ROOT).as_posix()}/previews/three_quarter.png" alt="{html.escape(row["name"])}"><p>{row["geometry"]["triangles"]} triângulos · 1 material · 16 ossos</p><nav><a href="../../{row["blend"]}">Blender</a><a href="../../{row["glb"]}">GLB animado</a></nav></article>')
            readme=base/'README.md'; text=readme.read_text(encoding='utf-8')
            text=text.replace('com metadados para futura rigagem','com rig de 16 ossos')
            text=text.replace('exportação estática','exportação animada')
            text=re.sub(r'- (?:Sem rig/animações nesta etapa\.|Modelo estático para conferência, ainda sem rig ou animações\.|Modelos estáticos para revisão, ainda sem rig ou animações\.)[^\n]*','- Rig de 16 ossos; animações `idle`, `walk` e `spell`. Banco de unidades inalterado.',text)
            if '## Animações' not in text:
                text+=f'\n## Animações\n\nCriadas via MCP do Blender, preservando geometria, UVs e texturas aprovadas.\n\n- `idle`: 3 s, loop.\n- `walk`: 1,5 s, loop no lugar; velocidade de referência {spec["walk_speed_m_per_s"]:.3f} m/s.\n- `spell`: 3 s, execução única; liberação em {spec["spell_release_seconds"]:.2f} s. Casting comum às seis escolas desta raça: {spec["casting_name"]}.\n- Blender: idle nos frames 1–145, walk 161–233, spell 241–385; 48 fps. O intervalo de prévia está no casting.\n- Godot: preserve `.glb.import` e o post-import `school_mage_animation_import.gd`, que configura filtro pixelizado e loops. Escala nativa 1,0.\n\n[Galeria das animações](../../../../art_source/school_mages_animation_review/index.html).\n'
            if '### Revisão 3 dos movimentos' not in text:
                text+='\n### Revisão 3 dos movimentos\n\nCasting articulado pelo ombro e por um eixo fixo de cotovelo. Antebraço sem torção axial independente; mão acompanha o antebraço, com pequeno movimento controlado de punho na mão livre. Caminhada também usa o eixo anatômico do cotovelo. Verificados os frames completos, a suavidade angular, o contato mão/cetro, os pés e a ausência de cruzamentos de mãos/antebraços com o torso.\n'
            readme.write_text(text,encoding='utf-8')
        sections.append(f'<section id="{race}"><h2>{label} · {html.escape(casting["casting_name"])}</h2><p>{html.escape(casting["casting_description"])} Liberação em {casting["spell_release_seconds"]:.2f} s.</p><a href="{blend}">Abrir os seis {label.lower()} animados no Blender</a><details><summary>Ver as etapas do gesto no Blender</summary><img src="blender_cast_poses/{race}/contact_sheet.jpg" alt="Seis etapas do casting"></details><div class="grid">'+''.join(cards)+'</div></section>')
        original=ROOT/'art_source'/(race+'_school_mages_review')
        for name in ['README.md','index.html']:
            path=original/name; text=path.read_text(encoding='utf-8')
            text=text.replace('Sem rig/animações nesta etapa','Com rig e animações idle, walk e spell')
            text=text.replace('ainda sem animações','com animações idle, walk e spell')
            text=text.replace('Modelos estáticos para revisão, ainda sem rig ou animações','Modelos com rig e animações idle, walk e spell')
            text=text.replace('Modelos estáticos para conferência','Modelos animados para conferência')
            text=text.replace('Modelos independentes e estáticos para conferência','Modelos independentes e animados para conferência')
            if name.endswith('.html') and '../school_mages_animation_review/index.html' not in text:
                text=text.replace('<main>','<main><nav><a href="../school_mages_animation_review/index.html">Ver idle, walk e os quatro castings</a></nav>',1)
            elif name.endswith('.md') and 'school_mages_animation_review/index.html' not in text:
                text+='\nAnimações: `idle` 3 s e `walk` 1,5 s em loop; `spell` 3 s sem loop. Na cena Blender: idle 1–145, walk 161–233, spell 241–385 a 48 fps. [Galeria animada](../school_mages_animation_review/index.html).\n'
            path.write_text(text,encoding='utf-8')
    previews=[]
    for clip,label in [('spell','Casting · spell · 3 s'),('idle','Descanso · idle · 3 s'),('walk','Caminhada · walk · 1,5 s')]:
        previews.append(f'<section><h2>{label}</h2><p>Da esquerda para a direita: humano, elfo, anão e orc. Captura dos GLBs no Godot com o terreno e a iluminação do jogo.</p><button data-clip="{clip}" aria-pressed="true">Pausar prévia</button><img id="{clip}-preview" src="{clip}.webp" alt="Animação {clip} nas quatro raças"><p class="small">A prévia repete para comparação; o clip spell no GLB é executado uma única vez.</p></section>')
    side_previews='<section><h2>Anão · revisão das articulações de lado</h2><p>Cotovelo com eixo fixo, antebraço sem torção e mão acompanhando o braço. Movimento completo nos três clips.</p>'
    for clip,label in [('dwarf_spell_side','Casting de lado'),('dwarf_walk_side','Caminhada de lado'),('dwarf_idle_side','Descanso de lado')]:
        side_previews+=f'<h3>{label}</h3><button data-clip="{clip}" aria-pressed="true">Pausar prévia</button><img id="{clip}-preview" src="{clip}.webp" alt="{label}">'
    side_previews+='</section>'
    page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>24 magos · animações</title><style>
body{margin:0;background:#18212b;color:#ece8dc;font:16px/1.55 system-ui,sans-serif}main{max-width:1280px;margin:auto;padding:28px}h1{font-size:34px}h2{margin-top:12px}a{color:#a3d2fa}p{color:#c6d0d4}section{margin:36px 0}img{width:100%;display:block;border-radius:8px}nav{display:flex;gap:20px;flex-wrap:wrap;margin:12px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:18px}article{background:#24313d;padding:18px;border-radius:10px}article p,.small{font-size:14px}button{background:#3c5367;color:#fff;border:0;padding:10px 18px;border-radius:6px;margin-bottom:12px;cursor:pointer}summary{cursor:pointer;padding:16px 0}details{margin:16px 0}</style><main>
<h1>24 magos · idle, walk e spell</h1><p>Seis escolas por civilização. Humanos e elfos usam gestos relacionados, com ritmo e condução próprios; anões lançam um pulso firme e orcs usam um ritual amplo. O casting é compartilhado pelas seis escolas de cada raça.</p>
<nav><a href="school_mages_24_animated_review.blend">Abrir os 24 animados no Blender</a><a href="manifest.json">Manifesto dos assets</a><a href="#human">Humanos</a><a href="#elf">Elfos</a><a href="#dwarf">Anões</a><a href="#orc">Orcs</a></nav>
<p>Revisão 3 das animações: cotovelos com eixo fixo, mãos acompanhando os antebraços e casting articulado desde o ombro. Humanos com roupas simplificadas, sem adornos aplicados em 3D; anatomia, UVs, texturas e animações aprovadas preservadas. GLBs com 1 malha, 1 material e 16 ossos por personagem. Metros, escala 1,0 e pivô nos pés.</p>'''+''.join(previews)+side_previews+''.join(sections)+'''<section><h2>Os 24 na câmera do jogo</h2><img src="godot_all_24_game_view.png" alt="24 magos no ângulo da câmera do jogo"><p>No Blender, a prévia abre no casting: frames 241–385. Descanso: 1–145; caminhada: 161–233. Todas as cenas usam 48 fps.</p></section>
<script>document.querySelectorAll('button[data-clip]').forEach(button=>button.addEventListener('click',()=>{let clip=button.dataset.clip,img=document.getElementById(clip+'-preview'),playing=button.getAttribute('aria-pressed')==='true';img.src=clip+(playing?'_poster.png':'.webp');button.setAttribute('aria-pressed',String(!playing));button.textContent=playing?'Reproduzir prévia':'Pausar prévia';}));</script></main></html>'''
    (WORK/'index.html').write_text(page,encoding='utf-8')
    (WORK/'README.md').write_text('''# Magos das quatro civilizações — animações

24 modelos, 72 clips. Abra `index.html` para ver as animações capturadas no Godot ou `school_mages_24_animated_review.blend` para conferir os 24 lado a lado no Blender.

`idle`: 3 s em loop. `walk`: 1,5 s em loop, no lugar. `spell`: 3 s, execução única. Cada raça compartilha o casting entre as seis escolas. Humanos e elfos têm gestos próximos com condução distinta; anões usam um pulso firme e orcs um ritual amplo.

Revisão 3 dos movimentos: eliminada a torção axial independente dos antebraços durante o casting, especialmente visível nos braços largos dos anões. Cotovelos com eixo fixo e mãos seguindo os antebraços; os dois braços do casting são articulados desde o ombro. A revisão inclui limites de punho, suavidade angular e cruzamentos com o corpo, além de prévias laterais do anão para idle, walk e spell. A versão anterior está em `before_arm_logic_revision_3/`.

Blender: 48 fps; idle 1–145, walk 161–233, spell 241–385. A faixa de prévia abre em spell. Use Alt+A / Espaço para reproduzir. As cenas raciais continuam nos diretórios de revisão de cada raça, agora animadas.

Fontes editáveis e GLBs individuais estão nos caminhos do `manifest.json`. Uma malha, um material, dezesseis ossos por GLB. Proporções, geometria, UVs e texturas aprovadas preservadas; pesos rígidos mantêm o estilo blocky. Escala em metros 1,0, pés na origem, Godot frente +Z. O post-import mantém nearest com mipmaps e configura idle/walk em loop, spell sem loop. O banco de unidades do jogo permanece como estava.

Os instantes de liberação constam em `animation.spell_release_seconds` no relatório de cada asset e no marcador SPELL_RELEASE da fonte Blender: humano 1,68 s; elfo 1,74 s; anão 1,62 s; orc 1,80 s. O jogo pode disparar os efeitos das escolas nesses instantes.

Backup integral dos modelos aprovados antes da animação em `before_animations/`. Validações em `docs/school_mages_animation_*_validation.json`: continuidade, pés apoiados, articulações conectadas, contato mão/cetro, malhas e texturas preservadas, exportação e poses dos 72 clips no Godot. Criação, rig, animações e exportação via MCP do Blender aberto. Uma sessão nativa do Godot gerou as prévias.
''',encoding='utf-8')
    # Check every locally linked artifact and source once the gallery is complete.
    links=re.findall(r'(?:href|src)="([^"#]+)"',page)
    for relative in links: assert (WORK/relative).exists(),relative
    (WORK/'current_stage.json').write_text(json.dumps(dict(stage='completed',status='PASS',models=24,clips=72)),encoding='utf-8')
    print(json.dumps(dict(status='PASS',models=24,clips=72,animated_previews=len(preview_clips),valid_local_links=len(links))))

if __name__=='__main__': build()
