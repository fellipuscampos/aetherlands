# Canteiro de construção anão

Canteiro genérico para edifícios anões em produção, baseado nas imagens do centro da cidade, da oficina e do salão dos guardiões. Inclui pedra cinza, cobre alaranjado e telhas cinza-azuladas escuras, nas cores dos edifícios existentes. Três anões talham pedra, limam uma telha e rebitam cobre sobre uma bigorna.

- `dwarf_construction_site_hex_v1.blend`: fonte editável com 386 cuboides, rig e animação.
- `dwarf_construction_site_hex_v1.glb`: 4632 triângulos, 2 malhas, 1 material, atlas 1024×1024, 25 ossos.
- `dwarf_construction_site_hex_v1.tscn`: inicia e repete `construction` automaticamente.
- `previews/`: vistas gerais, closes e alinhamento ao hexágono virtual.

Nove blocos, três chapas, seis lingotes, dez telhas, cantoneiras e cintas de cobre aguardam instalação. A anatomia, as barbas, os rostos e os bonés são os do colonizador anão original, em escala uniforme de 0,26. Mangas articuladas formam os ombros; os antebraços permanecem curtos e sem torção.

O loop dura 6 segundos a 30 fps. Pés e raiz ficam fixos. Martelos atingem o formão e o rebite com a cabeça; a lima e a mão de apoio mantêm contato com a telha. O modelo não contém prédio específico, chão ou tile. A geometria é blocky, sem bevels ou suavização.

Integrado em `HexGrid` para cidades `dwarf`, aplicando `hex_size` uma vez. O visual desaparece ao concluir ou cancelar a obra. Revisão nativa: `scenes/art_review/DwarfConstructionReview.tscn`. Página, referências, vídeo e GIF: `art_source/dwarf_construction_review/`.
