"""Write Godot map scenes and docs, then import the kit in an isolated project."""
import json, shutil, subprocess, tempfile, re, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art_source/embark_boats_review'
GODOT=Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
descriptions={
 'human':'Casco de madeira clara, vela azul lisa com bordas de linho, baú na popa.',
 'orc':'Madeira escura, vela ferrugem remendada sem emblema, presas na proa e escudos laterais.',
 'elf':'Casco esbelto, proa em folha dourada, vela verde sem desenho com borda dourada.',
 'dwarf':'Casco largo, placas de ferro e cintas de cobre, vela azul-ardósia lisa com bordas de cobre.',
}
for entry in manifest['assets']:
    stem=entry['stem']; folder=(ROOT/entry['glb']).parent
    relative=(folder/(stem+'.tscn')).relative_to(ROOT).as_posix(); entry['godot_scene']=relative
    (folder/(stem+'.tscn')).write_text('[gd_scene load_steps=2 format=3]\n\n'
        '[ext_resource type="PackedScene" path="res://'+entry['glb']+'" id="1_model"]\n\n'
        '[node name="'+stem+'" type="Node3D"]\n'
        'metadata/race = "'+entry['race']+'"\nmetadata/waterline = 0.0\n\n'
        '[node name="Visual" parent="." instance=ExtResource("1_model")]\n'
        'scale = Vector3(0.52, 0.52, 0.52)\n',encoding='utf-8')
    (folder/'README.md').write_text('# '+entry['name']+' — embarcação de transporte\n\n'+descriptions[entry['race']]+'\n\n'
        'Representa **uma unidade embarcada**. São quatro designs, um por raça, com velas sem símbolos e estufadas para a frente.\n\n'
        '- `'+stem+'.blend`: peças separadas e editáveis, texturas empacotadas.\n'
        '- `'+stem+'.glb`: '+str(entry['game_meshes'])+' grupos de malha, um material opaco, albedo e ORM de 512×512 embutidos, filtro nearest.\n'
        '- `'+stem+'.tscn`: cena para o mapa, escala 0,52 já aplicada no filho `Visual`.\n'
        '- `previews/`: vistas na água, de cima, de lado e casco completo.\n\n'
        '**Animações embutidas:** `idle` (4 s) e `walk` (2 s), em loop e no lugar. '
        'Afundamento suave em Y negativo e inclinação pequena em torno da linha d’água; o mar permanece um plano fixo. '
        'A vela tem uma deformação discreta pelo vento. O barco anão tem menos balanço. '
        'O post-import `tools/art_pipeline/embark_boat_import.gd` configura os loops e autoplay de `idle`; '
        'use `AnimationPlayer.play("walk")` para navegar.\n\n'
        'A origem fica no centro da linha d’água; no Godot o eixo frontal é **−Z**, Y aponta para cima. '
        'O casco submerso permanece abaixo de Y=0. Posicione a raiz na altura da superfície da água. '
        'A cena usa uma escala simbólica para caber no hexágono de raio 1; o GLB conserva a escala de modelagem.\n\n'
        'Importe a cena `.tscn` como visual da unidade durante `embarked=true`, escondendo o visual terrestre. '
        'Ao desembarcar, restaure o visual terrestre. A troca automática de visual não foi alterada por este pacote de modelos.\n\n'
        'Modelado e animado no Blender aberto pelo MCP em localhost:9876. '
        'Versão anterior em `art_source/embark_boats_review/before_sails_animation/`.\n',encoding='utf-8')
manifest['automatic_gameplay_integration']=False
(ROOT/'assets/generated/embark_boats_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(WORK/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')

