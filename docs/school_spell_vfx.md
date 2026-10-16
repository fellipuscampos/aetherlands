# Efeitos das seis escolas

> Histórico da primeira implementação. A apresentação atual substitui os cubos
> e símbolos por efeitos suaves e emissão dos focos: [revisão visual](natural_spell_vfx.md).

As 24 magias de `V2SpellDatabase` têm VFX registrado, pelo mesmo caminho de
conjuração para jogador e IA. A Sagrada mantém a apresentação anterior;
as cinco escolas restantes acrescentam os seguintes efeitos:

| Escola | Magias e apresentação |
| --- | --- |
| Infernal | Chama Infernal: projétil em brasa e impacto. Fogo Voraz: chamas ascendentes. Explosão Infernal: expansão pelos hexágonos e erupções nos inimigos atingidos. Condenação: fragmento incandescente descendente, pilares e selo concentrado. |
| Necromancia | Erguer Mortos: almas, ossos e brilho na unidade invocada. Recompor Ossos: reação no corpo e cura efetiva. Comando Macabro: lâminas espectrais enquanto o bônus estiver ativo. Erguer Legião: invocação mais densa na formação real. |
| Druidismo | Brotar Bosque: crescimento das árvores reais. Restaurar Terreno: dispersão de folhas. Erguer Terreno: fragmentos de terra subindo. Despertar a Mata: crescimento em sequência somente nos hexágonos efetivamente alterados. |
| Arcanismo | Passo Arcano: partida e chegada. Silêncio: glifo interrompido e marcador persistente. Dissipar: fragmentação da runa e reação no corpo afetado. Portal do Véu: dois portais octogonais persistentes e feedback na travessia. |
| Elementalismo | Névoa Cerrada: blocos translúcidos. Vendaval: trilhas de vento. Tempestade Elétrica: nuvens em blocos e raios no tick de dano. Cataclismo Elemental: quatro cores elementais, expansão até raio 2 e reação na rodada. |

Cada escola usa cores, símbolos e movimentos próprios, com pequenos cubos,
formas em degraus e linhas geométricas. Não há fumaça fotográfica, discos opacos
ou deformação dos personagens.

## Integração

`SpellVFX` registra as seis escolas. `SchoolCastFX` fornece concentração de mana,
brilho no foco e no corpo, trajeto, visibilidade e limpeza para as cinco novas.
Cada subclasse compõe os movimentos e formas da escola.

As regras continuam resolvendo imediatamente. Registros visuais capturam
coordenadas, referências fracas e ganhos/perdas reais de vida. Um golpe letal
ainda deixa impacto no tile depois que o modelo morre. O Passo Arcano guarda
a partida antes do teleporte. Terrenos e zonas recebem apenas os hexágonos
realmente alterados, sem representar áreas preexistentes como novas.

Modelos e clipes não foram editados. A inspeção dos `.blend` e GLBs calculou
os focos dos vinte cajados nas coordenadas do osso `hand_r`. Os dados estão
embutidos em `SchoolFocusProfiles.gd`, incluindo builds exportados.
Grandes manifestações usam o próprio osso do núcleo/foco.

## Persistência

- Comando Macabro e Silêncio derivam de `magic_status`: expiração, dissipação,
  morte, troca de forma e reconstrução após carregamento.
- Portais seguem os pares de `V2PortalSystem`. Substituir ou fechar um par remove
  seus visuais; a travessia preserva custos e destino.
- A atmosfera elemental segue as zonas canônicas e suas rodadas reais, incluindo
  carregamento e dissipação. Cada campo usa oito blocos em `MultiMesh`.
- Tempestade e Cataclismo emitem a reação de dano somente quando o tick realmente
  reduz vida. Criar uma zona não produz um falso ataque imediato.
- O crescimento altera somente a escala do novo marcador de terreno. A escala
  volta ao normal ao terminar ou interromper a apresentação.
- Overlays respeitam o flash de dano e não alteram materiais compartilhados,
  posições lógicas, ossos ou atributos.

## Visibilidade e acessibilidade

Conjuradores, trajetos e hexágonos ocultos não são revelados pelos efeitos.
Marcadores persistentes seguem a névoa atual. Existe um limite compartilhado
de 12 apresentações transitórias por mapa, incluindo conjurações, travessias
e impactos ambientais; a regra funciona mesmo ao atingir esse limite visual.

Partículas GPU são limitadas e não projetam sombras. Campos fora da visão
interrompem sua atualização. Movimento reduzido diminui emissões e mantém
estáveis os blocos ambientais. Desativar iluminação de criaturas também
desativa a luz temporária de conjuração.

## Validação

Passaram **174 testes e 2.377 asserções**, cobrindo as seis escolas, modelos,
duração e integração de VFX. Os testes novos verificam golpes letais,
invocação, cura efetiva, crescimento, áreas parcialmente elegíveis, partida
do teleporte, Silêncio/Dissipar, save/load de portais e zonas, dano na rodada,
névoa, acessibilidade, focos das quatro raças e das manifestações restantes.
Suites antigas ainda podem registrar objetos/recursos pendentes ao fechar
o GUT; não houve falha de asserção.

A revisão nativa conjura as vinte magias novas no mapa real e verifica custo,
criação e limpeza. Inclui o tick real de Tempestade/Cataclismo. O resultado
está em `docs/previews/school_vfx/validation.json`, com `PASS` e sem falhas.

```powershell
& $godot --path . --script tools/art_pipeline/review_school_vfx.gd --windowed --resolution 1120x840 --fixed-fps 30 -- --record
ffmpeg -y -framerate 30 -i art_source/school_vfx_review/frames/%05d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart docs/previews/school_vfx/school_spells.mp4
```

Sem `--record`, gera somente capturas. `--school=arcanism`, por exemplo,
permite revisar uma escola isolada. O vídeo reúne a última magia de cada
escola; as capturas individuais mostram carga, impacto e dano ambiental.

Recalcular os focos, sem editar os modelos:

```powershell
& $blender --background --python tools/art_pipeline/inspect_school_focus.py
python tools/art_pipeline/build_school_focus_profiles.py
```
