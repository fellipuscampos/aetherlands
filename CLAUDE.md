# Aetherlands — notas para sessões do Claude Code

Documento vivo, carregado automaticamente no início de toda sessão nesta
pasta. Mantenha curto — detalhe extenso vive nos docs referenciados abaixo,
não aqui.

## O jogo

4X de fantasia medieval em Godot 4.7, single-player vs. IA (multiplayer é
visão futura, não implementado). Visão completa: `docs/GAME_DESIGN_BIBLE.md`.

## Antes de mexer em modelos 3D de personagem/monstro

Leia **`docs/ASSET_FACTORY_GUIDE.md`** primeiro. Cobre: como gerar/editar
modelos (CLI headless vs. editor addon dentro do Blender), como importar
pro Godot, o sistema de escala (KayKit vs. Asset Factory — regra: para
personagens da Asset Factory a altura em jogo é o `"height"` do preset,
NÃO um multiplicador copiado de outro personagem), a metodologia de
verificação usada no projeto ("confirme com bounding box/screenshot
descartável, não adivinhe visualmente"), e um catálogo de bugs já
resolvidos pra não redescobrir.

## Antes de mexer em performance/FPS/lag

Leia **`docs/PERFORMANCE_GUIDE.md`** primeiro. Cobre a distinção mais
importante (travadela de CPU num evento discreto vs. teto de FPS de
V-Sync/GPU são dois problemas diferentes, uma otimização de um nunca move
o número do outro), o roteiro de benchmark headless usado pra medir de
verdade em vez de adivinhar, e a lista do que já foi otimizado (A* em
`compute_path`, overlays de neblina guiados por coordenada em vez de por
pixel, cache de território habitável) com custo antes/depois — não
redescubra os mesmos gargalos.

## Executáveis

- Blender: `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe`
- Godot: `C:\Users\felipe campos\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`

## Regras gerais deste projeto

- Novo arquivo `.gd` com `class_name`: rodar
  `godot --headless --path . --import` antes de qualquer teste, senão
  aparecem erros em cascata de "not declared".
- Qualquer conferência visual em jogo: sempre não-headless, **uma vez só**
  (nunca em loop) — screenshot via
  `get_viewport().get_texture().get_image().save_png(...)`, apagar os
  arquivos temporários da cena de teste logo depois e confirmar com
  `git status --porcelain`.
- Outros docs vivos: `docs/DRAGON_EVENT_DESIGN.md`,
  `docs/WORLD_EVENT_CONTRACT.md`.
