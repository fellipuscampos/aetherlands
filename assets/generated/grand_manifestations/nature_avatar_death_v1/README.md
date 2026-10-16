# Avatar da Natureza — morte V1

Animação criada no Blender aberto, via MCP. Primeiro o núcleo se contrai e gira dentro do peito até desaparecer aos 0,9 s. A madeira permanece intacta até 1,05 s; só então perde sustentação e desaba. As 85 peças caem com gravidade e se acomodam em uma pilha compacta, preservando a queda da revisão anterior. A madeira permanece em tamanho integral até 4 s, depois desaparece localmente, terminando o clipe aos 5 s. Sem partículas ou VFX adicionais.

- `index.html` / `Morte.mp4`: prévia com controles, 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `nature_avatar_death.blend`: cena independente, Death selecionada, quadros 1–121. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `nature_avatar_death.glb`: Death, Summon, Idle, Walk, Attack e Spell; uma malha, um material, 103 ossos e 2.060 triângulos. Mesma geometria, UVs, textura e rig da invocação aprovada.
- `validation.json`: 241 poses e meios de quadro; início no repouso, raiz fixa, núcleo invisível antes da queda, madeira imóvel durante o colapso do núcleo, madeira apoiada no piso, tamanho integral até 4 s e desaparecimento posterior. Área da pilha próxima de 2,74 × 2,23 m. Os cinco clipes existentes e as texturas embutidas foram comparados com o GLB da invocação.

A queda da madeira usa Bullet durante a criação, com gravidade de −9,81 m/s², 32 subpassos e 50 iterações. O movimento gravado é reposicionado no tempo para começar após o desaparecimento do núcleo, que colapsa no peito sem cair. As facetas interligadas do modelo começam sobrepostas: camadas distintas de colisão evitam impulsos artificiais entre essas partes. Piso e limites temporários mantêm a queda compacta. Toda a animação é gravada nos ossos; helpers, colisores e física não acompanham o asset.

Death deve executar uma vez e manter a pose final até remover a unidade, sem retornar a Idle. O piso de estúdio é apenas para revisão e não acompanha o GLB. Revisão de arte ainda sem ligação ao evento de morte no jogo. A invocação aprovada e os assets em uso foram preservados.

Fontes: `tools/art_pipeline/animate_nature_avatar_death_mcp.py` chama `retime_nature_avatar_death_core_first_mcp.py`; `finish_nature_avatar_death_mcp.py`, `render_nature_avatar_death_mcp.py` (via `blender_mcp_client.py`) e `package_nature_avatar_death_review.py` validam e empacotam.
