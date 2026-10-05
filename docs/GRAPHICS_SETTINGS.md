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

## Padrões

- **Anti-aliasing: MSAA 2x** — melhor relação qualidade/custo para a arte de blocos/hexes (bordas retas).
- **Sombras: Média.**

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
