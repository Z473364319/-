extends CharacterBase
class_name Player

# ================= 基础移动与冲刺参数 =================
@export var speed : float = 500.0
@export var dash_speed : float = 1500.0
@export var dash_duration : float = 0.15
@export var dash_cooldown : float = 3.0
@export var trail_interval: float = 0.04
@export var trail_fade_time: float = 0.25
@export var loot_count: int = 0
@export var time_slow_duration: float = 6.6  # 时停持续 6.6 秒
@export var time_slow_cooldown: float = 8.0  # 冷却 8 秒
@export var time_scale_factor: float = 0.2   # 将世界速度减缓到 20%

# ================= 初始武器配置 =================
@export var initial_ranged: WeaponData
@export var weapon_scale: Vector2 = Vector2(0.008, 0.008)

# ================= 内部状态变量 =================
var ranged_weapon: WeaponData = null
var current_weapon: WeaponData = null
var damage_multiplier: float = 1.0
var _ranged_cooldown_timer: float = 0.0
var is_invincible := false
var _is_dashing := false
var _is_hurt := false
var _is_dead := false
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_direction := Vector2.RIGHT
var _last_direction := Vector2.RIGHT
var _trail_timer := 0.0
var _original_collision_mask: int
var bull_number : int = 1
var _is_synergy_animating: bool = false # 联动动画播放锁
var has_time_stop_upgrade: bool = false # 是否获得了 0007
var is_time_slowed: bool = false        # 当前是否处于时停状态
var time_slow_timer: float = 0.0        # 时停剩余时间
var time_slow_cooldown_timer: float = 0.0 # 时停冷却
var _slow_trail_timer: float = 0.0 # 时停时的拖尾间隔计时器
var _regen_accumulator : float = 0.0

# ================= 节点引用 =================
@onready var sprite : Sprite2D = $visual/Sprite
@onready var anim : AnimationPlayer = $AnimationPlayer
@onready var weapon_pivot : Node2D = $WeaponPivot
@onready var weapon_sprite : Sprite2D = $WeaponPivot/WeaponSprite
@onready var muzzle : Marker2D = $WeaponPivot/Muzzle

# 背包与联动记录
var inventory_upgrades: Dictionary = {}
var triggered_synergies: Dictionary = {}

# ================= 生命周期 =================
func _ready() -> void:
	add_to_group("player")
	super._ready()
	anim.animation_finished.connect(_on_animation_finished)
	if initial_ranged:
		equip_weapon(initial_ranged)

func _physics_process(delta: float) -> void:
	# 1. 状态与冷却倒计时
	# 注意：使用 delta / Engine.time_scale 确保计时器在时停期间依然按现实时间流逝
	var real_delta = delta / Engine.time_scale 
	
	if _dash_cooldown_timer > 0.0: _dash_cooldown_timer -= real_delta
	if _ranged_cooldown_timer > 0.0: _ranged_cooldown_timer -= real_delta
	if time_slow_cooldown_timer > 0.0: time_slow_cooldown_timer -= real_delta
	
	# 处理时停的持续时间
	if is_time_slowed:
		time_slow_timer -= real_delta
		if time_slow_timer <= 0.0:
			_end_time_slow()
			
	# ================= 【新增】生命再生逻辑 =================
	# 如果活着，血量没满，且有再生属性，就开始回血
	if not _is_dead and current_health < max_health and health_regen > 0.0:
		# 按现实时间累积（这样即使时停，回血速度也是正常的）
		_regen_accumulator += health_regen * real_delta
		
		# 当累积器达到 1 点血时，真正加上去
		if _regen_accumulator >= 1.0:
			var heal_amount = int(_regen_accumulator)
			current_health = min(max_health, current_health + heal_amount) # 加上去，但不超过上限
			_regen_accumulator -= heal_amount # 扣掉已经加过的部分
			
			# 飘绿字提示
			_show_float_text("+" + str(heal_amount), Color.GREEN)

	# 2. 获取输入
	var direction := Input.get_vector("LEFT", "RIGHT", "UP", "DOWN")
	if direction != Vector2.ZERO:
		_last_direction = direction.normalized()

	# 3. 触发按键（判断是冲刺还是时间减缓）
	if Input.is_action_just_pressed("DASH") and not _is_hurt:
		if has_time_stop_upgrade:
			# 触发时间减缓
			if time_slow_cooldown_timer <= 0.0 and not is_time_slowed:
				current_health -= 10
				_start_time_slow()
		else:
			# 正常的冲刺逻辑
			if _dash_cooldown_timer <= 0.0 and not _is_dashing:
				_start_dash(direction)

	# 4. 移动逻辑
	if _is_hurt:
		velocity = Vector2.ZERO
	elif _is_dashing:
		_dash_timer -= real_delta
		velocity = _dash_direction * dash_speed
		# 冲刺残影
		_trail_timer -= real_delta
		if _trail_timer <= 0.0:
			_spawn_trail()
			_trail_timer = trail_interval
		if _dash_timer <= 0.0:
			_is_dashing = false
			is_invincible = false
			collision_mask = _original_collision_mask
	else:
		# 时停状态下，玩家的移动速度需要补偿，保持原本速度
		if is_time_slowed:
			velocity = direction * speed * (1.0 / time_scale_factor)*2.5
			
			# 【新增】时停且移动时，不断生成残影
			if direction != Vector2.ZERO:
				_slow_trail_timer -= (delta / Engine.time_scale) # 使用现实时间递减
				if _slow_trail_timer <= 0.0:
					_spawn_trail()
					_slow_trail_timer = 0.05 # 每 0.05 秒生成一次残影
		else:
			velocity = direction * speed

	move_and_slide()
	
	if current_health <= 0:
		die()

	# 5. 左右翻转与动画
	if direction.x != 0:
		sprite.flip_h = direction.x < 0
	_update_animation(direction)

	# ================= 武器系统 =================
	if not weapon_pivot: return
	weapon_pivot.look_at(get_global_mouse_position())
	if weapon_sprite:
		weapon_sprite.flip_v = get_global_mouse_position().x < global_position.x

	if Input.is_action_just_pressed("ATTACK_remote") and ranged_weapon != null and _ranged_cooldown_timer <= 0.0:
		_perform_ranged_attack()

