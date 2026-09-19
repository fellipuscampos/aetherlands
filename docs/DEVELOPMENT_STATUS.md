# Aetherlands — estado do desenvolvimento

Atualizado em **17/09/2026**. Sistemas centrais integrados e regressão aprovada.
Duração humana e balanceamento final ainda não certificados.

## Implementação

- **Pesquisa:** 55 descobertas mundanas e 55 mágicas; efeitos reais de General,
  Engenheiro, Mercador e Posto Avançado; requisitos e progresso por projeto.
- **Magia V1:** seis escolas, conjuradores, recargas individuais, invocações
  vinculadas, manutenção, silêncio, ocultação, portais e terreno temporário.
- **Grimório:** requisitos, custos, seis Grandes Rituais, canalização,
  interrupção e resultados. Lich e Arquidemônio agem de forma autônoma.
- **Cidades:** trabalho de terrenos próprios além do primeiro anel; melhorias
  reutilizam espaço; recrutamento aguarda posição livre; estruturas mágicas
  aparecem no mapa e contam na especialização arcana.
- **Combate:** suportes, armas contra cavalaria/blindagem e cerco; efeitos em
  área respeitam terceiros em paz.
- **IA:** elenco completo, expansão por recursos conhecidos, caminhos válidos,
  especialização, suportes, magia, rituais e reação a ameaças. Recrutamento
  considera força disponível; a preparação contra o Dragão usa reserva maior.
  Ouro pode acelerar produção.
- **Diplomacia:** guerras, paz e comércio entre todos, razões visíveis,
  cansaço e trégua de dez turnos.
- **Dragão:** recompensa proporcional por dano de participantes elegíveis,
  sem prêmio exclusivo pelo último golpe; pagamento persistido e único.
- **Vitória:** Dominação, Supremacia Militar e Transcendência em partidas novas;
  progresso, avisos e interrupção. Saves antigos preservam regras legadas.
- **Save v21:** migração v17–20, escrita temporária, validação antes de
  reconstrução, diplomacia/comércio, terreno, ordens, cerco, pesquisa,
  magia/rituais, vínculos e RNG individual das IAs.
- **Apresentação:** árvore por escolas, Grimório rolável, efeitos no mapa,
  edifícios por escola e modelos Asset Factory. Árvores e recursos acompanham
  transformações locais de terreno.
- **Limpeza:** ciclos entre jogadores e fixtures que não liberavam mapas,
  unidades e painéis corrigidos. Saída do aplicativo agora libera os playbacks
  de áudio antes de encerrar, inclusive ao sair durante vitória ou pausa.

Regras: [MAGIC_IMPLEMENTATION.md](MAGIC_IMPLEMENTATION.md).
`MAGIC_SYSTEM_V1.md` foi lido somente na entrada da etapa de magia e preservado.

## Validação

### Regressão final

**1.330 testes, 331.624 verificações, 48 scripts: todos passaram**, em 255,673 s.
Sem erros de script, órfãos no resumo final ou avisos de ObjectDB/recursos ao
encerrar. Há 16 avisos do harness/fixtures, incluindo comparações float/int e tipos
de evento desconhecidos em testes de compatibilidade; não foram suprimidos. Contagens transitórias
antes de processar `queue_free` não equivalem ao resumo final.

Baseline: 1.295 testes, 331.176 verificações, 714 órfãos no resumo e avisos de
recursos ao sair. Não é comparação de desempenho: a suíte e a carga de CPU mudaram.

Regressões novas cobrem feitiços, terceiros em paz, invocações, recargas, silêncio,
terreno, rituais/interrupções, save no meio da canalização, Transcendência,
conquistas desenvolvidas, RNG/tréguas, payloads inválidos e recompensa após JSON.

### Campanhas naturais

`test/integration/test_campaign_v21.gd` usa o loop real, sem conceder pesquisas ou
recursos. O lugar do humano também é conduzido pela IA. A campanha para ao ocorrer
vitória ou eliminação completa desse jogador.

Execução final após limitar a preparação militar do Dragão, corrigir o
encerramento de áudio e alinhar a configuração do harness à geração real:

| Seed | Mapa | Turno final | Resultado | Primeira guerra | Maior turno CPU |
|---|---|---:|---|---:|---:|
| 4242 | 320×84 | 101 | Limite de 100 turnos, sem encerramento | 33 | 1.903 ms |
| 1709 | 61×61 | 53 | Humano eliminado | 22 | 137 ms |
| 2718 | 61×61 | 135 | Anão: Transcendência | 22 | 2.408 ms |
| 3141 | 61×61 | 214 | Humano: Transcendência | 22 | 11.434 ms |

