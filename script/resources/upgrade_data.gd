extends Resource
class_name UpgradeData

@export var id: String = "unique_id"
@export var upgrade_name: String = "未知增益"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var price: int = 15


# 固定生效的效果
@export var effects: Array[StatEffect] = []

# 【新增】随机效果池（如果这个数组有东西，购买时会在里面随机抽一个生效）
@export var random_effect_pool: Array[StatEffect] = []
