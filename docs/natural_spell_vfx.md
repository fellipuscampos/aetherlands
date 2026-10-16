# Revisão visual das 24 magias — 14/10/2026

As seis escolas usam formas orgânicas, partículas suaves e iluminação dos
próprios focos. Esta revisão substitui a apresentação de cubos e símbolos 3D.

| Escola | Apresentação |
| --- | --- |
| Sagrada | Fluxos luminosos, restauração ascendente, faixas suaves no Milagre e proteção translúcida na Égide. |
| Infernal | Chamas com ruído animado, línguas de fogo ascendentes e erupções nos alvos reais. |
| Necromancia | Almas em espiral, partículas espectrais, ossos e reação na formação invocada ou restaurada. |
| Druidismo | Folhas suaves, fragmentos irregulares de terra e crescimento da vegetação real. |
| Arcanismo | Rastros de energia, dissipação espectral e portais elípticos com superfície fluida. |
| Elementalismo | Névoa baixa, vento curvo, nuvens elevadas com chuva e descargas ramificadas. |

`NaturalVFX` reúne sprites com shaders procedurais, partículas GPU, nuvens em
MultiMesh e faixas contínuas. `LightningArcFX` recompõe o canal branco, halo e
ramificações das descargas. Os impactos corporais da tempestade acontecem
quando a rodada realmente causa dano; pequenos arcos atmosféricos são cosméticos.

`FocusGlowFX` não acrescenta geometria visível ao cajado. Uma cópia temporária
do material recebe emissão nas seis ilhas UV da ponta existente, calculadas
para os 24 modelos das quatro raças. Grandes manifestações usam o mapa de
emissão original ou a proximidade do foco. A luz acompanha o osso animado pelo
`WorldGlow`, responde à escuridão e respeita a opção de iluminação de criaturas.
Conjurações simultâneas compartilham o controlador; a última restaura os
overrides anteriores sem editar materiais importados compartilhados.

A chuva comum forma nuvens acima de unidades visíveis: no máximo 12 bancos
próximos da câmera, sete lóbulos por banco em uma chamada de desenho.
Parar o clima limpa os bancos; esconder uma unidade esconde sua nuvem.
Chuva e neve continuam cosméticas e fora do save.

## Integração e limites

Custos, vida, ação, recargas, terrenos, status e portais mantêm suas regras.
Modelos e animações existentes são preservados. O limite compartilhado continua
em 12 apresentações transitórias por mapa. Campos ocultos interrompem sua
atualização visível. Movimento reduzido diminui partículas e elimina a
recomposição rápida dos raios. Desligar as luzes mantém a emissão dos materiais.

## Conferência

A revisão nativa executou as 24 magias no mapa real, conferindo custos, criação
e limpeza. Tempestade e Cataclismo passaram pelo dano real da rodada. Capturas,
vídeo e resultados estão em `docs/previews/natural_vfx/`. Ferramenta:
`tools/art_pipeline/review_school_vfx.gd`, com `--record`, `--school=...` ou `--ambient`.

Passaram 211 testes e 30.452 asserções de magias, modelos, iluminação e clima.
Os novos testes verificam emissão sem geometria adicional, isolamento de
materiais, conjurações sobrepostas, luz dia/noite, névoa, ciclo das nuvens
e preservação do fade durante a recomposição dos raios.
A seed privada de um teste climático foi fixada para exercitar chuva em toda execução.
Suítes antigas ainda registram recursos pendentes no encerramento headless.
Uma verificação adicional em `test_core_glow.gd` encontrou duas expectativas
antigas de texto da tela de configurações; esses rótulos não foram alterados.
