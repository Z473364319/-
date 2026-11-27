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

# ==================== 精确刷怪配置（可选） ====================
@export_group("精确刷怪（填了就不走随机权重）")
## 精确刷怪：第 i 项固定刷出 fixed_counts[i] 个
@export var fixed_enemies: Array[EnemyData] = []

## 与 fixed_enemies 一一对应的数量（填 0 表示这一种不刷；数量总和就是本波的总怪数）
@export var fixed_counts: Array[int] = []

# ==================== 精英配置（可选） ====================
@export_group("精英（额外固定刷，其余仍随机）")
## 本波额外固定刷新的精英敌人（不影响上面的随机权重刷怪）
@export var elite_enemies: Array[EnemyData] = []

## 与 elite_enemies 一一对应的数量
@export var elite_counts: Array[int] = []

## 精英的额外强度倍率（1 = 和普通怪一样；1.5 = 血量/伤害更高、移速略快）
@export var elite_scale: float = 1.0

# ==================== 刷新速度 ====================
@export_group("刷新速度")
## 波次结束时的刷新间隔（秒）：整波会从 spawn_interval 逐渐过渡到这个值
## 填 0 表示整波保持 spawn_interval 不变；比 spawn_interval 小 = 越刷越快，大 = 越刷越慢
@export var spawn_interval_end: float = 0.0
