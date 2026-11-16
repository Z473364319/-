extends CanvasLayer

@onready var item_grid: GridContainer = $Panel/ScrollContainer/ItemGrid
@onready var close_btn: Button = $Return_Button

var _was_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	close_btn.pressed.connect(close_inventory)

func open_inventory() -> void:
	_was_paused = get_tree().paused 
	get_tree().paused = true
	show()
	_refresh_inventory()

func close_inventory() -> void:
	hide()
	get_tree().paused = _was_paused 

func _refresh_inventory() -> void:
	for child in item_grid.get_children():
		child.queue_free()
		
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0: return
	
	var player = players[0]
	var inv_dict = player.inventory_upgrades 
	
	for item_id in inv_dict.keys():
		var count = inv_dict[item_id] 
		var upgrade_data = GameDatabase.get_upgrade_data_by_id(item_id)
		
		if upgrade_data:
			var item_box = Control.new()
			item_box.custom_minimum_size = Vector2(64, 64) 
			item_box.tooltip_text = upgrade_data.upgrade_name + "\n" + upgrade_data.description
			
			var icon_rect = TextureRect.new()
			icon_rect.texture = upgrade_data.icon
			icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			item_box.add_child(icon_rect)
			
			if count > 1:
				var count_label = Label.new()
				count_label.text = "x" + str(count)
				count_label.add_theme_font_size_override("font_size", 20)
				count_label.add_theme_color_override("font_color", Color.YELLOW)
				count_label.add_theme_color_override("font_outline_color", Color.BLACK)
				count_label.add_theme_constant_override("outline_size", 4)
				count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 2)
				item_box.add_child(count_label)
				
			item_grid.add_child(item_box)
			
