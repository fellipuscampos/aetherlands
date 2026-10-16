# Arquidemônio — invocação e morte V1

Criadas no Blender aberto, via MCP. Somente a armadura original animada; partículas e demais efeitos ficam para o Godot. Revisão de arte, ainda sem integração com os eventos de nascimento e morte do jogo.

- `index.html`: alternar entre invocação e morte, reproduzir, pausar e repetir.
- `Summon.mp4`: invocação de 4 s, 97 quadros incluindo o final; `Death.mp4`: morte de 5 s, 121 quadros incluindo o final. Ambos em 800 × 800, 24 fps.
- `archdemon_summon.blend` e `archdemon_death.blend`: mesma cena editável, com o respectivo clipe já selecionado e intervalo pronto. Espaço: play/pausa. Shift+Seta Esquerda: início.
- `archdemon_lifecycle.glb`: Idle, Walk, Attack, Spell, Summon e Death. Uma malha, um material, 57 ossos e 1.084 triângulos. Os 28 pivôs adicionais controlam apenas o desaparecimento das peças; preservam os movimentos dos 29 ossos originais, as malhas e os UVs.
- `validation.json`: 434 poses e meios de quadro; raiz fixa, 16 conjuntos apoiados no piso ou na pilha entre 3 e 4 s, área de repouso próxima de 2,1 × 2,2 m, tamanho normal até 4 s, faixas sem abrir nas junções e poses de ligação ao Idle conferidas. Os quatro clipes originais e a invocação aprovada foram comparados no GLB exportado.

Summon: surgimento do corpo, coroa e ombros convergindo, mãos chegando com atraso entre os lados, expansão contida e acomodação no repouso. Deve executar uma vez e seguir para Idle.

Death: 16 conjuntos de armadura e tecido se soltam em momentos diferentes e caem por simulação de corpos rígidos do Blender, com gravidade, colisão no piso e pequenos ressaltos. Impulsos voltados para dentro, maior amortecimento e limites usados apenas na simulação de autoria mantêm as peças próximas, formando uma pilha de aproximadamente 2,1 × 2,2 m, quase na área de um tile de raio 1 m. As peças permanecem apoiadas no chão ou em outras peças, em tamanho normal, até 4 s; então desaparecem no próprio lugar. O movimento foi convertido em keyframes: o GLB e o Blender salvo não dependem de física em tempo real, e os limites temporários não são exportados. Deve executar uma vez, manter o último quadro e remover a unidade; não retornar a Idle.

As versões do jogo e as animações do Serafim foram preservadas. Fontes reproduzíveis em `tools/art_pipeline/{animate,finish,render}_archdemon_lifecycle_mcp.py`, `revise_archdemon_death_ground_mcp.py` (executada automaticamente pelo script de animação) e `package_archdemon_lifecycle_review.py`.
