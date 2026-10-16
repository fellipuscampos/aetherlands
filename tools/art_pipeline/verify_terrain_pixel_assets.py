"""Validate final textures, preservation, and the local review gallery."""
from pathlib import Path
import hashlib, json, re
from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art_source/terrain_pixel_review'
DEST = ROOT / 'assets/textures/terrain/pixel_v1'
manifest = json.loads((WORK / 'manifest.json').read_text(encoding='utf-8'))
hashes = set()
for row in manifest['assets']:
    path = ROOT / row['path']
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest == row['sha256'] and digest not in hashes
    hashes.add(digest)
    with Image.open(path) as image:
        assert image.size == (128, 128) and image.mode == 'RGB'
        assert len(image.getcolors(16384)) <= 24
    assert (ROOT / row['source']).exists()
    settings = (path.with_suffix('.png.import')).read_text(encoding='utf-8')
    assert 'mipmaps/generate=true' in settings and 'compress/mode=0' in settings
    assert max(row['wrap_boundary_ratio']) < 2
backup = ROOT / 'art_source/terrain_before_pixel_v1'
snapshot = json.loads((backup / 'snapshot.json').read_text(encoding='utf-8'))
photographs = 0
for row in snapshot['files']:
    assert hashlib.sha256((backup / row['path']).read_bytes()).hexdigest() == row['sha256']
    if row['path'].endswith('.jpg'):
        assert hashlib.sha256((ROOT / row['path']).read_bytes()).hexdigest() == row['sha256']
        photographs += 1
before = (backup / 'scripts/world/HexGrid.gd').read_text(encoding='utf-8')
after = (ROOT / 'scripts/world/HexGrid.gd').read_text(encoding='utf-8')
for method in ['generate_map', '_build_hex_prism_mesh', 'elevation_kind_for', '_material_kind_for']:
    pattern = re.compile(r'^(?:static )?func ' + method + r'\(.*?(?=^(?:static )?func |\Z)', re.M | re.S)
    assert pattern.search(before).group() == pattern.search(after).group(), method
errors = []
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, channel='msedge')
    page = browser.new_page(viewport={'width': 1440, 'height': 1050}, device_scale_factor=1)
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto((WORK / 'index.html').as_uri(), wait_until='networkidle')
    assert page.locator('.card').count() == 15
    assert page.locator('.legend span').count() == 25
    assert page.locator('img').evaluate_all('(images)=>images.every(img=>img.complete && img.naturalWidth>0)')
    assert page.locator('.swatch').evaluate_all('(els)=>els.every(el=>getComputedStyle(el).imageRendering==="pixelated")')
    page.get_by_role('button', name='Repetição 3 × 3').click()
    assert page.locator('#repeat').get_attribute('aria-pressed') == 'true'
    size = page.locator('.swatch').first.evaluate('(el)=>parseFloat(el.style.backgroundSize)')
    height = page.locator('.swatch').first.evaluate('(el)=>el.clientHeight')
    assert abs(size * 3 - height) < .01
    page.get_by_role('button', name='Chão anterior', exact=True).click()
    assert page.locator('#comparison').get_attribute('src') == 'terrain_before.png'
    page.get_by_role('button', name='Chão em pixel art', exact=True).click()
    page.get_by_role('button', name='Textura inteira', exact=True).click()
    page.screenshot(path=str(WORK / 'gallery_desktop.png'), full_page=True)
    page.set_viewport_size({'width':390,'height':844})
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
    assert not errors, errors
    browser.close()
report = dict(status='PASS',textures=len(hashes),maximum_colors=24,resolution=[128,128],runtime_png_bytes=sum(row['bytes'] for row in manifest['assets']),backup_files_preserved=len(snapshot['files']),original_photographs_preserved=photographs,geometry_and_generator_unchanged=True,gallery_cards=15,gallery_terrain_inventory=25,gallery_repeat_and_comparison=True,gallery_mobile_overflow=False)
(ROOT / 'docs/terrain_pixel_assets_validation.json').write_text(json.dumps(report, indent=2),encoding='utf-8')
print(json.dumps(report))
