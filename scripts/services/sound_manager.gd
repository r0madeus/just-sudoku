class_name SoundManager
extends Node

## Game sounds, made in code: no audio files (GDD §41). Each sound is rendered once, on first use,
## into a short 16-bit sample from a few sine partials with a soft attack and a natural decay
## (wooden marimba for moves, bells for completions), and played on a small pool of players, so
## quick taps overlap instead of queueing up behind each other.

const MIX_RATE: int = 32000
## Sounds that can ring at the same time
const VOICES: int = 6
## Loudest sample, a little under full scale so overlapping sounds do not clip much
const PEAK: float = 0.7
## Attack: long enough to never click, short enough to feel instant
const ATTACK: float = 0.004

## Digits 1..9 as a D major pentatonic run, so a row filled in order sounds like a melody
const DIGIT_NOTES: Array[float] = [293.66, 329.63, 369.99, 440.0, 493.88, 587.33, 659.25, 739.99, 880.0]

## Wood: the strong 4th harmonic of a marimba bar, which dies away fast
const MARIMBA: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(4.0, 0.22), Vector2(9.9, 0.05)]
## Bell: inharmonic partials of a small chime
const BELL: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(2.76, 0.32), Vector2(5.4, 0.12), Vector2(8.93, 0.04)]
## Soft and round, for notes and colours
const SOFT: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(2.0, 0.12)]

## Every sound the game plays, most used first: rendered in the background at start-up
const ALL_KEYS: Array[String] = [
	"place_1", "place_2", "place_3", "place_4", "place_5", "place_6", "place_7", "place_8", "place_9",
	"note", "erase", "conflict", "unit", "complete", "place_0", "tap",
]

static var _players: Array[AudioStreamPlayer] = []
static var _next: int = 0
static var _cache: Dictionary = {}
# The background renderer and the game both fill the cache
static var _cache_lock := Mutex.new()
static var _prerender_task: int = -1

static func init_audio(parent_node: Node) -> void:
	if not _players.is_empty() and is_instance_valid(_players[0]):
		return
	_players.clear()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		parent_node.add_child(p)
		_players.append(p)
	# The finale takes a few hundred milliseconds to render on a phone: done now, off the main
	# thread, it never stalls the victory animation
	if _prerender_task == -1:
		_prerender_task = WorkerThreadPool.add_task(_prerender, false, "Render sounds")

static func _prerender() -> void:
	for key in ALL_KEYS:
		get_stream(key)

## Waits for the background rendering; called before the app quits
static func shutdown() -> void:
	if _prerender_task != -1:
		WorkerThreadPool.wait_for_task_completion(_prerender_task)
		_prerender_task = -1

## A digit placed: a marimba note of its own (any digit: 0)
static func play_number_placed(digit: int = 0) -> void:
	_play("place_%d" % clampi(digit, 0, 9))

## A note written or taken out, or a colour given: lighter than a digit
static func play_note() -> void:
	_play("note")

static func play_erase() -> void:
	_play("erase")

static func play_button_tap() -> void:
	_play("tap")

## A clash or wrong digit: a low, muted knock with a falling step, felt but never harsh
static func play_conflict() -> void:
	_play("conflict")

static func play_unit_complete() -> void:
	_play("unit")

static func play_complete() -> void:
	_play("complete")

static func _play(key: String) -> void:
	if not SettingsScreen.sounds_enabled or _players.is_empty():
		return
	var stream := get_stream(key)
	if stream == null:
		return
	# A free voice if there is one, else the one that started longest ago
	var player: AudioStreamPlayer = null
	for i in VOICES:
		var p := _players[(_next + i) % VOICES]
		if is_instance_valid(p) and not p.playing:
			player = p
			break
	if player == null:
		player = _players[_next]
	_next = (_players.find(player) + 1) % VOICES
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	player.stream = stream
	player.play()

static func get_stream(key: String) -> AudioStreamWAV:
	_cache_lock.lock()
	var cached: AudioStreamWAV = _cache.get(key)
	_cache_lock.unlock()
	if cached != null:
		return cached
	var samples := render(key)
	if samples.is_empty():
		return null
	var wav := _to_wav(samples)
	_cache_lock.lock()
	# Rendered on both threads at once: keep the first, so a sound is always the same object
	if not _cache.has(key):
		_cache[key] = wav
	wav = _cache[key]
	_cache_lock.unlock()
	return wav

