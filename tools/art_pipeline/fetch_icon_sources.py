"""Baixa os SVG dos pictogramas do jogo.

Le tools/art_pipeline/icon_sources/manifest.json (id do pictograma -> "autor/nome" em https://game-icons.net) e grava
tools/art_pipeline/icon_sources/svg/<id>.svg. Os SVG ficam versionados: o jogo nao depende da rede, este script so
serve para ACRESCENTAR ou TROCAR um desenho.

    python tools/art_pipeline/fetch_icon_sources.py            # baixa o que falta
    python tools/art_pipeline/fetch_icon_sources.py --force    # baixa tudo de novo (depois de trocar uma linha)

Depois: gere as mascaras com tools/art_pipeline/build_icon_glyphs.gd (ver o cabecalho dele).
Licenca dos icones: CC BY 3.0 - o credito ao autor e obrigatorio (assets/icons/CREDITS.txt, gerado pelo build).
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.join("tools", "art_pipeline", "icon_sources")


def main() -> int:
    force = "--force" in sys.argv
    with open(os.path.join(ROOT, "manifest.json"), encoding="utf-8") as handle:
        manifest = json.load(handle)
    out_dir = os.path.join(ROOT, "svg")
    os.makedirs(out_dir, exist_ok=True)
    record_path = os.path.join(out_dir, "_sources.json")
    record = {}
    if os.path.exists(record_path):
        with open(record_path, encoding="utf-8") as handle:
            record = json.load(handle)
    failed = 0
    for glyph_id, source in sorted(manifest["glyphs"].items()):
        target = os.path.join(out_dir, glyph_id + ".svg")
        # Um id cuja linha mudou no manifesto e baixado de novo mesmo sem --force.
        if os.path.exists(target) and record.get(glyph_id) == source and not force:
            continue
        try:
            data = urllib.request.urlopen(manifest["source_url"] + source + ".svg", timeout=30).read()
        except Exception as error:  # noqa: BLE001 - relata e segue para os demais
            print("FALHOU %s (%s): %s" % (glyph_id, source, error))
            failed += 1
            continue
        with open(target, "wb") as handle:
            handle.write(data)
        record[glyph_id] = source
        print("baixado %s <- %s" % (glyph_id, source))
    for stale in [glyph_id for glyph_id in record if glyph_id not in manifest["glyphs"]]:
        del record[stale]
        stale_path = os.path.join(out_dir, stale + ".svg")
        if os.path.exists(stale_path):
            os.remove(stale_path)
            print("removido %s (saiu do manifesto)" % stale)
    with open(record_path, "w", encoding="utf-8") as handle:
        json.dump(record, handle, indent="\t", sort_keys=True)
        handle.write("\n")
    print("%d pictograma(s) no manifesto, %d falha(s)" % (len(manifest["glyphs"]), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
