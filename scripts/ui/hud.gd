extends CanvasLayer
## HUD mínimo: ponto de mira, texto de interação, bateria, pausa e fade.
## Pouca interface = mais imersão = mais medo.

@onready var prompt: Label = $Prompt
@onready var battery_label: Label = $Battery
@onready var crosshair: Control = $Crosshair
@onready var pause_panel: Control = $PausePanel
@onready var fade_rect: ColorRect = $Fade
@onready var subtitle: Label = $Subtitle

var _battery_visible_time := 0.0
var _subtitle_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	prompt.text = ""
	subtitle.text = ""
	battery_label.modulate.a = 0.0
	Game.paused_changed.connect(_on_paused_changed)

	var player := get_parent() as Player
	if player:
		player.interact_prompt_changed.connect(_on_prompt_changed)
		player.battery_changed.connect(_on_battery_changed)

	# Começa no preto e clareia devagar.
	fade_rect.color.a = 1.0
	fade_to(0.0, 3.0)


func _process(delta: float) -> void:
	if _battery_visible_time > 0.0:
		_battery_visible_time -= delta
		battery_label.modulate.a = minf(1.0, battery_label.modulate.a + delta * 3.0)
	else:
		battery_label.modulate.a = maxf(0.0, battery_label.modulate.a - delta * 1.5)

	if _subtitle_time > 0.0:
		_subtitle_time -= delta
		if _subtitle_time <= 0.0:
			var tw := create_tween()
			tw.tween_property(subtitle, "modulate:a", 0.0, 0.8)


func _on_prompt_changed(text: String) -> void:
	prompt.text = text
	crosshair.modulate.a = 0.9 if text != "" else 0.35


func _on_battery_changed(percent: float) -> void:
	battery_label.text = "BATERIA %d%%" % int(round(percent))
	_battery_visible_time = 2.5


func _on_paused_changed(is_paused: bool) -> void:
	pause_panel.visible = is_paused


## Escurece/clareia a tela. alpha 1 = preto total.
func fade_to(alpha: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, duration)
	return tw


## Mostra uma legenda/pensamento do personagem por alguns segundos.
func show_subtitle(text: String, duration: float = 3.5) -> void:
	subtitle.text = text
	subtitle.modulate.a = 1.0
	_subtitle_time = duration
