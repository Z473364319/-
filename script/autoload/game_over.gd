extends Control

@onready var wave_label: Label = $VBoxContainer/WaveLabel
@onready var menu_btn: Button = $MenuButton

func _ready() -> void:
	# 1. 从单例中读取刚才死亡时保存的数据
	wave_label.text = "生存波次：" + str(SaveManager.last_game_wave)
	
	# 2. 连接按钮事件
	menu_btn.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
