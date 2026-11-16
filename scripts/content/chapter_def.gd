class_name ChapterDef
extends Resource

@export var title: String = ""
@export var source_origin_m: float = 0.0
@export var gate_price: int = 0
@export var gate_multiplier: float = 1.0
@export var regions: Array[RegionDef] = []


func sight_count() -> int:
	var count: int = 0
	for region: RegionDef in regions:
		count += region.sights.size()
	return count


func length_m() -> float:
	return regions.back().end_distance_m - source_origin_m
