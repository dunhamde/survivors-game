class_name EnemyData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var texture: Texture2D
@export var max_health: int = 40
@export var move_speed: float = 70.0
@export var xp_value: int = 2
@export var contact_damage: int = 8
@export var collision_radius: float = 12.0
@export var sheet_cols: int = 1
@export var sheet_rows: int = 1
@export var sheet_cols_are_dirs: bool = false
@export var walk_frames: int = 5
@export var death_row: int = 9
@export var death_frames: int = 5
## Explicit death frames as (column, row). Empty uses linear frames from death_row.
@export var death_cells: Array[Vector2i] = []
## South/SE death clip. Used when facing E/SE/S if non-empty; otherwise death_cells.
@export var death_cells_south: Array[Vector2i] = []
