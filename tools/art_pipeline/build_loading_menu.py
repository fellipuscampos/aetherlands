"""Code-native pixel loading assets and Godot scene; reuses the approved menu landscape."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/ui/loading'


def main():
    ART.mkdir(parents=True, exist_ok=True)
    (ART / 'progress_track.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="48" height="28">
<path fill="#06171d" d="M4 0H44V4H48V24H44V28H4V24H0V4H4Z"/>
<path fill="#788373" d="M4 4H44V24H4Z"/>
<path fill="#112a31" d="M8 8H40V20H8Z"/>
<path fill="#071a20" d="M8 16H40V20H8Z"/>
</svg>''', encoding='utf-8')
    (ART / 'progress_fill.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="48" height="28">
<path fill="#70532d" d="M4 4H44V24H4Z"/>
<path fill="#c6a365" d="M4 4H44V20H4Z"/>
<path fill="#f6d395" d="M4 4H44V8H4Z"/>
<path fill="#e6c083" d="M12 8H16V20H12ZM28 8H32V20H28Z" opacity=".3"/>
</svg>''', encoding='utf-8')
    (ART / 'veil.gdshader').write_text('''shader_type canvas_item;
render_mode unshaded;
void fragment() {
    float lower_band = smoothstep(0.42, 0.72, UV.y);
    float edge = smoothstep(0.28, 0.78, distance(UV, vec2(0.58, 0.40)));
    COLOR = vec4(vec3(0.025, 0.070, 0.087), clamp(0.12 + lower_band * 0.84 + edge * 0.22, 0.0, 0.98));
}
''', encoding='utf-8')
    scene = '''[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/ui/LoadingScreen.gd" id="Script"]
[ext_resource type="Script" path="res://scripts/ui/LoadingSpinner.gd" id="Spinner"]
[ext_resource type="Texture2D" path="res://assets/ui/title_menu/kingdom_landscape_painted.png" id="Landscape"]
[ext_resource type="Texture2D" path="res://assets/ui/title_menu/crest.svg" id="Crest"]
[ext_resource type="Shader" path="res://assets/ui/loading/veil.gdshader" id="Shader"]

[sub_resource type="ShaderMaterial" id="Veil"]
shader = ExtResource("Shader")

[node name="LoadingScreen" type="Control"]
layout_mode = 1
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
texture_filter = 1
script = ExtResource("Script")

[node name="Backdrop" type="TextureRect" parent="."]
layout_mode = 1
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("Landscape")
expand_mode = 1
stretch_mode = 6

[node name="Veil" type="ColorRect" parent="."]
layout_mode = 1
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
material = SubResource("Veil")

[node name="Brand" type="HBoxContainer" parent="."]
layout_mode = 0
mouse_filter = 2
theme_override_constants/separation = 16

[node name="Crest" type="TextureRect" parent="Brand"]
custom_minimum_size = Vector2(56,56)
layout_mode = 2
mouse_filter = 2
texture = ExtResource("Crest")
expand_mode = 1
stretch_mode = 5

[node name="Titles" type="VBoxContainer" parent="Brand"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 4

[node name="Name" type="Label" parent="Brand/Titles"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"SetupTitle"
text = "AETHERLANDS"

[node name="Kicker" type="Label" parent="Brand/Titles"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"SetupKicker"
text = "UM MUNDO ENTRE ERAS"

[node name="CenterBox" type="CenterContainer" parent="."]
layout_mode = 0
mouse_filter = 2

[node name="Box" type="VBoxContainer" parent="CenterBox"]
layout_mode = 2
custom_minimum_size = Vector2(640,0)
theme_override_constants/separation = 12
mouse_filter = 2

[node name="KickerLabel" type="Label" parent="CenterBox/Box"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"SetupKicker"
text = "PREPARANDO SUA JORNADA"

[node name="TitleLabel" type="Label" parent="CenterBox/Box"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"SetupTitle"
text = "Gerando o Mapa..."

[node name="DetailLabel" type="Label" parent="CenterBox/Box"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"SetupBody"
custom_minimum_size = Vector2(0,52)
vertical_alignment = 1
autowrap_mode = 3
text = "Preparando seu mundo."

[node name="ProgressRow" type="HBoxContainer" parent="CenterBox/Box"]
custom_minimum_size = Vector2(640,0)
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 20

[node name="ProgressBar" type="ProgressBar" parent="CenterBox/Box/ProgressRow"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
custom_minimum_size = Vector2(0,28)
mouse_filter = 2
show_percentage = false

[node name="PercentLabel" type="Label" parent="CenterBox/Box/ProgressRow"]
layout_mode = 2
custom_minimum_size = Vector2(100,0)
mouse_filter = 2
theme_type_variation = &"SetupHeading"
horizontal_alignment = 2
vertical_alignment = 1
text = "0%"

[node name="Footer" type="HBoxContainer" parent="."]
layout_mode = 0
mouse_filter = 2
theme_override_constants/separation = 20

[node name="Emblem" type="Control" parent="Footer"]
layout_mode = 2
custom_minimum_size = Vector2(64,64)
mouse_filter = 2
script = ExtResource("Spinner")

[node name="FooterText" type="VBoxContainer" parent="Footer"]
layout_mode = 2
alignment = 1
mouse_filter = 2
theme_override_constants/separation = 6

[node name="SubtitleLabel" type="Label" parent="Footer/FooterText"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"SetupKicker"
text = "QUATRO POVOS. UM MUNDO A CONQUISTAR."

[node name="LoadLimitLabel" type="Label" parent="Footer/FooterText"]
layout_mode = 2
mouse_filter = 2
theme_type_variation = &"SetupMuted"
text = "Sua próxima era está prestes a começar."
'''
    (ROOT / 'scenes/ui/LoadingScreen.tscn').write_text(scene, encoding='utf-8')


if __name__ == '__main__':
    main()
