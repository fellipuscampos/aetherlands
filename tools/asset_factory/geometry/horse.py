"""
Cavalo decorativo (pedido do usuario: "faça um modelo de cavalo pra usar
nos tiles com o recurso cavalo", explicitamente pela pipeline de verdade
da Asset Factory/Blender, nao o box cru direto em GDScript que ja existe
-- ver ResourcePropsManager.gd::_build_horses_mesh, mantido pra outros
recursos e agora substituido SO pra "horses").

Decoracao ESTATICA de terreno: nunca se move nem luta (Unit.gd e o UNICO
consumidor de rig/skinning/animacao deste projeto) -- entao, ao contrario
do resto da Asset Factory (personagens biepdes com esqueleto de 18 ossos),
este modulo nao usa character/params.py nem rig/*/animation/* nenhum, so
geometry/primitives.py (box/wedge/strap).

v2 (pedido do usuario: "o cavalo ficou horroroso" com screenshot mostrando
2 cavalos sobrepostos, pernas finas demais tipo aranha/inseto e um
pescoco em "escadinha" de caixas pequenas desconexas) -- reescrito do
zero com poucas pecas GRANDES em vez de muitas pequenas empilhadas:
pescoco e cabeca agora sao 1 caixa diagonal cada (via prim.strap, que
constroi uma caixa entre 2 pontos 3D quaisquer -- da o angulo real
pescoco->cabeca sem precisar de "escada" nenhuma), pernas bem mais
grossas, torso mais alto/solido. So 1 cavalo por glb agora (era uma
"manada" de 2 sobrepostos, pedido explicito do usuario pra reduzir).
"""

import bpy

from geometry import primitives as prim


def _make_material(name, color, roughness=0.7):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    for spec_key in ("Specular IOR Level", "Specular"):
        if spec_key in bsdf.inputs:
            bsdf.inputs[spec_key].default_value = 0.2
            break
    mat.diffuse_color = (*color, 1.0)
    return mat


def _perp_up_offset(p1, p2, magnitude):
    """Desloca perpendicularmente ao segmento p1->p2, na mesma direcao
    "de cima" (right x axis) que prim.strap usa internamente pra
    construir a caixa em si -- usado pra colar a juba goela acima do
    pescoco (mesmo eixo chest_pt->poll_pt) sem depender de deltas Y/Z
    chutados a mao, que na 1a tentativa deixaram a juba flutuando longe
    da malha do pescoco em vez de colada nela."""
    import math
    ax, ay, az = (p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2])
    length = math.sqrt(ax * ax + ay * ay + az * az)
    ax, ay, az = ax / length, ay / length, az / length
    # right = axis x (0,0,1)
    rx, ry, rz = ay, -ax, 0.0
    rlen = math.sqrt(rx * rx + ry * ry + rz * rz) or 1.0
    rx, ry, rz = rx / rlen, ry / rlen, rz / rlen
    # depth_dir = right x axis (mesma formula de primitives.py::strap)
    dx = ry * az - rz * ay
    dy = rz * ax - rx * az
    dz = rx * ay - ry * ax
    return (dx * magnitude, dy * magnitude, dz * magnitude)


def _rotate_xy(v, angle):
    """Gira (x, y) ao redor de Z, mesma formula de ResourcePropsManager.gd
    _rotate_xz (ali chamada assim porque aquele arquivo usa Y-up; aqui,
    Blender e Z-up, entao o plano de giro e XY)."""
    import math
    c, s = math.cos(angle), math.sin(angle)
    x, y, z = v
    return (x * c - y * s, x * s + y * c, z)


