# Lobby de nova partida

Integrado ao fluxo real `TitleScreen → GameSetupScreen → Main`. O fundo, a fonte Pixelify Sans, os botões de metal/bronze e as bordas em degraus continuam a identidade do menu inicial. O tema é local a esta tela; `TitleMenuTheme.gd` e as demais telas não foram alterados.

As quatro cartas usam imagens transparentes das cidades e muralhas originais, renderizadas offline em Godot a 384×256, com filtragem nearest na interface. `emblem_*.svg`, `panel.svg` e `selected.svg` seguem uma grade de pixels. Nenhum modelo é carregado em 3D pelo lobby: todos os retratos são texturas estáticas.

- `tools/art_pipeline/build_setup_menu.py`: reproduz a cena e os ornamentos SVG.
- `tools/art_pipeline/render_setup_cities.gd`: reproduz os quatro retratos dos modelos do jogo.
- `scripts/ui/GameSetupTheme.gd`: tema local, estados dos controles e tipografia.
- `tools/art_pipeline/review_setup_menu.gd`: valida fluxo real, entradas, seleção, parâmetros emitidos e layout; capturas em `docs/previews/game_setup/`.

## Organização

1. Compare os quatro povos em uma linha de cartas. A seleção tem borda e marca de confirmação; foco possui contorno claro separado.
2. Leia as especialidades reais e, opcionalmente, abra a história. Nenhum bônus foi inventado para apresentação.
3. Personalize nome, tamanho do mapa e rivais de IA. Nome vazio mantém o nome padrão do povo; nome inválido recebe uma explicação e bloqueia o início.
4. Confira povo, mapa e rivais no resumo persistente e inicie a partida.

Tab segue a ordem de leitura. Setas percorrem as cartas/mapas e ligam os grupos de controles. Escape retorna ao menu. A rolagem acompanha o foco com fontes ampliadas, sem esconder Voltar/Iniciar. A reabertura restaura as escolhas padrão e limpa erro de nome.

Referências de projeto: [Xbox XAG 112 — navegação e ordem de foco](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/112) e [Xbox XAG 113 — indicação de foco](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/113). São critérios de projeto, sem declaração de conformidade integral.

## Verificação concluída

- 20 testes existentes passaram: `test_game_setup_screen.gd`, `test_ui_refinement.gd`, `test_ui_frontend_final.gd` (87 asserções).
- Smoke visual em `Main.tscn` passou: Novo jogo, escolha por setas/Enter, Escape, retorno, quatro povos, duas especialidades por povo, história e emissão dos parâmetros exatos sem gerar uma partida durante a verificação.
- Capturas: 1600×900, 1280×720, 1920×1080, 3440×1440 e 1280×720 com escala 150%; botões de ação permanecem visíveis. Relatório em `docs/previews/game_setup/validation.json`.
