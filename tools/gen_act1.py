"""
Gera scenes/levels/act1_trilha.tscn (Ato 1 — A Trilha).

Uso:  python tools/gen_act1.py

O terreno e a floresta são gerados pelo próprio Godot (scripts @tool),
então esta cena só guarda a "planta": trilha, clareiras, construções,
gatilhos e marcadores. Alturas (y) são ajustadas ao chão quando a fase
carrega (grupo "snap_ground"), por isso aqui quase tudo tem y = 0.
"""
from __future__ import annotations

import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scenes", "levels", "act1_trilha.tscn")

# ------------------------------------------------------------------ planta (x, z)
# Frente do jogador = -Z ("norte"). O sítio fica no sul, o barranco no norte.
PATH = [
    (0, 88), (0, 78), (3, 66), (-4, 53), (-8, 42), (-5, 28), (3, 16), (9, 5),
    (6, -6), (-2, -18), (-6, -31), (2, -44), (6, -55), (2, -64), (0, -69.6),
    # lá embaixo, depois da queda
    (0, -76), (8, -86), (20, -95), (32, -101),
]
SITIO = (0.0, 84.0)
SHED = (-15.0, 40.0)
CLEARINGS = [(SITIO[0], SITIO[1], 17.0), (SHED[0], SHED[1], 5.5), (1.0, -76.0, 4.0)]
CLIFF_Z = -70.0
ECO_SPOT = (25.0, 2.0)
SIGHTLINE = [(9.0, 7.0), ECO_SPOT]

MARKERS = {
    # nome: (x, z, yaw em graus, altura acima do chão)
    "Start": (0.0, 88.4, 0.0, 0.35),
    "DogGate": (0.0, 74.0, 0.0, 0.0),
    "DogFar": (12.0, -30.0, 0.0, 0.0),
    "ChaseCheckpoint": (6.0, -6.0, 0.0, 0.1),
    "CoisaSpawn": (9.0, 6.0, 0.0, 0.0),
    "Wake": (0.8, -75.2, 180.0, 0.1),
    "BarkEnd": (34.0, -102.0, 0.0, 1.0),
}
DOG_LEAD = [(3.0, 64.0), (-4.0, 51.0), (-11.0, 37.0), (-5.0, 27.0), (3.0, 15.0)]

TRIGGERS = {
    # nome: (x, z, (tam x, tam y, tam z), yaw)
    "ForestEdge": (2.0, 68.0, (9, 3, 2), 0),
    "StalkerOff": (-8.0, 47.0, (9, 3, 2), 0),
    "Blood": (-9.0, 42.5, (3.5, 3, 3.5), 0),
    "ShedInside": (-15.6, 40.0, (2.6, 2.6, 3.2), 0),
    "EcoSight": (7.0, 10.0, (11, 3, 2), 0),
    "Chase": (5.0, -9.0, (11, 3, 2), 0),
    "Fall": (0.0, -69.2, (232, 14, 1.4), 0),
    "End": (30.0, -100.0, (7, 3, 7), 0),
}
BLOOD = [(-8.6, 43.4), (-9.6, 42.6), (-10.7, 41.9), (-11.7, 41.2), (-12.6, 40.8), (-13.5, 40.4), (-14.4, 40.1)]


# ------------------------------------------------------------------ utilidades

def f(v):
    v = round(float(v), 5) + 0.0
    return f"{v:g}"


def v3(t):
    return f"Vector3({f(t[0])}, {f(t[1])}, {f(t[2])})"


def basis_rows(yaw_deg=0.0, pitch_deg=0.0, scale=1.0):
    """Linhas da base = Ry(yaw) * Rx(pitch) (ordem do Godot), como o .tscn guarda."""
    cy, sy = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
    cp, sp = math.cos(math.radians(pitch_deg)), math.sin(math.radians(pitch_deg))
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rx = [[1, 0, 0], [0, cp, -sp], [0, sp, cp]]
    m = [[sum(ry[i][k] * rx[k][j] for k in range(3)) * scale for j in range(3)] for i in range(3)]
    return [m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2]]


def xform(p, yaw=0.0, pitch=0.0, scale=1.0):
    b = basis_rows(yaw, pitch, scale)
    return "Transform3D(" + ", ".join(f(x) for x in b) + f", {f(p[0])}, {f(p[1])}, {f(p[2])})"


ext = []
sub = []
nodes = []