# ================= 武器逻辑 =================
func equip_weapon(new_weapon: WeaponData) -> void:
	if new_weapon.weapon_type == WeaponData.WeaponType.RANGED:
		ranged_weapon = new_weapon
		current_weapon = new_weapon
		_update_weapon_visual()

func _update_weapon_visual() -> void:
	if current_weapon and current_weapon.icon and weapon_sprite:
		weapon_sprite.texture = current_weapon.icon
		weapon_sprite.visible = true
	elif weapon_sprite:
		weapon_sprite.visible = false
	
func _perform_ranged_attack() -> void:
	_ranged_cooldown_timer = ranged_weapon.attack_cooldown
	current_weapon = ranged_weapon
	_update_weapon_visual()
	
	if not ranged_weapon.bullet_scene or not muzzle: return
	
	var shoot_direction = (get_global_mouse_position() - muzzle.global_position).normalized()
	var spread_angle = 0.2
	
	for i in range(bull_number):
		var bullet = ranged_weapon.bullet_scene.instantiate() as Bullet
		if not bullet: continue
		
		var angle_offset = randf_range(-spread_angle, spread_angle) 
		var current_direction = shoot_direction.rotated(angle_offset)
		
		bullet.global_position = muzzle.global_position + current_direction * 20.0
		bullet.direction = current_direction
		bullet.damage = int(ranged_weapon.damage * damage_multiplier)
		bullet.shooter = self
		get_parent().call_deferred("add_child", bullet) # 延迟添加防物理报错

# ================= 冲刺与残影 =================
func _start_dash(input_direction: Vector2) -> void:
	_is_dashing = true
	is_invincible = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_trail_timer = 0.0
	_dash_direction = input_direction.normalized() if input_direction != Vector2.ZERO else _last_direction
	_original_collision_mask = collision_mask
	collision_mask &= ~2

func _spawn_trail() -> void:
	if not sprite: return
	var trail := Sprite2D.new()
	trail.texture = sprite.texture
	trail.flip_h = sprite.flip_h
	trail.global_position = sprite.global_position
	trail.scale = sprite.scale
	
	# 时停时显示淡蓝色，普通冲刺是半透明白
	if is_time_slowed:
		trail.modulate = Color(0.5, 0.8, 1.0, 0.6) 
	else:
		trail.modulate = Color(1, 1, 1, 0.5)
		
	get_parent().add_child(trail)
	
	var tween := create_tween()
	tween.set_ignore_time_scale(true) # 【关键】忽略时间缩放，让渐隐正常播放
	tween.tween_property(trail, "modulate:a", 0.0, trail_fade_time)
	tween.tween_callback(trail.queue_free)

# ================= 受伤与死亡 =================
func take_damage(amount: int, attacker: Node = null) -> void:
	if _is_dead or is_invincible or _is_hurt: return
	super.take_damage(amount, attacker)
	if current_health > 0:
		_is_hurt = true
		anim.play("Injured")

func die() -> void:
	if _is_dead: return
	_is_dead = true
	print("玩家死亡！Game Over")
	
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	
	# 1. 获取当前打到了第几波
	var current_wave = 1
	var ground = get_parent()
	if ground and "_current_wave_index" in ground:
		current_wave = ground._current_wave_index + 1
	
	# 2. 保存最高记录
	SaveManager.save_high_scores(current_wave, loot_count)
	
	# 3. 【新增】保存本局结束数据，供结束界面显示
	SaveManager.set_game_over_data(current_wave, loot_count)
	
	# 4. 播放死亡动画
	if anim and anim.has_animation("Die"):
		anim.play("Die")
		await anim.animation_finished 
	
	# 5. 【修改】延迟后跳转到“游戏结束”界面（而不是主菜单）
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://Scenes/UI/game_over.tscn")

