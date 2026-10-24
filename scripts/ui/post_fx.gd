extends CanvasLayer
## Controla o shader de pós-processamento (PS1/VHS) da tela.

@onready var screen: ColorRect = $Screen

var _glitch := 0.0
var _material: ShaderMaterial


func _ready() -> void:
	_material = screen.material as ShaderMaterial


func _process(delta: float) -> void:
	if _material == null:
		return
	var player := get_parent() as Player
	_material.set_shader_parameter("fear", player.fear if player else 0.0)
	_glitch = maxf(_glitch - delta * 2.0, 0.0)
	_material.set_shader_parameter("glitch", _glitch)


## Dá um "pico" de glitch na imagem (0..1). Some sozinho em ~0,5s.
func glitch(amount: float) -> void:
	_glitch = maxf(_glitch, amount)