def ext_res(typ, path):
    for t, p, i in ext:
        if p == path:
            return i
    i = f"{len(ext) + 1}_{os.path.splitext(os.path.basename(path))[0]}"
    ext.append((typ, path, i))
    return i


def node(name, typ, parent=".", props=None, groups=None, instance=None, meta=None):
    head = f'[node name="{name}"'
    if typ:
        head += f' type="{typ}"'
    if parent is not None:
        head += f' parent="{parent}"'
    if instance:
        head += f' instance=ExtResource("{instance}")'
    if groups:
        head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
    head += "]"
    lines = [head]
    for k, v in (props or {}).items():
        lines.append(f"{k} = {v}")
    for k, v in (meta or {}).items():
        lines.append(f"metadata/{k} = {v}")
    nodes.append("\n".join(lines) + "\n")


def psx_mat(mid, tex, tint, tiles):
    sub.append(
        f'[sub_resource type="ShaderMaterial" id="{mid}"]\n'
        f'shader = ExtResource("{ext_res("Shader", "res://shaders/psx_world.gdshader")}")\n'
        f'shader_parameter/albedo_tex = ExtResource("{ext_res("Texture2D", tex)}")\n'
        f"shader_parameter/tint = Color({f(tint[0])}, {f(tint[1])}, {f(tint[2])}, 1)\n"
        f"shader_parameter/tiles_per_meter = {f(tiles)}\n"
        f"shader_parameter/snap_resolution = Vector2(480, 270)\n"
        f"shader_parameter/vertex_snap = true\n"
    )


def csg(name, parent, center, size, mat, yaw=0.0):
    node(name, "CSGBox3D", parent, {
        "transform": xform(center, yaw),
        "use_collision": "true",
        "size": v3(size),
        "material": f'SubResource("{mat}")',
    })


# ------------------------------------------------------------------ recursos
script_id = ext_res("Script", "res://scripts/levels/act1.gd")
terrain_script = ext_res("Script", "res://scripts/world/forest_terrain.gd")
scatter_script = ext_res("Script", "res://scripts/world/forest_scatter.gd")
rig_script = ext_res("Script", "res://scripts/world/eco_rig.gd")
trigger_script = ext_res("Script", "res://scripts/world/scare_trigger.gd")
light_script = ext_res("Script", "res://scripts/world/flicker_light.gd")
owl_script = ext_res("Script", "res://scripts/world/owl.gd")
stalker_script = ext_res("Script", "res://scripts/systems/stalker_sound.gd")
bump_script = ext_res("Script", "res://scripts/systems/eco_bump.gd")
player_scene = ext_res("PackedScene", "res://scenes/player/player.tscn")
dog_scene = ext_res("PackedScene", "res://scenes/world/dog.tscn")
coisa_scene = ext_res("PackedScene", "res://scenes/world/coisa_funda.tscn")
terrain_shader = ext_res("Shader", "res://shaders/psx_terrain.gdshader")
tex = {k: ext_res("Texture2D", f"res://assets/textures/{k}.png") for k in
       ["dirt_path", "bark", "foliage", "grass_tuft", "bush", "blood_decal"]}
tex["forest_floor"] = ext_res("Texture2D", "res://assets/textures/forest_ground.jpg")
flee_script = ext_res("Script", "res://scripts/world/animal_flee.gd")
deer_scene = ext_res("PackedScene", "res://assets/models/animals/Deer.gltf")


def model(name):
    return ext_res("PackedScene", f"res://assets/models/nature/{name}.gltf")


# (modelo, peso, escala mín, escala máx, raio do tronco)
TREES = (
    [(f"Pine_{i}", 0.11, 0.9, 1.35, 0.28) for i in range(1, 6)]
    + [(f"CommonTree_{i}", 0.05, 0.9, 1.25, 0.3) for i in range(1, 6)]
    + [(f"DeadTree_{i}", 0.055, 0.5, 0.75, 0.32) for i in range(1, 6)]
    + [(f"TwistedTree_{i}", 0.02, 0.45, 0.6, 0.45) for i in (1, 3, 5)]
)
# Bush_Common precisa ser o primeiro (vira os arbustos da beira do barranco).
PLANTS = [("Bush_Common", 0.3, 0.7, 1.3), ("Fern_1", 0.3, 0.18, 0.3), ("Plant_1_Big", 0.14, 0.3, 0.55),
          ("Plant_7_Big", 0.16, 0.6, 1.0), ("Mushroom_Common", 0.1, 0.4, 0.8)]
