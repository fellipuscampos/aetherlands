# Dragão vermelho escuro — seis animações

Modelo V4 preservado em geometria, escala e textura. Animações feitas no Blender
via MCP em uma cena independente, com movimentos das asas, corpo, cabeça e cauda.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
| `Dragon_Idle_Ground` | 3 s | Loop | Quatro patas apoiadas, respiração, cabeça e cauda suaves, asas recolhidas para trás |
| `Dragon_Idle_Flying` | 2 s | Loop | Voo estacionário, batidas das asas, corpo acompanhando e patas recolhidas |
| `Dragon_Walk_Ground` | 1,5 s | Loop | Marcha de quatro apoios, elevação alternada das patas, balanço do corpo e cauda |
| `Dragon_Walk_Flying` | 1,5 s | Loop | Corpo inclinado para avançar, batida forte das asas e breve planeio |
| `Dragon_Attack_Ground` | 3 s | Uma vez | Recuo, cauda como contrapeso, abertura e sustentação da boca, recuperação |
| `Dragon_Attack_Flying` | 3 s | Uma vez | Ataque mantendo o voo, abertura e sustentação da boca, recuperação |

Os deslocamentos são feitos no próprio eixo, sem translação acumulada. O movimento
do mapa é controlado pelo jogo. As patas são posicionadas com IK analítico no
Blender e gravadas como transformação dos ossos: não há dependência de IK em runtime.
Velocidade de referência da marcha: 0,271 m/s no tamanho nativo; o jogo pode ajustar
a velocidade de reprodução de acordo com seu deslocamento.

## Rajada de fogo

Não existem fogo, núcleo, fumaça ou partículas embutidos neste modelo. Ambos os
ataques usam a janela **0,75–2,0 s** para emissão da rajada, gravada também nos
marcadores `FIRE_START` e `FIRE_END` das Actions (frames 19 e 49 a 24 fps).

O osso não deformador **`mouth_fire`**, filho da cabeça, fica na saída da boca.
Seu eixo local **+Y** aponta para a frente. No Godot, um `BoneAttachment3D` pode
seguir esse osso para posicionar e orientar o emissor. O jogo controla as
partículas e o acerto; esta entrega contém somente os movimentos do dragão.

Os quatro ciclos fecham com poses iguais. Os dois ataques retornam à pose inicial
do idle correspondente. Todos os seis clipes possuem os mesmos 159 caminhos de
animação, permitindo mistura entre estados no `AnimationPlayer`/`AnimationTree`.

## Arquivos

- `dark_red_dragon_v5_animated.blend`: fonte com peças editáveis, rig, Actions e NLA.
- `dark_red_dragon_v5_animated.glb`: 1 malha, 1 material, 53 ossos, 6 clipes.
- `dark_red_dragon_v5_animated_{albedo,emission}.png`: texturas iguais à V4.
- `previews/animations/Dragon_All_Animations.mp4`: vídeo com as seis animações.
- `previews/animations/Dragon_*.{mp4,gif}`: prévias individuais capturadas no Godot.
- `animation_validation.json`: conferência de apoios, limites do piso e ciclos no Blender.
- `godot_animation_validation.json`: conferência de todos os frames após importar o GLB.

Scripts: `animate_dark_red_dragon_mcp.py`, `export_dark_red_dragon_animations_mcp.py`,
`review_dark_red_dragon_animations.gd` e `encode_dark_red_dragon_animations.py`,
em `tools/art_pipeline/`.

O rig da cena abre no idle de chão. Os demais clipes estão nas Actions e nas seis
pistas nomeadas do NLA. Altura da geometria de repouso: 3 m, mantendo a escala da V4.
Nenhuma unidade, regra de combate ou efeito do jogo foi alterado por esta entrega.

## Em jogo (2026-10-13)

É o Dragão do evento (`MonsterDatabase._apply_dragon_model`), no lugar do corpo procedural. Postura `flying` longe
do alvo e `ground` perto dele (`Unit.set_posture`, guiada por `DragonEvent.travel_mode`); as trocas usam captura de
pose (0,5 s; pouso/decolagem 1,1 s). O emissor do sopro e a luz ficam num `BoneAttachment3D` em `mouth_fire`
(`Unit._build_fire_breath`) e saem na janela 0,75–2,0 s. Sem clipe de morte: `Unit.play_death_topple`.
