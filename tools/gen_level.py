"""
Gera scenes/levels/test_house.tscn (a fase de teste) a partir de uma
descrição simples em caixas. Depois de gerada, a cena pode ser editada
normalmente no Godot — este script só existe para montar a primeira versão.

Uso:  python tools/gen_level.py
"""
from __future__ import annotations

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scenes", "levels", "test_house.tscn")

H = 2.6  # altura do pé-direito
T = 0.2  # espessura das paredes

# (nome, centro (x,y,z), tamanho (x,y,z), material)
boxes: list[tuple[str, tuple, tuple, str]] = []


def box(name, c, s, mat):
    boxes.append((name, c, s, mat))


def wall(name, c, s):
    box(name, c, s, "wall")


# ---------------------------------------------------------------- QUARTO (início)
box("Bedroom_Floor", (0, -0.1, 2), (4.4, 0.2, 4.4), "floor")
box("Bedroom_Ceiling", (0, H + 0.1, 2), (4.4, 0.2, 4.4), "ceiling")
wall("Bedroom_WallS", (0, H / 2, 4.1), (4.4, H, T))
wall("Bedroom_WallW", (-2.1, H / 2, 2), (T, H, 4.4))
wall("Bedroom_WallE", (2.1, H / 2, 2), (T, H, 4.4))
# parede norte com vão da porta (x de -0.45 a 0.45)
wall("Bedroom_WallN_L", (-1.325, H / 2, -0.1), (1.75, H, T))
wall("Bedroom_WallN_R", (1.325, H / 2, -0.1), (1.75, H, T))
wall("Bedroom_WallN_Top", (0, 2.05 + (H - 2.05) / 2, -0.1), (0.9, H - 2.05, T))
# móveis
box("Bed", (-1.25, 0.25, 2.9), (1.3, 0.5, 2.0), "furniture")
box("Bed_Head", (-1.25, 0.6, 3.95), (1.3, 1.2, 0.1), "furniture")
box("Nightstand", (-0.25, 0.3, 3.7), (0.45, 0.6, 0.4), "furniture")
box("Wardrobe", (1.65, 1.0, 3.2), (0.6, 2.0, 1.2), "furniture")

# ---------------------------------------------------------------- CORREDOR
box("Hall_Floor", (0, -0.1, -7.2), (2.0, 0.2, 14.4), "floor")
box("Hall_Ceiling", (0, H + 0.1, -7.2), (2.0, 0.2, 14.4), "ceiling")
# parede oeste com porta trancada em z = -9 (vão de -9.45 a -8.55)
wall("Hall_WallW_A", (-0.9, H / 2, -4.325), (T, H, 8.45))
wall("Hall_WallW_B", (-0.9, H / 2, -11.875), (T, H, 4.85))
wall("Hall_WallW_Top", (-0.9, 2.05 + (H - 2.05) / 2, -9.0), (T, H - 2.05, 0.9))
# parede leste com passagem pra cozinha (z de -13.8 a -12.2)
wall("Hall_WallE_A", (0.9, H / 2, -6.15), (T, H, 12.1))
wall("Hall_WallE_B", (0.9, H / 2, -14.0), (T, H, 0.4))
wall("Hall_WallE_Top", (0.9, 2.2 + (H - 2.2) / 2, -13.0), (T, H - 2.2, 1.6))
wall("Hall_WallN", (0, H / 2, -14.3), (2.0, H, T))
# uma cômoda no corredor
box("Hall_Dresser", (0.6, 0.45, -5.5), (0.4, 0.9, 1.0), "furniture")

# ---------------------------------------------------------------- COZINHA
box("Kitchen_Floor", (3.0, -0.1, -13.0), (4.2, 0.2, 6.4), "tile")
box("Kitchen_Ceiling", (3.0, H + 0.1, -13.0), (4.2, 0.2, 6.4), "ceiling")
wall("Kitchen_WallN", (3.0, H / 2, -16.1), (4.4, H, T))
wall("Kitchen_WallS", (3.0, H / 2, -9.9), (4.4, H, T))
wall("Kitchen_WallE", (5.1, H / 2, -13.0), (T, H, 6.4))
wall("Kitchen_WallW", (0.9, H / 2, -15.15), (T, H, 1.7))
box("Kitchen_Table", (3.1, 0.75, -13.2), (1.4, 0.06, 0.8), "furniture")
box("Kitchen_TableLeg1", (2.5, 0.36, -12.9), (0.06, 0.72, 0.06), "furniture")
box("Kitchen_TableLeg2", (3.7, 0.36, -12.9), (0.06, 0.72, 0.06), "furniture")
box("Kitchen_TableLeg3", (2.5, 0.36, -13.5), (0.06, 0.72, 0.06), "furniture")
box("Kitchen_TableLeg4", (3.7, 0.36, -13.5), (0.06, 0.72, 0.06), "furniture")
box("Kitchen_Counter", (3.3, 0.45, -15.65), (3.0, 0.9, 0.7), "furniture")
box("Kitchen_Fridge", (4.6, 0.9, -15.6), (0.7, 1.8, 0.7), "metal")