GRASS = [("Grass_Wispy_Short", 0.5, 0.8), ("Grass_Wispy_Tall", 0.35, 0.6), ("Grass_Common_Tall", 0.4, 0.7)]
ROCKS = [("Rock_Medium_1", 0.25, 0.8), ("Rock_Medium_2", 0.25, 0.8), ("Rock_Medium_3", 0.2, 0.7)]
DEER = [(9.0, 60.0, 200.0), (-13.0, 24.0, 60.0)]


def scenes_array(items):
    return "Array[PackedScene]([" + ", ".join(f'ExtResource("{model(it[0])}")' for it in items) + "])"


def floats(vals):
    return "PackedFloat32Array(" + ", ".join(f(v) for v in vals) + ")"


def vec2s(pairs):
    return "PackedVector2Array(" + ", ".join(f"{f(a)}, {f(b)}" for a, b in pairs) + ")"
snd = {k: ext_res("AudioStream", f"res://assets/audio/{k}.wav") for k in
       ["forest_night_loop", "bush_rustle", "branch_crack", "owl_screech", "wing_flaps",
        "impact_thud", "tinnitus", "light_buzz_loop", "bulb_pop", "dog_bark_1"]}

sub.append(
    '[sub_resource type="ShaderMaterial" id="Mat_terrain"]\n'
    f'shader = ExtResource("{terrain_shader}")\n'
    f'shader_parameter/floor_tex = ExtResource("{tex["forest_floor"]}")\n'
    f'shader_parameter/path_tex = ExtResource("{tex["dirt_path"]}")\n'
    "shader_parameter/floor_tint = Color(0.72, 0.7, 0.66, 1)\n"
    "shader_parameter/path_tint = Color(0.85, 0.82, 0.78, 1)\n"
    "shader_parameter/cliff_tint = Color(0.6, 0.55, 0.5, 1)\n"
    "shader_parameter/tiles_per_meter = 0.3\n"
    "shader_parameter/snap_resolution = Vector2(480, 270)\n"
    "shader_parameter/vertex_snap = true\n"
)
psx_mat("Mat_house", "res://assets/textures/wood_floor.png", (0.62, 0.58, 0.52), 0.5)
psx_mat("Mat_roof", "res://assets/textures/concrete.png", (0.32, 0.3, 0.28), 0.4)
psx_mat("Mat_fence", "res://assets/textures/door_wood.png", (0.6, 0.55, 0.5), 0.8)
psx_mat("Mat_shed", "res://assets/textures/wood_floor.png", (0.45, 0.4, 0.36), 0.6)
psx_mat("Mat_door", "res://assets/textures/door_wood.png", (0.7, 0.65, 0.6), 1.0)
sub.append(
    '[sub_resource type="StandardMaterial3D" id="Mat_window"]\n'
    "albedo_color = Color(1, 0.75, 0.4, 1)\n"
    "emission_enabled = true\n"
    "emission = Color(1, 0.7, 0.35, 1)\n"
    "emission_energy_multiplier = 1.6\n"
)
sub.append(
    '[sub_resource type="StandardMaterial3D" id="Mat_blood"]\n'
    "transparency = 1\n"
    f'albedo_texture = ExtResource("{tex["blood_decal"]}")\n'
    "texture_filter = 0\n"
)
sub.append('[sub_resource type="QuadMesh" id="Mesh_blood"]\nmaterial = SubResource("Mat_blood")\nsize = Vector2(0.7, 0.7)\n')
sub.append(
    '[sub_resource type="StandardMaterial3D" id="Mat_bulb"]\nshading_mode = 0\n'
    "albedo_color = Color(1, 0.9, 0.7, 1)\nemission_enabled = true\nemission = Color(1, 0.85, 0.6, 1)\n"
)
sub.append('[sub_resource type="SphereMesh" id="Mesh_bulb"]\nradius = 0.06\nheight = 0.12\nradial_segments = 6\nrings = 3\n')
sub.append(
    '[sub_resource type="Environment" id="Env"]\n'
    "background_mode = 1\n"
    "background_color = Color(0.01, 0.012, 0.02, 1)\n"
    "ambient_light_source = 2\n"
    "ambient_light_color = Color(0.1, 0.12, 0.18, 1)\n"
    "ambient_light_energy = 0.22\n"
    "tonemap_mode = 2\n"
    "tonemap_exposure = 1.1\n"
    "glow_enabled = true\n"
    "glow_intensity = 0.5\n"
    "glow_bloom = 0.05\n"
    "fog_enabled = true\n"
    "fog_light_color = Color(0.015, 0.02, 0.03, 1)\n"
    "fog_density = 0.035\n"
    "volumetric_fog_enabled = true\n"
    "volumetric_fog_density = 0.02\n"
    "volumetric_fog_albedo = Color(0.45, 0.5, 0.55, 1)\n"
    "volumetric_fog_length = 40.0\n"
    "volumetric_fog_anisotropy = 0.45\n"
)
for name, (_, _, size, _) in TRIGGERS.items():
    sub.append(f'[sub_resource type="BoxShape3D" id="Shape_{name}"]\nsize = {v3(size)}\n')
