extends Area2D

@export var value: int = 1                 # 拾取后增加的数量（比如金币数）
@export var move_speed: float = 900.0      # 被吸附时的飞行速度
@export var attract_radius: float = 1500.0  # 吸附半径（玩家进入这个范围就会被吸）

var player: Node2D = null
var _is_attracted: bool = false

func _ready() -> void:
	# 延迟一小会儿，确保玩家已经加载
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	
	# 出生时随便弹跳一下，视觉效果更好
	position += Vector2(randf_range(-15, 15), randf_range(-15, 15))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	var distance = global_position.distance_to(player.global_position)
	
	# 1. 判断是否进入吸附范围
	if distance < attract_radius:
		_is_attracted = true
	
	# 2. 如果处于吸附状态，飞向玩家
	if _is_attracted:
		# 距离越近，飞得越快
		var speed_multiplier = 1.0 + (1.0 - distance / attract_radius) * 2.0
		var direction = (player.global_position - global_position).normalized()
		global_position += direction * move_speed * speed_multiplier * delta
		
		# 如果碰到了玩家，触发拾取
		if distance < 20.0:
			_collect()

# 被玩家拾取
func _collect() -> void:
	# 这里调用玩家的拾取方法
	if player.has_method("add_loot"):
		player.add_loot(value)
	queue_free() # 消失
