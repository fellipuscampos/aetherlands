# Tropas orcs

20 personagens em cinco classes e quatro evoluções por classe. Comuns: **2 m**. Supremos lendários: **2,20 m**. A altura da cavalaria é a do cavaleiro com as pernas estendidas, sem incluir montaria ou lança. Cerco está fora deste lote.

A revisão de roupas `leather_and_skeletal_v1` usa couro castanho com costuras, bordas e rebites, faixas ajustadas ao torso, cintos com fivelas metálicas vazadas, painéis de couro sobre tecido, ombreiras em 3D com chifres e braçadeiras reforçadas. Torso, braços e parte das pernas continuam expostos nas versões leves.

Sentinela, Campeão Guardião, Cavaleiro Couraçado e Campeão da Cavalaria receberam a revisão `closed_carapace_v1`: armaduras de osso que cobrem quase todo o corpo, com placas corticais sobrepostas, bordas esculpidas, fissuras discretas e frestas estreitas de pele verde. O capacete de crânio de javali sem mandíbula é pintado no bloco original da cabeça, com relevo nasal e chifres grandes em 3D nas têmporas dianteiras, curvados para a frente e para cima. Ombreiras largas, braçadeiras, manoplas, coxas, canelas e pés completam a proteção. Cintos, couro, tecidos e fivelas aprovados foram preservados.

A revisão `forward_horns_and_painted_hoods_v1` aumenta e traz para a frente os chifres dos quatro capacetes de osso, preservando o corpo e as alturas anatômicas de 2 m / 2,20 m; os chifres são acessórios acima dessa altura. Os escudos de braço e seus reforços foram removidos do Cavaleiro Couraçado e do Campeão da Cavalaria. Os quatro arqueiros têm capuz de tecido verde-oliva desenhado diretamente na cabeça original, com costura central, borda acabada e abertura que preserva olhos, sobrancelhas, nariz, boca e presas.

A revisão `jawless_skull_v1` fecha as manoplas com textura contínua de osso, remove as sobrancelhas 3D dos quatro capacetes e deixa o rosto inferior original do orc exposto abaixo do crânio sem mandíbula. O relevo nasal foi elevado para acompanhar essa abertura. Os chifres conservam exatamente a curva, o tamanho e a textura aprovados; suas raízes foram recuadas para dentro das têmporas e têm folga verificada em relação às orelhas. Capuzes, corpos, roupas, armas, montarias e animações foram preservados.

Os escudos da linha de guardiões agora têm apenas o reforço central quadrado de ferro sobre a madeira: os quatro quadrados brancos das evoluções foram removidos. O escudo do escudeiro inicial já tinha esse acabamento e continua intacto.

As lâminas foram orientadas com o fio voltado para a frente por rotação axial das peças, preservando seus formatos, comprimentos, texturas e empunhaduras. Arcos, mãos, montarias e acessórios das armas mantêm a geometria aprovada, exceto as peças incluídas nessa rotação.

Os 18 blocos corporais, a cabeça única, as seis peças das orelhas, as presas, as alturas e os esqueletos continuam iguais à versão aprovada. Os **93 clips** foram mantidos; somente as translações das patas das montarias foram ajustadas nesta rodada, conforme descrito abaixo. As duas sobrancelhas 3D permanecem nas versões com rosto ou capuz e foram retiradas apenas dos quatro capacetes de osso. As novas peças usam os ossos existentes.

A revisão `war_bull_v3` mantém os touros inspirados na referência, com tronco e peito feitos de blocos retangulares. As placas de osso da montaria, os painéis extras junto à sela e a camada separada da testa foram removidos. Cabeça inclinada, olhos laterais, chifres, pelagem, cauda e cascos continuam como na versão anterior. Cavaleiros, alturas, roupas, armas, sela, estribos e rédeas foram preservados.

