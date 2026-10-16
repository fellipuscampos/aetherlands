# Mina de Ferro — lavra em degraus

Criada no Blender aberto via MCP local (`localhost:9876`) em 15/10/2026.
Melhoria `v2_improvement_iron_mine` do recurso `iron`, compartilhada pelas
quatro civilizações.

Frente de extração em degraus com rocha escura, grãos de ferro cinza expostos
e veios de ferrugem. Um guincho de madeira ergue um balde carregado; a corda
passa pela polia e retorna à manivela. Uma plataforma de separação, minério
solto e picareta completam a área trabalhada.

Os blocos cúbicos conservam a identidade do minério original. Os nove
quadrantes pintados do atlas do recurso foram copiados integralmente para
o atlas da melhoria, preservando seus texels e a densidade de projeção.
A composição é nova; os arquivos do recurso natural foram preservados e
verificados por SHA-256.

- `iron_mine_v1.blend`: fonte editável, atlas empacotado e estúdio isolado.
- `iron_mine_v1.glb`: modelo usado pelo jogo.
- Uma malha, uma superfície, um material; **820 triângulos**.
- Origem no chão, altura 0,68 e raio máximo 0,7166; cabe no círculo inscrito
  do tile. A altura considera o ícone de ferro, situado a 0,84 da superfície.
- Atlas pixelado 512 × 512, nearest e BC7; sem mapa de emissão.
- Componentes fechados, normais recalculadas e sem faces degeneradas.
- Sem rig, animações, câmeras ou luzes na exportação GLB.
- Gerador: `tools/art_pipeline/build_iron_mine_mcp.py`.

## Integração

O catálogo aponta a Mina de Ferro para o novo modelo. A substituição de prop
existente remove o minério natural do batch e limpa a decoração do próprio
tile, preservando recurso lógico e ícone. O minério avulso não reaparece no
rebuild. A base acompanha colinas e a escala do mapa pelo caminho atual.

Ganhos de Produção 2/3/4 por tier de Indústria, cargas e demais regras do
construtor foram mantidos. A alteração no código do jogo limita-se à entrada
de ferro no catálogo. O teste de apresentação do construtor foi atualizado
para conferir a mina nativa registrada, em lugar do antigo modelo KayKit
com selo dourado.

Sem luzes adicionais, partículas, timers ou novas rotinas de atualização.

## Conferência

- **48 testes / 212 asserções passaram**, saída 0: arte existente do Conduíte,
  melhorias/economia, limpeza de decoração e todos os 20 testes do construtor.
  Fixtures econômicas/construtor existentes reportam nós órfãos na limpeza;
  nenhuma regra econômica ou de unidade foi alterada.
- **35 verificações passaram** numa execução gráfica do Godot: geometria,
  HexGrid e V2ConstructorRuntime reais, quatro donos raciais, renda de Produção,
  substituição do minério no batch, solo plano/colina, névoa e rebuild.
  Mapa sintético; cidades e unidades ocultadas apenas para fotografar a melhoria.
- Nenhuma luz de recurso criada pela mina.
- `manifest.json`: geometria, origem das texturas e hashes dos arquivos originais.
- `game_validation.json`: resultado da conferência gráfica.
- `previews/three_quarter.png`, `game_top.png`, `top.png`: vistas no Blender.
- `previews/in_game_before.png`, `in_game_after.png`, `in_game_map_scale.png`,
  `in_game_night.png` e quatro vistas raciais: capturas reais do Godot.

As outras cenas do Blender foram preservadas; a cena ativa foi restaurada.
