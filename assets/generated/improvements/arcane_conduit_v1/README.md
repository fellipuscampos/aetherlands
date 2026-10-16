# Conduíte Arcano — melhoria compartilhada

> Proposta substituída pela [versão 2](../arcane_conduit_v2/README.md) após a
> revisão do usuário em 15/10/2026. Esta pasta conserva a primeira fonte e sua
> conferência histórica; o catálogo do jogo utiliza a versão 2.

Criado no Blender aberto via MCP (`localhost:9876`), em 15/10/2026.
Serve à melhoria existente `v2_improvement_arcane_conduit` do recurso
`mana_node`, para humanos, elfos, orcs e anões.

O nódulo aprovado foi copiado integralmente para o centro: cristal ciano
suspenso, fragmentos menores e rocha com veios arcanos. A instalação acrescenta
quatro coletores baixos de pedra/bronze, canais de condução e um controle rúnico.
O recurso original e as outras cenas do Blender foram preservados.

- **Uma malha, uma superfície, um material, 640 triângulos.**
- Origem no chão, altura 0,84 e raio máximo 0,7583 para tile de raio 1.
  Cabe no círculo inscrito do hexágono, inclusive com rotação.
- Atlas pixelado de 512 × 512 e máscara de emissão, embutidos no GLB e
  empacotados no `.blend`. O quadrante do recurso conserva seus texels/UVs.
- Texturas 3D importadas em BC7; filtro nearest. Sólidos fechados, normais
  planas; sem rig, animações, câmeras ou luzes exportadas.
- `arcane_conduit_v1.blend`: fonte editável; `arcane_conduit_v1.glb`: asset do jogo.

## Integração

`V2ResourceImprovementData` aponta a melhoria para este GLB. O marcador reconhece
a arte nativa em unidades de tile, aplica `hex_size` e apoia a base na superfície
real do terreno, incluindo colinas. Não recebe o cone dourado legado.

Como o modelo contém o próprio recurso, `replaces_resource_prop` remove somente
o prop cru, liberando antes os overlays de foco visual. O recurso lógico e seu
ícone são preservados. Rebuild e load não desenham um segundo cristal no mesmo
local. Os efeitos econômicos, cargas, custos e bônus raciais não foram alterados.

O perfil arcano existente em `WorldGlow` passa a iluminar a instalação, com uma
única luz sem sombras em substituição à luz do recurso. Respeita noite/dia,
névoa e a opção de iluminação dos recursos. A emissão usa o mesmo sistema.
Criação e alterações são por evento; sem novo `_process`, partículas ou timer.

Para futuras melhorias, marcar `replaces_resource_prop` apenas quando o asset
já incluir o recurso. A arte nativa deve caber no tile sem escala KayKit.

## Conferência

- `manifest.json`: geometria e método de criação no Blender MCP.
- `game_validation.json`: uma execução gráfica com HexGrid real e uso de
  `V2ConstructorRuntime`, quatro donos raciais, solo plano/colina, escala do
  mapa, dia/noite, névoa e reconstrução. PASS. Mapa de conferência sintético.
- `previews/three_quarter.png`, `game_top.png`, `top.png`: vistas no Blender.
- `previews/in_game_before.png` / `in_game_after.png`: antes/depois no jogo.
- `previews/in_game_night.png`: iluminação; `in_game_map_scale.png`: leitura à distância.
- **9 testes novos / 55 asserções passaram**, execução isolada com saída 0.
  Cobrem geometria, renda, escala, ícone, foco, rebuild/restauração, névoa,
  luzes e remoção ao destruir o recurso/gerar outro mapa.
- Rodada ampliada: **52 testes / 924 asserções passaram** (economia,
  save/load, iluminação e decoração). Houve aviso final de 2 objetos / 1 recurso
  em uso nessa combinação de fixtures; os nove testes novos isolados encerram
  sem esse aviso. Não foram alteradas fixtures de outros sistemas.
- Uma rodada adicional incluindo `test_core_glow` apontou o teste antigo de
  rótulos da página de vídeo: espera “Luzes do mapa/criaturas”, mas a interface
  atual usa “Iluminação dos recursos/manifestações”. Esses textos não foram
  alterados nesta entrega.

Os scripts/cena de conferência gráfica foram removidos. Gerador reproduzível:
`tools/art_pipeline/build_arcane_conduit_mcp.py`, enviado por
`tools/art_pipeline/blender_mcp_client.py`. O gerador protege um GLB existente.
