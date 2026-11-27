extends Control

@onready var high_wave_label: Label = $VBoxContainer/HighWaveLabel
@onready var high_gold_label: Label = $VBoxContainer/HighGoldLabel
@onready var start_btn: Button = $VBoxContainer/StartButton

func _ready() -> void:
	# 从暂停菜单 / 结算界面回来时，兜底恢复时间流速和暂停状态
	Engine.time_scale = 1.0
	get_tree().paused = false
	
	# 1. 读取并显示最高记录
	var records = SaveManager.get_high_scores()
	high_wave_label.text = "历史最高波次：" + str(records["wave"])
	high_gold_label.text = "历史最高金币：" + str(records["gold"])
	
	# 2. 连接开始按钮
	start_btn.pressed.connect(_on_start_pressed)
	
	# 恢复鼠标指针可见
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_start_pressed() -> void:
	# 切换到游戏主场景
	get_tree().change_scene_to_file("res://Scenes/levels/ground.tscn")
