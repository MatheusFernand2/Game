class_name GameHUD
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
var _volume_label: Label
var _volume_slider: HSlider
var _volume_toast: Label
var _volume_toast_time := 0.0
var _sens_label: Label
var _continue_button: Button
var _watch_label: Label
var _watch_time := 0.0
var _hint_label: Label
var _hint_time := 0.0
var _card_title: Label
var _card_sub: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	prompt.text = ""
	subtitle.text = ""
	battery_label.modulate.a = 0.0
	_build_pause_menu()
	_build_volume_toast()
	_build_extra_labels()
	Game.paused_changed.connect(_on_paused_changed)
	Game.volume_changed.connect(_on_volume_changed)

	var player := get_parent() as Player
	if player:
		player.interact_prompt_changed.connect(_on_prompt_changed)
		player.battery_changed.connect(_on_battery_changed)
		player.watch_requested.connect(show_watch)

	# Começa no preto e clareia devagar.
	fade_rect.color.a = 1.0
	fade_to(0.0, 3.0)


func _process(delta: float) -> void:
	if _battery_visible_time > 0.0:
		_battery_visible_time -= delta
		battery_label.modulate.a = minf(1.0, battery_label.modulate.a + delta * 3.0)
	else:
		battery_label.modulate.a = maxf(0.0, battery_label.modulate.a - delta * 1.5)

	if _volume_toast_time > 0.0:
		_volume_toast_time -= delta
		_volume_toast.modulate.a = 1.0
	else:
		_volume_toast.modulate.a = maxf(0.0, _volume_toast.modulate.a - delta * 2.0)

	if _watch_time > 0.0:
		_watch_time -= delta
		_watch_label.text = Game.watch_text()
		_watch_label.modulate.a = minf(1.0, _watch_label.modulate.a + delta * 4.0)
	else:
		_watch_label.modulate.a = maxf(0.0, _watch_label.modulate.a - delta * 2.0)

	if _hint_time > 0.0:
		_hint_time -= delta
		_hint_label.modulate.a = minf(1.0, _hint_label.modulate.a + delta * 3.0)
	else:
		_hint_label.modulate.a = maxf(0.0, _hint_label.modulate.a - delta * 1.5)

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
	if is_paused:
		_volume_slider.set_value_no_signal(Game.master_volume * 100.0)
		_update_volume_text(Game.master_volume)
		_continue_button.grab_focus()


func _on_volume_changed(volume: float) -> void:
	_update_volume_text(volume)
	if _volume_slider:
		_volume_slider.set_value_no_signal(volume * 100.0)
	# Teclas - e + fora do menu: mostra o volume no canto.
	if not get_tree().paused:
		_volume_toast.text = "VOLUME %d%%" % int(round(volume * 100.0))
		_volume_toast_time = 1.5


func _update_volume_text(volume: float) -> void:
	if _volume_label:
		_volume_label.text = "Volume: %d%%" % int(round(volume * 100.0))


## Escurece/clareia a tela. alpha 1 = preto total.
func fade_to(alpha: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, duration)
	return tw


## Olhar o relógio de pulso (tecla T).
func show_watch() -> void:
	_watch_time = 3.0
	_watch_label.text = Game.watch_text()


## Dica de controle no alto da tela.
func show_hint(text: String, duration: float = 4.0) -> void:
	_hint_label.text = text
	_hint_time = duration


