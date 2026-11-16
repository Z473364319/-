extends Node2D

# ================= 信号（用于通知 UI） =================
signal wave_started(wave_index: int, total_waves: int)
signal wave_time_updated(time_left: float)
signal wave_ended()

# ================= 波次配置 =================
@export var waves: Array[WaveData] = []        
@export var rest_duration: float = 5.0         
@export var transition_texture: Texture2D    

@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var inventory_menu: CanvasLayer = $InventoryMenu

@export var all_upgrades: Array[UpgradeData] = []

# ================= 内部状态 =================
var _current_wave_index: int = -1
var _current_wave_data: WaveData
var _wave_time_left: float = 0.0
var _spawn_timer: Timer
var _is_wave_active: bool = false

# ================= 生命周期 =================
func _ready() -> void:
	# 允许主节点在游戏暂停时也能接收按键
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_spawn_timer = Timer.new()
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_try_spawn_enemy)
	
	# 连接暂停菜单发出的“请求打开背包”信号
	if pause_menu and pause_menu.has_signal("inventory_requested"):
		pause_menu.inventory_requested.connect(_on_request_inventory)
	
	await get_tree().process_frame
	_start_next_wave()

# ================= 统一接管全局按键 =================
func _unhandled_input(event: InputEvent) -> void:
	# 1. 处理 Q 键（背包）
	if event.is_action_pressed("INVENTORY"):
		if inventory_menu.visible:
			inventory_menu.close_inventory() # 背包自己会处理好暂停恢复逻辑
		else:
			inventory_menu.open_inventory()  # 背包自己会记录状态并强制暂停
			
		get_viewport().set_input_as_handled()
		
	# 2. 处理 Esc 键（暂停）
	if event.is_action_pressed("PAUSE"):
		# 如果背包开着，按 Esc 先关背包
		if inventory_menu.visible:
			inventory_menu.close_inventory() 
		# 切换暂停菜单状态
		elif pause_menu.visible:
			pause_menu.hide()
			get_tree().paused = false # 关暂停菜单必须恢复游戏
		elif not get_tree().paused:
			if pause_menu.has_method("open_pause"):
				pause_menu.open_pause()
			else:
				pause_menu.show()
			get_tree().paused = true # 开暂停菜单必须暂停游戏
			
		get_viewport().set_input_as_handled()

# 当从暂停菜单点击“打开背包”时触发
func _on_request_inventory() -> void:
	inventory_menu.open_inventory()

# ================= 波次倒计时 =================
func _process(delta: float) -> void:
	if _is_wave_active:
		_wave_time_left -= delta
		wave_time_updated.emit(_wave_time_left) 
		
		if _wave_time_left <= 0.0:
			_end_current_wave()

# ================= 波次核心逻辑 =================
func _start_next_wave() -> void:
	_current_wave_index += 1
	
	# 1. 尝试读取预先配置好的波次
	if _current_wave_index < waves.size():
		_current_wave_data = waves[_current_wave_index]
	else:
		# 2. 预配置波次用完后，动态生成无限波次
		_current_wave_data = _generate_endless_wave(_current_wave_index + 1)
		print("=== 进入无限模式，第 ", _current_wave_index + 1, " 波 ===")
	
	# 防崩保护
	if _current_wave_data == null:
		push_warning("警告：波次数据为空，正在跳过...")
		_start_next_wave()
		return
	
	print("=== 开始第 ", _current_wave_index + 1, " 波，时长 ", _current_wave_data.duration, " 秒 ===")
	
	_wave_time_left = _current_wave_data.duration
	_is_wave_active = true
	
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

func _end_current_wave() -> void:
	_is_wave_active = false
	_spawn_timer.stop()
	wave_ended.emit()
	print("=== 第 ", _current_wave_index + 1, " 波结束 ===")
	
	# 1. 清空场上敌人（不掉金币）
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
	$player._check_synergies()
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
func _try_spawn_enemy() -> void:
	if not _is_wave_active: return
	
	if get_tree().get_nodes_in_group("enemies").size() >= _current_wave_data.max_enemies:
		return
		
	var enemy_data = _get_weighted_enemy(_current_wave_data)
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
		enemy.setup(enemy_data, _current_wave_data.difficulty_multiplier)
		enemy.enemy_died.connect(_on_enemy_died)

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
	
# ==================== 根据 ID 获取道具数据 ====================
func get_upgrade_data_by_id(id: String) -> UpgradeData:
	for upg in GameDatabase.all_upgrades:
		if upg.id == id:
			return upg
	return null
