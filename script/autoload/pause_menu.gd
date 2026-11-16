extends CanvasLayer

# 向外发送信号，告诉主游戏脚本：“玩家按了Q，想打开背包”
signal inventory_requested

@onready var continue_btn: Button = $Continue_Button
@onready var return_btn: Button = $Return_Button

func _ready() -> void:
	# 【极其重要】必须设置为 Always，这样游戏暂停时，按钮才能被点击
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	# 连接按钮信号
	continue_btn.pressed.connect(_on_continue_pressed)
	return_btn.pressed.connect(_on_return_pressed)

# 把打开暂停菜单的权限开放给外部（ground.gd 调用）
func open_pause() -> void:
	show()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# 把关闭暂停菜单的权限开放给外部
func close_pause() -> void:
	hide()
	# 注意：是否解除暂停（paused = false），由外部决定，防止打架

# 按钮：继续游戏
func _on_continue_pressed() -> void:
	hide()
	get_tree().paused = false # 只有点继续，才真正恢复游戏

# 按钮：返回主菜单
func _on_return_pressed() -> void:
	get_tree().paused = false # 切换场景前必须解除暂停
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")

# ---------------------------------------------------------
# 【可选】如果你想在暂停界面提供一个“打开背包”的按钮
# 可以在场景里加个按钮叫 Inventory_Button，然后在 _ready 里连上它
# ---------------------------------------------------------
func _on_inventory_btn_pressed() -> void:
	hide() # 隐藏暂停界面
	emit_signal("inventory_requested") # 通知外部打开背包
