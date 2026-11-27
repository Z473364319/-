extends BaseEnemy

func _physics_process(delta: float) -> void:
	super._physics_process(delta) # 调用基类逻辑（处理冷却、死亡等）
	
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	# 【受击】Hurt 动画播放期间原地不动，也不攻击
	if is_hurting:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	# 【视野判断】玩家不存在或者不在视野内 → 随机游走（不会傻站着）
	if not is_instance_valid(target) or not is_player_in_sight():
		wander(delta)
		return
		
	var distance = global_position.distance_to(target.global_position)
	var direction = (target.global_position - global_position).normalized()
	
	# 移动与攻击逻辑（move_with_separation 会自动叠加“分散力”，
	# 当和同伴距离小于 separation_radius 时会被推开，聚不成一坨）
	if distance > data.attack_range:
		# 追击玩家
		velocity = direction * move_speed
		move_with_separation()
		if anim and anim.has_animation("Move") and anim.current_animation != "Move":
			anim.play("Move")
	else:
		# 进入攻击范围，停下并攻击（站着输出时也会被同伴挤开）
		velocity = Vector2.ZERO
		move_with_separation()
		_perform_attack(attack_damage)
	
	# 左右翻转
	if direction.x != 0 and sprite:
		sprite.flip_h = direction.x < 0
