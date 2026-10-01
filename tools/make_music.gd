extends SceneTree
## Generates the background music loop and saves it to assets/audio/music.wav.
## Run from the project folder:
##   C:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/make_music.gd
##
## 8 bars at 120 BPM (16 seconds) over C - G - Am - F, played twice with a
## livelier melody the second time. Plucky lead, bouncy bass, soft drums.

const RATE := 22050
const BPM := 120.0
const EIGHTH := 60.0 / BPM / 2.0 # Seconds per eighth note.
const BARS := 8
const OUT := "res://assets/audio/music.wav"

# Melody as [midi note, length in eighths]; -1 is a rest. 8 eighths per bar.
const MELODY := [
	[76, 2], [79, 2], [84, 1], [83, 1], [79, 2], # C
	[74, 2], [79, 2], [83, 1], [81, 1], [79, 2], # G
	[72, 2], [76, 2], [81, 1], [79, 1], [76, 2], # Am
	[77, 1], [79, 1], [81, 2], [79, 2], [-1, 2], # F
	[76, 1], [76, 1], [79, 2], [84, 2], [88, 2], # C
	[86, 2], [83, 1], [79, 1], [74, 2], [79, 2], # G
	[81, 2], [84, 1], [83, 1], [81, 2], [76, 2], # Am
	[77, 2], [81, 2], [83, 2], [86, 2], # F then G, leading back to the start
]
# Bass root per half bar (two per bar).
const BASS_ROOTS := [48, 48, 43, 43, 45, 45, 41, 41, 48, 48, 43, 43, 45, 45, 41, 43]


func _initialize() -> void:
	var total := int(BARS * 8 * EIGHTH * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)

	# Melody
	var at := 0
	for note in MELODY:
		if note[0] >= 0:
			_add_tone(mix, at, note[1], note[0], 0.2, 4.0, [1.0, 0.0, 0.3, 0.0, 0.12])
		at += note[1]

	# Bass: root, octave, fifth, octave on the four beats of each bar.
	for half in BASS_ROOTS.size():
		var root: int = BASS_ROOTS[half]
		_add_tone(mix, half * 4, 2, root, 0.26, 5.0, [1.0, 0.25])
		_add_tone(mix, half * 4 + 2, 2, root + (12 if half % 2 == 0 else 7), 0.2, 5.0, [1.0, 0.25])

	# Drums: kick on beats 1 and 3, snare on 2 and 4, hi-hat on the off-beats.
	for beat in BARS * 4:
		var start := int(beat * 2 * EIGHTH * RATE)
		if beat % 2 == 0:
			_add_kick(mix, start)
		else:
			_add_noise(mix, start, 0.12, 0.09, 18.0)
		_add_noise(mix, start + int(EIGHTH * RATE), 0.04, 0.05, 60.0)

	# Gentle limiter so overlapping notes never clip.
	for i in total:
		mix[i] = tanh(mix[i] * 1.2) * 0.85

	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := wav.save_to_wav(OUT)
	print("Saved %s (%.1f s): %s" % [OUT, total / float(RATE), error_string(err)])
	quit()


## Adds a plucked note: harmonics[i] is the strength of harmonic i+1.
func _add_tone(mix: PackedFloat32Array, eighth: int, length: int, midi: int, volume: float, decay: float, harmonics: Array) -> void:
	var start := int(eighth * EIGHTH * RATE)
	var count := int(length * EIGHTH * RATE)
	var hz := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var release := int(0.012 * RATE) # Short fade at the end avoids clicks.
	for i in count:
		var t := float(i) / RATE
		var wave := 0.0
		for h in harmonics.size():
			wave += harmonics[h] * sin(TAU * hz * (h + 1) * t)
		var env := minf(t / 0.005, 1.0) * exp(-t * decay) * minf(float(count - i) / release, 1.0)
		var idx := (start + i) % mix.size() # Wraps so the loop stays seamless.
		mix[idx] += wave * env * volume


func _add_kick(mix: PackedFloat32Array, start: int) -> void:
	var count := int(0.15 * RATE)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(120.0, 45.0, t) / RATE
		mix[(start + i) % mix.size()] += sin(phase) * 0.35 * pow(1.0 - t, 2.0)


func _add_noise(mix: PackedFloat32Array, start: int, seconds: float, volume: float, decay: float) -> void:
	var count := int(seconds * RATE)
	for i in count:
		var t := float(i) / RATE
		mix[(start + i) % mix.size()] += randf_range(-1.0, 1.0) * volume * exp(-t * decay)