As 16 animações montadas foram reaproveitadas. As translações dos oito ossos das patas receberam pequenas correções verticais nas passadas e investidas para impedir que os cascos atravessem o chão, inclusive durante a interpolação entre quadros. Joelhos permanecem conectados; movimentos do cavaleiro, rotações, corpo da montaria, cabeça, rédeas e duração dos clips continuam intactos. Nenhuma animação nova foi criada. Os outros 16 orcs e as fontes das demais raças permanecem iguais.

- [Galeria das 20 tropas](previews/orc_troops/roster_three_quarter.jpg), [frente](previews/orc_troops/roster_front.jpg), [costas](previews/orc_troops/roster_back.jpg).
- [Revisão das animações](previews/orc_troops/bull_motion_contact_sheet.jpg).
- [Touros de guerra e cavaleiros](previews/orc_troops/war_bulls_three_quarter.jpg), [detalhes das montarias](previews/orc_troops/war_bulls_mount_closeup.jpg).
- [Detalhes dos capacetes sem mandíbula e das manoplas](previews/orc_troops/open_skull_details.jpg).
- [Detalhes dos novos chifres e capuzes](previews/orc_troops/horns_hoods_details.jpg).
- [Chifres e capuzes antes e depois](previews/orc_troops/horns_hoods_before_after.jpg).
- [Armaduras de osso antes e depois](previews/orc_troops/bone_armor_before_after.jpg).
- [Roupas antes e depois](previews/orc_troops/clothing_before_after.jpg).
- Blender: [conjunto editável](../assets/generated/orcs/orc_troops_review.blend).
- Godot: abra `res://_orc_troop_models_review.tscn` e pressione **F6**. A revisão permite escolher classe e animação, pausar, alterar velocidade, girar e aproximar.
- `.blend`, `.glb`, atlas e relatórios individuais: `assets/generated/orcs/`.
- Manifesto: `assets/generated/orcs/orc_troops_manifest.json`.

| Classe | Inicial | Evolução 2 | Evolução 3 | Supremo (2,20 m) |
|---|---|---|---|---|
| Guardião | [Escudeiro Orc](../assets/generated/orcs/orc_squire_v1/orc_squire_v1.blend) | [Guardião Orc](../assets/generated/orcs/orc_guardian_v1/orc_guardian_v1.blend) | [Sentinela Orc](../assets/generated/orcs/orc_sentinel_v1/orc_sentinel_v1.blend) | [Campeão Guardião Orc](../assets/generated/orcs/orc_guardian_champion_v1/orc_guardian_champion_v1.blend) |
| Guerreiro | [Guerreiro Orc](../assets/generated/orcs/orc_warrior_v1/orc_warrior_v1.blend) | [Espadachim Orc](../assets/generated/orcs/orc_swordsman_v1/orc_swordsman_v1.blend) | [Mestre de Armas Orc](../assets/generated/orcs/orc_weapon_master_v1/orc_weapon_master_v1.blend) | [Herói da Lâmina Orc](../assets/generated/orcs/orc_blade_hero_v1/orc_blade_hero_v1.blend) |
| Patrulheiro | [Arqueiro Orc](../assets/generated/orcs/orc_archer_v1/orc_archer_v1.blend) | [Caçador Orc](../assets/generated/orcs/orc_hunter_v1/orc_hunter_v1.blend) | [Atirador de Elite Orc](../assets/generated/orcs/orc_elite_marksman_v1/orc_elite_marksman_v1.blend) | [Caçador Lendário Orc](../assets/generated/orcs/orc_legend_hunter_v1/orc_legend_hunter_v1.blend) |
| Cavalaria | [Cavaleiro Orc](../assets/generated/orcs/orc_cavalier_v1/orc_cavalier_v1.blend) | [Cavaleiro de Choque Orc](../assets/generated/orcs/orc_shock_cavalier_v1/orc_shock_cavalier_v1.blend) | [Cavaleiro Couraçado Orc](../assets/generated/orcs/orc_armored_cavalier_v1/orc_armored_cavalier_v1.blend) | [Campeão da Cavalaria Orc](../assets/generated/orcs/orc_griffon_rider_v1/orc_griffon_rider_v1.blend) |
| Ladino | [Ladino Orc](../assets/generated/orcs/orc_rogue_v1/orc_rogue_v1.blend) | [Sabotador Orc](../assets/generated/orcs/orc_saboteur_v1/orc_saboteur_v1.blend) | [Assassino Orc](../assets/generated/orcs/orc_assassin_v1/orc_assassin_v1.blend) | [Mestre das Sombras Orc](../assets/generated/orcs/orc_shadow_master_v1/orc_shadow_master_v1.blend) |

