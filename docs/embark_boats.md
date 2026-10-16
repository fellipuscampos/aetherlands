# Embarcações de transporte — quatro raças

Quatro barcos pequenos para representar unidades terrestres na água, um design por raça. Formas facetadas, textura pixelada e cores baseadas nas tropas e oficinas existentes.

| Raça | Modelo | Triângulos |
| --- | --- | ---: |
| Barco Humano | `assets/generated/humans/human_embark_boat_v1/human_embark_boat_v1.glb` | 1552 |
| Barco Orc | `assets/generated/orcs/orc_embark_boat_v1/orc_embark_boat_v1.glb` | 1400 |
| Barco Elfo | `assets/generated/elves/elf_embark_boat_v1/elf_embark_boat_v1.glb` | 1100 |
| Barco Anão | `assets/generated/dwarves/dwarf_embark_boat_v1/dwarf_embark_boat_v1.glb` | 1876 |

Cada pasta contém o `.blend` editável, o `.glb` com texturas embutidas, a cena `.tscn` com escala de mapa, albedo/ORM e cinco imagens de revisão.

## Revisão

- Blender: `art_source/embark_boats_review/embark_boats_v1_review.blend`. A cena `Embark_Boats_V1_Review` também fica ativa no Blender aberto.
- Godot: `scenes/art_review/EmbarkBoatsReview.tscn`. Abra com F6; ESPAÇO alterna `idle` e `walk`.
- Imagem: `art_source/embark_boats_review/contact_sheet.png`.

- Vídeos e GIFs: `art_source/embark_boats_review/animations/idle` e `walk`.

## Posicionamento

A raiz fica no centro da linha d’água. Frente **−Z**, eixo vertical Y. Use a cena `.tscn` diretamente com a raiz na superfície da água; o filho `Visual` já tem escala uniforme **0,52**, que mantém o barco dentro do hexágono de raio 1 em qualquer rotação. Ao usar o GLB diretamente, aplique essa escala uma única vez.

**Idle:** 4 s, suave afundamento e balanço pequeno. **Walk:** 2 s, afundamento um pouco maior, leve inclinação e vela sob mais pressão do vento. Ambos fecham na pose inicial; não existe deslocamento horizontal. Todo deslocamento vertical é para dentro do plano da água; a quilha permanece submersa. As velas são lisas e estufadas para +Y do Blender / −Z do Godot. Deformação da vela por morph target, movimento do barco por nó `BoatMotion`, sem esqueleto. Não há tripulação. A implementação da troca automática do visual terrestre por barco durante `Unit.embarked` permanece para a integração de gameplay.

## Validação

Geometria fechada no Blender; exportação sem câmeras, iluminação ou chão de revisão; um material opaco por barco, filtro nearest e duas texturas embutidas. Relatórios em `docs/embark_boats_export_validation.json` e `docs/embark_boats_godot_validation.json`. Os quatro imports, oito clips, loops e limites de afundamento são verificados em um projeto Godot isolado.

Reprodução: `build_embark_boats_mcp.py` cria a primeira versão no MCP; `polish_embark_boats_mcp.py` recua os mastros da primeira versão; `verify_embark_boats.py` audita os exports e `finish_embark_boats.py` prepara e valida as cenas. `animate_embark_boats_mcp.py` remove os desenhos, estufa as velas para a frente e acrescenta as animações. `render_embark_boats_animation_mcp.py` e `encode_embark_boats_animation.py` geram a revisão em movimento. A versão anterior foi preservada em `art_source/embark_boats_review/before_sails_animation/`.
