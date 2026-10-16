"""Assemble review contact sheets and document the delivered static roster."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from dwarf_troop_assets import ASSETS,FAMILIES,TIERS,ROOT,OUT

DEST=ROOT/'docs/previews/dwarf_troops'
DEST.mkdir(parents=True,exist_ok=True)
FONT=Path('C:/Windows/Fonts/arial.ttf')
font=ImageFont.truetype(str(FONT),19)
small=ImageFont.truetype(str(FONT),16)
heading=ImageFont.truetype(str(FONT),28)


def gallery(view):
    cell=360; gap=8; header=96; footer=56
    canvas=Image.new('RGB',(cell*4+gap*5,header+(cell+footer+gap)*6+gap),(25,32,39))
    draw=ImageDraw.Draw(canvas)
    draw.text((20,14),'Anões — 24 modelos estáticos',font=heading,fill=(234,227,204))
    draw.text((20,50),'Base humanoide com 18 peças • Sem pescoço • Carneiros nas quatro cavalarias',font=small,fill=(175,188,192))
    for tier,title in enumerate(TIERS):
        draw.text((gap+tier*(cell+gap),76),title,font=small,fill=(205,174,115))
    for index,row in enumerate(ASSETS):
        family_index=index//4; tier=row['tier']
        x=gap+tier*(cell+gap); y=header+family_index*(cell+footer+gap)
        im=Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB')
        im.thumbnail((cell,cell),Image.Resampling.LANCZOS)
        canvas.paste(im,(x,y))
        draw.text((x+8,y+cell+5),row['family_name']+' — '+row['name'],font=small,fill=(237,233,218))
        draw.text((x+8,y+cell+29),row['stem'],font=small,fill=(156,173,180))
    path=DEST/('roster_'+view+'.jpg'); canvas.save(path,quality=94)
    return path


def comparison():
    cell=520; canvas=Image.new('RGB',(cell*2,80+(cell+52)*2),(25,32,39))
    draw=ImageDraw.Draw(canvas)
    draw.text((18,16),'Comparação de linguagem visual — humanos e anões',font=heading,fill=(237,231,210))
    draw.text((18,52),'Quinas retas, texturas em pixels e peças articuláveis. Anatomias próprias por raça.',font=small,fill=(185,197,198))
    pairs=[('squire_v1','dwarf_shieldbearer_v1'),('guardian_champion_v1','dwarf_guardian_champion_v1')]
    for row,(human,dwarf) in enumerate(pairs):
        for column,(race,stem) in enumerate([('humans',human),('dwarves',dwarf)]):
            path=ROOT/'assets/generated'/race/stem/'previews/three_quarter.png'
            im=Image.open(path).convert('RGB').resize((cell,cell),Image.Resampling.LANCZOS)
            x=column*cell; y=80+row*(cell+52)
            canvas.paste(im,(x,y))
            draw.text((x+16,y+cell+12),('Humano — ' if column==0 else 'Anão — ')+('básica' if row==0 else 'lendária'),font=font,fill=(237,231,210))
    canvas.save(DEST/'human_dwarf_comparison.jpg',quality=94)
    # The exact front view requested by the user, alongside the revised dwarf.
    canvas=Image.new('RGB',(1040,612),(25,32,39)); draw=ImageDraw.Draw(canvas)
    draw.text((18,12),'Construção e pintura — comparação frontal',font=heading,fill=(237,231,210))
    for column,(race,stem,title) in enumerate([
        ('humans','squire_v1','Escudeiro humano — referência'),
        ('dwarves','dwarf_shieldbearer_v1','Escudeiro anão — vestes e equipamentos revisados')]):
        im=Image.open(ROOT/'assets/generated'/race/stem/'previews/front.png').convert('RGB')
        im=im.resize((520,520),Image.Resampling.LANCZOS)
        canvas.paste(im,(column*520,54))
        draw.text((column*520+12,584),title,font=small,fill=(237,231,210))
    canvas.save(DEST/'human_dwarf_front_comparison.jpg',quality=94)


def revision_comparison():
    previous=ROOT/'art_source/dwarf_troops/before_final_boot_wrist_v6/dwarves'
    if not previous.exists(): return
    examples=[('dwarf_warrior_v1','three_quarter','Guerreiro — martelo para cima, volume ajustado e mão livre'),
              ('dwarf_archer_v1','three_quarter','Patrulheiro — besta maior, botas e punho alinhados'),
              ('dwarf_guardian_champion_v1','front','Guardião — canela e pé da mesma largura, braço relaxado'),
              ('dwarf_shadow_master_v1','three_quarter','Ladino — botas contínuas e mão livre vertical')]
    cell=460; row_height=cell+46
    canvas=Image.new('RGB',(cell*2,90+len(examples)*row_height),(25,32,39))
    draw=ImageDraw.Draw(canvas)
    draw.text((18,12),'Anões — ajustes de proporção e equipamento',font=heading,fill=(237,231,210))
    draw.text((18,53),'Antes — revisão 5',font=font,fill=(185,197,198))
    draw.text((cell+18,53),'Atual — revisão 6',font=font,fill=(205,174,115))
    for index,(stem,view,label) in enumerate(examples):
        y=90+index*row_height
        for column,folder in enumerate((previous,OUT)):
            im=Image.open(folder/stem/'previews'/(view+'.png')).convert('RGB').resize((cell,cell),Image.Resampling.LANCZOS)
            canvas.paste(im,(column*cell,y))
        draw.text((12,y+cell+10),label,font=font,fill=(237,231,210))
    canvas.save(DEST/'equipment_proportions_before_after.jpg',quality=94)


def main():
    gallery('three_quarter'); gallery('front'); gallery('game_top'); gallery('back'); comparison(); revision_comparison()
    for family,(title,_) in FAMILIES.items():
        rows=[r for r in ASSETS if r['family']==family]
        canvas=Image.new('RGB',(1440,452),(25,32,39)); draw=ImageDraw.Draw(canvas)
        draw.text((15,10),title+' — progressão visual',font=heading,fill=(237,231,210))
        for r in rows:
            x=r['tier']*360
            im=Image.open(OUT/r['stem']/'previews/three_quarter.png').convert('RGB').resize((360,360),Image.Resampling.LANCZOS)
            canvas.paste(im,(x,50)); draw.text((x+8,418),r['name'],font=small,fill=(237,231,210))
        canvas.save(DEST/(family+'_progression.jpg'),quality=94)
    text='''# Tropas dos anões — modelos estáticos

24 modelos: seis classes, cada uma com básica, evolução I, evolução II e suprema lendária.
Modelagem, pintura, exportação e renderização feitas no Blender aberto pelo MCP, após
ajustar as proporções de fantasia e simplificar as vestes/equipamentos conforme
as referências humanas. Revisão visual 6: botas alinhadas às canelas, mãos livres
relaxadas, martelos para cima com volume equilibrado e bestas maiores. Bordas,
rebites, tiras e divisões
de placas pintados, mantendo geometria adicional para barba, tecido pendente,
capacetes e acessórios com função concreta.

- [Galeria completa](previews/dwarf_troops/roster_three_quarter.jpg)
- [Antes e depois desta revisão](previews/dwarf_troops/equipment_proportions_before_after.jpg)
- [Vista frontal e orientação das armas](previews/dwarf_troops/roster_front.jpg)
- [Visão de jogo](previews/dwarf_troops/roster_game_top.jpg)
- [Costas e acessórios](previews/dwarf_troops/roster_back.jpg)
- [Comparação com humanos](previews/dwarf_troops/human_dwarf_comparison.jpg)
- [Referência humana lado a lado, de frente](previews/dwarf_troops/human_dwarf_front_comparison.jpg)
- Cena de revisão: `res://_dwarf_troop_models_review.tscn` (F6 no Godot).

## Construção comum

Os 20 anões, incluindo os cavaleiros e lendários, compartilham exatamente os mesmos
18 meshes anatômicos locais: cabeça, peito, barriga, cintura; duas coxas, canelas,
pés, ombros, braços, antebraços e mãos. A cabeça encosta no peito, sem pescoço.
Altura anatômica: 1,35 m. As poses alteram apenas transformações; nenhuma evolução
aumenta o corpo. Barba, cabelo, roupa e equipamento são peças adicionais ou pintura.

Base editável: `assets/generated/dwarves/common/dwarf_base_v1.blend`.
O código central `tools/art_pipeline/build_dwarf_troops.py` contém a única função
anatômica. As assinaturas dos 18 meshes são comparadas entre todos os 20 personagens.
Quinas retas, faces planas, atlas com 64 pixels por metro e filtro nearest acompanham
os humanos, com proporções anãs e materiais de madeira, couro, aço, cobre e ferro.
Peito, cabeça, mãos, quadril de 0,52 m e coxas de 0,205 m preservam as medidas
aprovadas. As canelas agora têm 0,235 m de largura, maiores que as coxas. Os pés
têm a mesma largura de 0,235 m e preservam o comprimento de 0,405 m, com o
calcanhar alinhado à parte traseira da canela. A silhueta passa a formar uma bota
contínua, com a ponta alongada. Essas medidas são comuns aos 20 personagens.

As roupas usam o mesmo princípio dos humanos: um membro espesso representa
ombreira, bracelete ou caneleira, com material e divisões na textura. Couro e
tecido nas básicas; malha/sobreveste na primeira evolução; placas nas seguintes.
Os guardiões usam apenas um escudo grande (0,66–0,786 m de largura), com madeira,
aro e ferragens pintadas, evoluindo para placas de aço/ferro; sem símbolos em “T”.
Guerreiros levam um martelo de guerra para cima, com cabeças de 0,43–0,505 m,
reduzidas em relação à revisão anterior para equilibrar a silhueta. Cavaleiros
usam machados grandes e controlam as rédeas com a outra mão. Patrulheiros usam
bestas maiores, de uma mão, com 0,70–0,835 m de largura e aljava; ladinos usam uma faca de aço
forjado, com ferramentas de sabotagem guardadas no equipamento da evolução I.
Todas as armas têm uma única empunhadura, com o cabo atravessando a mão. O gume,
a face de impacto, o escudo e a besta estão orientados para a frente (-Y).
As mãos livres ficam alinhadas ao antebraço, em braços quase verticais ao lado
do corpo. Os punhos mantêm alinhamento vertical, sem a rotação lateral da revisão anterior.
Os detalhes são ferragens, costuras, placas e veios de madeira, sem emblemas pintados.

## Cavalaria e cerco

Conforme a escolha do usuário, todas as quatro cavalarias montam carneiros de guerra,
inclusive a lendária. Não há grifos ou javalis. As quatro montarias compartilham a mesma
geometria física e encaixe da sela; a proteção evolui. A montaria ficou 0,18 m mais alta para
acomodar quatro coxas, quatro canelas e quatro cascos separados, com articulações
coincidentes e grupos próprios para animação futura. A suprema usa armadura de
ferro e machado grande. Os nomes visuais acompanham o equipamento; a integração
dos nomes no gameplay permanece posterior.

O cerco segue as máquinas existentes no sistema do jogo: mangonel de torção,
lança-rochas de contrapeso, bombarda e colosso de engenharia com morteiro, caldeira,
pistões e blindagem. Essas quatro máquinas não são personagens humanoides.

## Entrega e revisão

Cada pasta de tropa contém GLB estático, fonte Blender com peças separadas e textura
embutida, atlas PNG, relatório JSON e quatro imagens: frente, três quartos, costas e
vista de jogo. O GLB reúne peças por futura articulação para limitar o número de meshes.
Não contém animações, esqueletos, câmeras, luzes ou chão de estúdio.

Esta etapa não troca tropas no gameplay e não altera a base de dados de unidades.
IDs de gameplay no manifesto são referências para a integração posterior. Em particular,
o ID genérico da lendária de cavalaria ainda se chama `v2_legendary_griffon_rider`;
a arte anã entregue é um cavaleiro de carneiro terrestre. Movimento e animações serão
tratados na etapa seguinte, depois da revisão dos modelos.

## Catálogo

| Classe | Básica | Evolução I | Evolução II | Suprema lendária |
|---|---|---|---|---|
'''
    for family,(title,_) in FAMILIES.items():
        rows=[r for r in ASSETS if r['family']==family]
        text+='| '+title+' | '+' | '.join('['+r['name']+'](../assets/generated/dwarves/'+r['stem']+'/'+r['stem']+'.blend)' for r in rows)+' |\n'
    text+='''
## Verificação

- `docs/dwarf_troops_validation.json`: GLBs, texturas embutidas, UVs, anatomia comum,
  ausência de animações e integridade dos arquivos humanos/edifícios preexistentes.
- `docs/dwarf_troops_godot_validation.json`: importação e materiais reais no Godot,
  dimensões, contato com o chão e ausência de esqueletos/animações.
- `docs/dwarf_troops_project_validation.json`: os mesmos 24 modelos importados
  no projeto real do jogo.
- `docs/dwarf_troops_blender_validation.json`: conferência das 18 peças cúbicas
  nos personagens do Blender aberto e da geometria comum dos quatro carneiros.

O Blender foi deixado mostrando o guerreiro lendário e seu martelo grande com os materiais visíveis.
A cena `Dwarf_Troops_24_Model_Review` contém o conjunto completo; também está salva
em `assets/generated/dwarves/dwarf_troops_review.blend`.

Para regenerar pelo Blender aberto: `python tools/art_pipeline/run_dwarf_troop_mcp.py`.
O primeiro lote rejeitado foi preservado apenas em `art_source/dwarf_troops/rejected_v0`.
'''
    (ROOT/'docs/DWARF_TROOPS_CATALOG.md').write_text(text,encoding='utf-8')
    print('Contact sheets and dwarf catalogue saved.')


if __name__=='__main__': main()