# ---------------------------------------------------------------- escrita da cena
MATERIALS = {
    "wall": ("res://assets/textures/wallpaper_dirty.png", (1, 1, 1), 0.5),
    "floor": ("res://assets/textures/wood_floor.png", (1, 1, 1), 0.6),
    "ceiling": ("res://assets/textures/ceiling_stained.png", (0.9, 0.9, 0.85), 0.5),
    "furniture": ("res://assets/textures/wood_floor.png", (0.6, 0.55, 0.5), 1.2),
    "tile": ("res://assets/textures/concrete.png", (0.8, 0.85, 0.8), 0.7),
    "metal": ("res://assets/textures/concrete.png", (0.75, 0.75, 0.72), 1.0),
}


def f(v):
    return f"{v:g}"


def v3(t):
    return f"Vector3({f(t[0])}, {f(t[1])}, {f(t[2])})"


def xform(p, rot_y_deg=0.0):
    import math

    c, s = math.cos(math.radians(rot_y_deg)), math.sin(math.radians(rot_y_deg))
    # Godot escreve a base por linhas.
    return (
        f"Transform3D({f(round(c, 5))}, 0, {f(round(s, 5))}, 0, 1, 0, {f(round(-s, 5) + 0.0)}, 0, {f(round(c, 5))}, "
        f"{f(p[0])}, {f(p[1])}, {f(p[2])})"
    )


ext = []  # (type, path, id)
sub = []  # texto
nodes = []


def ext_res(typ, path):
    for t, p, i in ext:
        if p == path:
            return i
    i = f"{len(ext) + 1}_{os.path.splitext(os.path.basename(path))[0]}"
    ext.append((typ, path, i))
    return i


shader_id = ext_res("Shader", "res://shaders/psx_world.gdshader")
mat_ids = {}
for key, (tex, tint, tiles) in MATERIALS.items():
    tex_id = ext_res("Texture2D", tex)
    mid = f"Mat_{key}"
    mat_ids[key] = mid
    sub.append(
        f'[sub_resource type="ShaderMaterial" id="{mid}"]\n'
        f'render_priority = 0\n'
        f'shader = ExtResource("{shader_id}")\n'
        f'shader_parameter/albedo_tex = ExtResource("{tex_id}")\n'
        f"shader_parameter/tint = Color({f(tint[0])}, {f(tint[1])}, {f(tint[2])}, 1)\n"
        f"shader_parameter/tiles_per_meter = {f(tiles)}\n"
        f"shader_parameter/snap_resolution = Vector2(480, 270)\n"
        f"shader_parameter/vertex_snap = true\n"
    )

script_id = ext_res("Script", "res://scripts/levels/test_house.gd")
player_id = ext_res("PackedScene", "res://scenes/player/player.tscn")
door_id = ext_res("PackedScene", "res://scenes/world/door.tscn")
figure_id = ext_res("PackedScene", "res://scenes/world/figure.tscn")
eco_seated_id = ext_res("PackedScene", "res://scenes/world/eco_seated.tscn")
light_script = ext_res("Script", "res://scripts/world/flicker_light.gd")
trigger_script = ext_res("Script", "res://scripts/world/scare_trigger.gd")
pickup_script = ext_res("Script", "res://scripts/world/battery_pickup.gd")
snd_buzz = ext_res("AudioStream", "res://assets/audio/light_buzz_loop.wav")
snd_pop = ext_res("AudioStream", "res://assets/audio/bulb_pop.wav")
snd_amb = ext_res("AudioStream", "res://assets/audio/ambient_drone_loop.wav")
snd_pick = ext_res("AudioStream", "res://assets/audio/pickup.wav")

