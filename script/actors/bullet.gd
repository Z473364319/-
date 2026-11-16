extends Area2D
class_name Bullet

@export var speed: float = 1800.0
@export var lifespan: float = 2.0
var damage: int = 10
var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifespan).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# 1. 防止打到自己（发射者）
	if body == shooter:
		return
		
	# 2. 确保目标有 take_damage 方法
	if not body.has_method("take_damage"):
		return
		
	# 3. 阵营判断（核心逻辑）
	var shooter_is_player = shooter != null and shooter.is_in_group("player")
	var shooter_is_enemy = shooter != null and shooter.is_in_group("enemies")
	
	var body_is_player = body.is_in_group("player")
	var body_is_enemy = body.is_in_group("enemies")
	
	if shooter_is_player and body_is_enemy:
		# 玩家打敌人
		body.take_damage(damage, shooter)
		queue_free()
	elif shooter_is_enemy and body_is_player:
		# 敌人打玩家
		body.take_damage(damage, shooter)
		queue_free()
	else:
		# 如果碰到同类（敌人子弹碰敌人，或者玩家子弹碰玩家），直接穿透
		pass
