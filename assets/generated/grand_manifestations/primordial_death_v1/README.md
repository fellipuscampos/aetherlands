# Primordial dos Elementos — morte V1

Revisão criada no Blender aberto, via MCP. O núcleo se contrai, gira e desaparece antes de 0,84 s. Uma onda percorre a coluna, com atraso na perda de sustentação entre pescoço, meio do corpo e cauda. A serpente muda de curvatura e afunda com os segmentos seguindo uma curva suave, mantendo o comprimento original. O corpo se desfaz da cauda a partir de 1,55 s, deixando pescoço e cabeça por último. A cabeça cede e desaparece sob o chão. Duração: 5 s. Sem partículas ou VFX adicionais.

- `index.html` / `Morte.mp4`: prévia com controles, 800 × 800, 30 fps, 151 quadros incluindo a pose final.
- `primordial_death.blend`: cena independente, Death selecionada, quadros 1–151. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `primordial_death.glb`: Death, Summon, idle, walk, attack e spell; uma malha, um material, 91 ossos e 1.738 triângulos. Mesma geometria, pesos, UVs, texturas e 125 peças editáveis da invocação aprovada. Nomes dos clipes antigos preservados.
- `validation.json`: 301 poses e meios de quadro; início igual ao repouso, raiz fixa, núcleo desaparecido antes da perda do corpo, coluna conectada, mudança real da curvatura, limite de dobra entre segmentos, malha contínua, final invisível e corpo sob o piso. Os cinco clipes anteriores e as texturas embutidas foram comparados com o GLB da invocação.

A curva da coluna é interpolada com Catmull–Rom e percorrida respeitando o comprimento de cada segmento. As 40 seções existentes acompanham as tangentes da nova curva. Na dissolução, as seções da cauda se recolhem na ponta remanescente, mantendo a malha contínua. Nenhum fragmento, osso adicional ou sistema de partículas foi acrescentado. O movimento fica gravado nos ossos, sem física em tempo real.

Death deve executar uma vez e manter a pose final até remover a unidade, sem retornar a idle. O terreno deve ocultar a geometria que afunda abaixo da superfície. O piso de estúdio existe apenas para revisão e não acompanha o GLB. A revisão ainda não está ligada ao evento de morte no jogo. A invocação aprovada e os assets em uso foram preservados.

Fontes: `tools/art_pipeline/animate_primordial_death_mcp.py`, `finish_primordial_death_mcp.py`, `render_primordial_death_mcp.py` (via `blender_mcp_client.py`) e `package_primordial_death_review.py`.
