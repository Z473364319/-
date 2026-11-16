extends CharacterBody2D
class_name CharacterBase

# 数据蓝图：在编辑器里挂载对应的 .tres 文件
@export var base_stats: CharacterStats

# 运行时属性（会被资源库的数据覆盖）
var current_health: int
var max_health: int
var defense: int
var lifesteal: float
var ranged_attack: int
var health_regen: float

func _ready() -> void:
	_init_stats()

# 从资源库读取数据，初始化自身属性
func _init_stats() -> void:
	if not base_stats:
		push_warning(name + " 未配置 base_stats 资源！将使用默认值。")
		max_health = 100
		defense = 0
		lifesteal = 0.0
		ranged_attack = 10
	else:
		max_health = base_stats.max_health
		defense = base_stats.defense
		lifesteal = base_stats.lifesteal
		ranged_attack = base_stats.ranged_attack
	
	current_health = max_health

# ================= 通用战斗逻辑 =================
# 受到伤害
func take_damage(amount: int, attacker: Node = null) -> void:
	# 1. 防御减伤（最低受到 1 点伤害）
	var final_damage = max(1, amount - defense)
	current_health -= final_damage
	print(name, " 受到 ", final_damage, " 点伤害，剩余生命：", current_health)
	
	# 2. 吸血逻辑（攻击者攻击时触发）
	if attacker and "lifesteal" in attacker and attacker.lifesteal > 0.0:
		var heal_amount = int(final_damage * attacker.lifesteal)
		if heal_amount > 0 and current_health < max_health:
			attacker.heal(heal_amount)
			print(attacker.name, " 触发吸血，恢复 ", heal_amount, " 点生命")
	
	# 3. 死亡判定
	if current_health <= 0:
		die()

# 回血
func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)

# 死亡逻辑（子类可以重写此函数来实现玩家/敌人不同的死亡效果）
func die() -> void:
	print(name, " 死亡")
	queue_free()
