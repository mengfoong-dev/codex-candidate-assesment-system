extends Node

## Global UI sound effects, autoloaded as "Sfx" (see project.godot [autoload]).
## Mute is toggled from the pause menu. Sounds are procedural (scripts/development/generate_sfx.gd).

var _blip: AudioStreamPlayer
var _click: AudioStreamPlayer
var _muted := false

func _ready() -> void:
	_blip = _make("res://assets/ui/sfx/text_blip.wav", -8.0)
	_click = _make("res://assets/ui/sfx/ui_click.wav", -4.0)

func _make(path: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var stream: Variant = load(path)
	if stream is AudioStream:
		p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p

func blip() -> void:
	if not _muted and _blip != null and _blip.stream != null:
		_blip.play()

func click() -> void:
	if not _muted and _click != null and _click.stream != null:
		_click.play()

func set_muted(muted: bool) -> void:
	_muted = muted

func is_muted() -> bool:
	return _muted
