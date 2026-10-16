# Aetherlands — Opções gráficas e iluminação padrão

Documento vivo (V3 / Etapa 4). Código: `scripts/world/GraphicsQuality.gd` (tabelas + aplicação),
`scripts/autoload/Settings.gd` (persistência), `scripts/main/Main.gd::_apply_graphics_settings` (aplica no início e a
cada `Settings.graphics_changed`), página **Vídeo** de `scenes/ui/SettingsScreen.tscn`.

## Renderer

- Godot **4.7.1**, renderer **Forward+** (`project.godot: config/features = "Forward Plus"`).
- Tudo abaixo usa APIs de runtime do Forward+ e é aplicado **ao vivo**, sem reiniciar: `Viewport.msaa_3d`,
  `Viewport.screen_space_aa`, `DirectionalLight3D.shadow_enabled / directional_shadow_mode /
  directional_shadow_max_distance`, `RenderingServer.directional_shadow_atlas_set_size` e
  `RenderingServer.directional_soft_shadow_filter_set_quality`.
- Preferência do jogador em `user://settings.cfg`, seção `[graphics]` (`anti_aliasing`, `shadow_quality`) — **nunca** no
  save de partida. Valor ausente/inválido volta ao padrão. "Restaurar padrões gráficos" (página Vídeo) volta só AA e
  sombras (janela, resolução e V-Sync ficam como o jogador deixou). Não havia fluxo de "restaurar padrões" antes.

## Anti-aliasing

| Opção (UI) | id | `msaa_3d` | `screen_space_aa` | Observação |
|---|---|---|---|---|
| Desativado | `off` | desligado | desligado | serrilhado nas bordas dos hexes/voxels |
| FXAA | `fxaa` | desligado | FXAA | pós-processo barato; suaviza também bordas de shader/alpha, com leve desfoque |
| **MSAA 2x (padrão)** | `msaa_2x` | 2x | desligado | bordas da geometria limpas, custo pequeno |
| MSAA 4x | `msaa_4x` | 4x | desligado | bordas mais limpas, custo maior |

FXAA e MSAA são **mutuamente exclusivos**: escolher um zera o outro (nunca há combinação escondida). TAA não é
exposto (rastro em unidades que se movem) e fica sempre desligado. SMAA existe no 4.7, mas não foi pedido.

## Qualidade das sombras

| Opção | sol (`DirectionalLight3D`) | atlas direcional | filtro suave (PCF) | cascatas | alcance |
|---|---|---|---|---|---|
| Desativadas | `shadow_enabled = false` | — | — | — | — |
| Baixa | ligado | 2048 | `SHADOW_QUALITY_HARD` | 2 | 60 |
| **Média (padrão)** | ligado | 4096 | `SHADOW_QUALITY_SOFT_VERY_LOW` | 4 | 80 |
| Alta | ligado | 8192 | `SHADOW_QUALITY_SOFT_MEDIUM` | 4 | 100 |

Média reproduz o visual que o jogo já tinha (atlas 4096 e filtro "muito baixo" do `project.godot`), com alcance de 80
para sombras mais nítidas (o zoom máximo da `RTSCamera` é 30; o chão visível vai a ~60–70). O `shadow_blur` do sol
(1,5) não muda por nível. Não há luzes omni/spot com sombra no jogo, então o atlas posicional não é exposto.

### Alcance das sombras ajustado à vista (2026-10-14)

A câmera tem ângulo fixo, então o chão mais distante na tela depende só do zoom (~31 de profundidade no zoom padrão,
~50 no máximo). `GraphicsQuality.fit_shadows_to_view` (chamado pelo `Main` ao aplicar as opções e a cada
`RTSCamera.zoom_changed`) encolhe o alcance até a borda da tela + 6 de folga, dividido por `directional_shadow_fade_start`
(o esmaecimento sempre começa além do que se vê), sem nunca passar do alcance do perfil acima. As cascatas mantêm as
**mesmas distâncias absolutas** do perfil (8/16/40 na Média): só a última encolhe. Resultado: as sombras visíveis ficam
visualmente iguais (bordas deslocam menos de 1 texel, conferido lado a lado) e some o trabalho fora da tela (a última cascata desenhava centenas de objetos invisíveis). Números em
`docs/PERFORMANCE_GUIDE.md` §6.

