# Ancião Lich — invocação V1

Animação criada no Blender aberto, via MCP. O Lich emerge debaixo do piso com a cabeça baixa, desperta, ergue o cajado e o grimório e se acomoda na flutuação de repouso. Sem partículas ou efeitos adicionais; VFX serão feitos no Godot. A geometria espectral que já faz parte do modelo aprovado foi preservada.

- `index.html` / `Invocacao.mp4`: prévia com controles de reprodução; 800 × 800, 24 fps, 97 quadros incluindo a pose final (4 segundos de movimento).
- `elder_lich_summon.blend`: cena independente, Summon selecionada, quadros 1–97. Espaço: reproduzir/pausar. Shift+Seta Esquerda: início.
- `elder_lich_summon.glb`: Summon, Idle, Walk, Attack e Spell; uma malha, um material, 37 ossos e 1.548 triângulos. Modelo, textura, pesos e UVs originais preservados.
- `validation.json`: 193 poses e meios de quadro; raiz fixa, início abaixo do piso, corpo acima do chão ao terminar a emergência, braços conectados, punhos dentro do limite de 35°, vestes presas ao torso e adereços sem interseção com corpo/cabeça. Os quatro clipes existentes foram comparados no GLB exportado e a ligação ao Idle foi conferida.

Summon deve executar uma vez e seguir para Idle. O clipe move o osso do corpo verticalmente debaixo do chão até a pose de referência, mantendo a raiz da unidade fixa; o terreno deve ocultar a parte ainda subterrânea. A cena de estúdio fornece esse piso apenas para revisão: ele não é exportado no GLB.

Revisão de arte, ainda sem ligação ao evento de nascimento no jogo. Os assets em uso pelo jogo, as animações do Serafim e as do Arquidemônio foram preservados.

Fontes: `tools/art_pipeline/animate_elder_lich_summon_mcp.py`, `finish_elder_lich_summon_mcp.py`, `render_elder_lich_summon_mcp.py` (via `blender_mcp_client.py`) e `package_elder_lich_summon_review.py`.