sub.append(
    '[sub_resource type="Environment" id="Env"]\n'
    "background_mode = 1\n"
    "background_color = Color(0, 0, 0, 1)\n"
    "ambient_light_source = 2\n"
    "ambient_light_color = Color(0.12, 0.12, 0.15, 1)\n"
    "ambient_light_energy = 0.25\n"
    "tonemap_mode = 2\n"
    "tonemap_exposure = 1.1\n"
    "glow_enabled = true\n"
    "glow_intensity = 0.6\n"
    "glow_bloom = 0.05\n"
    "fog_enabled = true\n"
    "fog_light_color = Color(0, 0, 0, 1)\n"
    "fog_density = 0.06\n"
    "volumetric_fog_enabled = true\n"
    "volumetric_fog_density = 0.035\n"
    "volumetric_fog_albedo = Color(0.7, 0.7, 0.68, 1)\n"
    "volumetric_fog_length = 24.0\n"
    "volumetric_fog_anisotropy = 0.4\n"
)
sub.append(
    '[sub_resource type="StandardMaterial3D" id="Mat_bulb"]\n'
    "shading_mode = 0\n"
    "albedo_color = Color(1, 0.95, 0.8, 1)\n"
    "emission_enabled = true\n"
    "emission = Color(1, 0.9, 0.7, 1)\n"
    "emission_energy_multiplier = 3.0\n"
)
sub.append('[sub_resource type="SphereMesh" id="Mesh_bulb"]\nradius = 0.05\nheight = 0.1\nradial_segments = 6\nrings = 3\n')
sub.append('[sub_resource type="CylinderMesh" id="Mesh_cord"]\ntop_radius = 0.006\nbottom_radius = 0.006\nheight = 0.2\nradial_segments = 4\n')
sub.append(
    '[sub_resource type="StandardMaterial3D" id="Mat_battery"]\n'
    "albedo_color = Color(0.7, 0.55, 0.15, 1)\nroughness = 0.6\n"
)
sub.append(
    '[sub_resource type="CylinderMesh" id="Mesh_battery"]\nmaterial = SubResource("Mat_battery")\n'
    "top_radius = 0.016\nbottom_radius = 0.016\nheight = 0.06\nradial_segments = 6\n"
)
sub.append('[sub_resource type="BoxShape3D" id="Shape_battery"]\nsize = Vector3(0.15, 0.08, 0.15)\n')
triggers = {
    "KnockTrigger": ((0, 1, -7.6), (1.6, 2, 0.8)),
    "HallwayScare": ((0, 1, -10.4), (1.6, 2, 0.8)),
    "KitchenEnter": ((2.0, 1, -13.0), (0.8, 2, 1.6)),
    # Área da cozinha inteira: o som some enquanto o jogador está aqui.
    "KitchenSilence": ((3.0, 1, -13.0), (3.9, 2, 5.9)),
}
for name, (_, size) in triggers.items():
    sub.append(f'[sub_resource type="BoxShape3D" id="Shape_{name}"]\nsize = {v3(size)}\n')

# --- nós
nodes.append(f'[node name="TestHouse" type="Node3D"]\nscript = ExtResource("{script_id}")\n')
nodes.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("Env")\n')
nodes.append(
    f'[node name="Ambience" type="AudioStreamPlayer" parent="."]\nstream = ExtResource("{snd_amb}")\n'
    "volume_db = -10.0\nautoplay = true\n"
)

nodes.append('[node name="Geometry" type="Node3D" parent="."]\n')
for name, c, s, mat in boxes:
    nodes.append(
        f'[node name="{name}" type="CSGBox3D" parent="Geometry"]\n'
        f"transform = {xform(c)}\n"
        "use_collision = true\n"
        f"size = {v3(s)}\n"
        f'material = SubResource("{mat_ids[mat]}")\n'
    )

# Jogador começa no quarto, de frente pra porta (-Z).
nodes.append(f'[node name="Player" parent="." instance=ExtResource("{player_id}")]\ntransform = {xform((0.3, 0.05, 2.6))}\n')

nodes.append('[node name="Doors" type="Node3D" parent="."]\n')
nodes.append(f'[node name="BedroomDoor" parent="Doors" instance=ExtResource("{door_id}")]\ntransform = {xform((0, 0, -0.1))}\n')
nodes.append(
    f'[node name="BasementDoor" parent="Doors" instance=ExtResource("{door_id}")]\n'
    f"transform = {xform((-0.9, 0, -9.0), 90)}\n"
    "locked = true\n"
)

