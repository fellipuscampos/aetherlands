# Mina de Gemas — melhoria do recurso de cristal

Criada no Blender aberto pelo MCP local (`localhost:9876`) em 15/10/2026.
Usada pelo construtor para o recurso `gems`, igualmente nas quatro civilizações.

A composição mostra uma frente de mineração de ametista: rocha em degraus,
cristais expostos, entrada de mina escorada, trilhos e carrinho carregado,
picareta e bandeja de fragmentos selecionados. O recesso da entrada tem
paredes, piso e fundo próprios. A jazida fica exposta na visão de cima.

Os cristais reutilizam a primitiva `crystal` do gerador aprovado
`tools/art_pipeline/build_crystal_resource_mcp.py`: seção quadrada, faces
planas, ponta piramidal e a paleta roxa original. Cada exemplar é uma cópia
uniformemente escalada desse perfil. A composição completa do recurso natural
não foi copiada; seus arquivos permanecem intactos.

- `gem_mine_v1.blend`: fonte editável, atlas empacotado e estúdio isolado.
- `gem_mine_v1.glb`: modelo usado pelo jogo.
- Uma malha, uma superfície, um material; **898 triângulos**.
- Altura 0,7584 e raio máximo 0,7952; origem no chão. Cabe no círculo inscrito
  do tile, inclusive com rotação; respeita o ajuste existente para colinas.
- Atlas pixelado de 512 × 512, cor e emissão, filtro nearest; texturas 3D em BC7.
- Componentes fechados, normais recalculadas e sem faces degeneradas.
- Sem rig, animações, câmeras ou luzes na exportação GLB.
- Gerador: `tools/art_pipeline/build_gem_mine_mcp.py`.

## Integração

O catálogo `V2ResourceImprovementData` aponta `v2_improvement_gem_mine` para
este modelo. A integração já existente substitui a representação natural e
limpa a decoração do tile, preservando recurso lógico e ícone. Rebuild não
duplica cristais. A melhoria mantém os ganhos de Ouro 4/6/8 por tier,
consumo de cargas e demais regras atuais.

O perfil `GlowProfiles.AMETHYST` reutiliza uma única luz de recurso pelo
`WorldGlow`, com emissão apenas nas partes de ametista. Respeita dia/noite,
névoa e a opção de iluminação do mapa. Sem novas partículas, timers ou
rotinas de atualização; a mudança no código de jogo se limita à entrada
de gemas no catálogo.

## Conferência

- **28 testes / 162 asserções passaram**, saída 0: arte do Conduíte existente,
  melhorias/economia e limpeza de decoração. A fixture econômica existente
  reporta nós órfãos na limpeza; seus testes não foram modificados.
- **35 verificações passaram** numa execução gráfica do Godot: HexGrid e
  V2ConstructorRuntime reais, quatro donos raciais, melhoria pelo construtor,
  renda, geometria, solo plano/colina, névoa, rebuild e luzes. Mapa sintético;
  cidades e unidades ocultadas apenas para fotografar o modelo.
- Os quatro recursos melhorados conservam quatro luzes no total; a instância
  natural foi removida do batch da GPU e não retorna após reconstrução.
- `manifest.json`: geometria e origem do perfil dos cristais.
- `game_validation.json`: resultado da conferência no Godot.
- `previews/three_quarter.png`, `game_top.png`, `top.png`: vistas no Blender.
- `previews/in_game_before.png`, `in_game_after.png`, `in_game_map_scale.png`,
  `in_game_night.png` e as quatro vistas raciais: capturas reais do Godot.

As outras cenas do Blender foram preservadas e a cena ativa foi restaurada.
