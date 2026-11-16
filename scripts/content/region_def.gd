class_name RegionDef
extends Resource

@export var key: String = ""
@export var title: String = ""
@export var source_node: String = ""
@export var end_distance_m: float = 0.0
@export var night: bool = false
@export var helmet: bool = false
@export var sights: Array[SightDef] = []
@export_file("*.json") var landscape: String = ""
