# Entreposto de Seda — coleta, fios e tecelagem

Criado no Blender aberto via MCP local (`localhost:9876`) em 15/10/2026.
Melhoria `v2_improvement_silk_post` para `silk`, compartilhada pelas quatro
civilizações.

A composição mostra uma amoreira cultivada com casulos, tear aberto com
urdidura e tecido em produção, bancada com enrolador manual, bandeja de
casulos colhidos e uma pilha de seda dobrada. O tear fica exposto para a
atividade continuar legível na câmera do mapa, sem um telhado cobrindo-a.

O arbusto foi recomposto para a área de coleta usando as primitivas `block`
e `cocoon` do gerador do recurso aprovado. Folhagem em blocos, casulos de
extremidades em degraus e paleta de marfim/verde preservam a identidade do
recurso. Os mesmos casulos aparecem na bandeja; não são gemas ou novelos
genéricos. O gerador reutiliza somente essas primitivas, sem copiar toda a
composição original. Arquivos do recurso natural permanecem intactos.

- `silk_post_v1.blend`: fonte editável, atlas empacotado e estúdio isolado.
- `silk_post_v1.glb`: modelo utilizado pelo jogo.
- Uma malha, uma superfície, um material; **1.076 triângulos**.
- Origem no chão, altura 0,70 e raio máximo 0,7141; cabe no círculo inscrito
  do tile. A integração existente aplica escala do mapa e altura das colinas.
- Atlas pixelado 512 × 512, nearest e BC7; sem mapa de emissão.
- Componentes sólidos fechados, normais recalculadas, sem faces degeneradas.
- Sem rig, animações, câmeras ou luzes na exportação GLB.
- Gerador: `tools/art_pipeline/build_silk_post_mcp.py`.

## Integração

O catálogo de melhorias aponta o Entreposto para este modelo e utiliza a
substituição de prop já existente. A amoreira avulsa é retirada do batch,
incluindo a decoração do próprio tile; o recurso lógico e o ícone continuam.
Rebuild não recoloca a planta original dentro da melhoria.

Os bônus atuais foram preservados: Ouro 2/3/4 por tier econômico e
Conhecimento 1/2/3 por tier acadêmico, além das cargas e regras do construtor.
A única mudança no código do jogo nesta tarefa é a entrada de seda no catálogo.
Sem luzes adicionais, partículas, timers ou novas rotinas de atualização.

## Conferência

- **28 testes / 162 asserções passaram**, saída 0: arte do Conduíte existente,
  melhorias/economia e limpeza de decoração. A fixture econômica existente
  reporta nós órfãos na limpeza; seus testes não foram modificados.
- **39 verificações passaram** em uma execução gráfica do Godot: geometria,
  HexGrid e V2ConstructorRuntime reais, quatro donos raciais, Ouro e Conhecimento,
  substituição da planta no batch, solo plano/colina, névoa e rebuild.
  Mapa sintético; cidades e unidades ocultadas apenas para fotografar a melhoria.
- Nenhuma luz de recurso criada pelo Entreposto.
- `manifest.json`: geometria, origem das primitivas e hash do gerador original.
- `game_validation.json`: resultado da conferência gráfica.
- `previews/three_quarter.png`, `game_top.png`, `top.png`: vistas no Blender.
- `previews/in_game_before.png`, `in_game_after.png`, `in_game_map_scale.png`,
  `in_game_night.png` e quatro vistas raciais: capturas reais do Godot.

As outras cenas do Blender foram preservadas; a cena ativa foi restaurada.
