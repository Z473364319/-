extends BaseEnemy

func _physics_process(delta: float) -> void:
	super._physics_process(delta) # 调用基类逻辑（处理冷却、死亡等）
	
	# 如果死了，或者找不到玩家，直接返回
	if _is_dead or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	# 【视野判断】如果玩家在视野外，原地待机
	if not is_player_in_sight():
		velocity = Vector2.ZERO
		move_and_slide()
		if anim and anim.has_animation("Stand") and anim.current_animation != "Stand":
			anim.play("Stand")
		return
		
	var distance = global_position.distance_to(target.global_position)
	var direction = (target.global_position - global_position).normalized()
	
	# 移动与攻击逻辑
	if distance > data.attack_range:
		# 追击玩家（记得加上 move_and_slide）
		velocity = direction * move_speed
		move_and_slide()
		if anim and anim.has_animation("Move") and anim.current_animation != "Move":
			anim.play("Move")
	else:
		# 进入攻击范围，停下并攻击
		velocity = Vector2.ZERO
		move_and_slide()
		_perform_attack(attack_damage)
	
	# 左右翻转
	if direction.x != 0 and sprite:
		sprite.flip_h = direction.x < 0