## Para máquinas fracas (2026-10-14)

Duas opções na página Vídeo, **com padrão igual ao visual de sempre** (o jogador só vê diferença se escolher):

| Opção | id em `[graphics]` | Valores | Padrão | O que faz |
|---|---|---|---|---|
| Resolução 3D | `render_scale` | 100, 85, 75, 67, 50 (%) | 100 | Abaixo de 100 o mundo é desenhado em menos pixels e ampliado com AMD FSR 1.0 (`Viewport.scaling_3d_mode = FSR`); a interface continua na resolução nativa. 100 = `BILINEAR` em escala 1, o padrão do Viewport. A alavanca mais forte de GPU: 75 % desenha ~56 % dos pixels. |
| Oclusão de ambiente e reflexos | `screen_effects` | ligado/desligado | ligado | SSAO e SSR do `WorldEnvironment`. Nunca mexe no glow (o brilho de lava, cristais e magia é parte da arte). |

Código: `GraphicsQuality.apply_render_scale` / `apply_screen_effects`, `Settings.render_scale_percent` /
`screen_effects_enabled`, `Main._apply_graphics_settings`. "Restaurar padrões gráficos" volta as duas.

## Padrões

- **Anti-aliasing: MSAA 2x** — melhor relação qualidade/custo para a arte de blocos/hexes (bordas retas).
- **Sombras: Média.**
- **Resolução 3D: 100 %; oclusão e reflexos: ligados.**

## Desempenho aproximado

Medição da Etapa 4 (não científica): cena real do mundo padrão 144×76 sobre floresta, V-Sync desligado durante a
medição, 240 frames por configuração. Ver os números em `docs/AETHERLANDS_V3_IMPLEMENTATION.md` (Etapa 4 → Opções
gráficas). Lembrete do `docs/PERFORMANCE_GUIDE.md`: com V-Sync ligado o teto é o do monitor — estas opções só mexem no
custo de GPU por frame.

## Iluminação padrão (WorldEnvironment + sol)

Direção: **fantasia temperada/europeia** — temperatura neutra a levemente fresca, sombras presentes, cores vivas sem o
"sol tropical de meio-dia". Nada de filtro azul: os ajustes são no pipeline real.

| Parâmetro | Antes | Agora |
|---|---|---|
| Sol: cor | (1,00; 0,92; 0,78) — quente/amarelada | (1,00; 0,97; 0,93) — quase neutra |
| Sol: energia | 1,10 | 0,95 |
| Sol: ângulo | −45° | −42° (sombras um pouco mais longas) |
| Luz ambiente (céu): energia | 0,22 | 0,20 |
| Tonemap | Filmic, exposição 1,0 | Filmic, exposição 0,95 (areia/neve/água sem estourar) |
| Ajuste: saturação | 1,30 | 1,08 |
| Ajuste: contraste | 1,12 | 1,06 |
| Glow: intensidade / bloom | 0,6 / 0,10 | 0,4 / 0,02 |
| Céu: topo / horizonte | (0,25; 0,45; 0,75) / (0,65; 0,75; 0,85) | (0,30; 0,47; 0,72) / (0,70; 0,77; 0,84) |

Também avaliados e descartados na exploração: AgX (acinzentado/lavado demais) e ACES (areia ainda estourada). A água
não foi redesenhada: o ciano excessivo vinha principalmente da saturação global 1,3.

## Ciclo de dia e noite (2026-10-09)

Só visual, em tempo real (nunca por turno), sem nenhuma regra de jogo ligada a ele. Código:
`scripts/world/DayNightCycle.gd` (keyframes + amostragem) e `scripts/world/DayNightController.gd` (aplica no `Sun` e no
`WorldEnvironment`, criado por `Main._ready`). Testes: `test/unit/test_day_night_cycle.gd`.

