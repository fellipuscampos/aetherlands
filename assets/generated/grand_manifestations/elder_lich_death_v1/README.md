# Ancião Lich — morte V1

Revisão da morte criada no Blender aberto, via MCP. O Lich afunda enquanto agoniza: reage ao impacto, curva o tronco e tenta se erguer apoiado no cajado. Três esforços assimétricos erguem a cabeça e os braços, com tremores breves; entre eles o corpo cede e afunda mais. O braço do grimório perde força gradualmente. Cajado, livro e vestes acompanham o corpo até tudo desaparecer abaixo do chão. A escala permanece igual durante os 5 segundos; o desaparecimento ocorre por submersão. Sem partículas ou efeitos adicionais: VFX serão feitos no Godot.

- `index.html` / `Morte.mp4`: prévia com controles de reprodução; 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `elder_lich_death.blend`: cena independente, Death selecionada, quadros 1–121. Espaço: reproduzir/pausar. Shift+Seta Esquerda: início.
- `elder_lich_death.glb`: Death, Summon, Idle, Walk, Attack e Spell; uma malha, um material, 37 ossos e 1.548 triângulos. Geometria, textura, pesos e UVs preservados.
- `validation.json`: 241 poses e meios de quadro; início no repouso, raiz fixa, braços conectados, vestes presas ao corpo, escala constante, ausência de colisões dos adereços com o tronco e submersão completa na pose final. Os cinco clipes anteriores foram comparados no GLB exportado.

Death deve executar uma vez e manter a pose final até remover a unidade, sem retornar a Idle. O movimento é gravado nos ossos; não depende de física em tempo real. O terreno do jogo precisa ocultar a geometria que afunda abaixo da superfície. O piso de estúdio é apenas para revisão e não acompanha o GLB.

Revisão de arte, ainda sem ligação ao evento de morte no jogo. A invocação aprovada, os assets em uso e as cenas das outras manifestações foram preservados.

Fontes: `tools/art_pipeline/animate_elder_lich_death_mcp.py`, `finish_elder_lich_death_mcp.py`, `render_elder_lich_death_mcp.py` (via `blender_mcp_client.py`) e `package_elder_lich_death_review.py`.
