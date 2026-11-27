extends Area2D
class_name Bullet

@export var speed: float = 1800.0
@export var lifespan: float = 2.0
## 命中敌人后还能反弹几次：0 = 命中即消失；篮球类子弹 > 0
@export var bounce_count: int = 0
var damage: int = 10
var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null

var _bounces_left: int = 0

func _ready() -> void:
	_bounces_left = bounce_count
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
		_bounce_or_free(body)
	elif shooter_is_enemy and body_is_player:
		# 敌人打玩家
		body.take_damage(damage, shooter)
		queue_free()
	else:
		# 如果碰到同类（敌人子弹碰敌人，或者玩家子弹碰玩家），直接穿透
		pass

## 命中敌人后：还有反弹次数就弹开继续飞，否则销毁
func _bounce_or_free(body: Node2D) -> void:
	if _bounces_left <= 0:
		queue_free()
		return
	
	_bounces_left -= 1
	
	# 沿“敌人圆心 -> 自己”的方向弹开，再加一点随机角度，避免每次都弹成死板的一条线
	var away := global_position - body.global_position
	if away.length() < 0.01:
		away = -direction
	direction = away.normalized().rotated(randf_range(-0.25, 0.25))
	
	# 把子弹往外挪一点，避免弹开后的第一帧还判定在敌人身体里
	global_position += direction * 8.0
