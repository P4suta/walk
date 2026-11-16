class_name GameState
extends RefCounted

var steps: int = 0
var total_steps: int = 0
var distance_m: float = 0.0
var chapter_distance_m: float = 0.0
var chapter: int = 0
var purchases: Array[int] = [0, 0, 0, 0, 0, 0]
var reached_count: int = 0
var visited_count: int = 0
var home: bool = false
var play_time_s: float = 0.0
var auto_fraction: float = 0.0


func copy() -> GameState:
	var result := GameState.new()
	result.steps = steps
	result.total_steps = total_steps
	result.distance_m = distance_m
	result.chapter_distance_m = chapter_distance_m
	result.chapter = chapter
	result.purchases.assign(purchases)
	result.reached_count = reached_count
	result.visited_count = visited_count
	result.home = home
	result.play_time_s = play_time_s
	result.auto_fraction = auto_fraction
	return result
