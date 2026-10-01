extends Node
## Background music. Loaded as an autoload (see project.godot), so it keeps
## playing smoothly when the game restarts instead of starting over.
## Regenerate the track with tools/make_music.gd.

const TRACK := preload("res://assets/audio/music.wav")
const VOLUME_DB := -8.0 # Sits under the sound effects.

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Keeps playing on the pause screen.
	var stream: AudioStreamWAV = TRACK
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = &"Music"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.play()
