class_name WeaponData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var scene: PackedScene
@export var max_level: int = 5
@export var upgrade_hint: String = "+Damage"

@export var base_damage: float = 10.0
@export var damage_per_level: float = 4.0
@export var base_cooldown: float = 0.6
@export var cooldown_per_level: float = -0.04
@export var base_area: float = 48.0
@export var area_per_level: float = 6.0
@export var base_count: int = 1