| Fase | Minutos do ciclo | Duração |
|---|---|---|
| Noite profunda | 19,0 → 1,0 | 2 min (a noite inteira, com as bordas, vai de 18,0 a 2,0: 4 min) |
| Amanhecer: hora azul → nascer do sol → manhã | 2,0 → 4,5 | 2,5 min |
| Dia: manhã → **meio-dia (10,0)** → tarde | 4,5 → 15,5 | 11 min |
| Entardecer: hora dourada → crepúsculo | 15,5 → 18,0 | 2,5 min |

- **Ciclo de 20 min, dia longo e noite curta.** Um turno de 4X dura de 30 s a 2 min: com 10 min a noite voltaria a cada
  poucos turnos; com 20 ela vira clima de fundo. A noite é luar azul legível (~55% do brilho do meio-dia), nunca breu.
- **O meio-dia é exatamente a iluminação padrão acima.** Com o ciclo desligado, no menu ou fora da partida, o jogo fica
  nele. Mudar a iluminação padrão = mudar `Main.tscn` e o keyframe `meio-dia` juntos (um teste confere).
- **Fade de verdade:** smoothstep entre keyframes vizinhos e tabela cíclica. Nenhuma grandeza muda mais de 1% a cada
  0,5 s, e nenhum instante fica mais escuro que a noite profunda (a primeira versão tinha crepúsculo mais escuro que a
  noite: escurecia e clareava de novo).
- **Uma luz só:** de dia o sol varre o azimute (−20° → 35° → 100°) com elevação de 25° a 42°; à noite a mesma luz vira
  "lua" (azul, energia 0,5) e volta devagar ao leste. Sem salto de sombra e sem segunda luz com sombra. Elevação
  mínima de 25° para as sombras não virarem riscos enormes.
- **Sombras somem à noite** (pedido do usuário: sombras fortes à noite ficavam estranhas): `shadow_opacity` do sol
  é 1,0 o dia inteiro, cai enquanto anoitece (hora dourada 0,8 → crepúsculo 0,2 → noite 0) e volta enquanto amanhece
  (hora azul 0,1 → nascer 0,6 → manhã 1,0). Um teste garante que o entardecer só apaga e o amanhecer só acende.
- **Partida nova, carregada ou reiniciada começa no meio da manhã (minuto 7).** A hora não vai para o save.
- **Pausa congela o ciclo** (`get_tree().paused`); o turno da IA não (é tempo real).
- **Interruptor:** Configurações → Vídeo → "Ciclo de dia e noite" (padrão ligado), `[graphics] day_night_cycle` em
  `user://settings.cfg`. "Restaurar padrões gráficos" volta para ligado.
- Lava, cristais do terreno e água já são emissivos e ganham destaque à noite sem código extra. Os RECURSOS que
  brilham (Gemas, Nódulo Arcano) usam o sistema da seção "Brilho do mundo" abaixo.
- **Escuridão da cena (`darkness`):** cada keyframe tem um valor de 0 (dia inteiro) a 1 (noite profunda): hora dourada
  0,35, crepúsculo 0,85, hora azul 0,85, nascer do sol 0,35. O clima soma o seu (`WeatherKinds` → `look.darkness`:
  chuva 0,25, neve 0,12). É valor de arte, não medida física — a noite do jogo é um luar legível, e derivar do brilho
  fazia uma manhã chuvosa contar quase como noite. O `DayNightController` publica o valor no parâmetro global de
  shader `world_darkness` e no sinal `darkness_changed`, só quando muda mais de 0,005.
- **Custo:** sol aplicado em passos de 0,1 s, céu e ambiente em passos de 2 s (`Sky.PROCESS_MODE_INCREMENTAL`); medição
  em `docs/PERFORMANCE_GUIDE.md`, seção 2.12.

## Brilho do mundo (2026-10-12)

Só visual. Coisas do mapa que brilham e iluminam o que está em volta, mais evidentes conforme a cena escurece. Hoje:
os recursos **Gemas** (cristal de ametista) e **Nódulo Arcano**. Feito para ser reutilizado em outras coisas (prédios,
unidades, biomas). Código: `scripts/data/GlowProfiles.gd` (perfis), `scripts/world/WorldGlow.gd` (o sistema, filho do
`HexGrid`: `hex_grid.world_glow`), `shaders/glow_prop.gdshader` (emissão do modelo). Testes: `test/unit/test_world_glow.gd`.

