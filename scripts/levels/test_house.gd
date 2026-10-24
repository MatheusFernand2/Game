extends Node3D
## Fase de teste: quarto -> corredor -> cozinha.
## Sequência de sustos:
##   1. Batidas atrás da porta trancada do corredor.
##   2. A Coisa aparece no fim do corredor, as luzes estouram e ela surge na sua cara.
##   3. A porta do quarto bate sozinha atrás de você.
## Depois disso, um "diretor de ambiente" solta sons aleatórios atrás do jogador.
## Na cozinha: o Eco sentado, com a mão no rosto, do lado das pilhas.
## Você tem que passar do lado dele pra pegar. Ele nunca reage.

const SND_KNOCK := preload("res://assets/audio/knock_3x.wav")
const SND_WHISPER := preload("res://assets/audio/whisper.wav")
const SND_TENSION := preload("res://assets/audio/tension_rise.wav")
const SND_STINGER := preload("res://assets/audio/stinger_scream.wav")

@onready var player: Player = $Player
@onready var hud: Node = $Player/HUD
@onready var post_fx: Node = $Player/PostFX
@onready var ambience: AudioStreamPlayer = $Ambience
@onready var figure: Figure = $Figure
@onready var bedroom_door: Door = $Doors/BedroomDoor
@onready var basement_door: Door = $Doors/BasementDoor
@onready var hall_light_a: FlickerLight = $Lights/HallLightA
@onready var hall_light_b: FlickerLight = $Lights/HallLightB
@onready var figure_spot: Marker3D = $Markers/FigureEndOfHall

var _scripted_scare_running := false
var _director_enabled := false
var _in_kitchen := false
var _ambience_tween: Tween
var _director_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	ambience.finished.connect(ambience.play)
	($Triggers/KnockTrigger as ScareTrigger).triggered.connect(_on_knock_trigger)
	($Triggers/HallwayScare as ScareTrigger).triggered.connect(_on_hallway_scare)
	($Triggers/KitchenEnter as ScareTrigger).triggered.connect(_on_kitchen_enter)
	var kitchen := $Triggers/KitchenSilence as Area3D
	kitchen.body_entered.connect(_on_kitchen_body_entered)
	kitchen.body_exited.connect(_on_kitchen_body_exited)
	_intro()


func _process(delta: float) -> void:
	_update_director(delta)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


# ------------------------------------------------------------ roteiro

func _intro() -> void:
	await _wait(3.5)
	hud.call("show_subtitle", "...que cheiro é esse?", 3.0)


func _on_knock_trigger(_p: Player) -> void:
	# Batidas fortes do outro lado da porta trancada.
	Game.play_sound_at(SND_KNOCK, basement_door.global_position + Vector3.UP * 1.3, 6.0)
	player.add_fear(0.25)
	player.shake(0.01, 0.4)
	basement_door.locked_message = "Trancada. Alguma coisa respira do outro lado."


func _on_hallway_scare(_p: Player) -> void:
	if _scripted_scare_running:
		return
	_scripted_scare_running = true

	# 1) Tensão: som subindo, lâmpada do fundo começa a falhar e ELA está lá.
	Game.play_sound_2d(SND_TENSION, -4.0)
	player.add_fear(0.15)
	hall_light_b.flicker(3.2)
	figure.appear(figure_spot.global_position, player)
	await _wait(2.8)

	# 2) Apagão.
	hall_light_b.kill()
	await _wait(0.12)
	hall_light_a.kill()
	figure.vanish()
	player.force_flicker(1.5)
	ambience.volume_db = -40.0
	await _wait(1.5)

	# 3) Ela na sua cara.
	player.flashlight_on = true
	var forward := -player.camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	figure.appear(player.global_position + forward * _free_distance(forward, 1.5), player, true)
	Game.play_sound_2d(SND_STINGER, 2.0)
	post_fx.call("glitch", 1.0)
	player.shake(0.09, 0.7)
	player.add_fear(0.75)
	await _wait(0.4)
	figure.vanish()
	post_fx.call("glitch", 0.6)

	# 4) Silêncio... e a porta do quarto bate atrás.
	await _wait(1.6)
	hall_light_a.restore(0.35, FlickerLight.Mode.HEAVY)
	if not _in_kitchen:
		_fade_ambience(-10.0, 6.0)
	await _wait(1.2)
	if bedroom_door.is_open:
		bedroom_door.slam()
	else:
		Game.play_sound_at(SND_KNOCK, bedroom_door.global_position + Vector3.UP, 4.0, 0.8)
	player.add_fear(0.3)
	player.shake(0.03, 0.3)
	await _wait(2.5)
	hud.call("show_subtitle", "Não olha pra trás. Não olha pra trás.", 3.5)

	_scripted_scare_running = false
	_director_enabled = true
	_director_timer = _rng.randf_range(20.0, 35.0)


## Cozinha: o som do mundo some. Sobra a lâmpada e a respiração.
func _on_kitchen_body_entered(body: Node3D) -> void:
	if body is Player:
		_in_kitchen = true
		_fade_ambience(-45.0, 1.2)


func _on_kitchen_body_exited(body: Node3D) -> void:
	if body is Player:
		_in_kitchen = false
		_fade_ambience(-10.0, 3.0)


func _fade_ambience(target_db: float, duration: float) -> void:
	if _ambience_tween and _ambience_tween.is_valid():
		_ambience_tween.kill()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(ambience, "volume_db", target_db, duration)


func _on_kitchen_enter(_p: Player) -> void:
	await _wait(0.8)
	hud.call("show_subtitle", "Pilhas na mesa... preciso delas.", 3.0)


## Distância livre na frente do jogador (pra Coisa não nascer dentro da parede).
func _free_distance(direction: Vector3, wanted: float) -> float:
	var from := player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * wanted)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return wanted
	var dist := from.distance_to(hit["position"])
	return maxf(dist - 0.3, 0.5)


# ------------------------------------------------------------ diretor de ambiente

## Toca sons aleatórios ATRÁS do jogador de tempos em tempos.
## É barato e funciona muito: o jogador nunca se sente sozinho.
func _update_director(delta: float) -> void:
	if not _director_enabled or _scripted_scare_running or _in_kitchen:
		return
	_director_timer -= delta
	if _director_timer > 0.0:
		return
	_director_timer = _rng.randf_range(25.0, 60.0)
	var behind := player.global_basis.z
	behind.y = 0.0
	var side := player.global_basis.x * _rng.randf_range(-0.6, 0.6)
	var pos := player.global_position + (behind.normalized() + side) * _rng.randf_range(3.0, 6.0) + Vector3.UP * 1.4
	var stream: AudioStream = SND_WHISPER if _rng.randf() < 0.5 else SND_KNOCK
	Game.play_sound_at(stream, pos, -2.0, _rng.randf_range(0.85, 1.0))
	player.add_fear(0.12)
