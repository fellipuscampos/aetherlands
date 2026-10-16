"""Package the current-model comparison without changing any model."""
import hashlib
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'art_source/elder_lich_style_review'
refs = json.loads((DEST / 'references.json').read_text(encoding='utf-8'))
for item in refs.values():
    assert hashlib.sha256((ROOT / item['source']).read_bytes()).hexdigest() == item['sha256'], item['source']

observations = {
    'skeleton': 'Referência correta para o crânio: órbitas amplas com contorno irregular, cavidade nasal, dentes visíveis e mandíbula separada. O Lich atual tem olhos pequenos e uma boca que acaba parecendo um sorriso.',
    'necromancer': 'O roxo, o capuz e o cajado já ligam o Lich ao mago humano. A roupa do necromante tem variação de pixels mais presente; no Lich, as grandes superfícies do manto ficam relativamente lisas.',
    'lich': 'O conceito funciona: um antigo mago morto, com grimório, cajado, ossos expostos e corpo espectral. Eu manteria a estrutura e revisaria principalmente o rosto e a pintura das vestes.',
    'archdemon': 'Versão V5, a mais recente criada. Placas com textura em pixels e peças afastadas dão uma silhueta forte. Serve como comparação de acabamento e presença de mini boss.',
    'seraph': 'Versão V4 animada, a mais recente criada. As asas, os anéis e o cubo dão presença pela silhueta. O Lich pode continuar mais contido e reconhecível como mago, preservando sua origem na lore.',
}
cards = []
for key, item in refs.items():
    name = html.escape(item['name'])
    source = html.escape(item['source'])
    cards.append(f'''<article><h2>{name}</h2><a href="{key}.png"><img loading="lazy" src="{key}.png" alt="{name}"></a><p>{observations[key]}</p><p class="source"><a href="../../{source}">{source}</a></p></article>''')

page = '''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Lich Ancião — comparação com os modelos atuais</title><style>
*{box-sizing:border-box}body{margin:0;background:#111822;color:#e5e8ef;font:16px/1.6 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:32px}h1{font-size:30px;line-height:1.2}h2{font-size:21px}p{max-width:1000px}a{color:#b9c7ff}img{display:block;width:100%;border-radius:8px;background:#52627a}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}article{padding:20px;background:#1b2533;border-radius:12px}.source{font-size:12px;overflow-wrap:anywhere;color:#a9b4c9}.recommendation{border-left:4px solid #9d88d1;padding:12px 24px;background:#202739;margin:24px 0}
</style><main><h1>Lich Ancião — comparação com os modelos atuais</h1>
<p>Os cinco arquivos GLB foram renderizados no Godot com a mesma câmera de três quartos, iluminação e materiais importados. A imagem conjunta mantém a escala real dos modelos; as imagens individuais ajustam o enquadramento para mostrar o acabamento.</p>
<a href="comparison_before.png"><img src="comparison_before.png" alt="Esqueleto atual, necromante humano, Lich, Arcdemônio e Serafim na mesma escala"></a>
<div class="recommendation"><strong>Avaliação: ajustes pontuais, mantendo o conceito.</strong><p>Refazer o rosto conforme o esqueleto atual e dar às vestes roxas uma pintura em pixels mais trabalhada. A altura de 3 metros, o capuz, o grimório, o cajado e a flutuação já sustentam a ideia de um mago que transcendeu a morte. Um manto um pouco mais aberto seria uma opção para aumentar sua presença, mas eu não considero necessário redesenhar sua estrutura.</p><p>Esta revisão é uma comparação: o modelo do Lich permanece sem alterações.</p></div>
<div class="grid">''' + '\n'.join(cards) + '''</div><p class="source"><a href="references.json">Arquivos usados e hashes SHA-256</a></p></main></html>'''
(DEST / 'index.html').write_text(page, encoding='utf-8')
print('Review written; all five source GLB hashes unchanged.')