- **Duas partes, um perfil.** Um perfil de `GlowProfiles` descreve a LUZ (cor, energia à noite, alcance, altura,
  atenuação) e a EMISSÃO do modelo (energia à noite), mais `day_strength`: a fração que sobra em pleno dia.

| Perfil | Luz (cor, energia, alcance) | Emissão | De dia |
|---|---|---|---|
| `amethyst` (Gemas) | lilás (0,74; 0,42; 1,0), 1,5, 2,6 | 1,6 | 15% |
| `arcane` (Nódulo Arcano) | ciano (0,35; 0,92; 1,0), 1,9, 3,0 | 2,0 | 20% |

- **Segue a escuridão da cena** (`darkness`, seção do ciclo de dia e noite): intensidade = `day_strength` → 1 conforme
  a escuridão vai de 0 a 1. A luz recebe por `WorldGlow.set_darkness` (ligado em `Main` ao sinal do
  `DayNightController`); a emissão lê o parâmetro global `world_darkness` no shader. Com o ciclo desligado o jogo fica
  no meio-dia, então o brilho fica no mínimo.
- **Luz:** um `OmniLight3D` **sem sombra** por fonte, criado por `WorldGlow.add_light(grupo, chave, posição, perfil)`.
  Cada sistema usa o seu grupo (`"resources"` para os recursos) e limpa só as suas (`clear_group`).
- **Emissão:** `WorldGlow.prop_material(material do modelo, perfil)` devolve o shader de brilho com a mesma aparência
  do material do GLB. Brilha a parte COLORIDA do atlas (croma linear acima de 0,09–0,14): os cristais e os veios
  pintados acendem na própria cor; a rocha neutra da base não. Não precisa de textura de emissão por asset.
- **Névoa de guerra:** brilho só em tile VISÍVEL agora. Tile explorado é memória (sem luz nem emissão), e
  uma luz acesa em tile nunca visto entregaria o recurso. A luz nasce apagada; `ResourcePropsManager.apply_fog` acende
  (luz + `INSTANCE_CUSTOM.r` da instância no MultiMesh) e só reenvia o que mudou.
- **Recurso destruído ou prop removido** (obra, cidade): a luz sai junto (`clear_prop_at`).
- **Para dar brilho a outra coisa:** (1) um perfil novo em `GlowProfiles`; (2) pedir a luz com
  `hex_grid.world_glow.add_light(seu_grupo, chave, posição, perfil)` e acendê-la com `set_light_shown` quando estiver
  visível; (3) se o modelo deve acender, trocar o material por `WorldGlow.prop_material(...)` (ou ler `world_darkness`
  no shader próprio). Outro recurso de mapa: uma linha em `ResourcePropsManager.GLOW_PROFILE_BY_KIND`.
- **Custo:** o mapa padrão (128×72) tem 36 fontes (18 Gemas + 18 Nódulos). Medição em
  `docs/PERFORMANCE_GUIDE.md`, seção 2.15: sem diferença mensurável com as luzes ligadas ou desligadas.

### Núcleos das Grandes Manifestações (2026-10-13)

O mesmo efeito, numa coisa que se move. Testes: `test/unit/test_core_glow.gd`.

- **Luz presa ao osso do núcleo.** `UnitData.glow_profile` + `glow_bone` (preenchidos por
  `UnitDatabase.MANIFESTATION_CORES`): `Unit._build_core_glow` cria um `BoneAttachment3D` no osso (`core`; no Lich,
  `staff_focus`, o foco do cajado) e pede a luz com `WorldGlow.attach_light(GROUP_UNITS, id da unidade, nó, perfil)`.
  A luz é descendente do modelo: acompanha a flutuação e os gestos, some com a unidade na névoa e no embarque e
  morre com ela — sem código de limpeza (o `WorldGlow` esquece sozinho as luzes que morreram). Nasce acesa.
