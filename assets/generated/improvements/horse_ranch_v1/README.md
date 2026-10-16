# Haras — melhoria do recurso de cavalos

Criado no Blender aberto pelo MCP local (`localhost:9876`) em 15/10/2026.
Modelo compartilhado por humanos, elfos, orcs e anões para a melhoria
`v2_improvement_horse_ranch` do recurso `horses`.

Cercado de madeira com portão aberto, dois cavalos castanhos, abrigo aberto
ao fundo, fardos de feno e cocho. O abrigo fica atrás dos animais para que
ambos permaneçam legíveis na câmera de estratégia. Cerca baixa e passagem
central mantêm o espaço do cercado visível.

Os animais reutilizam as dezenove peças do cavalo de recurso aprovado,
sem sela ou equipamento. Anatomia, olhos, focinho, lista branca, meias,
crina, cauda e pintura foram preservados, aplicando apenas escala uniforme
de 0,74/0,76 e posicionamento. O atlas original de 512 × 512 foi copiado
integralmente para a metade direita de um atlas de 1024 × 512, sem reduzir
seus pixels. A metade esquerda contém madeira, feno, terra e gramado.
O arquivo fonte do cavalo foi verificado por SHA-256 antes/depois.

- `horse_ranch_v1.blend`: fonte editável, atlas empacotado e estúdio isolado.
- `horse_ranch_v1.glb`: modelo utilizado no jogo.
- Uma malha, uma superfície, um material; **1.168 triângulos**.
- Origem no chão, altura 0,7122 e raio máximo 0,8063; cabe no círculo
  inscrito do tile, inclusive com rotação. Apoio acompanha a altura das colinas.
- Uma textura de cor, 1024 × 512, nearest e BC7; sem mapa de emissão.
- Componentes sólidos fechados, normais recalculadas, sem faces degeneradas.
- Sem rig, animações, câmeras ou luzes na exportação GLB.
- Gerador: `tools/art_pipeline/build_horse_ranch_mcp.py`.

## Integração

O catálogo de melhorias aponta o Haras para este modelo e utiliza a substituição
de prop já implementada. O cavalo avulso é removido junto de seu cache de
materiais de névoa; não reaparece após reconstruir os props. Recurso lógico
e ícone permanecem. A decoração do próprio tile é limpa pela integração atual.

As regras de trabalho do construtor e os bônus de capacidade de Suprimentos
4/6/8 por tier foram preservados. A entrada de cavalos no catálogo é a única
alteração no código do jogo nesta tarefa. Sem luzes adicionais, partículas,
timers ou rotinas de atualização.

## Conferência

- **28 testes / 162 asserções passaram**, saída 0: arte do Conduíte existente,
  melhorias/economia e limpeza de decoração. A fixture econômica existente
  reporta nós órfãos na limpeza; seus testes não foram modificados.
- **35 verificações passaram** numa execução gráfica do Godot: geometria,
  HexGrid e V2ConstructorRuntime reais, quatro donos raciais, capacidade de
  Suprimentos, remoção do cavalo avulso, solo plano/colina, névoa e rebuild.
  Mapa sintético; cidades e unidades ocultadas apenas para fotografar a melhoria.
- Nenhuma luz de recurso criada pelo Haras.
- `manifest.json`: geometria, fonte, hash e preservação dos cavalos.
- `game_validation.json`: resultado da conferência gráfica.
- `previews/three_quarter.png`, `game_top.png`, `top.png`: vistas no Blender.
- `previews/in_game_before.png`, `in_game_after.png`, `in_game_map_scale.png`,
  `in_game_night.png` e quatro vistas raciais: capturas reais do Godot.

As outras cenas do Blender e os arquivos originais foram preservados;
a cena ativa foi restaurada após a geração.