def build_horse_parts(coat_color=(0.45, 0.29, 0.15), mane_color=(0.16, 0.12, 0.09),
                       hoof_color=(0.08, 0.06, 0.05), scale=1.0, offset=(0.0, 0.0, 0.0), yaw=0.0):
    """Devolve a lista de objetos Blender (ainda NAO unidos) de UM cavalo
    de pe, virado pra +Y antes de `yaw` girar. `scale` reescala toda
    medida abaixo (proporcao fixa); `offset`/`yaw` posicionam e viram o
    cavalo inteiro."""
    coat = _make_material("horse_coat", coat_color)
    mane = _make_material("horse_mane", mane_color, roughness=0.85)
    hoof = _make_material("horse_hoof", hoof_color, roughness=0.5)

    parts = []

    def place(local_pos):
        scaled = tuple(v * scale for v in local_pos)
        rotated = _rotate_xy(scaled, yaw)
        return tuple(a + b for a, b in zip(rotated, offset))

    def add_box(name, size, local_center, material):
        obj = prim.box(name, tuple(v * scale for v in size), place(local_center))
        prim.assign_material(obj, material)
        parts.append(obj)
        return obj

    def add_wedge(name, size, local_center, material, taper=0.35):
        scaled_size = tuple(v * scale for v in size)
        obj = prim.wedge(name, scaled_size, place(local_center), taper=taper)
        prim.assign_material(obj, material)
        parts.append(obj)
        return obj

    def add_strap(name, local_p1, local_p2, width, depth, material):
        obj = prim.strap(name, place(local_p1), place(local_p2), width * scale, depth * scale)
        prim.assign_material(obj, material)
        parts.append(obj)
        return obj

    # --- medidas base (metros, cavalo real ~1.5m na cernelha) -----------
    # Pernas bem mais grossas que a v1 (0.16 de secao, era 0.085 -- a v1
    # lia como pernas de aranha/inseto, nao de cavalo) e torso mais alto
    # (0.46, era 0.42) pra ficar solido/chunky como o estilo de referencia.
    leg_h = 1.27  # chao ate a barriga
    hoof_h = 0.14
    leg_w = 0.16
    hoof_w = 0.20
    body_len, body_h, body_w = 1.35, 0.46, 0.46
    withers_z = leg_h + body_h * 0.5  # 1.50

    # Pernas + cascos: 4 cantos, caixa reta (decoracao parada, sem
    # junta/animacao nenhuma precisa dobrar) -- leg box sobrepoe a metade
    # de cima do casco (sem gap na junta), casco mais largo/escuro na
    # ponta pra separar visualmente do pelo.
    leg_box_h = leg_h - hoof_h * 0.5
    leg_center_z = hoof_h * 0.5 + leg_box_h * 0.5
    hoof_center_z = hoof_h * 0.5
    leg_x = body_w * 0.5 - 0.05
    for side_x in (-leg_x, leg_x):
        for side_y in (body_len * 0.34, -body_len * 0.34):
            add_box("Leg", (leg_w, leg_w, leg_box_h), (side_x, side_y, leg_center_z), coat)
            add_box("Hoof", (hoof_w, hoof_w, hoof_h), (side_x, side_y, hoof_center_z), hoof)

    # Torso -- 1 caixa solida.
    add_box("Torso", (body_w, body_len, body_h), (0.0, 0.0, withers_z), coat)

    # Pescoco + cabeca: 2 caixas DIAGONAIS via prim.strap (caixa real entre
    # 2 pontos 3D, ja com a rotacao certa embutida) em vez da "escada" de
    # caixas pequenas da v1 -- da o angulo peito->cabeca de um cavalo de
    # verdade com só 2 pecas grandes, sem junta visivel quebrada.
    # poll = topo do pescoco/base do craneo (ponto mais alto da cabeca,
    # onde as orelhas nascem). Cabeca desce E avanca do poll ate o focinho
    # (perfil alerta real de cavalo: testa->nariz inclina pra BAIXO, nao
    # pra cima -- primeira tentativa subia e lia como pescoco de ganso).
    chest_pt = (0.0, body_len * 0.5 - 0.08, withers_z + body_h * 0.22)
    poll_pt = (0.0, body_len * 0.5 + 0.40, withers_z + 0.68)
    muzzle_pt = (0.0, poll_pt[1] + 0.36, poll_pt[2] - 0.12)

    add_strap("Neck", chest_pt, poll_pt, 0.30, 0.30, coat)
    add_strap("Head", poll_pt, muzzle_pt, 0.28, 0.30, coat)

    # Focinho escuro bem NA ponta da cabeca (quase sem avancar alem de
    # muzzle_pt) -- avancar demais deixa a caixa (eixo reto) flutuando
    # alem da tampa da caixa diagonal da cabeca, que e o que aconteceu na
    # tentativa anterior.
    nose_c = (0.0, muzzle_pt[1] + 0.03, muzzle_pt[2] - 0.02)
    add_box("Nose", (0.18, 0.12, 0.14), nose_c, hoof)

    # Orelhas: wedge (afina em +Z) bem no poll (ponto mais alto da
    # cabeca), apontando pra cima.
    ear_z = poll_pt[2] + 0.08
    for side_x in (-0.075, 0.075):
        add_wedge("Ear", (0.06, 0.09, 0.18), (side_x, poll_pt[1] - 0.02, ear_z), coat, taper=0.15)

    # Juba: fileira de 3 caixas GRANDES (nao muitos cubos pequenos, nao 1
    # unica prancha diagonal -- a prancha unica (1a tentativa) lia como
    # uma aba/vela solta ao lado do pescoco em vez de pelo, porque uma
    # caixa reta perfeitamente diagonal e paralela ao pescoco fica FINA
    # DEMAIS visualmente de perfil; poucas caixas retas maiores, uma por
    # "tufo", leem melhor como pelo grosso na mesma tecnica ja usada no
    # Dragao -- ver memoria "several small boxes... implied by a
    # staircase") ao longo da crista do pescoco/nuca, deslocadas por
    # _perp_up_offset (mesma direcao "de cima" que prim.strap usa) pra
    # ficarem embutidas na superficie de cima do pescoco, nao flutuando.
    mane_offset = _perp_up_offset(chest_pt, poll_pt, 0.13)
    for i, t in enumerate((0.1, 0.45, 0.8)):
        base = tuple(a + (b - a) * t for a, b in zip(chest_pt, poll_pt))
        center = tuple(a + b for a, b in zip(base, mane_offset))
        shrink = 1.0 - 0.12 * i
        add_box("Mane", (0.13 * shrink, 0.16, 0.17 * shrink), center, mane)

    # Rabo: 1 caixa diagonal caindo da garupa pra tras/baixo (nao mais 2
    # segmentos empilhados finos).
    tail_p1 = (0.0, -body_len * 0.5 - 0.02, withers_z + 0.02)
    tail_p2 = (0.0, tail_p1[1] - 0.14, tail_p1[2] - 0.75)
    add_strap("Tail", tail_p1, tail_p2, 0.16, 0.18, mane)

    return parts
