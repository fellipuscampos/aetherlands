# Dragão vermelho escuro — V4

Revisão de formato feita no Blender via MCP a partir da referência do usuário.
Sem núcleo. Os detalhes da barriga e do queixo são pintados nas próprias faces;
não existem placas, tábuas ou lâminas suspensas sob o corpo.

Mudanças de proporção em relação à V3:

| Parte | V3 | V4 |
| --- | --- | --- |
| Focinho, comprimento / profundidade | 2,59 | 1,54 |
| Cabeça | Focinho longo e fino, mandíbula aberta | Crânio profundo, focinho curto, mandíbula ajustada |
| Patas dianteiras | Mãos achatadas e garras para frente | Palmas volumosas, cotovelos dobrados, dedos e garras para baixo |
| Patas traseiras | Quatro pés na mesma altura | Membros curtos, recolhidos atrás do corpo |
| Asas | Painéis separados, raiz fora do plano dos ossos | Uma superfície conectada por asa, armação no plano da membrana |
| Proporção da vela superior, altura / largura | 0,66 | 1,06 |
| Cauda | Curva curta, poucas seções na ponta | Raiz descendente, cauda ascendente longa, gancho arredondado |

As asas têm borda dianteira contínua e dois dedos de sustentação, em vez de um
leque de triângulos. A membrana chega ao ombro e à lateral do tórax e possui
espessura real. Os ossos da asa ficam centrados na superfície da membrana.
A cauda tem 27 seções, com mais seções reservadas à curva pequena da ponta.

- `dark_red_dragon_v4.blend`: fonte editável com texturas empacotadas.
- `dark_red_dragon_v4.glb`: uma malha, um material, 52 ossos preparados.
- `dark_red_dragon_v4_{albedo,emission}.png`: atlas de pixel art, 1024 × 1024.
- `previews/`: vistas de três quartos, frente, lateral e câmera alta.
- `blender_validation.json`: topologia, simetria e contato entre armação e membrana.
- `godot_validation.json`: conferência do GLB importado.

Altura nativa de 3 m e folga de voo de 0,25 m. Frente −Y no Blender / +Z no Godot.
O modelo permanece independente, com rig preparado e sem clipes de animação.
Nenhuma regra ou unidade do jogo foi alterada.

Gerador: `tools/art_pipeline/build_dark_red_dragon_v4_mcp.py`.
