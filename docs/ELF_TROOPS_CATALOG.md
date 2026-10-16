# Tropas élficas — derivadas dos humanos

24 modelos em seis classes: 20 personagens derivados dos humanos e quatro máquinas de cerco de construção própria, todos feitos pelo MCP do Blender aberto. Os arquivos `.blend` mantêm as peças editáveis; os `.glb` têm texturas embutidas, rig e todos os clipes dos humanos de origem.

O corpo humano foi reutilizado diretamente: cabeça, peito, barriga, pélvis e, dos dois lados, coxa, canela, pé, ombro, braço, antebraço e mão. Cada orelha é uma ponta em três blocos retangulares fechados, ligados ao osso da cabeça. As faces têm pele pálida, cabelos loiros e olhos verdes desenhados com pixels exatamente espelhados.

## Revisão de rosto, capacetes e materiais

A cabeça permanece um único bloco. Rosto, cabelo, capuz, coifa e capacete completo são desenhados nesse bloco, sem outro rosto ou casco sobreposto. Os capacetes completos de Sentinela, Campeão Guardião, Cavaleiro Couraçado e Campeão da Cavalaria têm faceplate metálica fechada, viseiras simétricas e respiradouros. Suas cristas e plumas geométricas foram retiradas. O Espadachim e o Herói da Lâmina também tiveram os volumes externos de cabelo e seus acessórios retirados; o cabelo está pintado no cubo. Chapéus, gorros e capacetes abertos do tipo chapéu mantêm seus volumes externos. As alturas em pé foram recalibradas para 1,80 m/2 m sem depender dos volumes removidos.

As roupas e armaduras foram repintadas no próprio corpo, com materiais distintos dos humanos: linho oliva, tecido marfim, couro castanho e musgo, bronze, aço claro e aço escurecido. Os cinco lendários usam placas ou lâminas sobrepostas de metal dourado, com couro e tecido nas articulações. A paleta considera marfim, verdes, bronze e dourado dos edifícios élficos existentes. Escudos, mantos e roupas usam construção material: costuras, rebites, juntas de placas, aros e bordas discretas. Os brasões humanos foram removidos.

- [Antes e depois da revisão](previews/elf_troops/refinement_before_after.jpg)
- [Cabeças ampliadas, sem interpolação](previews/elf_troops/head_faces.png)

As três primeiras evoluções mantêm a escala humana de **1,80 m**; a quarta é lendária de **2 m**. Na cavalaria, esse valor corresponde ao cavaleiro em pé; a altura total inclui cavalo e lança. A montaria continua sendo o cavalo blocky dos humanos. O nome interno `griffon_rider` é herdado do jogo, sem acrescentar grifo.

## Animações humanas equivalentes

Os 20 elfos usam os 93 clipes de seus humanos equivalentes: repouso, caminhada, ataque e técnicas próprias de cada evolução. As amostras dos GLBs são idênticas às dos humanos, inclusive durações e movimentos da montaria. As trilhas NLA dos arquivos editáveis estão habilitadas, com marcadores para localizar os clipes na linha do tempo.

A revisão `assets/generated/elves/elf_troops_review.blend` abre com o intervalo de caminhada selecionado. Pressione **Espaço** para reproduzir. Desative **Preview Range** para percorrer a sequência completa: repouso no quadro 1, caminhada no 91, ataque no 201 e técnicas a partir do 331. Cada arquivo individual conserva a linha do tempo original do humano correspondente.

- `elf_troops_animation_blender_validation.json`: comparação das matrizes de todos os ossos em seis instantes por clipe, movimento real de caminhada/ataque e reabertura dos 20 arquivos salvos para verificar as trilhas habilitadas.
- Para aplicar essa configuração pelo MCP do Blender aberto: `python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/activate_elf_animations_mcp.py`.

## Revisão

- Abra `res://_elf_troop_models_review.tscn` no Godot e pressione **F6**.
- Escolha a classe para ver as quatro evoluções, girar a câmera e testar clipes e técnicas.
- Marque a comparação para exibir a base humana da mesma classe.
- [Galeria das 20 tropas](previews/elf_troops/roster_three_quarter.jpg)
- [Frente](previews/elf_troops/roster_front.jpg), [visão de jogo](previews/elf_troops/roster_game_top.jpg), [costas](previews/elf_troops/roster_back.jpg)
- [Comparação humano/elfo](previews/elf_troops/human_elf_comparison.jpg)

