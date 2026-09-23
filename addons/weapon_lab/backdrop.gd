@tool
extends Node2D

var mode: int = 2
var extent := Vector2(600, 400)


func _draw() -> void:
	if mode == 1:
		draw_rect(Rect2(-extent, extent * 2), Color("171d24"))
		return
	var atlas := preload("res://assets/tiles/elwynn/summer_tiles.png")
	var tile := 32 if mode == 2 else 16
	var count := Vector2i((extent / float(tile)).ceil())
	for y in range(-count.y, count.y + 1):
		for x in range(-count.x, count.x + 1):
			var rect := Rect2(Vector2(x, y) * tile, Vector2.ONE * tile)
			if mode == 2:
				var index := posmod(x * 7 + y * 13, SummerCatalog.SOLID_GRASS.size())
				var cell := SummerCatalog.SOLID_GRASS[index]
				draw_texture_rect_region(atlas, rect, Rect2(Vector2(cell) * 33, Vector2(32, 32)))
			else:
				var color := Color("252a32") if posmod(x + y, 2) == 0 else Color("343b45")
				draw_rect(rect, color)
