"""Catalog, static overview and full animation index for the eight human units."""
import json
from PIL import Image, ImageDraw, ImageFont
from human_rogue_siege_assets import ROOT, ASSETS, roles

preview=ROOT/'docs/previews/human_rogue_siege'; preview.mkdir(parents=True,exist_ok=True)
gallery=Image.new('RGB',(1440,864),(28,32,40)); draw=ImageDraw.Draw(gallery)
try: font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20)
except OSError: font=ImageFont.load_default()
rows=[]
for i,a in enumerate(ASSETS):
    folder=ROOT/'assets/generated/humans'/a['stem']; report=json.loads((folder/(a['stem']+'_report.json')).read_text(encoding='utf-8'))
    tile=Image.open(folder/'previews/threequarter.png').convert('RGB').resize((360,360),Image.Resampling.LANCZOS)
    x=i%4*360; y=i//4*432; gallery.paste(tile,(x,y))
    draw.text((x+12,y+368),a['label'],font=font,fill=(239,239,239))
    draw.text((x+12,y+398),str(a['height']).replace('.',',')+' m / '+str(report['triangles'])+' tris / '+str(len(roles(a)))+' clipes',font=font,fill=(170,185,207))
    path='../assets/generated/humans/'+a['stem']+'/'
    rows.append('| '+a['label']+' | '+str(a['height']).replace('.',',')+' m | '+str(report['triangles'])+' | '+str(len(roles(a)))+' | [GLB]('+path+a['stem']+'.glb) · [Blender]('+path+a['stem']+'.blend) · [Prévia]('+path+'previews/threequarter.png) |')
gallery.save(preview/'overview.png')
lines=['# Tropas humanas — Ladino e Cerco','','Produção pelo Blender MCP, concluindo e salvando cada unidade antes da seguinte. Somente arte humana. Fontes anteriores preservadas por SHA-256.','',
       '![As oito tropas humanas](previews/human_rogue_siege/overview.png)','','| Unidade | Altura | Triângulos | Clipes | Arquivos |','|---|---:|---:|---:|---|',*rows,'',
       '## Derivação e acabamento','',
       'Guerreiro aprovado → Ladino → Sabotador → Assassino → Mestre das Sombras. A geometria real do antecessor foi copiada, preservando os blocos do corpo e suas juntas. Capuz e máscara são pintados no único bloco da cabeça. A evolução acrescenta bolsa e ferramentas, segunda adaga, proteção de ombro e capa dividida; o lendário tem capa longa com acabamento dourado. Os três comuns têm 1,80 m de corpo; o lendário tem 2,00 m.','',
       'Catapulta → Trebuchet → Bombarda → Colosso de Cerco. O chassi foi copiado e os mecanismos evoluem: braço de torção; pórtico com contrapeso pendente e funda; canhão oco com recuo; grande bombarda de cano único, carro de carvalho com laterais inclinadas, seis rodas com raios e guincho manual. Máquinas sem tripulação visível. Altura de repouso: 1,80 m para as comuns e 2,00 m para o Colosso. No Colosso, a altura vem da estrutura de madeira. Madeira, ferro e azul humano; dourado adicional no lendário.','',
       'Capas presas ao torso, selos presos ao cinto, eixos sustentados por mancais, bandeiras com suportes ligados ao chassi e mastros laterais fora do caminho do braço de lançamento. Rodas do Colosso têm espaçamento próprio.','',
       'O Colosso recebeu uma revisão visual completa, preservando o chassi, o rig e as curvas dos cinco clipes. Apoios laterais e trilho de recuo deixam o interior do canhão livre. A revisão passou na importação Godot, na inspeção de geometria e nos dois testes de reprodução das tropas (77 assertivas). [Relatório da revisão](siege_colossus_redesign_validation.json).','',
       '## Animações cumulativas','',
       '| Linha | Todas as unidades | A partir da primeira evolução |','|---|---|---|',
       '| Ladino | Idle, Walk, Attack, SneakAttack | Dismantle (Sabotador, Assassino, Mestre das Sombras) |',
       '| Cerco | Idle, Walk, Attack, DemolitionAmmo | PreparedBombardment (Trebuchet, Bombarda, Colosso) |','',
       'Os quatro ladinos usam o mesmo rig rígido de 16 ossos. As curvas de todos os clipes herdados são cópias exatas, verificadas por SHA-256; a altura lendária fica somente no ROOT. No cerco, os papéis dos clipes são herdados e os movimentos se adaptam ao mecanismo (lançamento ou recuo). Todos os clipes são amostrados a 24 fps, Idle/Walk repetem, ações recuperam a postura inicial e têm marcador de impacto. GIF/MP4 de revisão em 12 fps.','',
       'Revisão 3D: abra [_human_rogue_siege_review.tscn](../_human_rogue_siege_review.tscn) no Godot e pressione F6. Teclas 1–5 selecionam parado, andar, ataque, técnica inicial e técnica avançada; Q/E giram a câmera.','',
       '## Animações para revisão','']
for a in ASSETS:
    lines += ['### '+a['label'],'','| Ação | Revisão |','|---|---|']
    path='../assets/generated/humans/'+a['stem']+'/previews/animations/'
    for role in roles(a):
        clip=a['prefix']+'_'+role
        lines.append('| '+role+' | [GIF]('+path+clip+'.gif) · [MP4]('+path+clip+'.mp4) · [Contato]('+path+clip+'_contact.png) |')
    lines += ['']
lines += ['## Uso no Godot','',
          'Cada GLB tem uma malha, um material e um esqueleto; atlas albedo/emission embutidos e filtro nearest. Frente +Z, origem no solo, escala nativa 1:1. Fonte Blender isolada e editável, com peças separadas e os mesmos clipes. O script de pós-importação de cada modelo configura os loops.','',
          'UnitDatabase usa os novos caminhos e o helper existente das tropas humanas, com crossfade de 0,2 s e mapeamento de técnicas. Não há mudanças nos atributos ou regras de combate. Desmantelar e Munição Demolidora permanecem passivas no jogo; os respectivos clipes estão entregues para uso visual e revisão. Ataque Furtivo e Bombardeio Preparado usam os clipes pelo fluxo existente das técnicas.','',
          'Validações: [importação Godot](human_rogue_siege_godot_validation.json), [geometria e suportes](human_rogue_siege_geometry_validation.json), [reprodução no jogo](human_rogue_siege_runtime_validation.json), [fontes anteriores](human_rogue_siege_source_baseline.json). Os 10 testes das duas suítes de tropas passaram, com 260 assertivas. Teste do playback real em Unit: test/unit/test_v2_human_rogue_siege_models.gd.','',
          'Pipeline: tools/art_pipeline/human_rogue_siege_live.py e run_human_rogue_siege.py; somente MCP do Blender para modelagem, animação, render e exportação.']
(ROOT/'docs/HUMAN_ROGUE_SIEGE_CATALOG.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'catalog':'docs/HUMAN_ROGUE_SIEGE_CATALOG.md','overview':str(preview/'overview.png'),'units':len(ASSETS),'clips':sum(len(roles(a)) for a in ASSETS)}))
