# Efeitos da Escola Sagrada

> Histórico da primeira implementação. A versão atual usa fluxos suaves,
> proteção translúcida e emissão dos focos: [revisão visual](natural_spell_vfx.md).

Integrados à conjuração real de jogador e IA. Humanos, elfos, orcs e anões
compartilham os efeitos; cada cajado usa o ponto de foco do próprio modelo.
O Serafim usa o osso do núcleo. Os modelos, clipes e regras existentes são preservados.

| Magia | Regra existente | Apresentação |
| --- | --- | --- |
| Luz Restauradora | Cura 8, limitada à vida máxima | Carga no corpo/cajado, trajeto de pequenos cubos dourados, selo breve, brilho que sobe pelo corpo e partículas de restauração |
| Égide Sagrada | +35% de defesa, até o próximo turno do dono, incluindo a fase inimiga | Conjuração dourada, símbolo de escudo e três pequenos escudos persistentes; desaparecem com expiração, dissipação ou morte |
| Onda de Cura | Cura 6 nos aliados próprios num raio de 1 hexágono | Selos segmentados nos sete hexágonos, abrindo do centro para as bordas; só unidades efetivamente curadas recebem a reação corporal |
| Milagre | Restaura a vida de um alvo vivo, respeitando modificadores de cura | Sol maior, coluna de segmentos dourados e partículas mais densas; não representa ressurreição |

## Direção visual

Cubos pequenos, símbolos com degraus, contornos de hexágonos abertos e faixas
discretas de luz sobre o corpo. Marfim e ouro identificam a escola; turquesa
suave identifica a concentração de mana e a restauração. Nada de fumaça realista,
discos opacos ou alterações físicas nos personagens. O brilho do cajado acompanha
o osso animado, com liberação em 1,1 s e chegada em 1,48 s. A apresentação dura
aproximadamente 3,13 s, acompanhando o clipe de conjuração existente.

## Integração e duração

`V2MagicRuntime.cast` continua resolvendo cura, mana, ação e recarga imediatamente.
Depois disso, `SpellVFX` escolhe a apresentação da escola. As seis escolas têm
VFX registrado (ver `school_spell_vfx.md`). O valor flutuante da cura usa o ganho real de vida e aparece
na chegada do efeito. Sem cena visual ou quando o limite de efeitos é atingido,
o feedback de cura tem um caminho de fallback.

`SacredAegisFX` deriva sua existência de `magic_status`, sem estado novo no save.
O refresh existente reconstrói a proteção após carregamento ou troca de forma.
Outros estados e técnicas mantêm seus marcadores anteriores.

As reações usam overlays temporários por instância: não modificam os materiais
compartilhados, os ossos nem a posição da unidade. O flash de dano tem prioridade.
Referências fracas e limpeza ao sair da árvore evitam resíduos quando uma unidade
é removida durante a animação.

## Visibilidade e custo

- Névoa de guerra é consultada durante o efeito. A conjuração oculta não revela
  o mago ou o trajeto; selos não aparecem em hexágonos fora da visão.
- No máximo 12 conjurações simultâneas por mapa; a regra do feitiço funciona mesmo
  quando esse limite visual é atingido.
- Partículas GPU em forma de cubo, quantidades limitadas e sem sombras dinâmicas.
- Movimento reduzido diminui partículas, remove flutuação e a pulsação do foco.
- Desativar iluminação de criaturas remove a luz temporária, mantendo a leitura
  dos símbolos e partículas.
- Focos das quatro raças estão embutidos em um script preloaded, funcionando
  também em builds exportados sem depender de filtros de arquivos JSON.

## Verificação

`test_sacred_vfx.gd` cobre conjuração real, alvo inválido, cura em área, valor efetivo,
proteção durante a fase inimiga, restauração de marcador, dissipação, morte,
névoa, limpeza de overlays, remoção de participantes, limite e acessibilidade.
As suites sagradas existentes e os testes de duração também são executados.

Resultado: **58/58 testes sagrados/VFX/duração (519 asserções)** e **103/103 testes
de modelos e compatibilidade com as outras escolas (1.642 asserções)**.
Após o ajuste dos selos ao relevo, os **9/9 testes de VFX** foram reexecutados com
**78 asserções**, incluindo a orientação das seis bordas do hexágono.
As suites antigas ainda registram avisos de objetos/recursos pendentes no encerramento
do GUT; não houve falha de asserção. A revisão nativa termina com código 0 e
`docs/previews/sacred_vfx/validation.json` registra `PASS`, incluindo as quatro raças,
o Serafim e a apresentação noturna com movimento reduzido.

Prévia nativa: `tools/art_pipeline/review_sacred_vfx.gd`. Usa o mapa e os modelos
reais e lança as quatro magias pelo runtime. Para gravar com tempo determinístico:

```powershell
& $godot --path . --script tools/art_pipeline/review_sacred_vfx.gd --windowed --resolution 1280x900 --fixed-fps 30
ffmpeg -y -framerate 30 -i art_source/sacred_vfx_review/frames/%05d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart docs/previews/sacred_vfx/sacred_spells.mp4
```

Regerar os focos, sem modificar os modelos:

```powershell
& $blender --background --python tools/art_pipeline/inspect_sacred_focus.py
python tools/art_pipeline/build_sacred_focus_profiles.py
```

A inspeção lê o UV do cristal no `.blend`, encontra os seus 24 vértices no GLB
e calcula o centro em coordenadas do osso `hand_r` exportado. O arquivo
`assets/vfx/sacred/focus_profiles.json` é o registro de auditoria; o script
`scripts/vfx/SacredFocusProfiles.gd` é a fonte usada em jogo.
