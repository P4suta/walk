class_name GameSettings
extends RefCounted

var audio_enabled: bool = true
var hold_to_walk: bool = false
var walk_key: int = KEY_SPACE
var music_volume: float = 0.5
var effects_volume: float = 0.7


static func valid_walk_key(code: int) -> bool:
	return code >= KEY_SPACE and code <= KEY_Z or code >= KEY_F1 and code <= KEY_F12
