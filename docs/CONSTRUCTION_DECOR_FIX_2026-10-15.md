# Props sobre os canteiros — 15/10/2026

O prédio concluído já passava por `_clear_tile_decor_at`, mas a criação do
canteiro em `refresh_construction_markers` não fazia essa limpeza. A composição
de natureza impedia novas plantas sobre obras existentes, porém não removia
as instâncias desenhadas antes delas.

A criação do canteiro agora limpa o próprio tile pela rotina central, antes
de instanciar o modelo. Vale para as quatro raças e obras restauradas de saves.
Atualizações de progresso reutilizam o canteiro e não repetem essa limpeza.
Os props dos tiles vizinhos e seus MultiMeshes permanecem intactos.

Também corrigida a ordem em `destroy_resource_at`: libera primeiro os props
guardados pelo foco visual, depois remove suas instâncias e índices. Isso
evita que a saída do foco/restauração de transparência recoloque o recurso
destruído dentro da obra. A regra existente de destruir o recurso ao iniciar
a construção foi preservada.

Sem reconstrução global adicional, polling, timers ou trabalho novo por quadro.
A limpeza usa os índices por coordenada e altera somente as instâncias do tile.

Validação:

- Seis regressões novas em `test_construction_decor.gd`; antes da correção,
  as três regressões iniciais relevantes falharam, incluindo todas as raças.
- **71 testes / 14.857 asserções passaram** na rodada final: decoração de obras,
  modelos dos canteiros, aviso/destruição de recursos, conclusão no turno real,
  composição da natureza e foco visual V3. Execução final encerrou sem avisos
  de recursos em uso ou vazamentos.
- Uma execução gráfica com HexGrid real e os quatro modelos; comparação antes/
  depois em `docs/previews/construction_decor_20261015/`. Além das capturas,
  validou as transformações reais das instâncias do MultiMesh zeradas após
  limpar o tile e após sair da inspeção do recurso. `validation.json`: PASS.
  A imagem anterior reproduz o caminho antigo de criação, sem restaurar código.
- Cena e script descartáveis removidos após a execução; status conferido.