# Keep validation independent of Blender's preview renders.
def write_contact_sheet():
    canvas=Image.new('RGB',(1600,1020),'#152b36'); draw=ImageDraw.Draw(canvas)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',27)
    small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',19)
    draw.text((40,24),'AETHERLANDS  /  EMBARCAÇÕES',font=font,fill='#e6ddc5')
    draw.text((40,66),'Um barco por unidade · quatro raças · idle / walk · água plana',font=small,fill='#aebdc2')
    for i,entry in enumerate(manifest['assets']):
        x=(i%2)*800; y=110+(i//2)*450
        source=Image.open((ROOT/entry['glb']).parent/'previews/three_quarter.png').convert('RGBA')
        source.thumbnail((620,405),Image.Resampling.LANCZOS)
        canvas.paste(source,(x+90+(620-source.width)//2,y),source)
        draw.text((x+50,y+398),entry['name'].upper(),font=font,fill='#e7dfc8')
        draw.text((x+50,y+432),str(entry['triangles'])+' triângulos · '+str(entry['editable_parts'])+' peças editáveis',font=small,fill='#9eafb8')
    canvas.save(WORK/'contact_sheet.png')
if '--validate-only' not in sys.argv: write_contact_sheet()

# Scene that can be opened directly in the user's Godot editor.
review_dir=ROOT/'scenes/art_review'; review_dir.mkdir(exist_ok=True)
lines=['[gd_scene load_steps=10 format=3]','']
for i,e in enumerate(manifest['assets']):
    lines.append('[ext_resource type="PackedScene" path="res://'+e['godot_scene']+'" id="'+str(i+1)+'_boat"]')
lines.append('[ext_resource type="Script" path="res://scripts/art_review/EmbarkBoatsReview.gd" id="5_review"]')
lines += ['','[sub_resource type="Environment" id="Environment_review"]','background_mode = 1','background_color = Color(0.035, 0.075, 0.10, 1)',
    'ambient_light_source = 3','ambient_light_color = Color(0.65, 0.77, 0.88, 1)','ambient_light_energy = 0.65','reflected_light_source = 2',
    '','[sub_resource type="StandardMaterial3D" id="Material_water"]','albedo_color = Color(0.06, 0.20, 0.26, 1)','roughness = 0.44','metallic = 0.15',
    '','[sub_resource type="PlaneMesh" id="Mesh_water"]','material = SubResource("Material_water")','size = Vector2(20, 14)',
    '','[node name="EmbarkBoatsReview" type="Node3D"]','script = ExtResource("5_review")',
    '','[node name="WorldEnvironment" type="WorldEnvironment" parent="."]','environment = SubResource("Environment_review")',
    '','[node name="Water" type="MeshInstance3D" parent="."]','position = Vector3(0, -0.003, 0)','mesh = SubResource("Mesh_water")',
    '','[node name="Sun" type="DirectionalLight3D" parent="."]','rotation_degrees = Vector3(-48, -28, 0)','light_color = Color(1, 0.94, 0.84, 1)','light_energy = 1.25','shadow_enabled = true',
    '','[node name="Fill" type="DirectionalLight3D" parent="."]','rotation_degrees = Vector3(-32, 145, 0)','light_color = Color(0.74, 0.85, 1, 1)','light_energy = 0.45',
    '','[node name="Camera3D" type="Camera3D" parent="."]','position = Vector3(0, 5.3, -7.4)','rotation_degrees = Vector3(-32, 180, 0)','projection = 1','size = 9.1','current = true']
for i,e in enumerate(manifest['assets']):
    x=(i-1.5)*2.0
    lines += ['','[node name="'+e['race'].title()+'" parent="." instance=ExtResource("'+str(i+1)+'_boat")]','position = Vector3('+str(x)+', 0, 0)',
        '','[node name="Label'+e['race'].title()+'" type="Label3D" parent="."]','position = Vector3('+str(x)+', 0.13, -1.35)',
        'billboard = 1','font_size = 42','pixel_size = 0.005','modulate = Color(0.92, 0.88, 0.77, 1)','text = "'+e['name'].upper()+'"']
# Five ext resources, three subresources, and the scene itself.
lines[0]='[gd_scene load_steps=9 format=3]'
lines += ['','[node name="Instructions" type="CanvasLayer" parent="."]',
    '','[node name="Label" type="Label" parent="Instructions"]','offset_left = 24.0','offset_top = 20.0',
    'theme_override_colors/font_color = Color(0.92, 0.88, 0.77, 1)','theme_override_font_sizes/font_size = 22',
    'text = "ESPAÇO: alternar idle / walk"']
(review_dir/'EmbarkBoatsReview.tscn').write_text('\n'.join(lines)+'\n',encoding='utf-8')

table='\n'.join('| '+e['name']+' | `'+e['glb']+'` | '+str(e['triangles'])+' |' for e in manifest['assets'])
(ROOT/'docs/embark_boats.md').write_text('# Embarcações de transporte — quatro raças\n\n'
    'Quatro barcos pequenos para representar unidades terrestres na água, um design por raça. '
    'Formas facetadas, textura pixelada e cores baseadas nas tropas e oficinas existentes.\n\n'
    '| Raça | Modelo | Triângulos |\n| --- | --- | ---: |\n'+table+'\n\n'
    'Cada pasta contém o `.blend` editável, o `.glb` com texturas embutidas, a cena `.tscn` '
    'com escala de mapa, albedo/ORM e cinco imagens de revisão.\n\n'
    '## Revisão\n\n- Blender: `art_source/embark_boats_review/embark_boats_v1_review.blend`. '
    'A cena `Embark_Boats_V1_Review` também fica ativa no Blender aberto.\n'
    '- Godot: `scenes/art_review/EmbarkBoatsReview.tscn`. Abra com F6; ESPAÇO alterna `idle` e `walk`.\n'
    '- Imagem: `art_source/embark_boats_review/contact_sheet.png`.\n\n'
    '- Vídeos e GIFs: `art_source/embark_boats_review/animations/idle` e `walk`.\n\n'
    '## Posicionamento\n\nA raiz fica no centro da linha d’água. Frente **−Z**, eixo vertical Y. '
    'Use a cena `.tscn` diretamente com a raiz na superfície da água; o filho `Visual` já tem '
    'escala uniforme **0,52**, que mantém o barco dentro do hexágono de raio 1 em qualquer rotação. '
    'Ao usar o GLB diretamente, aplique essa escala uma única vez.\n\n'
    '**Idle:** 4 s, suave afundamento e balanço pequeno. **Walk:** 2 s, afundamento um pouco maior, '
    'leve inclinação e vela sob mais pressão do vento. Ambos fecham na pose inicial; não existe deslocamento horizontal. '
    'Todo deslocamento vertical é para dentro do plano da água; a quilha permanece submersa. '
    'As velas são lisas e estufadas para +Y do Blender / −Z do Godot. '
    'Deformação da vela por morph target, movimento do barco por nó `BoatMotion`, sem esqueleto. '
    'Não há tripulação. A implementação da troca automática '
    'do visual terrestre por barco durante `Unit.embarked` permanece para a integração de gameplay.\n\n'
    '## Validação\n\nGeometria fechada no Blender; exportação sem câmeras, iluminação ou chão de revisão; '
    'um material opaco por barco, filtro nearest e duas texturas embutidas. '
    'Relatórios em `docs/embark_boats_export_validation.json` e `docs/embark_boats_godot_validation.json`. '
    'Os quatro imports, oito clips, loops e limites de afundamento são verificados em um projeto Godot isolado.\n\n'
    'Reprodução: `build_embark_boats_mcp.py` cria a primeira versão no MCP; '
    '`polish_embark_boats_mcp.py` recua os mastros da primeira versão; '
    '`verify_embark_boats.py` audita os exports e `finish_embark_boats.py` prepara e valida as cenas. '
    '`animate_embark_boats_mcp.py` remove os desenhos, estufa as velas para a frente e acrescenta as animações. '
    '`render_embark_boats_animation_mcp.py` e `encode_embark_boats_animation.py` geram a revisão em movimento. '
    'A versão anterior foi preservada em `art_source/embark_boats_review/before_sails_animation/`.\n',encoding='utf-8')

if '--previews-only' in sys.argv:
    print('EMBARK_BOATS_PREVIEWS_UPDATED'); raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix='embark_boats_validation_') as temporary:
    project=Path(temporary).resolve()
    assert project.parent==Path(tempfile.gettempdir()).resolve()
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Embark Boats Validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[filesystem]\nimport/blender/enabled=false\n',encoding='utf-8')
    for e in manifest['assets']:
        for path in (ROOT/e['glb'],ROOT/e['godot_scene']):
            target=project/path.relative_to(ROOT); target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(path,target)
    (project/'assets/generated/embark_boats_manifest.json').write_text(json.dumps(manifest),encoding='utf-8')
    shutil.copy2(ROOT/'tools/art_pipeline/verify_embark_boats_import.gd',project/'verify.gd')
    import_script=Path('tools/art_pipeline/embark_boat_import.gd')
    (project/import_script).parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/import_script,project/import_script)
    review_script=Path('scripts/art_review/EmbarkBoatsReview.gd')
    (project/review_script).parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/review_script,project/review_script)
    target_review=project/'scenes/art_review'; target_review.mkdir(parents=True)
    shutil.copy2(review_dir/'EmbarkBoatsReview.tscn',target_review/'EmbarkBoatsReview.tscn')
    def run_godot(args):
        run=subprocess.run([str(GODOT),'--headless','--path',str(project),*args],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
        if run.returncode or 'SCRIPT ERROR' in run.stdout+run.stderr or 'ERROR:' in run.stderr:
            print(run.stdout); print(run.stderr); raise RuntimeError('Godot validation failed')
        print(run.stdout[-1600:])
    run_godot(['--editor','--import'])
    for e in manifest['assets']:
        settings=(project/e['glb']).with_suffix('.glb.import')
        text=settings.read_text(encoding='utf-8')
        text=re.sub(r'^import_script/path=.*$', 'import_script/path="res://'+import_script.as_posix()+'"',text,flags=re.M)
        text=re.sub(r'^animation/fps=.*$', 'animation/fps=30',text,flags=re.M)
        settings.write_text(text,encoding='utf-8')
    run_godot(['--editor','--import'])
    run_godot(['--script','res://verify.gd'])
    for args in (['res://scenes/art_review/EmbarkBoatsReview.tscn','--quit-after','2'],['res://scenes/art_review/EmbarkBoatsReview.tscn','--quit-after','2','--','--walk']):
        run_godot(args)
    report=json.loads((project/'godot_validation.json').read_text(encoding='utf-8'))
    assert report['status']=='PASS' and len(report['assets'])==4
    (ROOT/'docs/embark_boats_godot_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    for e in manifest['assets']:
        settings=(project/e['glb']).with_suffix('.glb.import'); destination=(ROOT/e['glb']).with_suffix('.glb.import')
        text=settings.read_text(encoding='utf-8')
        if destination.exists():
            old_uid=re.search(r'^uid=.*$',destination.read_text(encoding='utf-8'),flags=re.M)
            if old_uid: text=re.sub(r'^uid=.*$',old_uid.group(0),text,flags=re.M)
        destination.write_text(text,encoding='utf-8')
    for path in (import_script,review_script):
        generated=(project/path).with_suffix('.gd.uid'); destination=(ROOT/path).with_suffix('.gd.uid')
        if generated.exists() and not destination.exists(): shutil.copy2(generated,destination)
print('EMBARK_BOATS_GODOT_PASS')
