# Magia V1 — implementação e uso

Revisão de 17/09/2026. O desenho original está em `MAGIC_SYSTEM_V1.md`.
Este documento registra as regras executadas pelo jogo.

## Pesquisa e cidades

- Tecnologia: 55 pesquisas em dez níveis. Magia: seis escolas de nove níveis
  e Transcendência universal, totalizando 55 pesquisas mágicas.
- Uma pesquisa ativa por civilização, compartilhada entre as duas árvores.
  Trocar de projeto conserva o progresso individual.
- Escolas: Sagrada, Infernal, Necromancia, Druidismo, Arcanismo e Elementalismo.
- Cada escola libera conjurador, infraestrutura, feitiços e um Grande Ritual.
  Edifícios mágicos participam da identidade arcana da cidade e aparecem no mapa.
- Custos de pesquisa por nível: 16, 24, 36, 55, 85, 130, 195, 295 e 445;
  Transcendência custa 740. Estes são valores iniciais sujeitos a playtest.

## Conjuração

Abra **Magia** para pesquisar e **Grimório** para consultar requisitos e conjurar.
Também há ações mágicas no painel da unidade selecionada.

Feitiços exigem um conjurador da escola com ação disponível, mana, alcance,
visibilidade e recarga individual liberada. Um conjurador selecionado sem ação
não transfere silenciosamente o custo para outra unidade. Conjurar consome sua
ação. Silêncio bloqueia magia; atacar ou conjurar revela unidades ocultas.

As seis escolas oferecem cura/purificação, dano e sacrifício, mortos-vivos,
floresta e ocultação, teleporte e silêncio, raios e tempestades. Regiões mágicas
possuem contorno, duração e efeitos por turno. Mudanças temporárias de terreno
preservam recursos e restauram o terreno anterior ao expirar ou ser dissipadas.
Árvores e altura dos recursos acompanham as mudanças locais.

Invocações respeitam limites por invocador. Perder o invocador desfaz as unidades
vinculadas. Manutenção de mana é descontada a cada turno; sem mana, criaturas
dependentes desaparecem e conjuradores ficam silenciados. O tooltip de mana
explica renda, manutenção e saldo previsto.

## Grandes Rituais

Um Grande Ritual por civilização em canalização. Exige pesquisa, estrutura da
escola e quatro conjuradores livres a até dois hexágonos; Necromancia exige cinco.
Custa 300 mana inicial e 20 por turno. Canalização: sete turnos, nove para o Lich
e oito para Cataclismo. Conjuração concluída entra em recarga de 25 turnos.

| Escola | Resultado |
|---|---|
| Sagrada | Aurora: cura, proteção e dissipação de regiões hostis |
| Infernal | Arquidemônio autônomo com demônios vinculados |
| Necromancia | Lich Ancião autônomo com esqueletos vinculados |
| Druidismo | Terras Vivas: transformação, ocultação e defesa territorial |
| Arcanismo | Convergência: transporte de tropas para uma âncora própria |
| Elementalismo | Cataclismo: dano, lentidão e devastação de uma região |

Sede, ritualistas e progresso são públicos. Os participantes ficam imobilizados.
Perder a sede/estrutura, um participante, mana ou a âncora necessária interrompe
o ritual; silêncio também interrompe. Cancelar libera os conjuradores sem reembolso.
Lich e Arquidemônio começam a agir no turno seguinte à criação; não aceitam
ordens manuais. Seus seguidores dependem deles.

## Vitória em partidas novas

- **Dominação:** eliminar as demais civilizações.
- **Supremacia Militar:** pesquisar Exército Supremo e manter cidade desenvolvida
  capturada de cada rival ainda vivo, com pelo menos duas conquistas desenvolvidas.
  Rivais eliminados satisfazem sua parte. Cidade desenvolvida significa população
  de pelo menos três e dois espaços de edifícios usados no momento da captura.
  A aproximação gera aviso; recapturar cidades pode impedir a vitória.
- **Transcendência:** dominar duas escolas no N9, pesquisar a descoberta universal,
  concluir dois Grandes Rituais distintos, controlar três Nódulos, gerar 30 mana
  por turno, construir Santuário e reunir cinco conjuradores de duas escolas.
  Custo: 400 inicial e 40 por turno durante sete turnos. Perdas de participantes,
  sede, Nódulos, mana ou silêncio interrompem. Todos recebem o aviso da sede.

Saves anteriores mantêm suas condições de vitória legadas. Eliminação completa
do jogador humano encerra sua campanha mesmo quando ainda há vários rivais.

## IA e persistência

A IA combina infraestrutura mundana com especialização mágica, reúne ritualistas,
protege conjuradores, usa feitiços e reage a rituais públicos perigosos. Pode
concluir Grandes Rituais e vencer por Transcendência sem receber recursos extras
do harness. Recrutamento considera tamanho do império; preparação para o Dragão
tem reserva militar maior e preserva projetos militares em andamento.

Save v21 aceita v17–20 com migrações explícitas. Persiste IDs de unidades,
recargas, vínculos, silêncio, regiões, terreno anterior, rituais, participantes,
histórico, guerras, tréguas, rotas, ordens e estado exato do RNG de cada IA.
Carregar não avança a canalização nem paga novamente recompensas do Dragão.
Arquivos estruturalmente inválidos são rejeitados antes de reconstruir a partida.

## Limites de avaliação

Testes de regressão cobrem regras e integração; simulações medem comportamento
das IAs. A duração humana de 3–4 horas, dificuldade por raça e equilíbrio entre
as três vitórias ainda exigem partidas humanas completas. Os conjuradores usam
um modelo base comum com identificação por escola; maior variedade artística
pode ser adicionada sem alterar as regras.
