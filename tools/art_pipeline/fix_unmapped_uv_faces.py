"""Faces sem UV num GLB de tropa: corrige no próprio arquivo, sem reexportar.

O DEFEITO (relato do usuário 2026-10-12: "a textura dos orcs in game tá bugada"): partes acrescentadas depois do
atlas (presas, olhos, espinhos, argolas de arma...) ficaram com TODAS as UVs em (0, 0) do Blender — o canto exato do
atlas, que no glTF é (0, 1). No Blender o canto cai sempre no mesmo pixel e a peça aparece na cor de base do atlas
(o bege 190/172/132), então os previews parecem certos. No jogo a amostragem `nearest` com repetição oscila entre os
QUATRO pixels que se encontram naquele canto (o de baixo à esquerda e, pela repetição, os outros três cantos, pretos):
a peça vira um chuvisco bege/preto.

A CORREÇÃO: essas UVs passam a apontar para o CENTRO do maior quadrado liso da mesma cor que o canto tinha — a cor
que a peça sempre mostrou no Blender. Longe de qualquer borda de pixel e com folga para os mipmaps. Só os floats de
TEXCOORD_0 mudam, no lugar: tamanho do arquivo, malha, rig, animações e imagem embutida ficam idênticos.

Uso (Python do sistema, com Pillow — não precisa do Blender):
    python tools/art_pipeline/fix_unmapped_uv_faces.py            # só relata
    python tools/art_pipeline/fix_unmapped_uv_faces.py --apply    # corrige os GLB em assets/generated
Depois de aplicar: `godot --headless --path . --import`. Rodar de novo depois de QUALQUER reexportação de tropa —
`test_unit_art_catalog.gd` falha se um modelo em jogo voltar a ter face no canto do atlas.
"""
import glob
import io
import json
import struct
import sys

from PIL import Image

COMPONENT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
## Menor lado aceito para o quadrado liso de destino (pixels): abaixo disso os mipmaps misturariam a cor vizinha.
MIN_SWATCH = 6


def _layout(doc, accessor_index):
    accessor = doc["accessors"][accessor_index]
    view = doc["bufferViews"][accessor["bufferView"]]
    fmt = COMPONENT[accessor["componentType"]]
    count = COUNT[accessor["type"]]
    size = struct.calcsize(fmt) * count
    return accessor, fmt, count, view.get("byteStride", size), view.get("byteOffset", 0) + accessor.get("byteOffset", 0)


def _read(doc, data, bin_start, accessor_index):
    accessor, fmt, count, stride, base = _layout(doc, accessor_index)
    return [struct.unpack_from("<" + fmt * count, data, bin_start + base + i * stride) for i in range(accessor["count"])]


def _embedded_image(doc, data, bin_start, primitive):
    material = doc["materials"][primitive["material"]] if "material" in primitive else {}
    texture = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
    if texture is None:
        return None
    image = doc["images"][doc["textures"][texture["index"]]["source"]]
    if "bufferView" not in image:
        return None
    view = doc["bufferViews"][image["bufferView"]]
    start = bin_start + view.get("byteOffset", 0)
    return Image.open(io.BytesIO(bytes(data[start:start + view["byteLength"]]))).convert("RGB")


def largest_uniform_square(image, color):
    """(x, y, lado) do maior quadrado só de `color` — programação dinâmica clássica, uma passada."""
    width, height = image.size
    pixels = image.load()
    best = (0, 0, 0)
    previous = [0] * (width + 1)
    for y in range(height):
        current = [0] * (width + 1)
        for x in range(width):
            if pixels[x, y] == color:
                side = min(previous[x], previous[x + 1], current[x]) + 1
                current[x + 1] = side
                if side > best[2]:
                    best = (x - side + 1, y - side + 1, side)
        previous = current
    return best


def process(path, apply):
    data = bytearray(open(path, "rb").read())
    json_length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(bytes(data[20:20 + json_length]))
    bin_start = 20 + json_length + 8
    report = {"path": path, "faces": 0, "vertices": 0, "target": None, "problem": "", "skipped": ""}
    for mesh in doc.get("meshes", []):
        for primitive in mesh["primitives"]:
            if "TEXCOORD_0" not in primitive["attributes"] or "indices" not in primitive:
                continue
            uv_index = primitive["attributes"]["TEXCOORD_0"]
            accessor, fmt, _count, stride, base = _layout(doc, uv_index)
            if fmt != "f":
                continue
            uvs = _read(doc, data, bin_start, uv_index)
            indices = [entry[0] for entry in _read(doc, data, bin_start, primitive["indices"])]
            unmapped = set()
            mapped = set()
            for t in range(0, len(indices), 3):
                triangle = indices[t:t + 3]
                if all(uvs[i] == (0.0, 1.0) for i in triangle):
                    unmapped.update(triangle)
                    report["faces"] += 1
                else:
                    mapped.update(triangle)
            if not unmapped:
                continue
            if unmapped & mapped:
                report["problem"] = "vértice no canto compartilhado com face mapeada"
                continue
            image = _embedded_image(doc, data, bin_start, primitive)
            if image is None:
                # Material de cor lisa (modelos antigos da Asset Factory): sem textura, a UV não é lida.
                report["skipped"] = "material sem textura: a UV não é usada"
                continue
            width, height = image.size
            color = image.getpixel((0, height - 1)) # o pixel que o canto (0, 1) mostrava no Blender
            x, y, side = largest_uniform_square(image, color)
            if side < MIN_SWATCH:
                # Textura repetida/paleta minúscula (pipeline antigo), sem atlas: não é este defeito.
                report["skipped"] = "sem área lisa de %s com %d px (maior: %d)" % (color, MIN_SWATCH, side)
                continue
            target = ((x + side / 2.0) / width, (y + side / 2.0) / height)
            report["target"] = {"color": color, "square": (x, y, side), "uv": target}
            report["vertices"] += len(unmapped)
            if apply:
                for vertex in unmapped:
                    struct.pack_into("<ff", data, bin_start + base + vertex * stride, target[0], target[1])
                # min/max do accessor continuam válidos: o destino fica dentro de [0, 1] como o canto ficava.
    if apply and report["vertices"] > 0 and not report["problem"]:
        open(path, "wb").write(data)
    return report


def main():
    apply = "--apply" in sys.argv
    roots = [arg for arg in sys.argv[1:] if not arg.startswith("--")] or ["assets/generated"]
    affected = 0
    problems = 0
    for root in roots:
        for path in sorted(glob.glob(root + "/**/*.glb", recursive=True)):
            path = path.replace("\\", "/")
            report = process(path, apply)
            if report["faces"] == 0:
                continue
            affected += 1
            if report["problem"]:
                problems += 1
                print("PROBLEMA  %-36s %s" % (path.split("/")[-1], report["problem"]))
                continue
            target = report["target"]
            if target is None:
                affected -= 1
                print("ignorado  %-36s %s" % (path.split("/")[-1], report["skipped"]))
                continue
            print("%s %-36s faces %4d  cor %s  quadrado liso %s" % ("corrigido" if apply else "afetado  ", path.split("/")[-1], report["faces"], target["color"], target["square"]))
    print("%d modelo(s) com face no canto do atlas; %d sem correção automática%s" % (affected, problems, "" if apply else " (relato apenas: use --apply)"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
