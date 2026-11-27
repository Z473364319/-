extends Control

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel

var _upgrade_data: UpgradeData = null

func setup(upgrade_data: UpgradeData, count: int) -> void:
	_upgrade_data = upgrade_data
	
	# 注意：如果 setup 在节点入树前被调用，@onready 变量还是 null，这里兜底直接取子节点
	var icon_rect: TextureRect = icon if icon else get_node_or_null("Icon")
	if icon_rect:
		icon_rect.texture = upgrade_data.icon if upgrade_data else null
	
	var label: Label = count_label if count_label else get_node_or_null("CountLabel")
	if label:
		if count > 1:
			label.text = "x" + str(count)
			label.show()
		else:
			label.hide()
	
	# 鼠标停在格子上时，显示物品名称 + 描述
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if _upgrade_data == null:
		return
	var ui := get_tree().get_first_node_in_group("inventory_ui")
	if ui and ui.has_method("show_item_tooltip"):
		ui.show_item_tooltip(_upgrade_data.upgrade_name, _upgrade_data.description)

func _on_mouse_exited() -> void:
	var ui := get_tree().get_first_node_in_group("inventory_ui")
	if ui and ui.has_method("hide_item_tooltip"):
		ui.hide_item_tooltip()
