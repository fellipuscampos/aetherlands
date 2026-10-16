# Tropas dos anões — modelos e animações

24 modelos animados: seis classes, cada uma com básica, evolução I, evolução II e suprema lendária.
Cada classe possui exatamente três animações compartilhadas: `idle`, `walk` e `attack`.
São 18 Actions no Blender e seis bibliotecas no Godot, aplicadas às 24 tropas.
O idle das quatro máquinas de cerco é completamente imóvel. A geometria, os UVs,
as normais e os atlas da revisão visual aprovada foram preservados.
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
coincidentes e rig próprio para trote articulado. A suprema usa armadura de
ferro e machado grande. Os nomes visuais acompanham o equipamento; a integração
dos nomes no gameplay permanece posterior.

O cerco segue as máquinas existentes no sistema do jogo: mangonel de torção,
lança-rochas de contrapeso, bombarda e colosso de engenharia com morteiro, caldeira,
pistões e blindagem. Essas quatro máquinas não são personagens humanoides.

## Entrega e revisão

Cada pasta de tropa contém GLB com um mesh, um esqueleto e três clipes, fonte Blender
com peças separadas, rig e Actions compartilhadas, atlas PNG, relatório JSON e as
quatro imagens dos modelos aprovados: frente, três quartos, costas e vista de jogo.
Cada modelo também tem `previews/idle.mp4`, `previews/walk.mp4` e
`previews/attack.mp4`, renderizados com sua própria aparência a 48 fps. São 72
vídeos H.264 em MP4, que abrem diretamente em um player comum. Os movimentos
repetem algumas vezes somente na prévia, para facilitar a revisão.
As texturas continuam embutidas, com filtro nearest; câmeras, luzes e chão de
estúdio ficam apenas nos arquivos de revisão do Blender.

Abra `_dwarf_troop_models_review.tscn` com F6 para ver as quatro evoluções juntas.
Use os botões Idle/Walk/Attack ou as teclas 1/2/3; espaço pausa, e o seletor de
velocidade permite revisar em câmera lenta. A opção de repetir ataques pertence
somente ao visualizador: o recurso `attack` continua sendo um clipe único.

As bibliotecas prontas estão em `assets/generated/dwarves/animations/<classe>.tres`.
As Actions editáveis correspondentes estão em `<classe>_actions.blend` no mesmo
diretório. Todas as evoluções referenciam os mesmos três datablocks no Blender
aberto. Os GLBs também incluem os clipes, para utilização independente.
`dwarf_troops_animation_review.blend` reúne seis cenas, com quatro tropas em cada
uma; a cena dos guerreiros mostra o ataque compartilhado.

- [Galeria de animações](previews/dwarf_troops/animations/index.html)
- [Revisão do ataque dos guerreiros](previews/dwarf_troops/animations/warrior_attack.webp)
- [Trote dos carneiros](previews/dwarf_troops/animations/cavalry_walk.webp)
- [Quatro guerreiros no Blender](previews/dwarf_troops/animations/blender_four_warriors.png)

| Classe | Idle | Walk | Attack |
|---|---|---|---|
| Guardião | Respiração e guarda firme | Passos pesados, escudo estável | Golpe frontal de escudo |
| Guerreiro | Respiração e ajuste discreto do martelo | Passos pesados e braço livre em contrapeso | Martelo erguido e golpe frontal |
| Patrulheiro | Vigia atento | Passos controlados, besta estável | Mira, disparo com recuo e recuperação |
| Cavaleiro | Carneiro respira, cavaleiro acompanha a sela | Trote diagonal com coxas, canelas e cascos | Postura firme e golpe frontal de machado |
| Ladino | Respiração contida | Passos baixos e leves | Corte/estocada rápida com uma mão |
| Cerco | Imóvel | Rodas e pistões | Preparar, liberar/disparar e recuperar |

