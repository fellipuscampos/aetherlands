# Arconte do Véu — morte V1

Animação criada no Blender aberto, via MCP. O núcleo se contrai e gira até desaparecer aos 0,76 s. A armação luminosa se fecha em seguida e desaparece aos 1,13 s. As 34 placas rúnicas ficam suspensas até esse colapso terminar, depois se soltam em sequência, caem e se acomodam perto da posição original. Permanecem em tamanho integral até 4 s e desaparecem entre 4 e 4,8 s. O clipe termina aos 5 s. Sem partículas ou VFX adicionais; núcleo e estrutura são a geometria original do modelo.

- `index.html` / `Morte.mp4`: prévia com controles, 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `veil_archon_death.blend`: cena independente, Death selecionada, quadros 1–121. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `veil_archon_death.glb`: Death, Summon, Idle, Walk, Attack e Spell; uma malha, um material, 39 ossos e 1.364 triângulos. Mesma geometria, pesos, UVs, textura e rig da invocação aprovada; 47 peças editáveis na fonte.
- `validation.json`: 241 poses e meios de quadro; início no repouso, raiz fixa, núcleo e armação desaparecidos antes da queda, placas imóveis durante o colapso, contato com o chão, tamanho integral até 4 s e desaparecimento posterior. A pilha ocupa cerca de 3,26 × 3,30 m, próxima do diâmetro original. Os cinco clipes existentes e as texturas embutidas foram comparados com o GLB da invocação.

A queda das 34 placas usa Bullet durante a criação, com gravidade de −9,81 m/s², 32 subpassos e 50 iterações. As placas usam camadas de colisão para evitar impulsos de facetas vizinhas na posição inicial. Piso e limites temporários mantêm a queda compacta. Toda a animação é gravada nos ossos existentes; helpers, colisores e física não acompanham o asset.

Death deve executar uma vez e manter a pose final até remover a unidade, sem retornar a Idle. O piso de estúdio é apenas para revisão e não acompanha o GLB. Revisão de arte ainda sem ligação ao evento de morte no jogo. A invocação aprovada, os outros clipes e os assets em uso foram preservados.

Fontes: `tools/art_pipeline/animate_veil_archon_death_mcp.py`, `finish_veil_archon_death_mcp.py`, `render_veil_archon_death_mcp.py` (via `blender_mcp_client.py`) e `package_veil_archon_death_review.py`.
