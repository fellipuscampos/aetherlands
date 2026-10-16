# Serafim — invocação revisada: núcleo primeiro

Revisão criada no Blender aberto, via MCP. O cubo luminoso aparece entre 0,08 e 0,65 s e permanece sozinho até 0,9 s. Depois, as 12 arestas douradas se encaixam ao redor dele, as duas auréolas crescem atrás do núcleo e avançam girando, e as peças da estrutura traseira se montam. As bases douradas e os pares de asas entram em sequência: coroa, principais e inferiores. As asas crescem a partir das raízes, flexionam e abrem com leve ultrapassagem e acomodação. O movimento termina exatamente na primeira pose de Idle.

- `index.html` / `Invocacao.mp4`: prévia com controles, 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `seraph_summon.blend`: cena independente, Summon selecionada, quadros 1–121. Espaço reproduz/pausa; Shift+Seta Esquerda volta ao início.
- `seraph_summon.glb`: Summon, Idle, Walk, Attack e Spell. Uma malha, um material, 56 ossos e os mesmos 2.072 triângulos. Geometria, UVs e texturas da V4 preservados. Foram acrescentados 27 controles de montagem e 18 de flexão; novos pesos nas asas conservam o movimento original com os controles em repouso.
- `validation.json`: 241 poses e meios de quadro; início invisível, núcleo isolado na abertura, raiz fixa, geometria acima do piso, nenhum novo cruzamento das asas após a formação e pose final idêntica a Idle. As quatro animações existentes e as texturas embutidas foram comparadas com o GLB original; a deformação original também foi conferida antes e depois dos novos controles.

Sem partículas ou malhas adicionais de efeitos. A animação fica gravada nos ossos e não depende de física ou visibilidade específica do Blender. O estúdio serve apenas à revisão e não acompanha o GLB. Summon deve executar uma vez e seguir para Idle. A revisão ainda não está ligada ao evento de nascimento no jogo. Os assets em uso, a morte do Serafim e as outras manifestações permanecem preservados.

Fontes: `tools/art_pipeline/animate_seraph_summon_mcp.py` (encaminha para `animate_seraph_assembly_mcp.py`), `finish_seraph_summon_mcp.py`, `render_seraph_summon_mcp.py` e `package_seraph_summon_review.py` (encaminha para `package_seraph_assembly_review.py`). Os scripts de Blender executam pelo cliente MCP local.