- **Perfis** (`GlowProfiles`): um por núcleo, na cor do mapa de emissão do modelo — Serafim dourado, Arquidemônio
  vermelho, Lich verde espectral, Avatar verde-folha, Arconte violeta, Primordial ciano. Energia 2,1–2,4 à noite e
  20% de dia; alcance 4,2–4,6 (os cristais usam 2,6–3,0): o núcleo fica a ~1,7–2,4 m do chão e a luz precisa chegar
  ao terreno.
- **Emissão do modelo.** Os seis GLBs já trazem mapa de emissão (é o que define onde o núcleo brilha), então não
  usam o shader dos props: `WorldGlow.track_emission(material, perfil)` multiplica a COR de emissão do material pelo
  fator do perfil — `emission_day` (1,0: de dia o modelo fica exatamente como foi aprovado) até `emission_energy`
  (1,8–2,2) na noite profunda. Na cor e não na energia porque o clipe do Primordial anima a energia (o pulso do
  núcleo): os dois se multiplicam. O material é o do GLB, compartilhado por todas as unidades do modelo; a cor
  original fica guardada num meta do material e nunca se acumula entre unidades ou partidas.
- **Fora de um mapa** (cena de revisão, teste isolado) não há `WorldGlow`: a unidade fica só com a emissão do modelo.
- **Para outra criatura brilhar:** um perfil em `GlowProfiles` e `glow_profile`/`glow_bone` no `UnitData` dela.

### Opções de vídeo: luzes do mapa e luzes das criaturas (2026-10-13)

Configurações → Vídeo → **"Luzes do mapa (cristais e nódulos)"** e **"Luzes das criaturas (núcleos das Grandes
Manifestações)"**, as duas ligadas por padrão; `[graphics] map_lighting` / `creature_lighting` em
`user://settings.cfg`; "Restaurar padrões gráficos" religa as duas. Aplicadas na hora por
`Main._apply_graphics_settings` → `WorldGlow.apply_lighting_settings`.

- Cada grupo de luzes pertence a uma **camada** (`WorldGlow.layer_of`): `GROUP_UNITS` → `LAYER_CREATURES`; todo o
  resto (recursos, e o que vier: prédios, biomas) → `LAYER_MAP`. `set_layer_enabled` apaga/acende a camada inteira;
  luz criada com a camada desligada já nasce apagada, e anoitecer não a religa.
- Desligar apaga só as **luzes** (o que ilumina o terreno e as tropas em volta). O brilho do próprio modelo — a
  emissão do cristal ou do núcleo — continua: não é luz e não custa nada.
- **Custo:** medição em `docs/PERFORMANCE_GUIDE.md`, seção 2.15 — dentro do ruído mesmo com 24 Manifestações na tela.

## Névoa de guerra (refeita em 2026-10-12)

Três estados, cada um com um dono. A regra de visão continua em `HexGrid.visibility` (`recompute_fog`); isto é só como
cada estado aparece. Código: `scripts/world/FogLayer.gd`, `shaders/fog_layer.gdshader`, `shaders/fog_state.gdshaderinc`,
`HexGrid._rebuild_fog_state` / `shown_through_fog` / `MEMORY_TINT`. Testes: `test/unit/test_fog_layer.gd`.

| Estado | O que aparece | Quem faz |
|---|---|---|
| **Nunca visto** | Só a camada de névoa: blocos hexagonais opacos acima do mapa (tampa em y = 0,42, paredes até abaixo do plano de água). Terra e mar sob a MESMA superfície. | `FogLayer`; o terreno do tile nem é desenhado (`terrain.gdshader` recolhe o prisma) |
| **Explorado** (memória) | O mapa de verdade — chão com relevo e cores, água, árvores, recursos, covis — sob um filtro mais escuro e levemente frio. Sem ícones de recurso, sem unidades/cidades/prédios/obras/melhorias alheias. | `HexGrid.MEMORY_TINT` (uniform `fog_memory_tint` no terreno e na água; cor de instância nos props) |
| **Visível** | Tudo, ao vivo. | — |

