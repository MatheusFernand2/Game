extends Node
## Autoload global do jogo.
## Registra os controles, guarda configurações e cuida da pausa.

signal paused_changed(is_paused: bool)

## Sensibilidade do mouse (graus por pixel).
var mouse_sensitivity: float = 0.12
var invert_y: bool = false

# Ação -> lista de teclas (physical keycode) ou botões do mouse.
const KEY_BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"interact": [KEY_E],
	"flashlight": [KEY_F],
	"pause": [KEY_ESCAPE],
	"quit_from_pause": [KEY_Q],
	"toggle_fullscreen": [KEY_F11],
}

const MOUSE_BINDINGS := {
	"interact": [MOUSE_BUTTON_LEFT],
	"flashlight": [MOUSE_BUTTON_RIGHT],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()


func _register_inputs() -> void:
	for action: String in KEY_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for button: int in MOUSE_BINDINGS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
	elif get_tree().paused and event.is_action_pressed("quit_from_pause"):
		get_tree().quit()


func set_paused(value: bool) -> void:
	get_tree().paused = value
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	paused_changed.emit(value)


## Toca um som 3D solto no mundo e apaga o player quando terminar.
func play_sound_at(stream: AudioStream, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null or stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.attenuation_filter_cutoff_hz = 2500.0
	scene.add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()


## Toca um som 2D (sem posição) — para stingers e coisas "dentro da cabeça".
func play_sound_2d(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null or stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
