extends CharacterBody2D
class_name BaseEnemy

# ================= 信号（驱动波次和UI） =================
signal enemy_died(enemy: BaseEnemy)    # 死亡信号
signal health_updated(current_hp: int, max_hp: int) # 血量变化信号

# ================= 内部状态 =================
var data: EnemyData                    # 对应的数据蓝图
var current_health: int
var max_health: int
var attack_damage: int
var move_speed: float
var _attack_timer: float = 0.0
var target: Node2D = null
var _is_dead: bool = false
var detection_range: float = 700.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	add_to_group("enemies")
	# 寻找玩家
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

# ================= 初始化与难度系数 =================
# 由波次管理器在生成敌人后调用
func setup(enemy_data: EnemyData, difficulty_multiplier: float = 1.0) -> void:
	data = enemy_data
	max_health = int(data.max_health * difficulty_multiplier)
	current_health = max_health
	attack_damage = int(data.attack_damage * difficulty_multiplier)
	move_speed = data.move_speed * (1.0 + (difficulty_multiplier - 1.0) * 0.5)
	
	# 【新增】读取视野范围
	detection_range = data.detection_range
	
	# ... 血条初始化等其他代码保持不变 ...
	
	# 初始化血条

	# 播放对应的动画（如果有）
	if anim and anim.has_animation("Move"): anim.play("Move")

# ================= 受击逻辑 =================
func take_damage(amount: int, attacker: Node = null) -> void:
	if _is_dead: return
	current_health -= amount
	current_health = max(0, current_health)
	
	if current_health <= 0:
		die()

# ================= 死亡逻辑（含掉落） =================
# 专门负责掉落金币的函数
func drop_loot() -> void:
	if data and data.loot_scene:
		for i in range(data.loot_amount):
			var loot = data.loot_scene.instantiate()
			loot.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
					
			get_parent().call_deferred("add_child", loot)

# 【正常被玩家打死】：掉金币 + 播放动画 + 销毁
func die() -> void:
	if _is_dead: return
	_is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	
	drop_loot() # 只有正常死亡才掉金币
	
	if anim and anim.has_animation("Die"):
		anim.play("Die")
		await anim.animation_finished
		
	enemy_died.emit(self)
	queue_free()

# 【波次结束被系统清除】：直接原地消失，不掉金币！
func force_clear() -> void:
	if _is_dead: return
	_is_dead = true
	
	# 这里千万不要调用 drop_loot()
	enemy_died.emit(self) # 发送信号告诉管理器减少数量
	queue_free()          # 瞬间消失

# ================= 物理与攻击框架（由子类重写） =================
func _physics_process(delta: float) -> void:
	if _is_dead: return
	if _attack_timer > 0.0: _attack_timer -= delta
	if not is_instance_valid(target): return
	# 子类需重写此函数来实现具体的攻击模式

# 攻击冷却辅助函数
func _perform_attack(damage: int) -> void:
	if _attack_timer > 0.0: return
	_attack_timer = data.attack_cooldown
	if anim.has_animation("Attack"): anim.play("Attack")
	target.take_damage(damage, self)
	

## 判断玩家是否在视野内
func is_player_in_sight() -> bool:
	if not is_instance_valid(target):
		return false
	return global_position.distance_to(target.global_position) <= detection_range
	
