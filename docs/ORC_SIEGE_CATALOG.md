# Máquinas de cerco dos orcs

Quatro modelos originais construídos, texturizados, animados e exportados pelo MCP do Blender aberto (`localhost:9876`). A revisão v3 remove todas as placas de osso, conserva dois chifres em cada máquina e entrega os 19 clipes do padrão humano/élfico de cerco.

| Modelo | Mecanismo e acabamento | Altura | Clipes |
|---|---|---|---|
| Catapulta Orc | Torsão, braço reforçado, pedra quadrada, batente de couro e chifres frontais | 1,80 m | 4 |
| Trebuchet Orc | Estrutura em A, contrapeso com cintas de ferro, funda com pedra quadrada e guincho | 1,80 m | 5 |
| Bombarda Orc | Cano curto de ferro, apoios, trilho de recuo e dois chifres | 1,80 m | 5 |
| Colosso Quebra-Muralhas | Seis rodas, dois canhões pesados, recuos independentes, guincho e proteção de ferro | 2,00 m | 5 |

Madeira escura, couro, cordas, ferro, bronze e atlas pixelado com filtro nearest seguem o estilo orc existente. O marfim aparece somente nos chifres. Não há placas de osso nem caveira. As pedras continuam quadradas, inclusive a munição guardada no convés do colosso.

A estrutura, escala, dimensões e paleta aprovadas foram preservadas. Os rebites agora assentam nas proteções de ferro; fechos, cintas e apoios antes de osso passam a ser de metal. O colosso permanece uma bateria dupla de canhões. A versão anterior está em `art_source/orc_siege/before_horns_and_animations/`.

## Animações

| Sufixo | Duração | Comportamento |
|---|---|---|
| `Idle` | 2 s | Repouso mecânico, em loop |
| `Walk` | 2 s | Rodas girando em ciclo, sem deslocamento da origem |
| `Attack` | 2 s | Preparação, liberação ou recuo, recuperação e guincho de recarga |
| `DemolitionAmmo` | 3 s | Preparação mais lenta e liberação ou recuo mais forte |
| `PreparedBombardment` | 4 s | Preparação prolongada e disparo pesado, disponível a partir do trebuchet |

Prefixos: `Catapult`, `Trebuchet`, `Bombard`, `SiegeColossus`. Exemplo: `SiegeColossus_Attack`. A catapulta tem quatro clipes; cada máquina avançada tem cinco.

Braços, funda, contrapeso, guinchos e rodas usam pivôs e pesos rígidos. O contrapeso mantém a orientação vertical. O colosso dispara primeiro o canhão esquerdo e depois o direito, com recuo e retorno independentes. As ações têm marcadores de disparo e recuperação. Todos os clipes terminam na pose inicial. Idle e Walk recebem as flags de loop pelo script de importação do Godot.

Os clipes animam os mecanismos. Projéteis em voo, dano e efeitos de disparo continuam sob controle do gameplay, como nos modelos de referência. As pedras carregadas acompanham os mecanismos. Não há tripulação.

## Arquivos e revisão

Cada pasta `assets/generated/orcs/orc_{catapult,trebuchet,bombard,siege_colossus}_v1/` contém `.blend` com peças editáveis, atlas empacotado, armadura, ações e trilhas NLA; `.glb` com mesh consolidada, atlas embutido e clipes; `_import.gd`, `_albedo.png`, `_report.json`, README e cinco vistas em `previews/`.

Frente -Y no Blender / +Z no Godot; origem no solo; transformações aplicadas. As pontas dos cabos acompanham seus pontos de fixação. O manifesto separado é `assets/generated/orcs/orc_siege_manifest.json`.

Abra `_orc_siege_models_review.tscn` no Godot e pressione F6. Escolha a animação, pause, reinicie ou ajuste a velocidade. Bombardeio preparado deixa a catapulta em repouso, pois ela não possui essa técnica. A comparação com humanos, elfos e anões usa o mesmo seletor de animações. Botão direito gira a câmera, roda ajusta o zoom e R restaura a vista.

No Blender, `assets/generated/orcs/orc_siege_review.blend` reúne as quatro máquinas animadas. Reproduza a linha do tempo: Idle no quadro 1, Walk no 58, Attack no 115, DemolitionAmmo no 172 e PreparedBombardment no 253.

- [Galeria atualizada](previews/orc_siege/progression_three_quarter.jpg)
- [Prévia animada do ataque](previews/orc_siege/attack.gif)
- [Prévia animada do movimento](previews/orc_siege/walk.gif)
- [Munição de demolição](previews/orc_siege/demolition_stages.jpg)
- [Bombardeio preparado](previews/orc_siege/prepared_stages.jpg)
- [Comparação das quatro raças](previews/orc_siege/four_races_comparison.jpg)
- [Vista lateral](previews/orc_siege/progression_side.jpg)

## Validação

- `orc_siege_validation.json`: quatro GLBs, 19 clipes, durações, geometria, pesos, atlas, chifres e preservação dos 563 arquivos de referência.
- `orc_siege_native_validation.json`: leitura dos quatro .blend salvos, 19 ações, peças, malhas fechadas, UVs e atlas empacotados.
- `orc_siege_godot_validation.json`: importação real, nomes, durações, loops, poses amostradas, movimento, recuperação, escala e solo.
- `orc_siege_blender_review_validation.json`: revisão conjunta com quatro máquinas animadas.
- `orc_siege_revision_validation.json`: preservação da estrutura, dimensões e paleta, remoção das placas e colosso com dois canhões.
- `orc_siege_motion_preview_validation.json`: renderização dos clipes reais na revisão do Blender.

## Reprodução

Com o MCP do Blender aberto e conectado:

```powershell
python tools/art_pipeline/run_orc_siege_mcp.py
python tools/art_pipeline/configure_orc_siege_imports.py
python tools/art_pipeline/audit_orc_siege.py
python tools/art_pipeline/audit_orc_siege_revision.py
python tools/art_pipeline/run_orc_siege_review_mcp.py
python tools/art_pipeline/run_orc_siege_godot_validation.py --godot '<caminho-do-Godot-console.exe>'
```

Para gerar somente uma máquina, use `--only orc_siege_colossus_v1`. Renderize as prévias com `render_orc_siege_motion.py` pelo MCP após abrir a revisão conjunta e depois rode `package_orc_siege_motion.py` no Python local.
