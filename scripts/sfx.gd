extends Node
## Sound effects, synthesized in code at startup so no audio files are needed.
## Call play("boing"), optionally with a pitch multiplier.

const MIX_RATE := 22050
const VOICES := 8

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	_sounds["boing"] = _sweep(180.0, 520.0, 0.18, 0.5)
	_sounds["thud"] = _sweep(140.0, 260.0, 0.12, 0.45)
	_sounds["chirp"] = _chirp()
	_sounds["super"] = _sweep(300.0, 1400.0, 0.32, 0.45)
	_sounds["honk"] = _honk()
	_sounds["caw"] = _caw()
	_sounds["combo"] = _sweep(880.0, 1320.0, 0.1, 0.3)
	_sounds["game_over"] = _sweep(600.0, 140.0, 0.7, 0.5)
	_sounds["click"] = _sweep(900.0, 600.0, 0.06, 0.35)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		add_child(player)
		_players.append(player)


func play(sound: String, pitch: float = 1.0) -> void:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % VOICES
	player.stream = _sounds[sound]
	player.pitch_scale = pitch
	player.play()


# --- Synthesis -------------------------------------------------------------

## Sine wave gliding from one pitch to another, fading out.
func _sweep(from_hz: float, to_hz: float, seconds: float, volume: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var phase := 0.0
	var count := int(seconds * MIX_RATE)
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(from_hz, to_hz, t) / MIX_RATE
		samples.append(sin(phase) * volume * _envelope(t))
	return _to_wav(samples)


## Two quick high tweets.
func _chirp() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var phase := 0.0
	var count := int(0.14 * MIX_RATE)
	for i in count:
		var t := float(i) / count
		var local := fmod(t * 2.0, 1.0) # Two tweets back to back.
		phase += TAU * lerpf(2200.0, 3400.0, local) / MIX_RATE
		samples.append(sin(phase) * 0.25 * _envelope(local))
	return _to_wav(samples)


## Buzzy low tone that bends down, like a goose.
func _honk() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var phase := 0.0
	var count := int(0.28 * MIX_RATE)
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(330.0, 250.0, t) / MIX_RATE
		var wave := sin(phase) + 0.5 * sin(phase * 2.0) + 0.3 * sin(phase * 3.0)
		samples.append(clampf(wave * 0.9, -1.0, 1.0) * 0.4 * _envelope(t))
	return _to_wav(samples)


## Harsh, noisy squawk, like a crow.
func _caw() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var phase := 0.0
	var count := int(0.22 * MIX_RATE)
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(700.0, 450.0, t) / MIX_RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		samples.append((saw * 0.7 + randf_range(-0.3, 0.3)) * 0.3 * _envelope(t))
	return _to_wav(samples)


## Quick fade-in, then fade out to silence (avoids clicks).
func _envelope(t: float) -> float:
	return minf(t * 40.0, 1.0) * pow(1.0 - t, 1.5)


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
