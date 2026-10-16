# Arconte do Véu — invocação V1

Animação criada no Blender aberto, via MCP. A estrutura luminosa aparece primeiro. As 34 placas rúnicas surgem em duas coroas horizontais, giram e se fecham ao redor do núcleo, formando o poliedro. O núcleo cresce dentro da estrutura pronta e gira em sentido contrário à casca. O Arconte termina na pose inicial de Idle. Sem partículas ou VFX adicionais; estrutura e núcleo são a geometria do modelo original.

- `index.html` / `Invocacao.mp4`: prévia com controles, 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `veil_archon_summon.blend`: cena independente, Summon selecionada, quadros 1–121. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `veil_archon_summon.glb`: Summon, Idle, Walk, Attack e Spell; uma malha, um material, 39 ossos e 1.364 triângulos. As 47 peças editáveis, geometria, pesos, UVs e texturas originais foram preservados.
- `validation.json`: 241 poses e meios de quadro; início invisível, raiz fixa, peças acima do chão, núcleo sem interseções com as placas ou estrutura e pose final igual ao início de Idle. Os quatro clipes existentes e as texturas embutidas foram comparados com o GLB original.

Summon deve executar uma vez e seguir para Idle. O movimento é gravado nos ossos existentes, sem depender de partículas, física ou scripts de visibilidade. O piso de estúdio é apenas para revisão e não acompanha o GLB.

Revisão de arte, ainda sem ligação ao evento de nascimento no jogo. Os assets em uso e as animações das outras manifestações foram preservados.

Fontes: `tools/art_pipeline/animate_veil_archon_summon_mcp.py`, `finish_veil_archon_summon_mcp.py`, `render_veil_archon_summon_mcp.py` (via `blender_mcp_client.py`) e `package_veil_archon_summon_review.py`.
