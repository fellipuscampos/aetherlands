# Máquinas de cerco dos elfos

Quatro modelos originais construídos, pintados e animados pelo MCP do Blender aberto. A linha usa madeira clara de freixo, madeira escura nas peças de carga, bronze, aço, cordas de fibra, couro e tecidos verdes. Os acabamentos dourados do Colosso correspondem a ferragens e proteções de metal. As formas continuam feitas de blocos e prismas de poucas faces.

| Evolução | Construção | Altura funcional em repouso |
|---|---|---|
| Catapulta Élfica | Mangonel leve, quatro rodas abertas, torsão em corda, braço de lançamento e guincho traseiro | 1,80 m |
| Trebuchet Élfico | Estrutura em A, contrapeso articulado, funda e trilho de preparação | 1,80 m |
| Bombarda Élfica | Tubo longo de bronze, boca rebaixada, cintas de aço, apoios de madeira e recuo sobre trilhos | 1,80 m |
| Colosso de Guerra Élfico | Grande balista de torsão com seis rodas, dois braços laminados, cabos, trilho de virote e guincho | 2 m |

As três primeiras máquinas preservam os tipos de seus equivalentes humanos e anões com proporções, suportes e materiais próprios. O Colosso tem uma construção diferente: grande balista móvel, enquanto o humano usa uma grande bombarda e o anão um morteiro com caldeira.

Os 19 clipes mantêm os nomes, funções e durações da linha humana: Idle, Walk, Attack, DemolitionAmmo e, a partir do Trebuchet, PreparedBombardment. Os movimentos foram adaptados à mecânica de cada modelo. Idle permanece imóvel; as rodas giram no deslocamento, os braços lançam, a bombarda recua e a balista move braços, cordas, guincho e virote. Os contrapesos articulados e as pontas dos cabos acompanham seus pontos de fixação.

Abra `res://_elf_siege_models_review.tscn` no Godot e pressione F6 para começar na categoria Cerco. A cena geral `_elf_troop_models_review.tscn` também inclui a sexta categoria. Os arquivos `.blend`, `.glb`, atlas e relatórios ficam em `assets/generated/elves/elf_*_v1/`. A revisão `assets/generated/elves/elf_siege_review.blend` mostra as quatro máquinas juntas: Espaço pausa/reproduz; desative Preview Range para percorrer todas as técnicas.

- [Galeria das quatro máquinas](previews/elf_siege/progression_three_quarter.jpg)
- [Comparação entre as três raças](previews/elf_siege/three_races_comparison.jpg)
- [Disparo do Colosso](previews/elf_siege/colossus_attack_contact.jpg)
- [Revisão no Blender](previews/elf_siege/blender_review.png)
- `elf_siege_validation.json`: geometria exportada, alturas, skins, movimentos, nomes/durações dos clipes, atlas embutido, materiais, rodas e hashes dos modelos existentes.
- `elf_siege_blender_review_validation.json`: reprodução real do ataque das quatro máquinas na revisão.
- `elf_troops_project_validation.json`: importação no projeto Godot das 24 unidades élficas e execução da revisão de seis classes.

Para regenerar no Blender aberto: `python tools/art_pipeline/run_elf_siege_mcp.py`. Para uma máquina: `--only elf_siege_colossus_v1`. Os modelos fazem parte do catálogo de arte e revisão; a seleção racial de modelos no gameplay segue a integração das demais tropas.
