# Construtores e melhorias de recursos: estado e aplicação

Auditoria de 15/10/2026. Escopo: mapear o sistema e propor seu fechamento;
nenhum arquivo de gameplay, IA, balanceamento ou arte foi alterado nesta etapa.
Valores abaixo conferidos no código atual, pois há documentos históricos com
valores anteriores à rodada de balanceamento.

## 1. O que existe hoje

O núcleo já está implementado e funciona: pesquisa → Oficina → treino →
Construtor sobre o recurso → melhoria → rendimento da cidade → save/load.
A lacuna principal está na descoberta da mecânica, na representação das
melhorias e em regras de borda. Não é necessário criar outro sistema econômico.

| Parte | Implementação atual |
|---|---|
| Desbloqueio | Infraestrutura → Indústria → **Oficinas**, custo 16 Conhecimento. Libera Oficina e a possibilidade de treinar o Construtor. |
| Prédio de treino | A cidade precisa de uma **Oficina construída**: 24 PP, manutenção de 1 Ouro/turno. Só pesquisar não basta. |
| Treino | Produção → Unidades → Civis → Construtor. Custo 16 PP, sem Suprimentos. |
| Unidade | 8 Vida, Ataque 0, Defesa 1,5, Movimento 2, Visão 3. Tem arte própria e animação de trabalho para cada uma das quatro raças. |
| Cargas | 1/2/3 conforme o tier de Indústria no nascimento; humanos recebem +1. Pesquisa posterior não recarrega unidades existentes. |
| Trabalho | Precisa estar no próprio tile do recurso, em território de uma cidade do dono, com carga e movimento disponíveis. |
| Custo da melhoria | Instantânea, fora da fila da cidade; custa uma carga e todo o movimento restante. Sem custo adicional de Ouro/Mana/Suprimentos. |
| Última carga | A unidade é consumida, sem abate, XP ou evento de morte. |
| Armazenamento | `City.resource_improvements`: coordenada → ID da melhoria. Não ocupa slot de prédio. |
| Economia | `V2EconomyRuntime` soma o rendimento à cidade dona e faz a agregação global cabível. Não depende de cidadãos ou de tiles trabalhados V1. |
| Conquista | A melhoria acompanha a cidade e passa a usar a pesquisa do novo dono. |
| Pilhagem | Suspende seu rendimento pelo período de pilhagem; não exige gastar outra carga para restaurar o que o sistema já restaura ao expirar. |
| Persistência | Saves guardam melhorias e cargas. Rendimentos são derivados novamente na carga. |
| IA | Já decide treinar construtores e os move até recursos próprios conhecidos, usando o mesmo runtime de melhoria. |

### Rendimentos atuais

Valores-base por melhoria, nos tiers I / II / III. Multiplicadores raciais e
demais regras econômicas existentes continuam sendo aplicados pelo runtime.

| Recurso | Melhoria | Benefício | Linha que aumenta o rendimento |
|---|---|---|---|
| Ferro | Mina de Ferro | +2 / +3 / +4 Produção por turno, **local** | Indústria |
| Cavalos | Haras | +4 / +6 / +8 de **capacidade** de Suprimentos | Logística |
| Gemas | Mina de Gemas | +4 / +6 / +8 Ouro por turno | Economia |
| Seda | Entreposto de Seda | +2 / +3 / +4 Ouro e +1 / +2 / +3 Conhecimento por turno | Economia e Academia, separadamente |
| Nódulo Arcano | Conduíte Arcano | +2 / +3 / +4 Mana por turno | Arcano |

Produção acelera apenas a fila da cidade dona. Ouro, Mana e Conhecimento
entram nas contribuições dessa cidade ao total da civilização. Suprimentos
aumentam a capacidade para manter tropas; não são uma moeda acumulada por turno.
Os recursos brutos não concedem esses bônus automaticamente e não são requisitos
para treinar as linhas militares. Melhorias não concedem Vida/Ataque às tropas.

Um Construtor que chega gastando todo o movimento precisa esperar o próximo
turno para trabalhar. Esse bloqueio existe e deve ser comunicado claramente.

## 2. Evidência coletada

Rodada dos quatro arquivos de testes existentes: **44 testes, 43 passaram**;
**473 de 474 asserções passaram**. A falha é a expectativa de encontrar o
modelo KayKit da mina mais o selo: o modelo foi removido, restando um filho
no marcador. O fluxo principal de produção, economia e save/load passou.

Uma sonda headless isolada também consultou os presenters usados pela interface:

