# Revisão das texturas humanas — 06/10/2026

22 unidades revisadas; 20 corrigidas e aplicadas aos arquivos usados pelo jogo.
O guarda e o colonizador do conjunto antigo foram revisados e mantidos. Catapulta, trebuchet, bombard e colosso de cerco foram excluídos.

## Correções

- Remoção de riscos nas luvas e das colunas escuras interrompidas nas calças.
- Redução do ruído de cores em couro, tecido, pele, madeira e metal, com a mesma paleta de cada unidade.
- Costura acolchoada com contraste mais equilibrado; emblemas, rebites, fivelas, cintos, lâminas, olhos e boca mantêm o desenho original.
- PNG principal, PNG extraído pelo Godot, albedo embutido no GLB e imagem empacotada no Blender sincronizados.
- Regra compartilhada nos 16 pintores humanos; os quatro ladinos a herdam. A regra exclui a família de cerco.

## Comparação

![Antes e depois das 20 unidades](previews/human_texture_repair/before_after.jpg)

## Validação

- Metadados não relacionados a imagens e todos os buffers de geometria, UV, pesos, esqueleto e animação dos GLBs são idênticos aos originais.
- Arquivos Blender reabertos e comparados por digest dos objetos, malhas, UVs, pesos, ossos, trilhas e curvas de animação.
- Importação real no Godot 4.7.1: 22 modelos aprovados; pixels de albedo, filtros, ossos, durações, loops e poses finitas verificados.
- Emissão e resolução das texturas mantidas. Todos os arquivos originais do cerco e das duas unidades antigas mantidos.

Relatórios: [arquivos e fontes](human_texture_repair_validation.json) e [Godot isolado](human_texture_repair_godot_validation.json). A [checagem no projeto real](human_texture_repair_project_validation.json) tamb?m aprovou as 22 unidades ap?s a atualiza??o do cache.

Os originais estão em `art_source/human_texture_repair/before/`. As vistas estáticas foram atualizadas; vídeos de prévia de animação anteriores permanecem arquivados.

## Unidades corrigidas

| Unidade | Pixels corrigidos no atlas |
|---|---:|
| `archer_v1` | 18250 |
| `armored_cavalier_v1` | 38706 |
| `assassin_v1` | 16830 |
| `blade_hero_v1` | 24033 |
| `cavalier_v1` | 40520 |
| `elite_marksman_v1` | 17834 |
| `griffon_rider_v1` | 67923 |
| `guardian_champion_v1` | 22526 |
| `guardian_v1` | 22160 |
| `hunter_v1` | 18887 |
| `legend_hunter_v1` | 26408 |
| `rogue_v1` | 15374 |
| `saboteur_v1` | 16232 |
| `sentinel_v1` | 14479 |
| `shadow_master_v1` | 17431 |
| `shock_cavalier_v1` | 42075 |
| `squire_v1` | 21386 |
| `swordsman_v1` | 16320 |
| `warrior_v1` | 17025 |
| `weapon_master_v1` | 14216 |

## Reprodução da correção

Fluxo nativo autorizado pelo usuário: Python/Pillow para os pixels e Blender para UVs, imagens empacotadas e revisão. A imagem generativa de exploração não foi aplicada.

1. Executar `audit_human_textures.py` no Blender para criar o inventário UV e preservar os arquivos iniciais.
2. Executar `repair_human_textures.py` com Python para preparar PNGs e GLBs.
3. Executar `pack_human_texture_sources.py` no Blender para empacotar as fontes e renderizar as vistas.
4. Executar `run_human_texture_godot_validation.py --godot CAMINHO_DO_EXECUTAVEL`.
5. Executar `install_human_texture_repair.py` para instalar o conjunto completo validado.
