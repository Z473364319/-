extends Node2D

# ================= 信号（用于通知 UI） =================
signal wave_started(wave_index: int, total_waves: int)
signal wave_time_updated(time_left: float)
signal wave_ended()

# ================= 波次配置 =================
@export var waves: Array[WaveData] = []        
@export var rest_duration: float = 5.0         
@export var transition_texture: Texture2D    

# ================= UI 引用 =================
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var inventory_menu: CanvasLayer = $InventoryMenu

# ================= 内部状态 =================
var _current_wave_index: int = -1
var _current_wave_data: WaveData
var _wave_time_left: float = 0.0
var _spawn_timer: Timer
var _is_wave_active: bool = false
var _fixed_spawn_queue: Array[EnemyData] = []   # 精确刷怪：本波还没刷出来的敌人（为空数组表示走随机权重）
var _spawn_speed_scale: float = 1.0             # 运行时刷怪速度倍率（1 = 正常，2 = 快一倍）

# ================= 生命周期 =================
func _ready() -> void:
	# ===== 新的一局开始：重置上一局遗留的全局状态 =====
	Engine.time_scale = 1.0        # 防止“时停中死亡/退出”把慢动作带进新局
	get_tree().paused = false      # 防止暂停状态残留，导致新局一开局就是停住的
	InventoryManager.reset()       # 清空背包：道具/加成不跨局继承
	SaveManager.last_game_wave = 0
	SaveManager.last_game_gold = 0
	
	_spawn_timer = Timer.new()
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_try_spawn_enemy)
	
	# 连接暂停菜单发出的“请求打开背包”信号
	if pause_menu and pause_menu.has_signal("inventory_requested"):
		pause_menu.inventory_requested.connect(_on_request_inventory)
	
	await get_tree().process_frame
	_start_next_wave()

# ================= 统一接管全局按键（核心修复） =================
func _unhandled_input(event: InputEvent) -> void:
	# 1. 背包（Q 键）交给 InventoryMenu 自己处理：
	#    ground 在游戏暂停时不处理输入，商店里按 Q 就打不开背包了
	# 2. 处理 Esc 键（暂停）
	if event.is_action_pressed("PAUSE"):
		# 如果背包开着，按 Esc 先关背包
		if inventory_menu.visible:
			inventory_menu.close_inventory() 
		# 切换暂停菜单状态
		elif pause_menu.visible:
			pause_menu.hide()
			get_tree().paused = false 
		elif not get_tree().paused:
			if pause_menu.has_method("open_pause"):
				pause_menu.open_pause()
			else:
				pause_menu.show()
			get_tree().paused = true 
			
		get_viewport().set_input_as_handled()

func _on_request_inventory() -> void:
	inventory_menu.open_inventory()

# ================= 波次倒计时 =================
func _process(delta: float) -> void:
	# 【新增】如果游戏暂停了，波次倒计时停止
	if get_tree().paused:
		return
		
	if _is_wave_active:
		_wave_time_left -= delta
		wave_time_updated.emit(_wave_time_left) 
		
		# 波次内刷新速度：按进度从 spawn_interval 逐渐过渡到 spawn_interval_end
		_update_spawn_interval()
		
		# 精确刷怪模式：本波配置的敌人全部刷完、场上也清空后，不用再干等倒计时
		if _is_fixed_wave() and _fixed_spawn_queue.is_empty() and get_tree().get_nodes_in_group("enemies").is_empty():
			_end_current_wave()
			return
		
		if _wave_time_left <= 0.0:
			_end_current_wave()

# ================= 波次核心逻辑 =================
func _start_next_wave() -> void:
	_current_wave_index += 1
	
	if _current_wave_index < waves.size():
		_current_wave_data = waves[_current_wave_index]
	else:
		_current_wave_data = _generate_endless_wave(_current_wave_index + 1)
		print("=== 进入无限模式，第 ", _current_wave_index + 1, " 波 ===")
	
	if _current_wave_data == null:
		push_warning("警告：波次数据为空，正在跳过...")
		_start_next_wave()
		return
	
	print("=== 开始第 ", _current_wave_index + 1, " 波，时长 ", _current_wave_data.duration, " 秒 ===")
	
	_wave_time_left = _current_wave_data.duration
	_is_wave_active = true
	
	# 按本波配置生成本波的刷怪队列（固定数量 / 随机权重二选一）
	_build_spawn_plan(_current_wave_data)
	
	var total_waves = -1 if _current_wave_index >= waves.size() else waves.size()
	wave_started.emit(_current_wave_index + 1, total_waves)
	
	_spawn_timer.wait_time = _current_wave_data.spawn_interval
	_spawn_timer.start()
	
	# 通知玩家进行联动检测
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.has_method("_check_synergies"):
			player._check_synergies()
			
	# 精英：本波一开始就固定刷出来（其余敌人继续按随机权重刷）
	_spawn_elites()

