# Nuvens das tempestades elementais — 15/10/2026

Os sete volumes arredondados repetidos sobre cada tile pareciam balões presos às tropas. A posição também
mudava com a altura do ocupante, reforçando esse aspecto. A Tempestade Elétrica e o Cataclismo agora usam
cinco volumes angulares rasos, com opacidade baixa e variação determinística por coordenada. A altura fica
ancorada no campo, entre 3,80 e 3,98 unidades acima do tile, e não acompanha quem entra ou sai.

Chuva e relâmpagos continuam localizados na área mágica. A névoa, as rajadas de vento e os demais efeitos
continuam usando suas apresentações existentes; o novo shader só é usado nas nuvens de tempestade.
O clima geral continua sem criar nuvens sobre tropas. Não houve mudanças em regras, dano, custos ou duração.

## Custo e validação

- Uma submissão MultiMesh por tile, como antes. Geometria medida: **2.016 → 60 triângulos**, redução de 97%.
- Chuva: **36 → 24 partículas**; com movimento reduzido, **18 → 12**. Sem sombras ou novos loops/timers.
- O shader novo não deforma a malha por tempo. A altura e o tempo de vida da chuva são calculados na criação,
  retirando a consulta ao ocupante e os reajustes de posição/lifetime de cada frame.
- A geometria menor não foi convertida em alegação de FPS; não foi feito benchmark isolado da GPU.
- **69/69 testes, 28.291 asserções**, saída 0: VFX de escolas, VFX sagrado, Elementalismo, chuva e neve.
  O teste novo confirma que a nuvem e o emissor não mudam quando entra/sai uma manifestação grande.
- Comparação gráfica com o modelo anterior e o novo no mesmo mapa real, Vulkan/RTX 3060, 1600×900.
  Conferidos campo de sete tiles, ocupante grande e Cataclismo de 19 tiles. Movimento reduzido estava ativo.

[Comparação antes/depois](previews/elemental_clouds_20261015/01_comparison.png),
[Tempestade em detalhe](previews/elemental_clouds_20261015/02_storm_close.png),
[manifestação grande](previews/elemental_clouds_20261015/03_tall_unit.png),
[Cataclismo](previews/elemental_clouds_20261015/04_cataclysm.png),
[contagens e alturas medidas](previews/elemental_clouds_20261015/validation.json).

Cena comparativa e cópia descartável do visual antigo removidas; ausência confirmada por `git status`.
Cópias anteriores e logs: `%TEMP%/aetherlands_elemental_clouds_20261015/`.
