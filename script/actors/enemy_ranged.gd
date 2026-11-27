extends BaseEnemy

@onready var muzzle: Marker2D = $Muzzle # 枪口节点

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	# 0. 受击：Hurt 动画播放期间原地不动，也不射击
	if is_hurting:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	# 1. 视野判断：玩家不存在或者不在视野内 → 随机游走（不会傻站着）
	if not is_instance_valid(target) or not is_player_in_sight():
		wander(delta)
		return
		
	var distance = global_position.distance_to(target.global_position)
	var direction = (target.global_position - global_position).normalized()
	
	# 2. 走位逻辑：保持安全距离
	# 如果离得太远，往前走
	if distance > data.attack_range + 50:
		velocity = direction * move_speed
	# 如果离得太近（被贴脸了），往后退
	elif distance < data.attack_range - 50:
		velocity = -direction * move_speed
	# 距离刚好，停下来射击
	else:
		velocity = Vector2.ZERO
	
	# move_with_separation 会自动叠加“分散力”：和同伴靠得太近时会被推开
	move_with_separation()
	
	# 3. 左右翻转
	if direction.x != 0 and sprite:
		sprite.flip_h = direction.x < 0
		
	# 4. 射击逻辑
	if _attack_timer <= 0.0:
		_shoot(direction)
		_attack_timer = data.attack_cooldown

func _shoot(direction: Vector2) -> void:
	if not data.bullet_scene or not muzzle:
		return
		
	var bullet = data.bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = direction
	bullet.damage = attack_damage
	bullet.shooter = self # 标记子弹是自己射的，防止打到自己
	
	get_parent().add_child(bullet)
	if anim and anim.has_animation("Attack"):
		anim.play("Attack")
