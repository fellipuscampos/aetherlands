# Goblin saqueador — Aetherlands

Modelo original, criado e animado no Blender 5.2.2 pelo MCP em localhost:9876.
Mantém a construção blocky aprovada no Troll: volumes retangulares, Shade Flat,
transições duras e pixel art. Inclui rig e as ações Idle, Walk e Attack.

## Arquivos

- Fonte editável: `art_source/goblin_raider_v3/goblin_raider_v3.blend`, na raiz do projeto.
- `goblin_raider_v3_atlas.png`: atlas único 256×256, também embutido no blend.
- `goblin_raider_v3_report.json`: medições e auditoria de geometria/UVs.
- `previews/front.png`: frente.
- `previews/three_quarter.png`: 3/4.
- `previews/side.png`: perfil.
- `previews/back.png`: costas.
- `previews/animations/`: prévias MP4/GIF de cada animação.
- `goblin_raider_v3_animation_validation.json`: conferência dos ciclos, pés e encaixes.
- A versão estática anterior foi preservada em `art_source/goblin_raider_v3/goblin_raider_v3_static.blend`.

## Forma e identidade

- Altura de 1,30 m, frente aos 2,50 m do Troll aprovado.
- Tronco estreito, cintura fina, braços e pernas delgados.
- Cabeça grande, orelhas muito longas, nariz comprido e curvado por cortes retos.
- Olhos amarelos sob sobrancelhas inclinadas e dois pequenos dentes desiguais.
- Couro/trapos marrons, tira diagonal, botas simples e faixas nos tornozelos.
- Bolsa presa à cintura com moedas parcialmente visíveis.
- Adaga curta improvisada, com lâmina gasta e cabo alinhado ao punho.

A divisão de partes preserva a lógica do Troll: cabeça, mandíbula, peito,
abdômen, ombros, braços, antebraços, mãos, quadril, coxas, canelas e pés.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 684 |
| Altura | 1,30 m |
| Materiais do personagem | 1 |
| Textura | 256×256, sRGB, nearest |
| Ilhas UV | 329, únicas, sem sobreposição, com 2 px de margem |
| Densidade | 64 px/m nos dois eixos, igual à do Troll |
| Densidade medida | 63,99906–64,00052 px/m |
| Sombreamento | Flat; sem bevel/subdivision/smooth |
| Animações / rig | Idle, Walk, Attack; 22 ossos; 24 fps |

Cada face foi projetada em escala métrica com base ortonormal. A pintura foi
feita diretamente nas dimensões de cada ilha: não foram esticados painéis
quadrados para cobrir retângulos. Todas as arestas foram medidas para verificar
a densidade. Malhas fechadas e faces sem área zero.

## Organização no Blender

Cena `Goblin_Raider_V3`, isolada no arquivo final, com coleções:

1. `01_BODY`: partes estruturais nomeadas.
2. `02_FACE_EARS`: cabeça, nariz, mandíbula, olhos pintados, dentes e orelhas.
3. `03_CLOTHING_LOOT`: couro, botas, faixas e bolsa de saque.
4. `04_DAGGER`: cabo, guarda e lâmina.
5. `05_STUDIO`: câmera, luzes e chão para os renders de revisão.
6. `06_RIG`: esqueleto com ossos nomeados e três ações na NLA.

São 49 componentes simples e editáveis, vinculados ao rig sob `Goblin_Raider_V3_ROOT`,
com origem no centro dos pés. Frente no Blender: -Y. O atlas está packed no blend.
Integrado ao jogo em 2026-10-03 (`MonsterDatabase.gd`, kind "goblin"): `goblin_raider_v3.glb`,
exportado deste blend por `tools/art_pipeline/goblin_raider_export.py`.

## Animações

| Ação | Frames locais | Duração | Faixa NLA | Comportamento |
| --- | --- | --- | --- | --- |
| `Goblin_Idle` | 1–61 | 2,50 s | 1–61 | Respiração discreta, atenção e pés apoiados; loop |
| `Goblin_Walk` | 1–21 | 0,83 s | 81–101 | Passos curtos e postura curvada; loop no lugar |
| `Goblin_Attack` | 1–29 | 1,17 s | 121–149 | Preparação, estocada com adaga e recuperação |

Impacto do ataque no frame local **12** (frame **132** na NLA).
A caminhada corresponde a aproximadamente **0,3103 m/s** de deslocamento para
frente (-Y no Blender); o root permanece parado. Cada ação tem marcadores
para seus eventos. Para rever um ciclo no Blender, ajuste o intervalo de
reprodução à faixa NLA acima. As lacunas entre faixas mostram a pose de repouso.

Os pés foram calculados com IK analítico e gravados nos ossos: não há dependência
de solver em tempo de execução. A adaga acompanha rigidamente a mão direita;
bolsa e trapos têm ossos próprios. Os volumes permanecem rígidos, com pesos
mistos somente nas duas tiras de couro. Os endpoints dos loops coincidem;
foram conferidos todos os frames para piso, pesos e encaixe da arma, além dos
cruzamentos de superfícies entre adaga/corpo, trapos/coxas e bolsa/braço esquerdo.
Os renders estáticos anteriores continuam documentando a pose de repouso.

## Reprodução via MCP

Os scripts em `tools/art_pipeline/` devem rodar em sequência na mesma sessão Blender:

1. `goblin_raider_model.py`
2. `goblin_raider_paint_save.py`
3. `goblin_raider_previews.py`
4. `goblin_raider_finalize.py`, após a conferência visual.
5. `goblin_raider_animate.py` para criar rig e ações sobre o modelo estático.
6. `goblin_raider_animation_validate.py` e `goblin_raider_animation_contacts.py`.
7. `goblin_raider_animation_previews.py` pelo MCP e `encode_goblin_previews.py` pelo Python local.
8. `goblin_raider_animation_save.py`, após a revisão das animações.

Executar pelo cliente `python tools/art_pipeline/blender_mcp_client.py <script>`.
A geração recusa substituir uma cena existente para preservar ajustes manuais.