sub.append('[sub_resource type="BoxShape3D" id="Shape_boundsX"]\nsize = Vector3(2, 60, 240)\n')
sub.append('[sub_resource type="BoxShape3D" id="Shape_boundsZ"]\nsize = Vector3(240, 60, 2)\n')

# ------------------------------------------------------------------ nós
node("Act1Trilha", "Node3D", None, {"script": f'ExtResource("{script_id}")'})
node("WorldEnvironment", "WorldEnvironment", ".", {"environment": 'SubResource("Env")'})
node("Moon", "DirectionalLight3D", ".", {
    "transform": xform((0, 30, 0), 35, -58),
    "light_color": "Color(0.55, 0.62, 0.85, 1)",
    "light_energy": "0.18",
    "light_volumetric_fog_energy": "0.6",
    "shadow_enabled": "true",
    "directional_shadow_max_distance": "60.0",
})
node("Ambience", "AudioStreamPlayer", ".", {
    "stream": f'ExtResource("{snd["forest_night_loop"]}")', "volume_db": "-12.0"})

pp = ", ".join(f"{f(x)}, {f(z)}" for x, z in PATH)
cl = ", ".join(f"{f(x)}, {f(z)}, {f(r)}" for x, z, r in CLEARINGS)
node("Terrain", "Node3D", ".", {
    "script": f'ExtResource("{terrain_script}")',
    "size": "240",
    "noise_seed": "7",
    "height_scale": "3.5",
    "path_points": f"PackedVector2Array({pp})",
    "path_width": "2.2",
    "clearings": f"PackedVector3Array({cl})",
    "cliff_z": f(CLIFF_Z),
    "cliff_drop": "9.0",
    "cliff_steepness": "2.5",
    "material": 'SubResource("Mat_terrain")',
})
ex = ", ".join(f"{f(x)}, {f(z)}" for x, z in SIGHTLINE)
node("Forest", "Node3D", ".", {
    "script": f'ExtResource("{scatter_script}")',
    "terrain_path": 'NodePath("../Terrain")',
    "scatter_seed": "11",
    "tree_count": "950",
    "tree_models": scenes_array(TREES),
    "tree_model_weights": floats([t[1] for t in TREES]),
    "tree_model_scales": vec2s([(t[2], t[3]) for t in TREES]),
    "tree_model_trunks": floats([t[4] for t in TREES]),
    "plant_models": scenes_array(PLANTS),
    "plant_model_weights": floats([p[1] for p in PLANTS]),
    "plant_model_scales": vec2s([(p[2], p[3]) for p in PLANTS]),
    "plant_count": "2600",
    "grass_models": scenes_array(GRASS),
    "grass_model_scales": vec2s([(g[1], g[2]) for g in GRASS]),
    "rock_models": scenes_array(ROCKS),
    "rock_model_scales": vec2s([(r[1], r[2]) for r in ROCKS]),
    "rock_count": "220",
    "chunk_size": "48.0",
    "tree_draw_distance": "95.0",
    "plant_draw_distance": "72.0",
    "grass_draw_distance": "60.0",
    "exclusion_segments": f"PackedVector2Array({ex})",
    "exclusion_radius": "2.6",
    "grass_count": "7000",
    "bush_count": "700",
    "bark_texture": f'ExtResource("{tex["bark"]}")',
    "foliage_texture": f'ExtResource("{tex["foliage"]}")',
    "grass_texture": f'ExtResource("{tex["grass_tuft"]}")',
    "bush_texture": f'ExtResource("{tex["bush"]}")',
})

