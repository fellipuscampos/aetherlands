# Terrenos em pixel art — v1

15 materiais originais gerados com a ferramenta integrada `image_gen`, organizados em 14 superfícies de chão e um detalhe de água. O jogo usa 25 tipos de terreno: 21 terrestres e quatro líquidos. Biomas da mesma família compartilham a superfície, com sua tintura e seus efeitos específicos.

| Material | PNG | Uso |
| --- | --- | --- |
| Grama temperada | `grass_albedo.png` | Pradaria |
| Capim seco | `dry_grass_albedo.png` | Planície, Savana |
| Chão de floresta | `forest_floor_albedo.png` | Floresta, Taiga, Selva |
| Tundra | `tundra_albedo.png` | Tundra |
| Terra e colinas | `dirt_albedo.png` | Colinas |
| Neve | `snow_albedo.png` | Neve, Cobertura de picos |
| Gelo | `ice_albedo.png` | Gelo eterno |
| Areia | `sand_albedo.png` | Deserto |
| Rocha e falésias | `rock_albedo.png` | Montanhas, Paredes e falésias |
| Basalto | `basalt_albedo.png` | Rocha vulcânica, Colinas vulcânicas, Picos vulcânicos |
| Cinzas vulcânicas | `ash_albedo.png` | Cinzas vulcânicas |
| Cristal arcano | `crystal_albedo.png` | Campos de cristal, Picos de cristal, Fonte mística |
| Solo místico | `mystic_soil_albedo.png` | Solo místico |
| Crosta de magma | `magma_albedo.png` | Lava solidificada |
| Detalhe de água | `water_albedo.png` | Oceano, Costa, Oceano congelado |

O **mar de lava** continua no shader líquido procedural, com a animação existente; o PNG `magma` é usado nos tiles sólidos de lava. Oceano, costa e oceano congelado recebem o detalhe pixelizado de água, preservando profundidade, ondas, espuma e congelamento. O gelo terrestre tem sua própria textura. As falésias recebem rocha, as encostas respeitam a família mineral e os picos conservam a neve.

## Uso no projeto

- PNGs RGB de **128 × 128**, opacos, até **24 cores** por material.
- **64 pixels por unidade** de mundo; repetição a cada duas unidades, projetada em espaço mundo. Mesma densidade no chão e nas paredes, sem UVs esticados.
- Filtro `nearest_mipmap`, com mipmaps: pixels nítidos no zoom próximo e menos cintilação na visão do mapa.
- `terrain_surfaces.res`: uma `Texture2DArray` com 14 camadas, sem compressão de blocos destrutiva. A textura de água é independente. A seleção fica em `INSTANCE_CUSTOM.b` do mesmo MultiMesh existente: não cria uma draw call por bioma.
- `TerrainTextureCatalog.gd` define a ordem das camadas. Alterar essa ordem exige reconstruir a array e atualizar o catálogo juntos.
- Alterações de terreno por magia atualizam a superfície, a altura e os efeitos, mantendo a variação da instância. Saves, IDs de bioma e geração procedural permanecem compatíveis.
- Os JPEGs anteriores foram preservados, mas o material do mapa não os carrega. Normal e roughness fotográficas continuam sem uso.
- O preset Windows exporta todos os recursos: array e PNGs acompanham o jogo; não há dependência do JSON de revisão em runtime.

## Revisão e reconstrução

A galeria local `art_source/terrain_pixel_review/index.html` exibe cada material, repetição 3 × 3, comparação antes/depois e capturas com os modelos existentes. Os originais de geração ficam em `sources/`; os prompts completos estão em `generation_manifest.json`. Os PNGs do jogo foram reduzidos com nearest e quantizados sem dithering; os originais continuam preservados.

`package_terrain_pixels.py` prepara os PNGs e o inventário. `run_terrain_pixel_review.py` constrói a array, verifica os pixels das camadas e captura o resultado no renderer nativo do Godot. A construção da array exige GPU; o renderer dummy de `--headless` não fornece o readback necessário. Os testes de regressão, por sua vez, podem rodar headless com `check_terrain_pixel_regressions.py`.

Validação: PNGs distintos e opacos; resolução, paleta, hashes e bordas de repetição conferidos. Renderização nativa Forward+ com os 25 tipos de terreno, 21 superfícies terrestres, quatro capturas e transformação dinâmica de terreno. Relatórios em `docs/terrain_pixel_*_validation.json`.

Regressão: **167 testes funcionais passaram** (materiais, geração, movimento, modificação de terreno e vegetação). O único teste restante exige geração do mapa especial em menos de 5 s e falhou. Na comparação com a mesma seed 999 e os mesmos 26.880 tiles, o chão fotográfico levou 6.786/7.182 ms e o chão pixelizado 6.461/6.553 ms: ambos ultrapassam esse limite, sem piora observada causada pelos novos materiais. Há carga de outros processos durante a medição; esses tempos são de CPU e não medem FPS. O log combinado GUT também avisa sobre 46 objetos e sete recursos no encerramento; o teste isolado dos materiais e a revisão nativa terminaram sem esses avisos. Nenhum limite de teste ou parâmetro do gerador foi alterado.
