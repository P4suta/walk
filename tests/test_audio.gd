extends GutTest

var audio: GameAudio


func before_each() -> void:
	audio = GameAudio.new()
	add_child_autofree(audio)


func test_effects_are_bounded_signed_pcm_with_quiet_boundaries() -> void:
	for player: AudioStreamPlayer in audio.effects.values():
		var stream: AudioStreamWAV = player.stream as AudioStreamWAV
		assert_eq(stream.data[0], 0)
		assert_eq(stream.data[stream.data.size() - 1], 0)
		assert_eq(player.max_polyphony, 1)
		assert_lt(stream.get_length(), 0.5)


func test_music_loops_and_volume_controls_are_independent() -> void:
	var settings := GameSettings.new()
	settings.music_volume = 0.25
	settings.effects_volume = 0.75
	audio.configure(settings)
	var stream: AudioStreamOggVorbis = audio.music.stream as AudioStreamOggVorbis
	assert_true(stream.loop)
	assert_gt(stream.get_length(), 1.0)
	assert_almost_eq(db_to_linear(audio.music.volume_db), 0.25, 0.0001)
	assert_almost_eq(db_to_linear(audio.effects["step"].volume_db), 0.75, 0.0001)
	settings.audio_enabled = false
	audio.configure(settings)
	assert_true(audio.music.stream_paused)
	audio.play_effect("step", settings)
	assert_false(audio.effects["step"].playing)
