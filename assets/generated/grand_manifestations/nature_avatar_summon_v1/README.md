# Avatar da Natureza — invocação V1

Animação criada no Blender aberto, via MCP. Primeiro o núcleo aparece sozinho. Em seguida, as 85 peças de madeira do próprio modelo se formam ao redor, descrevem arcos e se encaixam para montar o Avatar: tronco, coroa, braços e raízes. O conjunto se acomoda na pose inicial de Idle. Sem partículas ou efeitos adicionais; VFX serão feitos no Godot. O núcleo verde é a geometria original.

- `index.html` / `Invocacao.mp4`: prévia com controles de reprodução, 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `nature_avatar_summon.blend`: cena independente, Summon selecionada, quadros 1–121. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `nature_avatar_summon.glb`: Summon, Idle, Walk, Attack e Spell; uma malha, um material, 103 ossos e 2.060 triângulos. As 86 peças editáveis, geometria, UVs e texturas foram preservados. Os 18 ossos originais recebem 85 filhos, um por peça de madeira, permitindo a montagem independente sem alterar as quatro animações anteriores.
- `validation.json`: 241 poses e meios de quadro; núcleo sozinho aos 0,625 s, raiz fixa, peças acima do chão, núcleo sem interseção com a madeira, encaixe final e pose final igual ao início de Idle. Os canais dos 18 ossos originais e as texturas embutidas foram comparados com o GLB original; os novos ossos ficam em repouso nas quatro animações anteriores. A deformação dos clipes originais também foi comparada antes e depois de adicionar os ossos de montagem.

Summon deve executar uma vez e seguir para Idle. A formação e os encaixes são gravados nos ossos; não dependem de física em tempo real, partículas, scripts de visibilidade ou helpers no jogo. O piso de estúdio é apenas para revisão e não acompanha o GLB.

Revisão de arte, ainda sem ligação ao evento de nascimento no jogo. Os modelos em uso, suas quatro animações e as animações anteriores das outras manifestações foram preservados.

Fontes: `tools/art_pipeline/animate_nature_avatar_summon_mcp.py` chama `animate_nature_avatar_assembly_mcp.py`; `finish_nature_avatar_summon_mcp.py`, `render_nature_avatar_summon_mcp.py` (via `blender_mcp_client.py`) e `package_nature_avatar_summon_review.py` validam, exportam e empacotam.