- Antes da pesquisa, `CityPresenter.unit_item` devolve vazio: o Construtor fica oculto.
- Após pesquisar, sem Oficina, aparece bloqueado com o requisito do prédio.
- Com Oficina, aparece disponível no grupo Civis.
- `UnitPresenter` oferece **Construir Mina de Ferro**, custo de uma carga, disponível.
- Humano no tier I nasceu na fixture com duas cargas, conforme o runtime normal.
- A melhoria mudou a Produção da cidade de **7 para 9**, consumiu uma carga e
  zerou o movimento. O registro da cidade e o breakdown econômico receberam a mina.
- Os quatro modelos raciais de Construtor existem. Os cinco modelos declarados
  para as melhorias não existem.

A sonda usou uma cidade e um spawn de teste; a atribuição normal das cargas
na produção foi verificada no código e pelo teste principal existente.
Resultados: [builder_system_audit_20261015.json](balance/builder_system_audit_20261015.json).
Cena/script da sonda removidos após a execução.

## 3. Lacunas confirmadas

### Descoberta e comunicação

1. A descrição de **Oficinas** ainda diz que habilitará construtores numa
   “próxima etapa econômica”, embora já os libere. Engenharia/Manufatura
   também não explicam suas cargas e o efeito sobre minas de ferro.
2. O Construtor desaparece inteiramente do catálogo antes da pesquisa.
   A pessoa não encontra uma opção bloqueada explicando como desbloqueá-lo.
3. O recurso bruto informa que precisa de Construtor, mas falta um caminho
   contextual até pesquisa, Oficina ou treino, conforme o estágio atual.
4. O botão de trabalho explica a carga, mas não apresenta o ganho real da
   cidade nem o consumo da última carga de forma suficientemente direta.
5. `improve_resource_with_selected` limpa a seleção mesmo quando ainda restam
   cargas. Isso dificulta perceber que a mesma unidade continua disponível.

### Representação visual

`V2ResourceImprovementData` aponta para cinco cenas KayKit removidas. O código
trata a ausência sem crash e desenha só um pequeno selo dourado. O resultado
econômico existe, mas não se parece com uma mina, haras ou instalação arcana.
A referência antiga a Rogue em `UnitDatabase` não é o visual normal atual:
`UnitArtCatalog` já substitui esse caminho pelos quatro construtores raciais.

### Regras de borda

- O Construtor tem `can_basic_attack = true`, herdado do padrão de `UnitData`.
  Ataque 0 não o torna pacífico: o combate usa essa flag para permitir ataques
  e um piso de dano. Deve declarar explicitamente ausência de ataque básico.
- O predicado de melhoria só bloqueia prédio concluído. Não bloqueia covil
  ou canteiro em andamento. A sonda confirmou resposta permissiva nesses
  estados artificiais; não demonstrou que todos são alcançáveis por cliques
  normais. Ainda assim, falta uma validação central para evitar conflitos
  quando outro caminho, carregamento ou evento produzir esse estado.
- Fundar cidade sobre recurso preserva o recurso lógico. O predicado permite
  melhorá-lo e o marcador atual tentaria colocar outra instalação junto à
  cidade. Esse caso precisa de uma representação deliberada.

## 4. Como recomendo que funcione

Manter o ciclo existente, apropriado a uma partida compacta de 4X:

1. Pesquisar Oficinas, construir uma Oficina e treinar o Construtor.
2. Anexar o recurso à cidade que se quer beneficiar, caso esteja fora do território.
3. Levar o Construtor até ele, protegendo a unidade civil.
4. Mostrar a melhoria correspondente, o ganho da cidade, a carga consumida
   e se a unidade será consumida. Executar com uma ação.
5. Exibir imediatamente o novo rendimento no breakdown da cidade e mostrar
   a instalação no mapa. O crédito efetivo segue o processamento normal de turnos.

Preservar cargas, custos e rendimentos atuais inicialmente. Não acrescentar
espera de vários turnos, manutenção, materiais extras ou uma segunda fila de
produção antes de medir o ciclo existente: já há pesquisa, prédio de treino,
produção da unidade, deslocamento e exposição a monstros como custos.

Para ocupação: uma melhoria por recurso; não construir sob covil nem canteiro.
Prédio comum continua usando a regra atual de destruir o recurso, com aviso.
Para recurso sob centro urbano, recomendo preservar seu aproveitamento com
uma carga e rendimento normal, mas representá-lo no painel/visual da cidade,
sem instanciar um segundo prédio sobre ela. Não conceder extração gratuita.

Quando restarem cargas, manter o Construtor selecionado e atualizar o botão.
Na última, focar o recurso melhorado e informar o ganho e o consumo da unidade.
Separar **Bruto**, **Melhorado** e **Saqueado**, como o painel de território
já começa a fazer. Não apresentar benefício potencial como renda já ativa.