# Limites invisíveis do mapa
node("Bounds", "StaticBody3D", ".")
for i, (pos, shape) in enumerate([((-113, 0, 0), "X"), ((113, 0, 0), "X"), ((0, 0, 106), "Z"), ((0, 0, -108), "Z")]):
    node(f"Wall{i}", "CollisionShape3D", "Bounds", {"transform": xform(pos), "shape": f'SubResource("Shape_bounds{shape}")'})

# --- O sítio
node("Sitio", "Node3D", ".", {"transform": xform((SITIO[0], 0, SITIO[1]))}, groups=["snap_ground"])
csg("House", "Sitio", (0, 1.5, 8), (9, 3, 6), "Mat_house")
csg("Roof", "Sitio", (0, 3.3, 8), (9.8, 0.6, 6.8), "Mat_roof")
csg("Porch", "Sitio", (0, 0.1, 4.4), (4.2, 0.2, 1.3), "Mat_house")
csg("FrontDoor", "Sitio", (0, 1.05, 4.97), (0.95, 2.1, 0.08), "Mat_door")
node("Window", "CSGBox3D", "Sitio", {"transform": xform((2.6, 1.5, 4.97)), "size": "Vector3(1, 0.8, 0.06)",
                                     "material": 'SubResource("Mat_window")'})
node("WindowGlow", "OmniLight3D", "Sitio", {"transform": xform((2.6, 1.5, 4.3)), "light_color": "Color(1, 0.7, 0.4, 1)",
                                            "light_energy": "0.5", "omni_range": "4.0"})
node("PorchLight", "OmniLight3D", "Sitio", {
    "transform": xform((0, 2.6, 4.7)),
    "light_color": "Color(1, 0.82, 0.55, 1)",
    "light_energy": "1.5",
    "shadow_enabled": "true",
    "omni_range": "13.0",
    "omni_attenuation": "1.3",
    "script": f'ExtResource("{light_script}")',
    "base_energy": "1.5",
    "mode": "1",
    "buzz_sound": f'ExtResource("{snd["light_buzz_loop"]}")',
    "buzz_volume_db": "-22.0",
    "pop_sound": f'ExtResource("{snd["bulb_pop"]}")',
})
node("Bulb", "MeshInstance3D", "Sitio/PorchLight", {"mesh": 'SubResource("Mesh_bulb")', "surface_material_override/0": 'SubResource("Mat_bulb")'})
# Cerca com o portão aberto no meio (z local -6 = z 78 no mundo)
for side, sx in (("L", -1), ("R", 1)):
    cx = sx * 7.65
    for k, y in enumerate((0.45, 0.95)):
        csg(f"Rail{side}{k}", "Sitio", (cx, y, -6), (12.7, 0.08, 0.06), "Mat_fence")
    for j in range(7):
        x = sx * (1.3 + j * 2.1)
        csg(f"Post{side}{j}", "Sitio", (x, 0.6, -6), (0.12, 1.2, 0.12), "Mat_fence")
csg("GateOpen", "Sitio", (1.25 + 0.55, 0.7, -6.55), (0.06, 1.0, 1.1), "Mat_fence", yaw=10)

# --- Casa de ferramentas (aberta pro lado da trilha, +x)
node("Shed", "Node3D", ".", {"transform": xform((SHED[0], 0, SHED[1]))}, groups=["snap_ground"])
csg("WallW", "Shed", (-2, 1.2, 0), (0.12, 2.4, 4), "Mat_shed")
csg("WallN", "Shed", (0, 1.2, -2), (4, 2.4, 0.12), "Mat_shed")
csg("WallS", "Shed", (0, 1.2, 2), (4, 2.4, 0.12), "Mat_shed")
csg("Roof", "Shed", (0, 2.5, 0), (4.6, 0.12, 4.6), "Mat_roof")
csg("Floor", "Shed", (0, 0.03, 0), (4, 0.06, 4), "Mat_shed")
csg("Bench", "Shed", (-1.45, 0.45, -0.9), (0.8, 0.9, 1.6), "Mat_house")
csg("Beam", "Shed", (-0.6, 2.15, 0), (0.12, 0.12, 4), "Mat_shed")
for j, (z, h) in enumerate([(-0.4, 0.9), (0.2, 0.7), (0.8, 1.1)]):
    csg(f"Tool{j}", "Shed", (-1.9, 1.5, z), (0.05, h, 0.08), "Mat_roof")
node("Owl", "Node3D", "Shed", {
    "transform": xform((-0.8, 2.3, 0.4), -90),
    "script": f'ExtResource("{owl_script}")',
    "screech_sound": f'ExtResource("{snd["owl_screech"]}")',
    "flap_sound": f'ExtResource("{snd["wing_flaps"]}")',
})

