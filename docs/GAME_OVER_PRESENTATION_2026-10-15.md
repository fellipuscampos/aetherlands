# Telas de vitória e derrota — 15/10/2026

A tela final já herdava o tema pixel do HUD, mas mantinha uma caixa fixa de
680 × 650, um título pequeno misturado às estatísticas e três botões empilhados.
Foi separada em `GameOverPanel.tscn`, com apresentação em
`GameOverPresentation.gd`; a HUD continua responsável pelo resultado e pelas ações.

- Mesmas texturas, fonte Pixelify Sans, fundo verde escuro e botões de bronze/pedra
  usados pelos menus atuais. Vitória em dourado, derrota em cobre claro.
- Resultado em destaque, explicação legível e quatro colunas de estatísticas.
- Conteúdo em uma única área de rolagem, com as ações sempre fora dela.
  Moldura se ajusta à janela/escala; botões empilham em janelas estreitas.
- Ciclo de teclado entre as ações, pulando Carregar quando indisponível.
- Valores e progresso continuam congelados no encerramento. Mudar a escala da
  interface só muda a apresentação. Um novo resultado descarta o snapshot anterior.
- Derrota por eliminação aceita vencedor nulo, como enviado por `GameManager`;
  o acesso anterior a `winner.civ` interrompia o preenchimento da tela.
- Barras de progresso receberam altura explícita de 6 px, escalável, para não
  aparecerem apenas como um fio. Sem mudanças nas condições ou no balanceamento.

Layout atualiza por abertura, redimensionamento ou acessibilidade. Sem `_process`,
timers, efeitos 3D ou novas consultas ao mapa. Snapshot calculado no sinal final,
preservando o contrato existente.

Conferência gráfica em uma única execução: HUD real sobre uma captura estática
do jogo, com resultados e estatísticas de teste; não é uma campanha simulada.
Capturas em `docs/previews/game_over_20261015/`, incluindo comparação anterior,
três rotas de vitória, derrota por eliminação/rival, 720p, escala de 150%, nome
longo e janela estreita. `validation.json` registra enquadramento, rolagem,
estatísticas congeladas e navegação por teclado. As capturas antecedem apenas
o ajuste final da altura das barras, também coberto pela regressão headless.
Cena e scripts descartáveis removidos após a execução.

Regressões: `test_game_over_presentation.gd` (overflow, rolagem, botões e foco)
e testes de resultado/vitória/reinício de `test_hud.gd`, incluindo vencedor nulo
e preservação dos valores após mudar a escala.

Resultado: **26 testes distintos / 120 asserções passaram**, somando os quatro
testes de apresentação e os filtros `game_over`, `victory` e `restart` da HUD
(descontado o teste presente em dois filtros).
