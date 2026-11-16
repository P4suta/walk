class_name ScenerySprite
extends RefCounted

var title: String
var texture: Texture2D
var origin: Vector2
var motion: int


func _init(data: Dictionary) -> void:
	title = String(data.name)
	texture = load("res://assets/art/" + String(data.artwork)) as Texture2D
	origin = Vector2(float(data.x), float(data.y))
	motion = int(data.motion)
