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
var is_hurting: bool = false          # 当前是否处于受击停顿
var _hurt_timer: float = 0.0          # 受击停顿剩余时间

# ================= 聚集与分散（防止敌人挤成一坨） =================
@export_group("聚集与分散")
## 与其他敌人的距离小于该值时，会自动向外散开（像素）
@export var separation_radius: float = 500.0
## 散开时的最大推力速度（越大越不容易挤在一起）
@export var separation_force: float = 120.0
## 每帧最多参考多少个邻居（敌人很多时的性能保护）
@export var separation_max_neighbors: int = 14

# ================= 游走（视野里没有玩家时随机走动） =================
@export_group("游走")
## 视野内没有玩家时，是否随机游走
@export var wander_enabled: bool = true
## 游走速度占正常移动速度的比例
@export var wander_speed_ratio: float = 0.5
## 围绕出生点游走的半径（离得太远会自动换个中心）
@export var wander_radius: float = 320.0
## 每次停下发呆的时长范围（秒）
@export var wander_pause_range: Vector2 = Vector2(0.6, 1.8)
## 每次朝目标点走动的时长范围（秒）
@export var wander_move_range: Vector2 = Vector2(1.0, 2.5)

# ================= 受击表现 =================
@export_group("受击表现")
## 受击后原地不动的时间（秒）；0 表示直接使用 Hurt 动画的时长
@export var hurt_stop_time: float = 0.0

# 敌人只和墙体做物理碰撞：墙体在场景里是 255 层（所有层），用 4 层就能挡住墙；
# 同时排除了玩家层(1)，避免玩家和敌人重叠时敌人被物理推着走。
const ENEMY_COLLISION_MASK: int = 4

# ================= 游走内部状态 =================
var _wander_origin: Vector2 = Vector2.ZERO  # 游走中心（出生点）
var _wander_target: Vector2 = Vector2.ZERO  # 当前游走目标点
var _wander_timer: float = 0.0              # 当前状态剩余时间
var _wander_moving: bool = false            # 当前是在走还是在发呆

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	add_to_group("enemies")
	# 【修复】敌人只和墙体做物理碰撞，不再和玩家身体互相推挤。
	# 之前玩家撞进敌人身体后，物理的“解嵌”会把敌人一路推着走，看起来就像敌人跟着玩家跑。
	collision_mask = ENEMY_COLLISION_MASK
	_wander_origin = global_position
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
		return
	
	# 还活着：播放受击动画，并进入短暂的“停止移动”状态
	_start_hurt()

## 进入受击状态：播放 Hurt 动画，期间原地不动
func _start_hurt() -> void:
	is_hurting = true
	velocity = Vector2.ZERO
	
	if anim and anim.has_animation("Hurt"):
		var hurt_anim: Animation = anim.get_animation("Hurt")
		_hurt_timer = hurt_anim.length if hurt_anim else 0.2
		anim.play("Hurt")
	else:
		_hurt_timer = 0.2
	
	# 想在编辑器里单独控制停顿时间的话，把 hurt_stop_time 设成大于 0 即可
	if hurt_stop_time > 0.0:
		_hurt_timer = hurt_stop_time

## 结束受击状态（动画播完 / 计时结束）
func _end_hurt() -> void:
	is_hurting = false
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)

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
	is_hurting = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	
	# 如果死在受击动画中途，把颜色恢复，避免尸体一直发红
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	
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
	
	# 受击停顿倒计时：时间到了自动恢复行动
	if is_hurting:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			_end_hurt()
	
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

# ================= 分散逻辑（防止敌人叠在一起） =================
## 计算来自周围敌人的“排斥力”：距离越近，推力越大，最远到 separation_radius 为止
func get_separation_velocity() -> Vector2:
	if separation_radius <= 0.0 or separation_force <= 0.0:
		return Vector2.ZERO

	var push := Vector2.ZERO
	var radius_sq := separation_radius * separation_radius
	var counted := 0

	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as BaseEnemy
		if other == null or other == self or other._is_dead:
			continue
		if not other.is_inside_tree():
			continue

		var offset: Vector2 = global_position - other.global_position
		var dist_sq := offset.length_squared()
		if dist_sq >= radius_sq:
			continue # 距离够远，不用管

		if dist_sq < 0.0001:
			# 完全重叠：随机给个方向，避免除以 0
			push += Vector2.RIGHT.rotated(randf() * TAU)
		else:
			var dist := sqrt(dist_sq)
			# 权重：贴着时为 1，正好等于 separation_radius 时为 0
			push += (offset / dist) * (1.0 - dist / separation_radius)

		counted += 1
		if counted >= separation_max_neighbors:
			break # 邻居太多时只算前面几个，保证性能

	if push.is_zero_approx():
		return Vector2.ZERO

	# 多个邻居叠加后限制在 1 以内，再把权重换算成速度
	return push.normalized() * minf(push.length(), 1.0) * separation_force

## 把“分散力”叠加到原本想要的速度上（追击/后退时都会自动带一点避让）
func apply_separation(desired_velocity: Vector2) -> Vector2:
	var final_velocity := desired_velocity + get_separation_velocity()
	# 允许比平时快一点，但不会无限叠加
	return final_velocity.limit_length(maxf(move_speed, separation_force))

## 统一移动入口：会自动叠加分散力，敌人聚到一起时会自己让开
func move_with_separation() -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return
	velocity = apply_separation(velocity)
	move_and_slide()

# ================= 游走逻辑（视野里没有玩家时） =================
## 视野外随机游走：走一段 → 停一会儿 → 换个方向继续走
func wander(delta: float) -> void:
	if not wander_enabled:
		velocity = Vector2.ZERO
		move_with_separation()
		return

	# 被引得太远时把游走中心挪到当前位置，免得一直想跑回出生点
	if global_position.distance_to(_wander_origin) > wander_radius * 2.0:
		_wander_origin = global_position

	_wander_timer -= delta

	if _wander_moving:
		var to_target := _wander_target - global_position
		if _wander_timer <= 0.0 or to_target.length() < 12.0:
			_start_wander_pause()
		else:
			velocity = to_target.normalized() * move_speed * wander_speed_ratio
	else:
		velocity = Vector2.ZERO
		if _wander_timer <= 0.0:
			_start_wander_move()

	# 游走时也保持同伴间距，避免又挤成一团
	move_with_separation()
	_update_wander_visual()

## 开始“走一段”
func _start_wander_move() -> void:
	_wander_moving = true
	_wander_timer = randf_range(wander_move_range.x, wander_move_range.y)
	var angle := randf() * TAU
	var dist := randf_range(wander_radius * 0.25, wander_radius)
	_wander_target = _wander_origin + Vector2.RIGHT.rotated(angle) * dist

## 开始“停一会儿”
func _start_wander_pause() -> void:
	_wander_moving = false
	_wander_timer = randf_range(wander_pause_range.x, wander_pause_range.y)
	velocity = Vector2.ZERO

## 游走时的动画与左右翻转
func _update_wander_visual() -> void:
	if absf(velocity.x) > 1.0 and sprite:
		sprite.flip_h = velocity.x < 0

	if anim == null:
		return
	if velocity.length() > 1.0:
		if anim.has_animation("Move") and anim.current_animation != "Move":
			anim.play("Move")
	elif anim.has_animation("RESET") and anim.current_animation != "RESET":
		anim.play("RESET")
	
