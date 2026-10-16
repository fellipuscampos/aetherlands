"""Package native Blender renders into shareable previews."""
from PIL import Image, ImageDraw, ImageFont
from orc_siege_assets import ROOT, WORK

dest = ROOT / 'docs/previews/orc_siege'
font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 19)
for role, title in [('walk', 'Movimento — rodas em ciclo'),
                    ('attack', 'Ataque — catapulta, trebuchet e recuo alternado do colosso')]:
    frames = []
    for path in sorted((WORK / 'motion_frames' / role).glob('*.png')):
        render = Image.open(path).convert('RGB')
        frame = Image.new('RGB', (render.width, render.height + 36), (34, 38, 33))
        frame.paste(render, (0, 36))
        ImageDraw.Draw(frame).text((14, 6), title, font=font, fill=(235, 230, 208))
        frames.append(frame.quantize(colors=192))
    assert len(frames) == 24
    frames[0].save(dest / (role + '.gif'), save_all=True, append_images=frames[1:],
                   duration=[83, 83, 84] * 8, loop=0, disposal=2, optimize=False)
for role, title in [('attack', 'Ataque'), ('demolition', 'Munição de demolição'), ('prepared', 'Bombardeio preparado')]:
    paths = sorted((WORK / 'motion_frames' / (role + '_stages')).glob('*.png'))
    assert len(paths) == 6
    sheet = Image.new('RGB', (1020, 3 * 246 + 40), (34, 38, 33))
    draw = ImageDraw.Draw(sheet); draw.text((14, 7), title, font=font, fill=(235, 230, 208))
    for index, path in enumerate(paths):
        image = Image.open(path).convert('RGB').resize((510, 204), Image.Resampling.LANCZOS)
        x = index % 2 * 510; y = index // 2 * 246 + 40
        sheet.paste(image, (x, y)); draw.text((x + 12, y + 210), 'Etapa ' + str(index + 1), font=font, fill=(235, 230, 208))
    sheet.save(dest / (role + '_stages.jpg'), quality=95)
print('NATIVE_ANIMATION_PREVIEWS_PACKAGED')
