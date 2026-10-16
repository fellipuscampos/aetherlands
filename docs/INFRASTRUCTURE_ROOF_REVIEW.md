# Revisão de telhados e apoios da infraestrutura

[Comparação antes/depois e referências anteriores](../art_source/infrastructure_roof_review/index.html). Revisão realizada no Blender aberto, pelo MCP.

Os modelos anteriores usam tanto telhados de duas águas quanto coberturas piramidais e hexagonais. O problema específico da infraestrutura era o chanfro aplicado a todos os cantos de cada fiada, inclusive nas coberturas retangulares. Esse recorte dava uma silhueta arredondada e repetia o mesmo detalhe entre civilizações.

Foram corrigidos **23 telhados em 19 modelos**, mantendo as fiadas planas do estilo existente, a altura da cobertura, os materiais e as construções aprovadas. A oficina e a universidade élficas receberam coberturas de duas águas para aproximá-las dos salões élficos. As demais coberturas de quatro águas mantêm sua função de pavilhão. A cobertura da universidade orc, de planta hexagonal, foi revisada e preservada. O silo humano e as pequenas torres também mantêm suas coberturas hexagonais.

Foram acrescentadas três travessas: uma na banca lateral do mercado humano e duas nos quiosques do mercado élfico. Elas fecham as pequenas folgas entre os pilares e os telhados. Os layouts e materiais foram preservados. Além dos telhados, apenas as peças identificadas na revisão de junções receberam ajustes de geometria.

As alturas e proporções seguem cada civilização: ardósia azul e alvenaria humana; verde alto e madeira esbelta élfica; ardósia escura baixa, granito e cobre anões; telhados ferrugem, madeira grossa e ferro orcs.

[Validação específica](infrastructure_roof_review_validation.json): 20 modelos, peças aprovadas preservadas, beirais sem chanfros artificiais, continuidade das fiadas, contato dos apoios e backup íntegro.

[Arquivos e texturas](infrastructure_buildings_validation.json), [fontes editáveis](infrastructure_buildings_source_validation.json), [importação Godot](infrastructure_buildings_godot_validation.json) e [testes do jogo](infrastructure_buildings_game_validation.json). Todos os IDs e o modelo único por categoria permanecem preservados.

Também foram acrescentados o eixo e o mancal do regulador no santuário anão, conectando a roda à base de pedra. As verificações conferem o contato da roda, do cubo, do eixo, do mancal e da base.

## Faces que causavam cintilação

Foram ajustadas **94 peças em 18 modelos**, corrigindo 130 pares de faces coplanares expostos detectados nas duas passagens. A auditoria cruza triângulos em planos coincidentes e testa pontos interiores e próximos aos cantos contra uma BVH de toda a geometria do prédio, nas vistas de jogo e direções laterais. Faces internas de contato entre sólidos não são tratadas como defeitos visuais.

As copas agora diminuem em largura e profundidade; molduras e canteiros usam juntas sem sobreposição; os encostos dos bancos recuam em relação aos assentos; fustes terminam dentro dos capitéis; detalhes de ferro e o canal de mana recebem encaixes que evitam faces no mesmo plano.

[Auditoria inicial](../art_source/infrastructure_roof_review/before_face_repairs.json), [segunda passagem](../art_source/infrastructure_roof_review/after_face_repairs_pass1.json), [peças corrigidas](../art_source/infrastructure_roof_review/face_repairs.json) e [auditoria final](../art_source/infrastructure_roof_review/after_face_repairs.json): **zero sobreposições expostas detectadas** nos vinte modelos. A verificação dos arquivos compara a geometria real do GLB com a fonte nativa auditada.

Backup: `art_source/infrastructure_before_roof_review`, com os vinte modelos anteriores, quatro vistas por modelo e manifesto SHA256.