**Dois testes de integração, quatro campanhas, 1.996 verificações: todos passaram.**
Executados em dois processos: mapa 320×84 com 400 verificações em 33,666 s;
três mapas 61×61 com 1.596 verificações em 419,486 s. Ambos encerraram com
exit 0, sem erros de script, avisos de ObjectDB ou recursos restantes.

A execução anterior de quatro campanhas passou com 1.924 verificações. A seed
3141 revelou quatro instâncias/dois recursos restantes: eram o playback e os
recursos de `victory.ogg`, reproduzidos sem mapa. A saída foi corrigida com
parada dos players e tempo real para o mixer liberar o playback. O reprodutor
`tools/verify_audio_shutdown.gd` passou com exit 0 e sem vazamentos.

O harness também passou a aplicar tamanho do mapa e número de rivais antes
de gerar covis, como o jogo real já fazia. Todas as linhas acima foram repetidas
com essa configuração. O pior turno da seed 3141 permanece acima do desejável;
os tempos de CPU incluem concorrência com outras verificações e não isolam
o custo de cada sistema.

Na seed 2718, o vencedor concluiu dois Grandes Rituais e controlava oito Nódulos.
Na 4242, elfos concluíram dois rituais e anões um. A limitação antiga de expansão/alcance
até Nódulos deixou de ser um bloqueio estrutural; sobrevivência varia muito por seed.

Uma execução anterior passou com 1.720 verificações e vitórias naturais de anões
e orcs por Transcendência. Revelou produção militar excessiva no caminho especial
do Dragão, corrigida antes da repetição final.

### Conferência visual

Executável não headless, Vulkan Forward+, RTX 3060. Árvore de escolas, mapa,
conjuradores, bosses e regiões conferidos. O primeiro exame detectou Grimório
fora da tela; corrigido com rolagem. Conferência posterior: painel cabe no
viewport 1920×1017, conteúdo rolável de 2.216 px e seis estruturas rituais visíveis.

Alturas medidas: conjurador 1,960 (inclui cajado), Lich 2,328, Arquidemônio 3,059.
Personagens Asset Factory usam escala 1. Cenas/scripts temporários foram removidos;
a ausência foi confirmada no Git.

Diagnóstico adicional em processos separados: duas instâncias de cada uma das
47 unidades treináveis e seis invocações, incluindo dano/descarte, e os 43
edifícios foram criados/liberados sem vazamentos. Esse teste isolou o aviso da
campanha como playback de áudio, sem atribuí-lo aos novos modelos.

### Reprodução

Defina `$godot` com o caminho do executável Godot 4.7.1 e rode na raiz do projeto:

```powershell
& $godot --headless --path . --import --quit
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
& $godot --headless --path . -s addons/gut/gut_cmdln.gd '-gconfig=' '-gtest=res://test/integration/test_campaign_v21.gd' -gexit
& $godot --headless --verbose --path . -s tools/verify_audio_shutdown.gd
```

Logs em `%TEMP%`: `aetherlands_final_units_audio.log`, `aetherlands_final_real_map.log`,
`aetherlands_final_campaigns_audio.log`, `aetherlands_audio_shutdown_verified.log`
e `aetherlands_visual_final.log`. Capturas: `aetherlands_grimoire_final.png` e
`aetherlands_structures_final.png`. Ver também [PERFORMANCE_GUIDE.md](PERFORMANCE_GUIDE.md).

## Limites e próxima avaliação

1. **Duração de 3–4 horas:** depende de partida humana completa. Tempo de CPU e
   número de turnos não substituem essa medição.
2. **Balanceamento:** quatro seeds não certificam paridade entre raças/estratégias
   ou frequência adequada das três vitórias. Supremacia tem regressão lógica,
   mas ainda não vitória natural observada neste conjunto final.
3. **Experiência:** dificuldade, clareza ao longo da campanha e diversão precisam
   de playtest humano; a conferência visual não foi uma campanha manual completa.
4. **Arte:** conjuradores compartilham modelo base e identificação por escola;
   estruturas usam formas existentes com elementos mágicos próprios.
5. **Escopo:** single-player contra IA; multiplayer continua visão futura.

## Workspace

Trabalho anterior preservado. Baseline: master 32 commits à frente do remoto
conhecido, 96 entradas modificadas/novas. Nenhum reset, descarte em bloco, commit
ou publicação. `git diff --check` passou; avisos de CRLF/LF não são erros de whitespace.

**Conclusão técnica:** integração funcional avançou e a regressão passou.
Não declarar o produto finalizado ou o pacing validado antes do playtest humano.