- **Por que uma camada física.** Antes a névoa era uma cor pintada pelo shader do terreno e pelo da água, cada um na
  sua altura: a costa aparecia pelo degrau e pela sombra entre os dois, e o relevo precisava ser achatado à força.
  Agora o nunca-visto é geometria opaca por cima de tudo — não há o que vazar.
- **Por que a camada é baixa (0,42) e não cobre tropas e castelos.** A câmera olha inclinada: uma camada na altura de
  um castelo esconderia também os tiles VISÍVEIS atrás dela (uns 2 tiles para cada 3 de altura). A camada cobre chão
  e mar; o que é alto simplesmente não é desenhado em tile nunca visto (props com alfa 0, entidades invisíveis).
- **Estado exato por tile.** `HexGrid._fog_state_texture`: 1 texel por tile, sem filtro (0 nunca visto, 128 explorado,
  255 visível), lida no VÉRTICE pela camada e pelo terreno (`fog_state.gdshaderinc`). A máscara borrada de baixa
  resolução (alfa de `biome_overlay_texture` / `liquid_type_texture`) continua existindo só para a passagem suave
  entre visível e explorado do filtro de memória.
- **Entidades: decididas na hora, não no fim da rodada.** `HexGrid.shown_through_fog(coord, dono)` é a regra única
  (as do jogador sempre; as outras só em tile visível agora) e é aplicada no instante em que a entidade nasce ou muda
  de tile: `spawn_unit`, `spawn_monster_at`, `move_unit`, `teleport_unit`, `place_building`, `found_city`,
  `capture_city`, covil criado no meio da partida, melhoria de recurso e canteiro de obra. Antes só
  `_apply_fog_to_entities` decidia, uma vez por rodada: tropa treinada, reforço de covil ou monstro saindo da visão
  ficavam com o estado antigo durante toda a fase da IA — o "aparece rapidamente entre as viradas de turno".
  `Unit.always_visible` (Dragão) mostra a unidade no momento em que é ligado.
- **Destaque na névoa.** Alcance de movimento/ataque/trajeto em tile nunca visto é desenhado pela própria camada
  (`_apply_fog_highlight`, textura de 1 texel por tile), já que o terreno dele não é desenhado. O marcador de seleção
  sobe para cima da camada.
- **Leve por construção.** Nada por quadro em GDScript. Mudar a névoa reenvia a textura de estado (largura × altura do
  mapa em BYTES) e ajusta um contador por pedaço. Os blocos ficam em pedaços de 16×16 tiles (um MultiMesh cada): o
  motor descarta os que estão fora da câmera e um pedaço sem nenhum tile nunca visto é desligado — o custo cai
  conforme o mapa é explorado, até zero. Bloco de tile conhecido é recolhido a um ponto (nenhum pixel). Sem sombra
  projetada. Medição em `docs/PERFORMANCE_GUIDE.md`, seção 2.16.
- **Ajustes:** altura em `FogLayer.TOP_Y`; cor/nuvem nos uniforms de `fog_layer.gdshader`; escuridão da memória em
  `HexGrid.MEMORY_TINT`; força do destaque em `HexGrid.FOG_HIGHLIGHT_STRENGTH`.

## Clima: chuva (2026-10-09)

Só cosmética (nenhuma regra de jogo lê nada daqui), em tempo real. Código: `scripts/world/WeatherSchedule.gd` (agenda e
intensidade, puro), `scripts/world/WeatherController.gd` (gotas, som, luz nublada, chão molhado; criado por
`Main._ready`). Testes: `test/unit/test_weather_rain.gd`.

- **Frequência:** a cada 4 min rola 30% de chance, só depois de 5 min de partida e com ≥ 10 min desde o fim da última
  chuva. Dura de 2 a 4 min, com 30 s de entrada (garoa → chuva) e 45 s de saída. Simulação de 50 h: uma chuva a cada
  ~20–25 min em média, nunca duas seguidas. Números em constantes no topo de `WeatherSchedule`.
