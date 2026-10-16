# Conduíte Arcano — jazida trabalhada de cristais de Mana

Substitui a primeira proposta após a revisão do usuário em 15/10/2026.
Modelado no Blender aberto, via MCP (`localhost:9876`). Compartilhado
por humanos, elfos, orcs e anões.

A revisão atual retira o reservatório e a calha que sugeriam Mana líquida.
A melhoria representa o trabalho com cristais sólidos: jazida de rocha,
guincho de madeira, bancada seca com amostras presas em suportes e caixa de
fragmentos. Madeira, pedra, silhuetas blocadas e atlas pixelado seguem o cenário.

Os cristais usam exatamente a primitiva `floating_shard` do gerador do recurso
original: seção quadrada sem chanfros, dois anéis nas frações 0,32 e 0,72 e
pontas superior/inferior, com dez vértices por cristal e a mesma paleta ciano.
O cristal central e os três satélites conservam as dimensões originais; amostras
menores usam o mesmo perfil. Só essa primitiva é reutilizada, sem copiar a
composição completa do recurso. O recurso natural permanece intacto.

- `arcane_conduit_v2.blend`: fonte editável com cena de estúdio isolada.
- `arcane_conduit_v2.glb`: exportação usada pelo jogo, sem câmeras/luzes/rig/animação.
- Uma malha, uma superfície, um material, **700 triângulos**.
- Altura 0,83; raio máximo 0,725; origem no chão. Cabe no círculo inscrito do tile.
- Atlas de cor e emissão de 512 × 512, filtro nearest; texturas 3D em BC7.
- Componentes sólidos fechados; normais recalculadas; sem faces degeneradas.
- Gerador: `tools/art_pipeline/build_arcane_conduit_v2_mcp.py`.

## Integração e verificação

O catálogo `V2ResourceImprovementData` aponta o Conduíte para esta versão. A
integração existente remove a representação natural para não sobrepor cristais,
preserva o recurso lógico/ícone e apoia o modelo na altura real do terreno.
Economia, cargas, balanceamento e regras do construtor foram preservados.

A instalação reutiliza uma única luz arcana por recurso pelo `WorldGlow`,
obedecendo dia/noite, névoa e configuração de iluminação. Sem novas partículas,
animações, timers ou atualizações contínuas.

- Revisão atual: **22 testes / 112 asserções passaram**, saída 0, cobrindo a
  arte e as melhorias/economia. A fixture econômica existente reporta nós
  órfãos durante a limpeza; não foram alterados seus testes ou regras.
- A rodada anterior da integração passou em 52 testes / 926 asserções, incluindo
  decoração de construção, integração/save/load da fase 15 e WorldGlow.
- **29 verificações gráficas passaram**, em uma execução não-headless do Godot
  com HexGrid e V2ConstructorRuntime reais num mapa sintético. Quatro donos
  raciais; solo plano e colina; dia/noite; escala do mapa; névoa; rebuild; renda.
  Cidades e unidades foram ocultadas apenas para fotografar o asset.
- Conferido que as instâncias naturais saem do batch de GPU e não retornam no
  rebuild; quatro recursos melhorados continuam usando quatro luzes ao todo.
- `manifest.json`: geometria, peças e método de criação.
- `game_validation.json`: resultado da execução gráfica.
- `previews/three_quarter.png`, `game_top.png`, `top.png`: vistas no Blender.
- `previews/in_game_before.png`, `in_game_after.png`, `in_game_map_scale.png`,
  `in_game_night.png` e as quatro vistas raciais: capturas reais do Godot.

As demais cenas do Blender e os arquivos do recurso natural foram preservados.