Verificação:
- `orc_war_bull_finish_validation.json`: blocos retangulares, retirada das placas e dos painéis, apoio dos cascos conferido a 48 fps, continuidade dos joelhos e alterações limitadas às translações das patas.
- `orc_war_bulls_validation.json`: revisão anterior; quatro touros; cavaleiros, armas, sela, estribos, materiais protegidos, esqueleto e 16 clips intactos; contatos de rédeas e pernas e separação dos chifres em relação a mãos e cabeça verificados em todos os frames; outros 16 orcs e 475 arquivos das demais raças preservados.
- `orc_open_skull_validation.json`: manoplas contínuas, rosto inferior original, sobrancelhas removidas somente nos capacetes, raízes dos chifres dentro da cabeça e folga geométrica em relação às orelhas; corpos, armas, curvas e os outros 16 modelos preservados.
- `orc_horns_hoods_validation.json`: chifres maiores e dianteiros, capuzes sem nova cabeça, retirada real dos escudos montados, materiais e geometria protegidos, esqueleto e curvas preservados; os outros 12 modelos continuam byte a byte intactos.
- `orc_bone_armor_validation.json`: cobertura de osso, capacete fechado na cabeça única, olhos simétricos, curvas e geometria protegidas, armas e couro intactos, e os outros 15 modelos byte a byte preservados.
- `orc_clothing_refinement_validation.json`: comparação dos GLBs com a cópia aprovada; geometria, pesos, esqueleto, curvas, materiais protegidos e rotações das lâminas.
- `orc_troops_anatomy_validation.json`: 4.364 poses exportadas, continuidade das articulações e ausência de interseções das mãos com rosto e tronco.
- `orc_troops_validation.json`: alturas, clips, atlas embutidos, olhos simétricos e fontes protegidas.
- `orc_troops_blender_validation.json`: arquivos editáveis, blocos, pesos e animações salvas.
- `orc_troops_godot_validation.json`: importação, dimensões, atlas, animações e revisão das cinco classes.

Para reaplicar a revisão de capacetes pelo MCP do Blender aberto: `python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_open_skull_all_mcp.py --timeout 1200`. A fonte para os capacetes sem mandíbula está em `art_source/orc_troops/open_skull/before_assets/`. A revisão anterior de chifres e capuzes usa `orc_horns_hoods_all_mcp.py`. A fonte aprovada para chifres e capuzes está em `art_source/orc_troops/horns_and_hoods/before_assets/`. A revisão de armadura fechada está em `orc_bone_all_mcp.py`. A fonte aprovada para esta rodada está em `art_source/orc_troops/bone_armor_refinement/before_assets/`. A revisão anterior de couro pode ser reaplicada com `python tools/art_pipeline/run_orc_clothing_mcp.py`. A fonte congelada está em `art_source/orc_troops/clothing_refinement/before_assets/`. As revisões anteriores e suas comparações permanecem arquivadas.

Para reaplicar os touros pelo MCP do Blender aberto: `python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/finish_orc_war_bulls_mcp.py --timeout 1200`. A fonte congelada antes deste ajuste está em `art_source/orc_troops/war_bull_finish/before_assets/`.
