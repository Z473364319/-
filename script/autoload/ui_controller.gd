extends CanvasLayer

# ================= UI 节点引用 =================
# 注意：这里的 $TimeLabel 要求节点必须是 CanvasLayer 的直接子节点
@onready var time_label: Label = $TimeLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_text: Label = $HealthBar/HealthText
@onready var loot_label: Label = $LootLabel
@onready var wave_text:Label = $Wave

# ================= 内部状态 =================
var player: CharacterBody2D = null
var _ground: Node2D = null

# ================= 生命周期 =================
func _ready() -> void:
	# 1. 获取 Ground 节点（假设 CanvasLayer 的父节点就是 Ground）
	_ground = get_parent()
	
	# 2. 使用代码连接信号
	if _ground and _ground.has_signal("wave_started"):
		_ground.wave_started.connect(_on_wave_started)
		_ground.wave_time_updated.connect(_on_wave_time_updated)
		_ground.wave_ended.connect(_on_wave_ended)
		print("UI: 成功连接 Ground 信号！")
	else:
		push_error("UI错误：找不到 Ground 节点或信号！请检查 CanvasLayer 的父节点是不是 Ground。")

	# 3. 寻找玩家（延迟一帧，确保玩家已进入场景树）
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("UI: 成功找到玩家！")
	else:
		push_warning("UI警告：找不到玩家，请确保玩家加入了 'player' 组！")

# ================= 逐帧更新（血量 UI） =================
func _process(_delta: float) -> void:
	# 血量 UI 变化频繁，不适合用信号，直接每帧刷新
	if is_instance_valid(player) and health_bar and health_text:
		if health_bar.max_value != player.max_health:
			health_bar.max_value = player.max_health
		
		health_bar.value = player.current_health
		health_text.text = str(int(player.current_health)) + " / " + str(player.max_health)
	
	if is_instance_valid(player) and loot_label:
		loot_label.text = "金币: " + str(player.loot_count)
# ================= 信号回调函数 =================
func _on_wave_started(wave_index: int, total_waves: int) -> void:
	print("UI: 第 ", wave_index, " 波开始，总共 ", total_waves, " 波")
	# 波次刚开始时，先显示波数
	time_label.text = "第 " + str(wave_index) + " 波"
	wave_text.text = "第 " + str(wave_index) + " 波"
	
func _on_wave_time_updated(time_left: float) -> void:
	# 使用 ceil 向上取整，确保 0.1 秒也会显示为 1 秒
	var seconds = int(ceil(time_left))
	time_label.text = "剩余时间：" + str(seconds) + " 秒"
	
func _on_wave_ended() -> void:
	print("UI: 波次结束，进入休息期")
	time_label.text = "波次结束！"
	
