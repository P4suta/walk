class_name GameAudio
extends Node

const MUSIC: AudioStreamOggVorbis = preload("res://assets/audio/ym2203_test_tune.ogg")

var music: AudioStreamPlayer
var effects: Dictionary[String, AudioStreamPlayer] = {}
var _last_step_usec: int = -1000000


func _ready() -> void:
	music = AudioStreamPlayer.new()
	var track: AudioStreamOggVorbis = MUSIC.duplicate() as AudioStreamOggVorbis
	track.loop = true
	music.stream = track
	add_child(music)
	var tones: Dictionary[String, Array] = {
		"step": [180.0, 140.0],
		"buy": [660.0, 880.0],
		"gate": [440.0, 660.0, 880.0],
		"home": [523.25, 659.25, 783.99, 1046.5],
	}
	for key: String in tones:
		var player := AudioStreamPlayer.new()
		player.stream = _tone(tones[key], 0.035 if key == "step" else 0.09)
		player.max_polyphony = 1
		add_child(player)
		effects[key] = player
	music.play()


func configure(settings: GameSettings) -> void:
	if music == null:
		return
	music.volume_db = linear_to_db(maxf(settings.music_volume, 0.00001))
	music.stream_paused = not settings.audio_enabled or settings.music_volume == 0.0
	for player: AudioStreamPlayer in effects.values():
		player.volume_db = linear_to_db(maxf(settings.effects_volume, 0.00001))
		player.stream_paused = not settings.audio_enabled or settings.effects_volume == 0.0
		if not settings.audio_enabled or settings.effects_volume == 0.0:
			player.stop()


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if music != null:
		music.stream_paused = false
		music.stop()
		music.stream = null
	for player: AudioStreamPlayer in effects.values():
		player.stop()
		player.stream = null


func play_effect(key: String, settings: GameSettings) -> void:
	if not settings.audio_enabled or settings.effects_volume <= 0.0:
		return
	if key == "step":
		var now: int = Time.get_ticks_usec()
		if now - _last_step_usec < 80000:
			return
		_last_step_usec = now
	if effects.has(key):
		effects[key].play()


func _tone(frequencies: Array, duration_s: float) -> AudioStreamWAV:
	var samples := PackedByteArray()
	for frequency: float in frequencies:
		var length: int = int(22050 * duration_s)
		for index: int in range(length):
			var phase: float = float(index) / 22050.0
			var envelope: float = minf(1.0, index / 80.0) * (1.0 - float(index) / length)
			var wave: float = 1.0 if sin(TAU * frequency * phase) >= 0.0 else -1.0
			samples.append(int(28.0 * wave * envelope) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.data = samples
	return stream
