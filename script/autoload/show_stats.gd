extends Label
## 人物属性展示：挂到任意 Label 上即可，会自动找到玩家并实时刷新文本
## （脚本在暂停时也会继续刷新，所以挂在背包 / 暂停菜单里都能正常显示）

var player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_find_player()
	_refresh_text()

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
	_refresh_text()

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _refresh_text() -> void:
	if not is_instance_valid(player):
		text = "人物属性\n（未找到玩家）"
		return
	
	var cur_hp := _get_int("current_health")
	var max_hp := _get_int("max_health")
	var defense := _get_int("defense")
	var speed := _get_float("speed")
	var lifesteal := _get_float("lifesteal")
	var regen := _get_float("health_regen")
	var bulls := maxi(1, _get_int("bull_number"))
	var gold := _get_int("loot_count")
	
	text = "生命：%d / %d\n攻击：%d\n防御：%d\n移速：%d\n吸血：%d%%\n回血：%.1f/秒\n弹道：%d\n金币：%d" % [
		cur_hp, max_hp, _get_attack_damage(), defense, int(speed),
		roundi(lifesteal * 100.0), regen, bulls, gold
	]

## 读取玩家身上的整数属性，属性不存在时返回 0
func _get_int(property: String) -> int:
	if property in player:
		return int(player.get(property))
	return 0

## 读取玩家身上的浮点属性，属性不存在时返回 0
func _get_float(property: String) -> float:
	if property in player:
		return float(player.get(property))
	return 0.0

## 攻击力：优先用当前武器的伤害 × 伤害倍率，没有武器就用基础远程攻击力
func _get_attack_damage() -> int:
	var mult := _get_float("damage_multiplier")
	if mult <= 0.0:
		mult = 1.0
	
	var weapon = player.get("ranged_weapon") if "ranged_weapon" in player else null
	if weapon != null and "damage" in weapon:
		return int(int(weapon.get("damage")) * mult)
	
	return _get_int("ranged_attack")