- **Uma intensidade (0..1) manda em tudo:** densidade das gotas, volume do som, luz nublada e chão molhado.
- **Gotas:** `GPUParticles3D` filho do `CameraRig` (seguem o pan), em coordenadas de mundo. Caem numa faixa perto do
  chão (nunca entre a câmera e o tabuleiro) e a caixa de emissão cresce com o zoom. Translúcidas (alfa 0,15), finas,
  com leve vento; material sombreado (acompanha dia e noite) com emissão mínima de 0,15 para não sumirem à noite.
- **Som:** `assets/audio/sfx/rain_loop.ogg`, chuva no chão **sintetizada** por `tools/audio/generate_rain_loop.py`
  (chiado + impactos curtos sem tom; a gravação CC0 anterior soava como "água caindo na água"). Volume = efeitos ×
  intensidade, pico em −18,5 dB (~−40 LUFS: ambientação de fundo). Registrado no `AudioManager` para parar com a partida
  e ser drenado ao fechar o jogo.
- **Luz nublada:** `DayNightCycle.with_overcast` (sol ×0,7, sombra ×0,45, saturação −0,1, exposição ×0,96, névoa 35%
  mais cinza da própria luminância — a noite continua noite). Aplicada pelo `DayNightController`, que segue sendo o
  único dono do sol e do ambiente.
- **Chão molhado:** parâmetro global de shader `weather_wetness` (`project.godot` → `[shader_globals]`) no
  `terrain.gdshader`: albedo ×0,82 e rugosidade ×0,6 no pico, aplicado antes da névoa de guerra; lava não molha. O
  chão seca em 90 s depois que a chuva para.
- **Interruptor:** Configurações → Vídeo → "Efeitos de clima (chuva)" (padrão ligado), `[graphics] weather`.
  Desligar faz a chuva atual sair em 3 s e impede novas. "Restaurar padrões gráficos" volta para ligado.
- **RNG próprio** (`WeatherController.rng`): o clima nunca usa `randf()`/`randi()` globais, então não altera o resultado
  de nenhuma partida (há teste). **Nada vai para o save:** partida nova, carregada ou reiniciada começa seca.
- **Pausa** congela agenda, gotas e som.

## Clima: neve (2026-10-10)

Mesma estrutura da chuva, generalizada: os dados de cada clima ficam em `scripts/world/WeatherKinds.gd` (chance,
duração, som, partículas e "look" da luz), a agenda (`WeatherSchedule`) roda **um evento por vez** e o
`WeatherController` monta um efeito (partículas + som) por tipo. Testes: `test/unit/test_weather_snow.gd`.

| Sorteio (a cada 4 min, depois de 5 min de partida e ≥ 10 min do último clima) | Resultado |
|---|---|
| < 0,30 | chuva (2–4 min) |
| 0,30 a 0,40 | neve (3–5 min, entrada de 45 s e saída de 60 s) |
| resto | tempo limpo |

Simulação de 50 h: chuva a cada ~25–30 min e neve a cada ~1 h–1 h 30 em média; nunca dois climas juntos.

- **Partículas:** alfa 0,45; até 3.000 flocos em billboard com textura radial suave (gerada em código), caindo devagar (3,5 u/s)
  com turbulência leve, na mesma faixa perto do chão e com a mesma caixa por zoom da chuva.
- **Som:** `assets/audio/sfx/snow_wind_loop.ogg`, vento de inverno **sintetizado** por
  `tools/audio/generate_wind_loop.py` (ruído filtrado em 5 faixas com rajadas; loop perfeito por construção). A neve em
  si é silenciosa; o vento é o "som de neve". O primeiro arquivo baixado ("Winter Wind", CC0) era uma música — conferir
  sempre o conteúdo, não o título (análise: pico tonal ÷ média local 32,7 na música, 7,0 no vento sintetizado, 7,6
  na chuva gravada). Pico de −22 dB (−18 LUFS no arquivo), no mesmo nível percebido da chuva, ~−40 LUFS.
- **Luz:** look próprio (sol ×0,85, sombra ×0,6, saturação −0,12, névoa 30% para um cinza levemente azulado) — fecha
  menos o tempo que a chuva.
