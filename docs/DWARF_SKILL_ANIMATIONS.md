# Habilidades dos anões

Os 24 modelos têm 43 animações novas de habilidade, feitas nos próprios rigs dos anões pelo Blender MCP. Com as 72 animações básicas existentes, os GLBs contêm 115 clipes. Os movimentos não foram copiados nem retargetados de outras raças.

A forma básica recebe a primeira habilidade da linha. A primeira evolução recebe a próxima habilidade e mantém a anterior; as evoluções seguintes mantêm ambas. A entrada e a sustentação da Muralha são duas partes da mesma habilidade, disponíveis nas quatro versões do guardião.

| Linha | Primeira habilidade | A partir da evolução I |
| --- | --- | --- |
| Guardião | `shield_wall` e `shield_wall_hold` | Mantém a mesma Muralha |
| Guerreiro | `power_strike` | `arc_attack` |
| Patrulheiro | `precise_shot` | `volley` |
| Cavalaria | `charge` | `tactical_retreat` |
| Ladino | `sneak_attack` | `dismantle` |
| Cerco | `demolition_ammo` | `prepared_bombardment` |

Os besteiros miram e recarregam suas bestas; os cavaleiros atacam e recuam sobre carneiros. Os guardiões sustentam o escudo, os guerreiros usam o peso dos martelos e os ladinos trabalham com golpes curtos. Mangonel, trebuchet, bombarda e colosso usam seus próprios mecanismos de disparo, contrapeso ou recuo. O movimento respeita os pivôs originais, os membros curtos, os contatos com o chão e as rédeas.

Firmar Lanças permanece passiva, sem um clipe separado. Desmantelar e Munição Demolidora também permanecem passivas nas regras: suas animações acompanham ataques contra os alvos relevantes. A integração inclui a postura sustentada da Muralha, o Bombardeio Preparado contra cidades e o Recuo Tático durante o deslocamento real.

## Arquivos e revisão

Cada pasta em [`assets/generated/dwarves`](../assets/generated/dwarves) contém o `.blend` editável e o `.glb` atualizado, além do relatório com os clipes de habilidade. As ações novas são particulares de cada modelo. Os movimentos básicos `idle`, `walk` e `attack`, a geometria, as UVs, os pesos e as texturas originais foram preservados.

Abra [`_dwarf_troop_models_review.tscn`](../_dwarf_troop_models_review.tscn) no Godot e execute com F6 para revisar as linhas e as habilidades. No Blender, selecione o rig do arquivo individual e habilite a faixa desejada no NLA, silenciando as demais; o FPS é 48 e a faixa da cena cobre todos os clipes.

As prévias foram renderizadas das ações reais do Blender. Há GIFs de cada habilidade na evolução II e imagens comparando as quatro versões:

- [Guardiões](previews/dwarf_skills/guardian_progression.jpg): [entrada](previews/dwarf_skills/guardian_shield_wall.gif), [sustentação](previews/dwarf_skills/guardian_shield_wall_hold.gif).
- [Guerreiros](previews/dwarf_skills/warrior_progression.jpg): [golpe poderoso](previews/dwarf_skills/warrior_power_strike.gif), [ataque em arco](previews/dwarf_skills/warrior_arc_attack.gif).
- [Besteiros](previews/dwarf_skills/ranger_progression.jpg): [tiro preciso](previews/dwarf_skills/ranger_precise_shot.gif), [salva](previews/dwarf_skills/ranger_volley.gif).
- [Cavaleiros](previews/dwarf_skills/cavalry_progression.jpg): [carga](previews/dwarf_skills/cavalry_charge.gif), [recuo](previews/dwarf_skills/cavalry_tactical_retreat.gif).
- [Ladinos](previews/dwarf_skills/rogue_progression.jpg): [ataque furtivo](previews/dwarf_skills/rogue_sneak_attack.gif), [desmantelar](previews/dwarf_skills/rogue_dismantle.gif).
- [Cerco](previews/dwarf_skills/siege_progression.jpg): [munição demolidora](previews/dwarf_skills/siege_demolition_ammo.gif), [bombardeio preparado](previews/dwarf_skills/siege_prepared_bombardment.gif).

Também há MP4s nas pastas `previews` dos seis modelos da evolução II. O backup anterior às habilidades está em `art_source/dwarf_skills/before_skills`.

## Validação

- [Comparação dos 24 GLBs com os originais](dwarf_skills_validation.json): 43 clipes novos, movimentos básicos preservados e 841 arquivos protegidos de humanos, elfos e orcs sem alterações.
- [Importação e poses no Godot](dwarf_skills_godot_validation.json): duração, repetição, movimento, chão, recuperação e transição da Muralha.
- [Ações nos arquivos nativos](dwarf_skills_native_validation.json): ações próprias de cada modelo e intervalo completo da cena.
- [Integração com unidades reais](dwarf_skills_gameplay_validation.json): progressão, Muralha, ataque a cidades, carga e recuo; 14 testes passaram.
- [Regressões existentes](dwarf_skills_regression_validation.json): 113 de 133 testes passaram, incluindo todos os 36 de combate e os 10 de modelos humanos. Os 20 restantes encontraram recursos KayKit de cenário ausentes e expectativas de nós de pesquisa não atendidas pela base atual; a rodada ampla não está integralmente aprovada. O relatório e o log registram cada suíte.
- [Prévias nativas](dwarf_skills_preview_validation.json): renderização das habilidades de todos os 24 modelos.
