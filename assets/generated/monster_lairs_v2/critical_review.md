# Revisão crítica dos covis — V1 → V2

## Critério

Conferência dos 12 monstros realmente usados em MonsterDatabase, dos renders existentes do mapa,
das três vistas de cada covil, das fontes Blender e dos GLBs. A linguagem geral da V1 era compatível
com os volumes blocky do bestiário. Os problemas principais eram legibilidade de alguns objetos,
geometria de apoio, repetição excessiva e origens naturais com aparência de construção.

| Espécie | Problema encontrado | Mudança aplicada |
|---|---|---|
| `goblin` | Conceito coerente; travessas retas não acompanhavam os postes tortos. Remendo grosso e cordas terminando no solo. | Travessas ligadas de poste a poste; remendos finos e cordas presas mais alto nos piquetes. Mantida a tenda de saqueadores. |
| `skeleton` | Conceito coerente; a tampa era pequena para o sarcófago e o fundo escuro estava escondido pela base de terra. | Tampa com dimensões compatíveis, fundo visível e ossos assentados acima dele. Mantida a cripta violada. |
| `worg` | Tronco parecia uma viga serrada, anéis de madeira não apareciam, marcas de garras estavam parcialmente enterradas e havia uma abertura atrás. | Tronco angular com cortes e veios legíveis, musgo localizado, fundo de terra fechado, garras visíveis e crânio de presa quadrúpede. |
| `giant_spider` | Casulos pareciam colmeias, o terceiro tronco não sustentava a teia e algumas extremidades não coincidiam com os apoios. | Casulos facetados sem anéis de pedra, ovos menores próprios, teia ancorada nos três troncos e casulo suspenso conectado ao fio. |
| `troll` | Pedra e musgo combinavam com o troll, mas o abrigo era simétrico como um dólmen e parecia aberto pela traseira. | Massas de pedra assimétricas, musgo em manchas, fundo fechado, cama de palha visível e crânio bovino de presa. |
| `wyvern` | Ninho elevado adequado, mas os ovos pareciam potes e as agulhas de pedra pareciam chaminés. Repetia o crânio humano de outros covis. | Ovos facetados manchados, pináculos quebrados em degraus, galhos menos regulares, marcas de fuligem na plataforma e crânio de presa. |
| `minotaur` | O portal com chifres funcionava; o interior parecia um pátio cercado, com pouca leitura de labirinto. | Duas paredes internas alternadas formam um meandro claro; canto superior quebrado e troféu com focinho bovino. |
| `basilisk` | Ninho coerente com a ave-réptil, mas ovos pareciam recipientes, penas estavam enterradas e a presa petrificada tinha anatomia ambígua. | Ovos facetados com manchas legíveis, penas assentadas sobre o terreno e lebre petrificada com patas, orelhas e cauda conectadas. |
| `colossal_worm` | Anéis regulares de blocos davam aparência de poço construído ou engrenagem. Cascas alinhadas brilhavam como pedras de passagem. | Funil contínuo assimétrico de areia fraturada, sem poço quadrado; fragmento de carapaça segmentada sem emissão de luz. |
| `arboreal_ancient` | As espirais ligavam o covil ao golem, mas estavam sobre um plano vertical que não acompanhava a pedra inclinada. O centro lembrava uma cama. | Espirais encostadas nas faces reais, placas partidas assimétricas e fissura verde estreita. Mantida a origem em pedra viva e raízes. |
| `mana_devourer` | O aro simétrico e as colunas roxas pareciam um altar ou piscina construída, distantes do monstro de pedras cinzentas e núcleo cúbico. | Jazida de pedra cúbica cinzenta fraturada, fissuras violetas localizadas e energia residual na rocha, sem aro ou colunas roxas. |
| `corrupted_hero` | O posto militar tinha relação com o velho cavaleiro, mas parecia limpo e funcional; havia detalhes parcialmente enterrados e placas que não acompanhavam o escudo. | Estandarte com recorte irregular, encosto quebrado, ferrugem discreta, maça visível e camadas do escudo transformadas como uma peça única. |

## Correções comuns

- UVs medidos em 64 px/m sobre as faces reais; a projeção anterior comprimira faces inclinadas.
- Faces não planas são trianguladas antes de receber UVs, mantendo a textura sem estiramento.
- Madeira orientada pelo eixo longo da peça e anéis centralizados no corte do tronco.
- Ovos com uma casca fechada, facetada e manchada; casulos com textura de seda própria.
- Bases baixas menos regulares e menor repetição de crânios humanos nos covis de predadores.
- Emissão limitada ao golem e à mana; carapaças descartadas não emitem luz.
- Um material e uma malha por GLB; fontes editáveis e dimensão adequada ao hex preservadas.

## O que a validação demonstra

`validation.json`: geometria do binário GLB, UVs métricos, texturas e limites espaciais.
`blender_validation.json`: abertura das fontes empacotadas e reimportação dos GLBs.
`geometry_audit.json`: contato entre ornamentos e seus suportes, fio do casulo, escudo
e fundos sólidos das duas tocas. A análise não proíbe interseções intencionais nas junções.
`map_readability.png` usa o ângulo frontal de 50° declarado pela câmera do jogo, num cenário
de conferência do Blender; não é uma captura do jogo nem teste de integração no Godot.

Os modelos continuam sendo marcadores em escala de mapa, assim como as construções vistas
nas capturas existentes do 4X. A escala nativa das criaturas é a de miniaturas de unidades;
a relação literal entre o tamanho do monstro e a abertura da toca não é uma escala arquitetônica.

A V1 e os modelos originais dos monstros permanecem preservados por comparação de hashes.
Todo o trabalho desta revisão fica em pastas de arte V2, isoladas com `.gdignore`.
