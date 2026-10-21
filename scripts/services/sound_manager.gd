class_name SoundManager
extends Node

## Procedural UI Sound Synthesizer (GDD §41)
## Generates clean UI feedback sounds with zero external binary assets.

static var _audio_player: AudioStreamPlayer
static var _generator: AudioStreamGenerator
static var _playback: AudioStreamGeneratorPlayback
static var _sample_rate: float = 22050.0

static func init_audio(parent_node: Node) -> void:
	if _audio_player != null:
		return

	_audio_player = AudioStreamPlayer.new()
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = _sample_rate
	_generator.buffer_length = 0.5
	_audio_player.stream = _generator

	parent_node.add_child(_audio_player)
	if _audio_player.is_inside_tree():
		_audio_player.play()
		_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

static func play_tone(freq: float, duration: float, volume: float = 0.25) -> void:
	if not SettingsScreen.sounds_enabled or _playback == null:
		return

	var frames_to_fill: int = int(_sample_rate * duration)
	var phase: float = 0.0
	var phase_increment: float = (freq * TAU) / _sample_rate

	for i in range(frames_to_fill):
		var env: float = 1.0 - (float(i) / float(frames_to_fill)) # Linear decay
		var sample: float = sin(phase) * env * volume
		_playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + phase_increment, TAU)

static func play_number_placed() -> void:
	play_tone(587.33, 0.06, 0.20) # D5 pop

static func play_erase() -> void:
	play_tone(293.66, 0.05, 0.18) # D4 soft tap

static func play_button_tap() -> void:
	play_tone(440.0, 0.04, 0.15) # A4 crisp micro-tap

static func play_conflict() -> void:
	play_tone(196.00, 0.12, 0.28) # G3 alert buzz

static func play_complete() -> void:
	# Rising major fanfare
	play_tone(523.25, 0.08, 0.25) # C5
	play_tone(659.25, 0.08, 0.25) # E5
	play_tone(783.99, 0.08, 0.25) # G5
	play_tone(1046.50, 0.25, 0.30) # C6