# ================= 动画状态机（核心修复） =================
func _update_animation(direction: Vector2) -> void:
	# 【核心修复】联动动画播放时，拦截其他动画切换
	if _is_synergy_animating: return 
	
	if _is_dead: return
	if _is_hurt: return
	if _is_dashing:
		if anim.current_animation != "Dash": anim.play("Dash")
	elif direction != Vector2.ZERO:
		if anim.current_animation != "Move": anim.play("Move")
	else:
		if anim.current_animation != "Stand": anim.play("Stand")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Injured":
		_is_hurt = false

func add_loot(amount: int) -> void:
	loot_count += amount

# ================= 道具与联动 =================
func apply_upgrade(upgrade: UpgradeData) -> void:
	print("获得了增益：", upgrade.upgrade_name)
	
	# 【你这里必须是这样写的！】用数字累加，而不是赋值为 true！
	if inventory_upgrades.has(upgrade.id):
		inventory_upgrades[upgrade.id] += 1
	else:
		inventory_upgrades[upgrade.id] = 1

	# 准备一个最终生效的效果列表（先复制你原本的固定效果）
	var final_effects = upgrade.effects.duplicate()
	
	if upgrade.id == "0007":
		has_time_stop_upgrade = true
		print("获得 0007：冲刺键已替换为时间减缓能力！")
		# 获取时自动回复满血，防止玩家不知道机制按空格把自己扣死
		current_health = max_health
	
	# 【核心新增】如果存在随机效果池，则随机抽一个加进去
	if not upgrade.random_effect_pool.is_empty():
		var random_effect = upgrade.random_effect_pool.pick_random()
		final_effects.append(random_effect)		
		# 发个飘字提示玩家抽到了什么（调用你之前写过的飘字逻辑或直接打印）
		_show_float_text("伤害 +（" + str(random_effect.value) + ")",Color(0.91,0.13,0.78,1),200)
	
	# 遍历最终生效的效果列表并应用
	for effect in final_effects:
		match effect.stat_type:
			"max_health":
				max_health += int(effect.value)
				current_health += int(effect.value)
			"speed":
				speed += effect.value
			"damage_multiplier":
				damage_multiplier += effect.value
			"dash_cooldown":
				dash_cooldown = max(0.1, dash_cooldown - effect.value)
			"lifesteal":
				lifesteal += effect.value
			"armor":
				defense += int(effect.value)
			"combo":
				bull_number += int(effect.value)
	

# 简单的飘字提示（可选，用在开盲盒反馈上）
# 优化：飘字提示支持自定义颜色
# 增加第三个参数 font_size，默认值为 24
func _show_float_text(text: String, color: Color = Color.YELLOW, font_size: int = 24) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	
	# 【核心修改】使用传入的字号
	label.add_theme_font_size_override("font_size", font_size) 
	
	label.z_index = 100 
	
	# 根据字号动态调整 Label 的宽度和高度，防止大字被截断
	label.size = Vector2(600, font_size + 40) 
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# X轴向左偏移一半宽度，保证文字完美居中在头顶
	label.global_position = global_position + Vector2(-300, -80) 
	
	get_parent().call_deferred("add_child", label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ignore_time_scale(true) 
	tween.tween_property(label, "global_position:y", label.global_position.y - 60, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(label.queue_free)

func _check_synergies() -> void:
	if inventory_upgrades.has("0001") and inventory_upgrades.has("0002"):
		if not triggered_synergies.has("ZXF_teacher"):
			triggered_synergies["ZXF_teacher"] = true
			_activate_ZXF_teacher()

func _activate_ZXF_teacher() -> void:
	max_health -= 40
	current_health = max_health
	speed += 500
	dash_speed += 600
	bull_number += 2
	_is_synergy_animating = true
	var anim_res = anim.get_animation("ZXFteacher")
	if anim_res: anim_res.loop_mode = Animation.LOOP_NONE
	anim.play("ZXFteacher")
	_show_float_text("张雪峰老师~~，\n我还记得你~~", Color.YELLOW, 410)
	await anim.animation_finished
	_is_synergy_animating = false
	
# 开启时间减缓
func _start_time_slow() -> void:
	is_time_slowed = true
	time_slow_timer = time_slow_duration
	time_slow_cooldown_timer = time_slow_cooldown
	Engine.time_scale = time_scale_factor
	_slow_trail_timer = 0.0 # 加这一句，按下瞬间立刻出残影

# 结束时间减缓
func _end_time_slow() -> void:
	is_time_slowed = false
	Engine.time_scale = 1.0 # 恢复正常流速
	print("=== 时间减缓结束 ===")
	
	# 恢复玩家颜色
	if sprite: sprite.modulate = Color(1, 1, 1, 1)