## The sound as samples in -1..1 (also what the tests listen to)
static func render(key: String) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	if key.begins_with("place_"):
		var d := key.substr(6).to_int()
		var freq: float = DIGIT_NOTES[d - 1] if d >= 1 else DIGIT_NOTES[5]
		_alloc(buf, 0.34)
		_add_tone(buf, 0.0, freq, 0.34, 0.9, MARIMBA, 0.09)
		return _finish(buf, 0.55)
	match key:
		"note":
			_alloc(buf, 0.16)
			_add_tone(buf, 0.0, 1174.66, 0.16, 0.8, SOFT, 0.035)
			return _finish(buf, 0.28)
		"erase":
			_alloc(buf, 0.16)
			_add_tone(buf, 0.0, 392.0, 0.16, 0.9, SOFT, 0.04, -0.35)
			return _finish(buf, 0.4)
		"tap":
			_alloc(buf, 0.08)
			_add_tone(buf, 0.0, 880.0, 0.08, 0.8, SOFT, 0.02)
			return _finish(buf, 0.25)
		"conflict":
			_alloc(buf, 0.36)
			_add_tone(buf, 0.0, 233.08, 0.2, 0.9, MARIMBA, 0.06)
			_add_tone(buf, 0.09, 220.0, 0.27, 0.9, MARIMBA, 0.08)
			_lowpass(buf, 1400.0)
			return _finish(buf, 0.6)
		"unit":
			_alloc(buf, 0.7)
			_add_tone(buf, 0.0, 880.0, 0.5, 0.7, BELL, 0.16)
			_add_tone(buf, 0.07, 1318.51, 0.6, 0.6, BELL, 0.2)
			_echo(buf, 0.11, 0.25)
			return _finish(buf, 0.5)
		"complete":
			# D major arpeggio in bells, its notes ringing on into a soft echo
			_alloc(buf, 2.0)
			var notes := [587.33, 739.99, 880.0, 1174.66]
			for i in notes.size():
				var last := i == notes.size() - 1
				_add_tone(buf, i * 0.11, notes[i], 1.4 if last else 0.9, 0.75 if last else 0.6, BELL, 0.5 if last else 0.3)
			_add_tone(buf, 0.33, 293.66, 1.3, 0.35, MARIMBA, 0.45)
			_echo(buf, 0.17, 0.3)
			_echo(buf, 0.23, 0.2)
			return _finish(buf, 0.75)
	return buf

static func _alloc(buf: PackedFloat32Array, seconds: float) -> void:
	buf.resize(int(seconds * MIX_RATE))
	buf.fill(0.0)

## Adds a tone at `start` seconds: each partial (ratio, gain) decays exponentially, the higher
## ones faster, after a short attack. `glide` bends the pitch by that fraction over the tone.
static func _add_tone(buf: PackedFloat32Array, start: float, freq: float, dur: float, amp: float,
		partials: Array[Vector2], decay: float, glide: float = 0.0) -> void:
	var first := int(start * MIX_RATE)
	var count := mini(int(dur * MIX_RATE), buf.size() - first)
	var attack := ATTACK * MIX_RATE
	for p in partials:
		var phase := 0.0
		var tau: float = decay / sqrt(p.x) * MIX_RATE
		var gain: float = amp * p.y
		for i in count:
			var t := float(i)
			var env := exp(-t / tau)
			if t < attack:
				env *= t / attack
			var f: float = freq * p.x * (1.0 + glide * t / count)
			phase += TAU * f / MIX_RATE
			buf[first + i] += sin(phase) * env * gain

## One-pole low-pass, to take the edge off
static func _lowpass(buf: PackedFloat32Array, cutoff: float) -> void:
	var a := 1.0 - exp(-TAU * cutoff / MIX_RATE)
	var y := 0.0
	for i in buf.size():
		y += a * (buf[i] - y)
		buf[i] = y

## A single soft repeat `delay` seconds later, as a small room would give
static func _echo(buf: PackedFloat32Array, delay: float, gain: float) -> void:
	var d := int(delay * MIX_RATE)
	for i in range(buf.size() - 1, d - 1, -1):
		buf[i] += buf[i - d] * gain

## Scales to `level` of PEAK and fades the last 20 ms out so nothing is cut off with a click
static func _finish(buf: PackedFloat32Array, level: float) -> PackedFloat32Array:
	var peak := 0.0
	for s in buf:
		peak = maxf(peak, absf(s))
	if peak <= 0.0:
		return buf
	var scale := PEAK * level / peak
	var fade := mini(int(0.02 * MIX_RATE), buf.size())
	for i in buf.size():
		var g := scale
		var from_end := buf.size() - 1 - i
		if from_end < fade:
			g *= float(from_end) / fade
		buf[i] *= g
	return buf

static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(int(samples[i] * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
