# Serafim — morte V1

Criada no Blender aberto por MCP, somente com animação dos ossos. Sem partículas, selo ou outros efeitos; VFX serão feitos no Godot.

- `index.html` / `Morte.mp4`: prévia de 800 × 800, 24 fps, com botão de reprodução.
- `seraph_death.blend`: cena independente, Death selecionada; quadros 1–85 (3,5 s). Espaço: reproduzir/pausar. Shift+Seta Esquerda: início.
- `seraph_death.glb`: Death, Summon, Idle, Walk, Attack e Spell. Uma malha, um material e 11 ossos; texturas incorporadas. As cinco animações anteriores são preservadas.
- `validation.json`: 169 poses verificadas, incluindo meios de quadro; início idêntico ao repouso, raiz fixa, asas sem novos cruzamentos antes de se extinguirem e sem atravessar o chão.

Death começa no repouso com uma reação curta ao impacto. As asas cedem com atraso entre os lados; as auréolas perdem alinhamento, caem e desaceleram. O núcleo se contrai e desaparece, seguido pelo restante da manifestação. No final, a escala positiva mínima mantém o rig válido, com a geometria imperceptível.

Na integração, Death deve executar uma vez, conservar o último quadro e remover a unidade ao terminar; não retornar a Idle. A cena é uma revisão e ainda não está ligada ao evento de morte no jogo.

Fontes: `tools/art_pipeline/animate_seraph_death_mcp.py`, `finish_seraph_death_mcp.py`, `render_seraph_death_mcp.py` e `package_seraph_death_review.py`. Os três primeiros usam `blender_mcp_client.py`. A invocação aprovada e os assets usados pelo jogo permanecem preservados.