# Rastro de sangue até a casa de ferramentas
node("BloodTrail", "Node3D", ".")
for i, (x, z) in enumerate(BLOOD):
    node(f"Blood{i}", "MeshInstance3D", "BloodTrail", {
        "transform": xform((x, 0, z), i * 47 % 360, -90),
        "mesh": 'SubResource("Mesh_blood")',
    }, groups=["snap_ground"], meta={"ground_offset": "0.04"})

# --- Personagens
node("Player", None, ".", {"transform": xform((0, 2, 88.4))}, instance=player_scene)
node("Pacoca", None, ".", {"transform": xform((0, 0, 74))}, instance=dog_scene)
node("Coisa", None, ".", {"transform": xform((9, 0, 6))}, instance=coisa_scene)
node("EcoSight", "Node3D", ".", {
    "transform": xform((ECO_SPOT[0], 0, ECO_SPOT[1]), 100),
    "script": f'ExtResource("{rig_script}")',
}, groups=["snap_ground"])
# Clareira de luar atrás do Eco: sem isso a silhueta preta não aparece no escuro.
node("EcoBacklight", "OmniLight3D", ".", {
    "transform": xform((ECO_SPOT[0] + 3.0, 0, ECO_SPOT[1] - 1.0)),
    "light_color": "Color(0.55, 0.65, 0.9, 1)",
    "light_energy": "0.9",
    "omni_range": "7.0",
    "omni_attenuation": "1.2",
}, groups=["snap_ground"], meta={"ground_offset": "1.6"})
node("Stalker", "Node3D", ".", {
    "script": f'ExtResource("{stalker_script}")',
    "rustle_sound": f'ExtResource("{snd["bush_rustle"]}")',
    "crack_sound": f'ExtResource("{snd["branch_crack"]}")',
    "side_distance": "9.0",
    "side": "1.0",
})
node("EcoBump", "Node3D", ".", {
    "script": f'ExtResource("{bump_script}")',
    "impact_sound": f'ExtResource("{snd["impact_thud"]}")',
    "ring_sound": f'ExtResource("{snd["tinnitus"]}")',
})
node("BarkBeyond", "AudioStreamPlayer3D", ".", {
    "transform": xform((0, 0, -82)),
    "stream": f'ExtResource("{snd["dog_bark_1"]}")',
    "volume_db": "4.0",
    "unit_size": "12.0",
    "max_distance": "150.0",
}, groups=["snap_ground"], meta={"ground_offset": "1.0"})

# --- Bichos que fogem de você (pista do plot twist)
for i, (x, z, yaw) in enumerate(DEER):
    node(f"Deer{i}", "Node3D", ".", {
        "transform": xform((x, 0, z), yaw),
        "script": f'ExtResource("{flee_script}")',
        "model_scene": f'ExtResource("{deer_scene}")',
        "flee_sound": f'ExtResource("{snd["branch_crack"]}")',
    }, groups=["snap_ground"])

# --- Marcadores
node("Markers", "Node3D", ".")
for name, (x, z, yaw, off) in MARKERS.items():
    node(name, "Marker3D", "Markers", {"transform": xform((x, 0, z), yaw)},
         groups=["snap_ground"], meta={"ground_offset": f(off)})
node("DogLead", "Node3D", "Markers")
for i, (x, z) in enumerate(DOG_LEAD):
    node(f"P{i}", "Marker3D", "Markers/DogLead", {"transform": xform((x, 0, z))}, groups=["snap_ground"])

# --- Gatilhos
node("Triggers", "Node3D", ".")
for name, (x, z, size, yaw) in TRIGGERS.items():
    offset = size[1] / 2 if name != "Fall" else 1.0
    node(name, "Area3D", "Triggers", {
        "transform": xform((x, 0, z), yaw),
        "script": f'ExtResource("{trigger_script}")',
    }, groups=["snap_ground"], meta={"ground_offset": f(offset)})
    node("Shape", "CollisionShape3D", f"Triggers/{name}", {"shape": f'SubResource("Shape_{name}")'})

# ------------------------------------------------------------------ escrever
parts = ["[gd_scene format=3]\n"]
parts += [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext]
parts.append("")
parts += sub
parts += nodes
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("\n".join(parts).rstrip() + "\n")
print("Cena gerada:", OUT, f"({len(nodes)} nós)")
