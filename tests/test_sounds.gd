extends SceneTree

## The sounds made in code: every one renders, starts and ends without a click, stays under full
## scale, each digit has its own rising note, and quick taps play side by side

const SoundManager = preload("res://scripts/services/sound_manager.gd")

const KEYS: Array[String] = ["place_0", "place_1", "place_5", "place_9", "note", "erase", "tap", "conflict", "unit", "complete"]

var _passed: int = 0
var _failed: int = 0

func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ✓ PASS: " + name)
	else:
		_failed += 1
		printerr("  ✗ FAIL: " + name)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	print("\n=== SOUNDS ===")
	_test_rendering()
	_test_digit_notes()
	await _test_playback()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

## Crossings of zero per second: a rough pitch of the first part of a sound
static func _pitch(buf: PackedFloat32Array) -> float:
	var n := mini(buf.size(), int(0.08 * SoundManager.MIX_RATE))
	var crossings := 0
	for i in range(1, n):
		if (buf[i - 1] < 0.0) != (buf[i] < 0.0):
			crossings += 1
	return crossings * 0.5 * SoundManager.MIX_RATE / n

func _test_rendering() -> void:
	var t0 := Time.get_ticks_msec()
	for key in KEYS:
		var buf := SoundManager.render(key)
		var peak := 0.0
		var jump := 0.0
		for i in buf.size():
			peak = maxf(peak, absf(buf[i]))
			if i > 0:
				jump = maxf(jump, absf(buf[i] - buf[i - 1]))
		_check("%s is a real sound (%.2f s)" % [key, buf.size() / float(SoundManager.MIX_RATE)],
			buf.size() > 1000 and peak > 0.1)
		_check("%s stays under full scale (peak %.2f)" % [key, peak], peak <= SoundManager.PEAK + 0.001)
		# The tail is faded to exactly nothing: a sound cut off while still ringing clicks
		_check("%s starts and ends at silence, no click" % key, absf(buf[0]) < 0.01 and absf(buf[buf.size() - 1]) < 0.0005)
		_check("%s has no sudden jump (largest step %.3f)" % [key, jump], jump < 0.25)
	var ms := Time.get_ticks_msec() - t0
	_check("Rendering every sound is quick (%d ms)" % ms, ms < 3000)
	_check("A finished game sounds longer than a placed digit",
		SoundManager.render("complete").size() > 3 * SoundManager.render("place_1").size())
	_check("Unknown sounds are silent, not an error", SoundManager.render("nope").is_empty())
	var a := SoundManager.get_stream("note")
	_check("A sound is rendered once and kept", a != null and a == SoundManager.get_stream("note"))
	_check("as a 16-bit sample at the mix rate",
		a.format == AudioStreamWAV.FORMAT_16_BITS and a.mix_rate == SoundManager.MIX_RATE and a.data.size() == SoundManager.render("note").size() * 2)

func _test_digit_notes() -> void:
	var pitches: Array[float] = []
	for d in range(1, 10):
		pitches.append(_pitch(SoundManager.render("place_%d" % d)))
	var rising := true
	for i in range(1, pitches.size()):
		rising = rising and pitches[i] > pitches[i - 1]
	_check("Digits 1 to 9 rise in pitch (%s)" % str(pitches.map(func(p): return roundi(p))), rising)
	_check("Digit 1 sounds near its note (%d Hz)" % roundi(pitches[0]), absf(pitches[0] - SoundManager.DIGIT_NOTES[0]) < 40.0)
	_check("A note is lighter than a digit",
		SoundManager.render("note").size() < SoundManager.render("place_5").size())
	_check("A clash sounds low", _pitch(SoundManager.render("conflict")) < 300.0)

func _test_playback() -> void:
	var host := Node.new()
	root.add_child(host)
	SoundManager.init_audio(host)
	AppSettings.sounds_enabled = true
	_check("A pool of voices is ready", host.get_child_count() == SoundManager.VOICES)
	SoundManager.shutdown()
	var t0 := Time.get_ticks_usec()
	for key in SoundManager.ALL_KEYS:
		SoundManager.get_stream(key)
	var us := Time.get_ticks_usec() - t0
	_check("Every sound was rendered in the background at start-up (%d µs to fetch them all)" % us, us < 20000)
	for d in range(1, 5):
		SoundManager.play_number_placed(d)
	await process_frame
	var playing := host.get_children().filter(func(p): return p.playing).size()
	_check("Quick taps ring together, not one after another (%d playing)" % playing, playing >= 4)
	for i in 20:
		SoundManager.play_note()
	_check("A burst of taps never grows the pool", host.get_child_count() == SoundManager.VOICES)
	for p in host.get_children():
		p.stop()
	AppSettings.sounds_enabled = false
	SoundManager.play_complete()
	await process_frame
	_check("Sounds off: nothing plays", host.get_children().all(func(p): return not p.playing))
	AppSettings.sounds_enabled = true
	SoundManager.init_audio(host)
	_check("Setting up again keeps the same pool", host.get_child_count() == SoundManager.VOICES)
	host.queue_free()
	await process_frame
