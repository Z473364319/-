extends Resource
class_name CharacterStats

@export_group("基础属性")
@export var max_health: int = 100        # 生命
@export var defense: int = 0             # 防御

@export_group("战斗属性")
@export var lifesteal: float = 0.0       # 吸血（0.1 代表 10%）
@export var health_regen: float = 0.0    #生命再生（1.5 代表每秒回 1.5 血）
@export var ranged_attack: int = 10      # 远程攻击力

@export_group("基础财富")
@export var wealth : int = 30