Clipes a 48 fps; idle e walk repetem, attack recupera a pose inicial. O deslocamento
é feito pelo jogo, pois walk anda no lugar. Os ataques marcam o quadro de impacto
nos manifests. As mãos permanecem presas aos cabos; os pés/cascos usam IK de dois
segmentos. As rédeas têm cada extremidade ligada à mão e ao cabresto.

A revisão de fluidez usa as animações humanas como referência de transferência
de peso e participação do corpo. Os dois braços acompanham cada ação: o braço
livre faz contrapeso, enquanto o outro preserva a empunhadura da arma ou do
escudo. Quadril, peito e cabeça acompanham a passada e os ataques; o cavaleiro
acompanha o trote do carneiro. As transições passam pelas poses intermediárias
com velocidade contínua, e os pés suavizam a saída e o retorno ao chão.
O braço livre mantém o cotovelo ligeiramente flexionado para a frente em idle,
walk e attack, incluindo o início e o fim dos clipes. A flexão varia com o
contrapeso sem estender o cotovelo para trás; o punho acompanha o antebraço.
Antecipação, impacto e recuperação têm ritmos diferentes. O idle de cerco
continua imóvel. As proporções, os equipamentos e as texturas aprovados foram
preservados; há somente três Actions por classe, compartilhadas pelas quatro
evoluções.

O rig comum de cerco possui canais para braço lançador, contrapeso, funda, carga,
recuo, rodas e pistões. Cada máquina liga suas peças aos canais do mecanismo que
possui. A orientação estática do eixo de recuo pertence ao rig de cada canhão;
a animação de disparo continua sendo única. As pedras carregadas deixam a funda
no disparo e reaparecem ao recarregar; projéteis e efeitos de combate pertencem
à integração de gameplay.

Esta etapa não troca tropas no gameplay e não altera a base de dados de unidades.
IDs de gameplay no manifesto são referências para a integração posterior. Em particular,
o ID genérico da lendária de cavalaria ainda se chama `v2_legendary_griffon_rider`;
a arte anã entregue é um cavaleiro de carneiro terrestre. A integração das tropas
e dos nomes no gameplay permanece uma etapa posterior.

## Catálogo