func _end_current_wave() -> void:
	_is_wave_active = false
	_spawn_timer.stop()
	wave_ended.emit()
	print("=== 第 ", _current_wave_index + 1, " 波结束 ===")
	
	# 1. 清空场上敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("force_clear"):
			enemy.force_clear()
		else:
			enemy.queue_free()
			
	# 2. 重置玩家状态
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		player.global_position = Vector2(0, 0)
		player.velocity = Vector2.ZERO
		player.current_health = player.max_health
		if "_regen_accumulator" in player:
			player._regen_accumulator = 0.0
			
	# 3. 播放过渡动画
	await get_tree().create_timer(0.3).timeout
	await _play_transition_animation()
	
	# 4. 动态实例化商店
	var shop_scene = load("res://Scenes/UI/shop_ui.tscn")
	if not shop_scene:
		push_error("找不到商店场景！")
		return
	var shop_instance = shop_scene.instantiate()
	add_child(shop_instance)
	
	# 5. 打开商店并等待玩家点击继续
	if players.size() > 0:
		shop_instance.open_shop(players[0])
		await shop_instance.shop_closed
		shop_instance.queue_free()
		
	# 6. 继续下一波
	print("=== 玩家离开商店，准备进入下一波 ===")
	# 【修复】使用安全的组获取方式，防止 $player 报错
	if players.size() > 0:
		var player = players[0]
		if player.has_method("_check_synergies"):
			player._check_synergies()
			
	_start_next_wave()
	
# ================= 过渡动画 =================
func _play_transition_animation() -> void:
	var transition_layer = CanvasLayer.new()
	transition_layer.layer = 100
	add_child(transition_layer)
	
	var bg_rect = TextureRect.new()
	bg_rect.texture = transition_texture
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT) 
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED 
	bg_rect.modulate.a = 0 
	transition_layer.add_child(bg_rect)
	
	var label = Label.new()
	label.text = "波次结束"
	label.add_theme_font_size_override("font_size", 60)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.modulate.a = 0 
	bg_rect.add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true) 
	tween.tween_property(bg_rect, "modulate:a", 1.0, 0.5)
	tween.tween_property(label, "modulate:a", 1.0, 0.5).set_delay(0.2)
	await tween.finished
	
	await get_tree().create_timer(1.0).timeout
	
	var tween_out = create_tween()
	tween_out.tween_property(bg_rect, "modulate:a", 0.0, 0.3)
	await tween_out.finished
	
	transition_layer.queue_free()
	
# ================= 无限波次生成逻辑 =================
func _generate_endless_wave(wave_num: int) -> WaveData:
	var extra_waves = wave_num - waves.size()
	var endless_wave = WaveData.new()
	
	endless_wave.duration = 20.0 + extra_waves * 1.0       
	endless_wave.spawn_interval = max(0.2, 1.2 - extra_waves * 0.1) 
	endless_wave.max_enemies = 15 + extra_waves * 2        
	endless_wave.difficulty_multiplier = 1.0 + extra_waves * 0.15 
	
	var all_enemies = GameDatabase.all_enemy_types
	if all_enemies.size() > 0:
		for i in range(min(2, all_enemies.size())):
			endless_wave.enemies.append(all_enemies.pick_random())
			endless_wave.weights.append(1) 
			
	return endless_wave

# ================= 刷怪逻辑 =================
## 当前波是否使用精确刷怪（配置了 fixed_enemies 就走固定数量模式）
func _is_fixed_wave() -> bool:
	return _current_wave_data != null and not _current_wave_data.fixed_enemies.is_empty()

## 按波次配置构建本波的待刷队列；没配置精确刷怪时队列为空，继续走随机权重
func _build_spawn_plan(wave: WaveData) -> void:
	_fixed_spawn_queue.clear()
	if wave == null or wave.fixed_enemies.is_empty():
		return
		
	for i in range(wave.fixed_enemies.size()):
		var enemy_data: EnemyData = wave.fixed_enemies[i]
		if enemy_data == null:
			continue
		# 没填数量的默认按 1 个算；填 0 表示这一种不刷
		var count := 1
		if i < wave.fixed_counts.size():
			count = max(0, wave.fixed_counts[i])
		for _n in range(count):
			_fixed_spawn_queue.append(enemy_data)
			
	# 打乱顺序，避免同一种敌人扎堆出现
	_fixed_spawn_queue.shuffle()
	print("=== 第 ", _current_wave_index + 1, " 波精确刷怪：共 ", _fixed_spawn_queue.size(), " 个 ===")