nodes.append('[node name="Lights" type="Node3D" parent="."]\n')
lights = [
    # nome, posição, cor, energia, alcance, modo (0 estável, 1 ocasional, 2 forte), sombra
    ("BedLamp", (-0.25, 0.85, 3.7), (1.0, 0.6, 0.3), 0.6, 3.5, 1, False),
    ("HallLightA", (0, 2.3, -3.5), (1.0, 0.93, 0.72), 1.3, 6.0, 1, True),
    ("HallLightB", (0, 2.3, -11.2), (0.9, 0.95, 0.8), 1.0, 6.0, 0, True),
    ("KitchenLight", (3.1, 2.3, -13.2), (0.95, 0.9, 0.75), 0.55, 4.0, 0, True),
]
for name, p, col, energy, rng_, mode, shadow in lights:
    nodes.append(
        f'[node name="{name}" type="OmniLight3D" parent="Lights" node_paths=PackedStringArray("bulb")]\n'
        f"transform = {xform(p)}\n"
        f"light_color = Color({f(col[0])}, {f(col[1])}, {f(col[2])}, 1)\n"
        f"light_energy = {f(energy)}\n"
        f"shadow_enabled = {'true' if shadow else 'false'}\n"
        f"omni_range = {f(rng_)}\n"
        "omni_attenuation = 1.4\n"
        f'script = ExtResource("{light_script}")\n'
        f"base_energy = {f(energy)}\n"
        f"mode = {mode}\n"
        f'buzz_sound = ExtResource("{snd_buzz}")\n'
        f"buzz_volume_db = {'-24.0' if name == 'BedLamp' else '-14.0'}\n"
        f'pop_sound = ExtResource("{snd_pop}")\n'
        'bulb = NodePath("Bulb")\n'
    )
    nodes.append(
        f'[node name="Bulb" type="MeshInstance3D" parent="Lights/{name}"]\n'
        'mesh = SubResource("Mesh_bulb")\n'
        'surface_material_override/0 = SubResource("Mat_bulb")\n'
    )
    if name != "BedLamp":
        nodes.append(
            f'[node name="Cord" type="MeshInstance3D" parent="Lights/{name}"]\n'
            f"transform = {xform((0, 0.15, 0))}\n"
            'mesh = SubResource("Mesh_cord")\n'
        )

nodes.append(f'[node name="Figure" parent="." instance=ExtResource("{figure_id}")]\n')
# O Eco sentado: ponta da mesa da cozinha, de frente pra porta, mão no rosto.
nodes.append(
    f'[node name="EcoSeated" parent="." instance=ExtResource("{eco_seated_id}")]\n'
    f"transform = {xform((4.25, 0, -13.2), 90)}\n"
)

nodes.append('[node name="Markers" type="Node3D" parent="."]\n')
nodes.append(f'[node name="FigureEndOfHall" type="Marker3D" parent="Markers"]\ntransform = {xform((0, 0, -13.6))}\n')

nodes.append('[node name="Triggers" type="Node3D" parent="."]\n')
for name, (pos, _) in triggers.items():
    nodes.append(
        f'[node name="{name}" type="Area3D" parent="Triggers"]\n'
        f"transform = {xform(pos)}\n"
        f'script = ExtResource("{trigger_script}")\n'
    )
    nodes.append(f'[node name="Shape" type="CollisionShape3D" parent="Triggers/{name}"]\nshape = SubResource("Shape_{name}")\n')

nodes.append('[node name="Pickups" type="Node3D" parent="."]\n')
nodes.append(
    f'[node name="Batteries" type="StaticBody3D" parent="Pickups"]\n'
    f"transform = {xform((3.2, 0.81, -13.2))}\n"
    f'script = ExtResource("{pickup_script}")\n'
    f'pickup_sound = ExtResource("{snd_pick}")\n'
)
nodes.append('[node name="Shape" type="CollisionShape3D" parent="Pickups/Batteries"]\nshape = SubResource("Shape_battery")\n')
for i, (x, z) in enumerate([(-0.02, 0), (0.02, 0.01)]):
    nodes.append(
        f'[node name="Cell{i + 1}" type="MeshInstance3D" parent="Pickups/Batteries"]\n'
        f"transform = {xform((x, 0, z))}\n"
        'mesh = SubResource("Mesh_battery")\n'
    )

# --- montar
load_steps = len(ext) + len(sub) + 1
parts = [f"[gd_scene load_steps={load_steps} format=3]\n"]
parts += [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext]
parts.append("")
parts += sub
parts += nodes
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("\n".join(parts).rstrip() + "\n")
print("Cena gerada:", OUT, f"({len(boxes)} caixas)")
