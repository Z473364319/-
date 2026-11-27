extends CanvasLayer

@onready var continue_btn: Button = $Continue_Button
@onready var return_btn: Button = $Return_Button

func _ready() -> void:
	# 保证它能在暂停时响应鼠标
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	continue_btn.pressed.connect(_on_continue_pressed)
	return_btn.pressed.connect(_on_return_pressed)

func open_pause() -> void:
	show()
	# 注意：不要在这里写 get_tree().paused = true，交给 ground.gd 去设！
	
func _on_continue_pressed() -> void:
	hide()
	get_tree().paused = false # 继续游戏

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("PAUSE") and visible:
		_on_continue_pressed() # 调用你关闭菜单的函数
		get_viewport().set_input_as_handled()
