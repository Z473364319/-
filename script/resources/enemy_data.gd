extends Resource
class_name EnemyData

@export_group("基础属性")
@export var enemy_name: String = "未知敌人"
@export var max_health: int = 100
@export var move_speed: float = 120.0

@export_group("战斗属性")
@export_enum("melee", "ranged", "suicide") var attack_type: String = "melee"
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var attack_range: float = 60.0
@export var bullet_scene: PackedScene # 仅远程敌人需要

@export_group("视觉与掉落")
@export var scene: PackedScene        # 敌人的场景（比如 enemy_melee.tscn）
@export var loot_scene: PackedScene  # 掉落的物品场景
@export var loot_amount: int = 1     # 掉落数量

@export_group("视野与战斗")
@export var detection_range: float = 2000.0   # 发现玩家的视野半径
