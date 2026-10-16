# Menu inicial de Aetherlands

`scenes/ui/TitleScreen.tscn` usa `kingdom_landscape_painted.png` como fundo real do menu. O tema pixelado de `scripts/ui/TitleMenuTheme.gd` aplica-se somente à página inicial. Carregar e configurações preservam suas telas e seu tema existentes.

Os botões usam texturas com bordas em degraus, nove regiões de escala, acabamento de bronze/metal, ícones e estados de repouso, hover, pressionado, indisponível e foco. Os arquivos SVG são construídos em uma grade de quatro pixels por `tools/art_pipeline/build_title_menu_vectors.py` e exibidos com filtragem nearest. A fonte Pixelify Sans acompanha a licença SIL OFL em `assets/fonts/pixelify_sans/OFL.txt`.

## Arte de fundo

- Arte integrada: `assets/ui/title_menu/kingdom_landscape_painted.png`.
- Referência arquitetônica renderizada com os modelos reais: `kingdom_landscape.png`.
- Ferramenta: imagegen integrado, sem CLI/API externa.
- Prompt final: `generation_prompt.txt`.
- A referência pode ser reproduzida com Godot `--path . --script tools/art_pipeline/render_title_landscape.gd --windowed --resolution 960x540`.
- O fundo final é estático; não há uma cena 3D nem animação sendo processada pelo menu.

## Organização e usabilidade

A ação principal tem destaque e os quatro comandos mantêm uma coluna previsível. Foco possui contorno claro e marcas laterais; setas/Tab percorrem os comandos em ordem circular, pulando carregar quando indisponível. Enter abre as telas existentes; Escape e Voltar retornam ao comando que abriu a página. Textos auxiliares explicam a ação selecionada. A escala de interface existente é preservada e o layout compacto evita sobreposição com o rodapé.

Critérios usados: [Xbox XAG 112 — navegação](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/112), [Xbox XAG 113 — foco](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/113) e [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/full-list/). São referências de projeto; esta alteração não declara conformidade integral com todas as diretrizes.

## Verificação

`tools/art_pipeline/review_title_menu.gd` verifica entradas reais de navegação, ativação, retorno, ordem de foco e limites/ausência de sobreposição em 1280×720, 1600×900, 1920×1080, 3440×1440 e 1280×720 com escala 150%. As capturas e o relatório estão em `docs/previews/title_menu/`.
