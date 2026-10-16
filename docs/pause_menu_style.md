# Aparência do menu de pausa

A pausa usa a moldura pixelada de pedra, detalhes em bronze, fonte Pixelify
e brasão já presentes nos menus. O mapa congelado continua visível sob uma
camada escura estática. **Continuar partida** recebe destaque; salvar/carregar,
configurações/debug e saída ficam em três linhas de ações relacionadas.

O resumo mostra civilização, turno e contagens atuais. O retorno de salvar
aparece somente após a ação. Cabeçalho, botão de continuar e indicação de ESC
ficam fora da área rolável. A lista acompanha o foco por teclado e a largura
e altura respeitam o viewport e a escala da interface.

Os fluxos de salvar, carregar, configurações, debug e confirmação de saída
mantêm seus handlers e o `MenuPager` existente. Abrir continua pausando a árvore;
continuar ou abrir debug despausa pelo mesmo caminho anterior.

## Escopo e coexistência com o trabalho de desempenho

Arquivos de produção alterados: `scripts/ui/PauseMenu.gd`,
`scenes/ui/PauseMenu.tscn` e o novo `scripts/ui/PauseMenuTheme.gd`.
O tema é local e reutiliza texturas importadas; não modifica os temas
compartilhados nem configurações gráficas. Layout é recalculado apenas ao
abrir, redimensionar ou alterar acessibilidade, com chamadas diferidas
coalescidas. Não há `_process`, efeitos de blur, shader de fundo ou animações novas.

Os arquivos de pausa estavam estáveis antes das edições. As alterações
recentes de desempenho em unidades, mapa, câmera, sombras e configurações
foram preservadas. A validação aguardou a ausência de processos de benchmark;
nenhuma outra instância de Godot foi encerrada ou reiniciada e não foi executada
uma importação geral do projeto.

## Conferência

Passaram os 17 testes existentes de pausa e navegação. A ferramenta
`tools/art_pipeline/review_pause_menu.gd` renderiza a cena real de pausa sobre
uma captura anterior do mapa congelado, sem gerar outra partida 3D. Confere
geometria em 1600×900, 1280×720 e 960×720, incluindo escala de 150%, feedback de
save, confirmação, navegação para carregar/configurações e retomada da árvore.
Resultado e capturas: `docs/previews/pause_menu/`.