## 把一个敌人刷到玩家周围（精确刷怪 / 随机刷怪 / 精英共用）
func _spawn_enemy(enemy_data: EnemyData, difficulty: float) -> void:
	if not enemy_data or not enemy_data.scene:
		return
		
	var enemy = enemy_data.scene.instantiate()
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var random_angle = randf() * TAU
		var spawn_distance = randf_range(800, 1200) 
		enemy.global_position = player.global_position + Vector2.RIGHT.rotated(random_angle) * spawn_distance
		
	add_child(enemy)
	if enemy is BaseEnemy:
		enemy.setup(enemy_data, difficulty)
		enemy.enemy_died.connect(_on_enemy_died)

## 本波精英：波次一开始就固定刷出来，其余敌人仍然按随机权重刷
func _spawn_elites() -> void:
	if _current_wave_data == null:
		return
		
	var elite_difficulty = _current_wave_data.difficulty_multiplier * _current_wave_data.elite_scale
	for i in range(_current_wave_data.elite_enemies.size()):
		var enemy_data: EnemyData = _current_wave_data.elite_enemies[i]
		if enemy_data == null:
			continue
		var count := 1
		if i < _current_wave_data.elite_counts.size():
			count = max(0, _current_wave_data.elite_counts[i])
		for _n in range(count):
			_spawn_enemy(enemy_data, elite_difficulty)
			print("=== 第 ", _current_wave_index + 1, " 波精英出现：", enemy_data.enemy_name, " ===")

func _try_spawn_enemy() -> void:
	if not _is_wave_active: return
	
	if get_tree().get_nodes_in_group("enemies").size() >= _current_wave_data.max_enemies:
		return
		
	var enemy_data: EnemyData = null
	if _is_fixed_wave():
		if _fixed_spawn_queue.is_empty():
			return # 本波配置的敌人已经全部刷完
		enemy_data = _fixed_spawn_queue.pop_front()
	else:
		enemy_data = _get_weighted_enemy(_current_wave_data)
		
	_spawn_enemy(enemy_data, _current_wave_data.difficulty_multiplier)

## 按波次进度动态调整刷怪间隔：从 spawn_interval 线性过渡到 spawn_interval_end
func _update_spawn_interval() -> void:
	if _current_wave_data == null:
		return
	
	var base_interval := _current_wave_data.spawn_interval
	var end_interval := _current_wave_data.spawn_interval_end
	if end_interval > 0.0:
		var total := _current_wave_data.duration
		var progress := 1.0 if total <= 0.0 else clampf(1.0 - _wave_time_left / total, 0.0, 1.0)
		base_interval = lerpf(base_interval, end_interval, progress)
	
	# 再叠加运行时的整体倍率（技能 / 事件可以通过 set_spawn_speed_scale 调整）
	var interval := maxf(base_interval / maxf(_spawn_speed_scale, 0.01), 0.05)
	
	# 只有变化比较明显时才写入，避免每帧都去改 Timer
	if absf(_spawn_timer.wait_time - interval) > 0.01:
		_spawn_timer.wait_time = interval

## 运行时整体加速/减速刷怪：1 = 正常，2 = 快一倍，0.5 = 慢一半
func set_spawn_speed_scale(scale: float) -> void:
	_spawn_speed_scale = clampf(scale, 0.1, 10.0)

func _on_enemy_died(enemy: BaseEnemy) -> void:
	if enemy.data:
		print(enemy.data.enemy_name, " 被击杀！")
	
# ================= 权重抽卡 =================
func _get_weighted_enemy(wave: WaveData) -> EnemyData:
	if wave.enemies.is_empty():
		return null
	if wave.enemies.size() != wave.weights.size():
		return wave.enemies.pick_random()
		
	var total_weight = 0
	for w in wave.weights:
		total_weight += w
		
	var random_val = randi_range(1, total_weight)
	var current_weight = 0
	
	for i in range(wave.enemies.size()):
		current_weight += wave.weights[i]
		if random_val <= current_weight:
			return wave.enemies[i]
			
	return wave.enemies[0]
