# Primordial dos Elementos — invocação V1

Animação criada no Blender aberto, via MCP. O núcleo aparece primeiro. A cabeça se materializa e o corpo cresce em sequência até a cauda, enquanto o dragão contorna o núcleo. A serpente se ergue e termina na pose inicial de idle. Sem partículas ou VFX adicionais; núcleo e corpo são a geometria do modelo aprovado.

- `index.html` / `Invocacao.mp4`: prévia com controles, 800 × 800, 30 fps, 151 quadros incluindo a pose final (5 segundos de movimento).
- `primordial_summon.blend`: cena independente, Summon selecionada, quadros 1–151. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `primordial_summon.glb`: Summon, idle, walk, attack e spell; uma malha, um material, 91 ossos e 1.738 triângulos. Mesma geometria, pesos, UVs, texturas e 125 peças editáveis da fonte aprovada. Os nomes minúsculos dos quatro clipes antigos foram mantidos.
- `validation.json`: 301 poses e meios de quadro; início invisível, núcleo sozinho aos 0,6 s, raiz fixa, corpo acima do chão, núcleo sem interseções e final igual ao início de idle. Os quatro clipes existentes e as texturas embutidas foram comparados com o GLB original.

A formação usa as 40 seções existentes da malha contínua. As seções ainda não formadas ficam recolhidas na ponta que cresce, evitando fragmentos ou linhas entre o corpo visível e a cauda. O movimento ao redor do núcleo e a recuperação reaproveitam as poses aprovadas de spell, com outro ritmo. A taxa original de 30 fps preserva a amostragem dos clipes anteriores.

Summon deve executar uma vez e seguir para idle. Toda a animação fica nos ossos, sem depender de física, partículas ou scripts de visibilidade. A revisão ainda não está ligada ao evento de nascimento no jogo. Os assets em uso e as animações anteriores das outras manifestações foram preservados.

Fontes: `tools/art_pipeline/animate_primordial_summon_mcp.py`, `finish_primordial_summon_mcp.py`, `render_primordial_summon_mcp.py` (via `blender_mcp_client.py`) e `package_primordial_summon_review.py`.
