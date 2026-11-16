extends Resource
class_name WaveData

@export var duration: float = 20.0
@export var spawn_interval: float = 1.0
@export var max_enemies: int = 15
@export var difficulty_multiplier: float = 1.0

# ==================== 权重刷怪配置 ====================
@export_group("敌人配置")
## 本波次可刷出的敌人类型（按顺序拖入）
@export var enemies: Array[EnemyData] = []

## 对应的权重（必须与上方数组长度一致，数值越大占比越高）
@export var weights: Array[int] = []