## 5. Ordem de aplicação

### A. Fechar regras e acesso

- `V2ConstructorRuntime`: centralizar elegibilidade de recurso/território/
  estruturas, incluindo canteiros e covis. Compartilhar a consulta de alvo
  elegível com a IA, sem duplicar regras.
- `UnitDatabase`: desabilitar explicitamente ataque básico do Construtor;
  preservar Vida, Defesa, custo e demais valores balanceados.
- `V2InfrastructureContent`: corrigir as descrições de Oficinas, Engenharia e
  Manufatura com as regras reais de treino, cargas e eficiência.
- `CityPresenter`: oferecer o caminho de desbloqueio do civil mesmo antes da
  pesquisa, por item explicativo bloqueado ou orientação contextual.
- `CityContextPanel`/inspetor: orientar por estágio: pesquisar → construir
  Oficina → treinar Construtor → anexar → deslocar → melhorar.

### B. Dar retorno claro e representação própria

- `UnitPresenter`: preview centralizado na economia, com benefício efetivo da
  cidade, cargas antes/depois, necessidade de movimento e aviso da última carga.
- `SelectionManager`: preservar seleção de quem ainda tem cargas e tratar o
  consumo sem referência inválida ou queda inadvertida para o chão.
- Economia/interface: emitir a atualização existente de estado quando a
  melhoria for confirmada; evitar depender apenas da notificação textual.
- Criar cinco instalações de extração adequadas aos recursos e à estética
  blocky atual; começar com modelos compartilhados entre raças, mantendo a
  identificação do dono. A unidade construtora já tem identidade racial.
- `V2ResourceImprovementData`/`HexGrid`: conectar cenas existentes de verdade,
  tratar o centro urbano sem sobreposição e preservar a leitura do recurso.
  O selo pode complementar a instalação. Não deve ser sua única representação.
- Sincronizar a confirmação visual com a animação de trabalho pela camada de
  apresentação; manter a lógica instantânea, sem nova simulação de obra.

### C. Validar integração e só então reconsiderar números

- Caminho real da interface: pesquisa, produção da Oficina, treino, deslocamento,
  clique de trabalho e aumento dos cinco rendimentos, nas quatro raças.
- Cargas fixadas ao nascer; última carga; chegada sem movimento; dois
  construtores disputando o mesmo recurso; canteiro/covil; centro urbano.
- Captura, pilhagem, cancelamento, destruição do recurso por prédio e save/load.
- Testes de arte devem verificar o catálogo atual e modelos legíveis, substituindo
  a expectativa histórica de dois filhos KayKit por uma garantia real de apresentação.
- IA utiliza a mesma validação e não insiste em recursos ocupados ou já melhorados.
- Depois, medir tempo até a primeira melhoria e uso real das cargas. Aumentar
  ou reduzir rendimentos agora confundiria defeito de descoberta com balanceamento.

## 6. Desempenho e pontos de integração

Reaproveitar as fontes existentes:

| Responsabilidade | Arquivo |
|---|---|
| Unidade e treino | `scripts/data/UnitDatabase.gd`, `scripts/data/BuildingDatabase.gd`, `scripts/city/City.gd` |
| Pesquisa e tiers | `scripts/data/V2InfrastructureContent.gd`, `scripts/core/V2EconomyRuntime.gd` |
| Validação e ação | `scripts/core/V2ConstructorRuntime.gd` |
| Catálogo dos cinco efeitos | `scripts/data/V2ResourceImprovementData.gd` |
| Interface da cidade/unidade | `scripts/ui/presenters/CityPresenter.gd`, `scripts/ui/presenters/UnitPresenter.gd` e painéis de contexto |
| Seleção e clique | `scripts/autoload/SelectionManager.gd` |
| Arte racial do Construtor | `scripts/data/UnitArtCatalog.gd` |
| Marcadores e ocupação | `scripts/world/HexGrid.gd` |
| Persistência | `scripts/autoload/SaveManager.gd` |
| Decisão e trabalho da IA | `scripts/core/V2StrategicAI.gd`, `scripts/core/V2AITacticalAI.gd` |

Continuar consultando apenas melhorias das cidades e índices de coordenada.
Sem varrer o mapa por quadro, sem `_process` por Construtor, sem nova moeda ou
estado econômico derivado salvo. Criar/alterar visuais por evento e limpar
props apenas no tile afetado, respeitando o foco visual e a névoa existentes.
Reutilizar modelos/materiais e animações fora de tela pausadas. Não acrescentar
cache econômico com invalidação complexa antes de demonstrar um gargalo.