- **Chão e copas levemente esbranquiçados, por código:** parâmetro global `weather_snow_cover`, que acumula até o
  máximo em 90 s de neve plena e derrete acompanhando o fim da nevasca (no máximo 45 s do cheio a zero; com 150 s o chão
  ficava branco por mais de 2 min depois de parar de nevar e parecia travado). No `terrain.gdshader`, só faces viradas para cima, em manchas
  (ruído), no máximo 30% em direção ao branco (com 50% os biomas deixavam de se distinguir). A vegetação passou a usar
  `shaders/nature_kit.gdshader`, que reproduz o material antigo do kit (conferido em tela: idêntico sem neve) e
  esbranquiça as copas até 35%. Água, lava, unidades e construções não mudam.
- **Por que código e não texturas brancas:** um parâmetro global e poucas operações por pixel, sem memória extra nem
  troca de material, e o efeito pode acumular, derreter e respeitar a inclinação (paredes continuam rocha). Medido: o
  shader novo da vegetação não tem custo mensurável em relação ao material antigo.
- **Interruptor único:** "Efeitos de clima (chuva e neve)" em Vídeo liga e desliga os dois.
- **Troca de clima** (debug): com um clima em andamento, pedir o outro faz o atual sair em 3 s e o novo começar em
  seguida, sem corte seco.

## Debug de clima e dia/noite

Painel de Debug da HUD (só em build de desenvolvimento): **Começar/Parar chuva** e **Começar/Parar neve** (parar
usa a saída suave de 3 s; começar durante a saída retoma da intensidade atual; começar um com o outro acontecendo
troca com saída suave), **Ir para a noite/dia** (pula para a noite profunda ou o
meio-dia; o ciclo segue dali) e **Ciclo dia/noite: acelerar ×20** (ver o anoitecer e o amanhecer em segundos; volta ao
normal em partida nova). Com o clima ou o ciclo desligados em Configurações, o botão avisa em vez de forçar.

## Contorno de território (2026-10-10)

Substitui o tingimento que pintava o hexágono inteiro na cor da civ (escondia o terreno e ficava "fluorescente" à
noite). Estilo Civilization: a área é circulada seguindo as arestas retas dos hexágonos. Código:
`scripts/world/TerritoryBorder.gd` (geometria pura), `HexGrid.refresh_territory_borders` / `_build_city_border_mesh`
(malha, altura, névoa) e `shaders/territory_border_shader.gdshader`. Testes: `test/unit/test_territory_border.gd`.

- **Tipos de aresta:** borda cheia onde o vizinho é de outro dono (ou de ninguém); linha interna fina e discreta entre
  cidades da MESMA civ; nada entre tiles da mesma cidade. Duas civs vizinhas: cada uma desenha a sua faixa do próprio
  lado da aresta (as duas cores lado a lado).
- **Junções exatas:** cada faixa é um trapézio dentro do próprio hexágono; nos cantos convexos o ponto de dentro fica
  na bissetriz, nos côncavos sobre a aresta compartilhada — o tile vizinho calcula o mesmo ponto, então o contorno
  fecha sem fresta nem sobreposição (teste de fechamento em território irregular). A aresta de cada direção vem da
  geometria: o contorno antigo (removido) supunha "vizinho i = cantos i e i+1", errado para metade das direções.
- **Altura:** cada vértice na superfície real do próprio tile + 0,03 — nunca a do vizinho mais alto.
- **Visual:** faixa de 0,26 hex: linha sólida (~0,11 hex) na cor da civ com um fio escuro na aresta (contraste em neve e
  areia) e um brilho que se apaga para dentro. Material SOMBREADO (escurece à noite e com chuva/neve) com emissão
  pequena só na linha. Ajustes visuais: uniforms do shader e `TerritoryBorder.FULL_WIDTH`.
- **Névoa:** tile não visto não desenha; explorado fica sob o filtro de memória (`HexGrid.MEMORY_TINT`) e mais fraco.
- **Quando redesenha:** a cada recálculo de névoa, fundação, captura (todas as cidades, porque o tipo de uma aresta
  depende do dono do vizinho) — evento discreto, nunca por quadro.

