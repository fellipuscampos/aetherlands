# Escudeiro Orc Base

Modelo único feito diretamente do `.blend` aprovado do Escudeiro Élfico, pelo MCP do Blender aberto. Mede **2,00 m do chão ao topo da cabeça**, sem capacete ou enfeite para completar a altura.

Mantém os mesmos 18 blocos do corpo e as seis peças das orelhas élficas. O peito tem 65% mais largura que a base élfica, os braços superiores 85%, os antebraços 65%, as mãos 60% e as coxas 55%, antes da escala uniforme até 2 m. Braços e pernas foram afastados, junto com os respectivos ossos de repouso e equipamento, para dar espaço aos membros robustos. Cada bloco corporal continua com oito vértices e seis faces retangulares; nenhum membro adicional foi criado. As orelhas mantêm a geometria original.

O equipamento usa os 18 blocos corporais da revisão robusta. O antebraço e a mão sem escudo foram girados 24 graus para suavizar a dobra do braço, preservando as dimensões dos blocos. Peito, barriga, braços, mãos e boa parte das coxas ficam expostos, com sombra muscular discreta. Uma tira diagonal larga sustenta a proteção do ombro do escudo, com pequena fivela e costura.

Couro com grão discreto e costuras completas substitui as manchas e riscos isolados. A tira é desenhada em coordenadas físicas, continuando entre peito e barriga até o cinturão, na frente e nas costas. Painéis de couro terminam com bainhas e envolvem todas as faces das coxas. A ombreira de osso tem tiras completas e rebites; braçadeiras têm costura lateral e cintas. As botas possuem cano e pé no mesmo couro, com bainha, duas tiras, costuras e sola. Todas as proteções principais continuam pintadas nos blocos existentes, sem outra camada geométrica de armadura.

O escudo está 18% maior em largura e altura, mantendo a profundidade e a posição da empunhadura. As 30 regiões de textura aprovadas, incluindo os pixels de margem, continuam idênticas à versão anterior e são comparadas byte por byte.

Cabeça com laterais raspadas e faixa curta de cabelo escuro pintada no topo, olhos âmbar simétricos e duas presas pequenas. As sobrancelhas agora são dois cubos retangulares projetados da testa, inspirados nos anões, inclinados 12 graus e mais baixos junto ao nariz. Os dois objetos têm pesos rígidos no osso `head`; nenhuma animação ou osso foi acrescentado. O rosto e o cabelo continuam no único bloco da cabeça. Atlas de 512 × 1024, com filtro nearest.

As cinco animações mantêm nomes e tempos: `Squire_Idle`, `Squire_Walk`, `Squire_Attack`, `Squire_ShieldWall`, `Squire_ShieldWallHold`. A revisão `anatomy_v2` conserva os movimentos dos braços da versão aprovada, incluindo a dobra mais suave, e adapta a cabeça para acompanhar o tronco sem entrar no peito. Orelhas, presas e sobrancelhas seguem a cabeça. Os arquivos editáveis mantêm as trilhas habilitadas. A geometria animada é conferida quadro a quadro em `orc_troops_anatomy_validation.json`; os atlas aprovados foram preservados byte por byte.

- Modelos, atlas e relatório: `assets/generated/orcs/orc_squire_v1/`.
- Revisão no Godot: abra `res://_orc_squire_model_review.tscn` e pressione **F6**; os dois escudeiros aparecem em suas escalas reais.
- [Comparação de aparência](previews/orc_squire/elf_orc_three_quarter.jpg), [frente](previews/orc_squire/elf_orc_front.jpg).
- [Antes e depois](previews/orc_squire/orc_bulk_three_quarter.jpg), [corpo de frente sem escudo](../assets/generated/orcs/orc_squire_v1/previews/body_front.png).
- [Revisão dos elementos visuais](previews/orc_squire/orc_equipment_three_quarter.jpg), [frente](previews/orc_squire/orc_equipment_front.jpg).
- [Roupa antes/depois sem escudo](previews/orc_squire/orc_finish_body_front.jpg), [costas](previews/orc_squire/orc_finish_back.jpg), [sobrancelhas de perto](../assets/generated/orcs/orc_squire_v1/previews/face_closeup.png).
- `orc_squire_validation.json`: altura real exportada, pele no PNG, olhos, atlas embutido, pesos, curvas das cinco animações e hashes dos modelos anteriores.
- `orc_squire_blender_validation.json`: cubos reais no arquivo editável, orelhas preservadas, armadura pintada e altura medida.
- `orc_squire_godot_validation.json`: importação, escala, atlas, reprodução das cinco animações e cena de comparação.

Para reaplicar a correção no Blender aberto: `python tools/art_pipeline/run_orc_pose_fix_mcp.py --only orc_squire_v1`. Este escudeiro também é a fonte dos [20 modelos das cinco classes orcs](ORC_TROOPS_CATALOG.md).
