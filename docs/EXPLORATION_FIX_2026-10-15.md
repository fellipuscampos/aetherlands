# Explorar por perfil de movimento — 15/10/2026

Relato: Explorar parecia não funcionar em algumas unidades, especialmente magos. As verificações separaram
falhas reais de navegação dos casos em que a unidade já gastou a ação ou não há fronteira acessível.

## Falhas corrigidas

- **Voo tático:** a exploração usava `unit_path`, que planeja passagem terrestre para essas unidades. Agora
  planeja uma sequência de pousos legais, com saltos limitados ao movimento total de um turno. Sobrevoa
  água/montanhas e ocupantes, preservando a regra de terminar em terra livre e o movimento disponível.
- **Infiltração:** a busca antiga bloqueava outras unidades e cobrava terreno comum. O Mestre das Sombras
  agora atravessa formações, paga seu custo plano e termina em tile livre. Nunca sobrescreve ocupantes no
  índice; se o movimento restante não permite sair da formação, aguarda um turno com orçamento suficiente.
- **Limite de 24 candidatos:** falhar nos candidatos mais próximos não significa que todas as fronteiras sejam
  inacessíveis. A seleção terrestre habitual foi mantida; quando ela falha, uma única busca complementar
  procura uma fronteira realmente alcançável, em vez de desligar por causa do limite.
- **Cancelamento na água:** uma exploração iniciada em terra pode continuar embarcada. O botão agora permite
  cancelá-la nessa situação. Continua bloqueado para iniciar uma exploração nova na água.
- **Feedback:** o comando mostra “Ordem futura” quando a unidade já gastou seu movimento. Se não encontra
  fronteira acessível ao ser ativado, informa o motivo. O marcador acompanha o deslocamento inicial.

O momento das ordens permanentes foi preservado: ativar usa o movimento disponível; depois, a ordem consome
o movimento restante ao encerrar o turno. Não consome antecipadamente o movimento recém-recarregado antes
de devolver o controle ao jogador. Custo, atributos, recargas, balanceamento e decisões dos rivais não mudaram.

## Implementação e custo

`ExplorationPlanner.gd` não é autoload nem adiciona `_process`, timers, filas de IA ou campos ao save. Usa heap,
custo de passagem canônico, fronteiras fechadas e caches locais à chamada. O grafo contém paradas legais;
a execução dos perfis especiais reutiliza `unit_route`, o helper da prévia/animação. O contato com inimigo novo
continua interrompendo o avanço. Hostes sem comando mantêm a ordem pendente.

Há um corte reverso de até 24 paradas para provar que pequenos bolsões estão isolados antes de procurar
no continente. Acima desse limite o resultado é inconclusivo, nunca um falso “inalcançável”. A busca principal
continua até uma fronteira ou até esgotar o componente acessível; componentes grandes sem acesso a objetivos
podem exigir mais trabalho. Não existe uma afirmação de tempo máximo constante por ordem.

Benchmark: `tools/perf/ExplorationBench.tscn`. Mede apenas CPU do **planejamento**, sem movimento, atualização
da névoa, modelos, animações, GPU ou IA. O baseline reproduz a seleção anterior de 24 candidatos. A/B sequencial,
com caches aquecendo e outros processos ativos: não é medição de FPS nem comparação isolada de campanha.

| Cenário | 128×72 — média nova | 320×84 — média nova | Amostras por variante |
|---|---:|---:|---:|
| Voo, fronteira em campo aberto | 2,99 ms | 3,08 ms | 30 |
| Infiltração, fronteira em campo aberto | 1,69 ms | 1,80 ms | 30 |
| Voo, mapa todo explorado | 2,00 ms | 7,28 ms | 10 |
| Voo, objetivo pequeno isolado por montanhas | 2,27 ms | 7,52 ms | 1 |

O caminho terrestre habitual continua usando o mesmo heap limitado e A* de antes. No ensaio grande, média
87,32 ms no baseline e 77,84 ms na rodada nova, sem atribuir a variação a uma otimização desse caminho.
O planejamento especial em campo aberto deixou de repetir a seleção global de candidatos: o baseline mediu
88,59 ms para voo e 86,83 ms para infiltração nesse mapa. As rotas especiais agora respeitam seus perfis;
uma rota vazia da versão anterior nos casos corrigidos é falha funcional, não vantagem de desempenho.

Artefatos: [mapa padrão](balance/exploration_cpu_20261015.json),
[mapa grande](balance/exploration_cpu_large_20261015.json).

## Cobertura

`test_exploration_profiles.gd`: 14 testes / 146 asserções. Antes dos ajustes, 7 dos 10 casos iniciais falhavam.
Cobertura inclui:

- 37 tipos treináveis que têm Explorar; o Colonizador mantém a exceção intencional da interface.
- As duas hostes invocadas, com e sem comando necromântico.
- Os seis magos de escola lançando um feitiço real, ativando Explorar pelo botão do painel e retomando a ordem
  depois de recuperar movimento. O botão permanece utilizável após a conjuração e indica a ordem futura.
- Voo sobre água e montanhas, pousos em vários turnos, distância de travessia impossível, infiltração com
  ocupantes preservados, custo plano, movimento parcial, destinos bloqueados e cancelamento embarcado.

Rodada ampla: **438/438 testes funcionais, 2.299 asserções, 255,46 s**, em dez arquivos: exploração por perfil,
ordens permanentes, movimento, embarque, seleção, GameManager, contexto da interface, foco de ações, hostes e HUD.
Não houve falha de asserção ou erro de script. O processo inicialmente terminou com aviso de 22 objetos / 7
recursos ainda carregados no encerramento (saída 1), além dos avisos de órfãos dos fixtures de interface.

Isolamento: os quatro arquivos de exploração, ordens, embarque e foco passaram **44/44**, saída 0. A suíte
`test_v2_retinue_system.gd` sozinha reproduziu os 22 objetos / 7 recursos: o teste de carregar save criava
jogadores que não estavam na lista de limpeza `_players`, deixando relações diplomáticas entre os novos
jogadores. Seu `after_each` agora libera também as relações desses jogadores antes de restaurar os globais.
É somente limpeza do fixture; não altera o carregamento nem as regras do jogo.

Depois dessa limpeza, os cinco arquivos juntos passaram **60/60, 516 asserções, 6,84 s**, com saída 0 e sem
o aviso de recursos no encerramento. A suíte nova de exploração sozinha também passou com saída 0. A rodada
ampla de 438 não foi repetida depois da alteração exclusiva no teardown do teste de hostes.

Logs e cópias anteriores dos quatro arquivos existentes: `%TEMP%/aetherlands_explore_fix_20261015/`.