| Classe | Básica | Evolução I | Evolução II | Suprema lendária |
|---|---|---|---|---|
| Guardião | [Escudeiro do Clã](../assets/generated/dwarves/dwarf_shieldbearer_v1/dwarf_shieldbearer_v1.blend) | [Guardião de Ferro](../assets/generated/dwarves/dwarf_guardian_v1/dwarf_guardian_v1.blend) | [Sentinela da Montanha](../assets/generated/dwarves/dwarf_sentinel_v1/dwarf_sentinel_v1.blend) | [Baluarte Ancestral](../assets/generated/dwarves/dwarf_guardian_champion_v1/dwarf_guardian_champion_v1.blend) |
| Guerreiro | [Marteleiro do Clã](../assets/generated/dwarves/dwarf_warrior_v1/dwarf_warrior_v1.blend) | [Combatente da Forja](../assets/generated/dwarves/dwarf_swordsman_v1/dwarf_swordsman_v1.blend) | [Mestre do Aço](../assets/generated/dwarves/dwarf_weapon_master_v1/dwarf_weapon_master_v1.blend) | [Herdeiro da Forja](../assets/generated/dwarves/dwarf_blade_hero_v1/dwarf_blade_hero_v1.blend) |
| Patrulheiro | [Besteiro do Clã](../assets/generated/dwarves/dwarf_archer_v1/dwarf_archer_v1.blend) | [Vigia das Passagens](../assets/generated/dwarves/dwarf_hunter_v1/dwarf_hunter_v1.blend) | [Besteiro de Precisão](../assets/generated/dwarves/dwarf_elite_marksman_v1/dwarf_elite_marksman_v1.blend) | [Olho da Montanha](../assets/generated/dwarves/dwarf_legend_hunter_v1/dwarf_legend_hunter_v1.blend) |
| Cavaleiro | [Cavaleiro de Carneiro](../assets/generated/dwarves/dwarf_cavalier_v1/dwarf_cavalier_v1.blend) | [Machado do Clã](../assets/generated/dwarves/dwarf_shock_cavalier_v1/dwarf_shock_cavalier_v1.blend) | [Couraça da Montanha](../assets/generated/dwarves/dwarf_armored_cavalier_v1/dwarf_armored_cavalier_v1.blend) | [Senhor dos Carneiros](../assets/generated/dwarves/dwarf_ram_lord_v1/dwarf_ram_lord_v1.blend) |
| Ladino | [Batedor das Minas](../assets/generated/dwarves/dwarf_rogue_v1/dwarf_rogue_v1.blend) | [Sabotador das Galerias](../assets/generated/dwarves/dwarf_saboteur_v1/dwarf_saboteur_v1.blend) | [Gume de Ardósia](../assets/generated/dwarves/dwarf_assassin_v1/dwarf_assassin_v1.blend) | [Sombra da Montanha](../assets/generated/dwarves/dwarf_shadow_master_v1/dwarf_shadow_master_v1.blend) |
| Cerco | [Mangonel do Clã](../assets/generated/dwarves/dwarf_catapult_v1/dwarf_catapult_v1.blend) | [Lança-rochas de Contrapeso](../assets/generated/dwarves/dwarf_trebuchet_v1/dwarf_trebuchet_v1.blend) | [Bombarda da Forja](../assets/generated/dwarves/dwarf_bombard_v1/dwarf_bombard_v1.blend) | [Colosso da Forja](../assets/generated/dwarves/dwarf_siege_colossus_v1/dwarf_siege_colossus_v1.blend) |

## Verificação

- `docs/dwarf_troops_validation.json`: GLBs, atlas, UVs, anatomia aprovada, três
  clipes por modelo e integridade dos 240 arquivos humanos/edifícios protegidos.
- `docs/dwarf_troops_animation_validation.json`: comparação de cada canto de
  triângulo/normais/UVs com os GLBs aprovados, texturas byte a byte, canais comuns,
  ciclos, recuperação, chão, articulações, empunhaduras e movimento relativo dos
  dois braços e do tronco no Blender MCP.
- `docs/dwarf_troops_animation_godot_validation.json`: os 24 modelos usando
  somente as seis bibliotecas compartilhadas; trilhas, skins, chão e ciclos reais.
- `docs/dwarf_troops_animation_project_validation.json`: importação e reprodução
  da cena de revisão no projeto real do jogo, incluindo as seis classes.
- `docs/dwarf_troops_animation_video_validation.json`: os 72 vídeos por modelo,
  codec, resolução, fps, duração, contagem de quadros e decodificação completa.
- As validações antigas `dwarf_troops_{godot,project,blender}_validation.json`
  registram a aprovação dos modelos estáticos anterior à etapa de animação.

O Blender foi deixado na cena `Dwarf_Animations_warrior_Review`, reproduzindo o mesmo
ataque nos quatro guerreiros. A revisão estática anterior continua disponível em
`assets/generated/dwarves/dwarf_troops_review.blend`.

Para animar fontes estáticas pelo Blender aberto:
`python tools/art_pipeline/run_dwarf_animations.py` (`--rebuild` para editar clipes
existentes, `--families warrior` para uma classe). Para validar, criar bibliotecas,
renderizar e atualizar a revisão: `python tools/art_pipeline/finish_dwarf_animations.py`.
Para gerar somente os vídeos por modelo:
`python tools/art_pipeline/run_dwarf_animation_videos.py`.
O backup aprovado antes dos rigs fica em
`art_source/dwarf_troops/approved_static_before_animation_v1`.
O primeiro lote rejeitado continua preservado em `art_source/dwarf_troops/rejected_v0`.