## Cartão de título no meio da tela ("Ato 1 — A Trilha"). Some sozinho.
func show_title_card(title: String, sub: String, duration: float = 4.0) -> void:
	_card_title.text = title
	_card_sub.text = sub
	var tw := create_tween()
	tw.tween_property(_card_title, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(_card_sub, "modulate:a", 1.0, 1.6)
	tw.tween_interval(duration)
	tw.tween_property(_card_title, "modulate:a", 0.0, 1.5)
	tw.parallel().tween_property(_card_sub, "modulate:a", 0.0, 1.5)


## Tela preta com um texto (fim de ato). Retorna quando terminou de aparecer.
func show_end_card(title: String, sub: String) -> void:
	await fade_to(1.0, 2.0).finished
	_card_title.text = title
	_card_sub.text = sub
	var tw := create_tween()
	tw.tween_property(_card_title, "modulate:a", 1.0, 1.5)
	tw.parallel().tween_property(_card_sub, "modulate:a", 1.0, 2.0)
	await tw.finished


## Mostra uma legenda/pensamento do personagem por alguns segundos.
func show_subtitle(text: String, duration: float = 3.5) -> void:
	subtitle.text = text
	subtitle.modulate.a = 1.0
	_subtitle_time = duration


# ------------------------------------------------------------ menu de pausa

func _make_label(text: String, size: int) -> Label:
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = Color(0.8, 0.76, 0.7)
	settings.outline_size = 3
	settings.outline_color = Color.BLACK
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_slider(min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 16)
	return slider


func _build_pause_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)

	box.add_child(_make_label("PAUSADO", 18))
	box.add_child(Control.new())  # espaço

	# Volume
	_volume_label = _make_label("", 11)
	box.add_child(_volume_label)
	_volume_slider = _make_slider(0.0, 100.0, 1.0, Game.master_volume * 100.0)
	_volume_slider.value_changed.connect(func(v: float) -> void: Game.set_master_volume(v / 100.0))
	box.add_child(_volume_slider)
	_update_volume_text(Game.master_volume)

	# Sensibilidade do mouse
	_sens_label = _make_label("", 11)
	box.add_child(_sens_label)
	var sens := _make_slider(0.02, 0.4, 0.01, Game.mouse_sensitivity)
	sens.value_changed.connect(_on_sensitivity_changed)
	box.add_child(sens)
	_on_sensitivity_changed(Game.mouse_sensitivity)

	box.add_child(Control.new())

	_continue_button = Button.new()
	_continue_button.text = "Continuar"
	_continue_button.pressed.connect(func() -> void: Game.set_paused(false))
	box.add_child(_continue_button)

	var menu := Button.new()
	menu.text = "Voltar ao menu"
	menu.pressed.connect(Game.go_to_menu)
	box.add_child(menu)

	var quit := Button.new()
	quit.text = "Sair do jogo"
	quit.pressed.connect(Game.quit_game)
	box.add_child(quit)

	box.add_child(_make_label("Atalhos:  - / + volume   T relógio   F11 tela cheia", 9))


func _on_sensitivity_changed(value: float) -> void:
	Game.set_mouse_sensitivity(value)
	_sens_label.text = "Sensibilidade do mouse: %.2f" % value


func _build_volume_toast() -> void:
	_volume_toast = _make_label("", 11)
	_volume_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_volume_toast.offset_left = -150.0
	_volume_toast.offset_right = -12.0
	_volume_toast.offset_top = 10.0
	_volume_toast.offset_bottom = 28.0
	_volume_toast.modulate.a = 0.0
	add_child(_volume_toast)


func _build_extra_labels() -> void:
	_watch_label = _make_label("", 12)
	_watch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_watch_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_watch_label.offset_left = 14.0
	_watch_label.offset_right = 160.0
	_watch_label.offset_top = -52.0
	_watch_label.offset_bottom = -32.0
	_watch_label.modulate.a = 0.0
	add_child(_watch_label)
	move_child(_watch_label, fade_rect.get_index())

	_hint_label = _make_label("", 10)
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint_label.offset_left = -220.0
	_hint_label.offset_right = 220.0
	_hint_label.offset_top = 16.0
	_hint_label.offset_bottom = 34.0
	_hint_label.modulate.a = 0.0
	add_child(_hint_label)
	move_child(_hint_label, fade_rect.get_index())

	# Cartões ficam POR CIMA do preto (aparecem no fim de ato).
	_card_title = _make_label("", 22)
	_card_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card_title.offset_left = -300.0
	_card_title.offset_right = 300.0
	_card_title.offset_top = -30.0
	_card_title.offset_bottom = 0.0
	_card_title.modulate.a = 0.0
	add_child(_card_title)
	move_child(_card_title, pause_panel.get_index())

	_card_sub = _make_label("", 11)
	_card_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card_sub.offset_left = -300.0
	_card_sub.offset_right = 300.0
	_card_sub.offset_top = 6.0
	_card_sub.offset_bottom = 26.0
	_card_sub.modulate.a = 0.0
	add_child(_card_sub)
	move_child(_card_sub, pause_panel.get_index())