## Modelos

| Classe | Primeira evolução | Segunda | Terceira | Lendária |
|---|---|---|---|---|
| Guardião | [Escudeiro Élfico](../assets/generated/elves/elf_squire_v1/elf_squire_v1.blend) | [Guardião Élfico](../assets/generated/elves/elf_guardian_v1/elf_guardian_v1.blend) | [Sentinela Élfico](../assets/generated/elves/elf_sentinel_v1/elf_sentinel_v1.blend) | [Campeão Guardião Élfico](../assets/generated/elves/elf_guardian_champion_v1/elf_guardian_champion_v1.blend) |
| Guerreiro | [Guerreiro Élfico](../assets/generated/elves/elf_warrior_v1/elf_warrior_v1.blend) | [Espadachim Élfico](../assets/generated/elves/elf_swordsman_v1/elf_swordsman_v1.blend) | [Mestre de Armas Élfico](../assets/generated/elves/elf_weapon_master_v1/elf_weapon_master_v1.blend) | [Herói da Lâmina Élfico](../assets/generated/elves/elf_blade_hero_v1/elf_blade_hero_v1.blend) |
| Patrulheiro | [Arqueiro Élfico](../assets/generated/elves/elf_archer_v1/elf_archer_v1.blend) | [Caçador Élfico](../assets/generated/elves/elf_hunter_v1/elf_hunter_v1.blend) | [Atirador de Elite Élfico](../assets/generated/elves/elf_elite_marksman_v1/elf_elite_marksman_v1.blend) | [Caçador Lendário Élfico](../assets/generated/elves/elf_legend_hunter_v1/elf_legend_hunter_v1.blend) |
| Cavalaria | [Cavaleiro Élfico](../assets/generated/elves/elf_cavalier_v1/elf_cavalier_v1.blend) | [Cavaleiro de Choque Élfico](../assets/generated/elves/elf_shock_cavalier_v1/elf_shock_cavalier_v1.blend) | [Cavaleiro Couraçado Élfico](../assets/generated/elves/elf_armored_cavalier_v1/elf_armored_cavalier_v1.blend) | [Campeão da Cavalaria Élfico](../assets/generated/elves/elf_griffon_rider_v1/elf_griffon_rider_v1.blend) |
| Ladino | [Ladino Élfico](../assets/generated/elves/elf_rogue_v1/elf_rogue_v1.blend) | [Sabotador Élfico](../assets/generated/elves/elf_saboteur_v1/elf_saboteur_v1.blend) | [Assassino Élfico](../assets/generated/elves/elf_assassin_v1/elf_assassin_v1.blend) | [Mestre das Sombras Élfico](../assets/generated/elves/elf_shadow_master_v1/elf_shadow_master_v1.blend) |

## Validação e reprodução

- `elf_troops_validation.json`: preservação da anatomia e pesos, remoção apenas dos enfeites de capacetes completos, 72 triângulos de orelhas ligados à cabeça, igualdade dos pixels reais de ambos os olhos no PNG, uma cabeça por modelo, dourado dos lendários, amostras das animações, atlas embutidos, filtragem nearest e hashes dos humanos/anões protegidos.
- `elf_troops_godot_validation.json`: importação dos 24 GLBs, dimensões, materiais, skins, reprodução dos 112 clipes e cena de revisão com seis classes.
- `elf_troops_project_validation.json`: os 24 modelos, 112 clipes e a revisão de seis classes executados no projeto real do jogo.
- `elf_troops_head_blender_validation.json`: inspeção das malhas reais de cabeça no Blender, volumes externos permitidos e alturas em pé após as remoções.
- `assets/generated/elves/elf_troops_review.blend`: revisão das cinco linhas no Blender, também deixada visível na sessão aberta.
- `assets/generated/elves/elf_troops_manifest.json`: caminhos, classe, evolução, referência de ID e altura do personagem.
- Para regenerar através do Blender aberto: `python tools/art_pipeline/run_elf_troop_mcp.py`. Use `--only elf_squire_v1` para uma variante.

Este lote entrega arte e a cena de revisão. A seleção racial no gameplay permanece para uma integração posterior; os modelos humanos e anões não foram substituídos. A linha de cerco está disponível no [catálogo das máquinas élficas](ELF_SIEGE_CATALOG.md), com Catapulta, Trebuchet, Bombarda e o Colosso de Guerra em forma de grande balista.
