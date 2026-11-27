extends CanvasLayer
@onready var item_grid: HFlowContainer = $Panel/ScrollContainer/ItemGrid
@onready var close_btn: Button = $Return_Button
const ITEM_SLOT_SCENE = preload("res://Scenes/UI/item_slot.tscn")
var _was_paused: bool = false

# ================= 物品悬浮提示 =================
# 自己画一个提示框：不依赖系统 tooltip，暂停时也能显示，而且不会被 ScrollContainer 裁掉
var _tooltip: PanelContainer
var _tt_title: Label
var _tt_desc: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inventory_ui")
	hide()
	close_btn.pressed.connect(close_inventory)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	_build_tooltip()

func _on_inventory_changed() -> void:
	if visible:
		_refresh_inventory()

func open_inventory() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	show()
	_refresh_inventory()

func close_inventory() -> void:
	hide_item_tooltip()
	hide()
	get_tree().paused = _was_paused

func _refresh_inventory() -> void:
	# 1. 清空旧图标：立刻从容器里移除再 queue_free，
	#    否则旧格子会和新格子同时存在一帧，导致物品叠在一起
	hide_item_tooltip()
	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()
		
	var inv_dict = InventoryManager.items
	print("=== 背包刷新：当前数据大小 = ", inv_dict.size()) # 保留这行调试打印
	
	# 2. 遍历数据并生成
	for item_id in inv_dict.keys():
		var count = inv_dict[item_id]
		var upgrade_data = GameDatabase.get_upgrade_data_by_id(item_id)
		
		if upgrade_data:
			print("=== 尝试生成格子：", upgrade_data.upgrade_name, " x", count)
			var slot_instance = ITEM_SLOT_SCENE.instantiate()
			item_grid.add_child(slot_instance)
			slot_instance.setup(upgrade_data, count)
		else:
			print("=== 警告：找不到物品：", item_id) # 【探照灯 3】

func _unhandled_input(event: InputEvent) -> void:
	# 背包的开/关都自己处理：这样在商店 / 暂停菜单（游戏暂停时）也能打开背包
	if event.is_action_pressed("INVENTORY"):
		if visible:
			close_inventory()
		else:
			open_inventory()
		get_viewport().set_input_as_handled()

# ================= 悬浮提示的创建与更新 =================
func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.name = "ItemTooltip"
	_tooltip.visible = false
	_tooltip.z_index = 200
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.96)
	style.border_color = Color(1.0, 0.85, 0.35, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_tooltip.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	_tooltip.add_child(vbox)
	
	_tt_title = Label.new()
	_tt_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tt_title.add_theme_font_size_override("font_size", 26)
	_tt_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35, 1.0))
	_tt_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_tt_title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(_tt_title)
	
	_tt_desc = Label.new()
	_tt_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tt_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tt_desc.custom_minimum_size = Vector2(340, 0)
	_tt_desc.add_theme_font_size_override("font_size", 20)
	_tt_desc.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	_tt_desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_tt_desc.add_theme_constant_override("outline_size", 3)
	vbox.add_child(_tt_desc)
	
	add_child(_tooltip)

## 由物品格子（item_slot.gd）调用：显示某个物品的名字和描述
func show_item_tooltip(title: String, desc: String) -> void:
	if _tooltip == null:
		return
	_tt_title.text = title
	_tt_desc.text = desc
	_tooltip.show()
	_tooltip.reset_size() # 先按内容重新算大小，再决定往哪边放
	_update_tooltip_position()

func hide_item_tooltip() -> void:
	if _tooltip:
		_tooltip.hide()

func _process(_delta: float) -> void:
	if _tooltip and _tooltip.visible:
		_update_tooltip_position()

func _update_tooltip_position() -> void:
	if _tooltip == null or not _tooltip.visible:
		return
	
	var mouse := _tooltip.get_global_mouse_position()
	var tip_size := _tooltip.size
	var area := _tooltip.get_viewport_rect().size
	
	# 默认放在鼠标右下方；贴边时翻到另一侧，最后再夹紧到屏幕内
	var pos := mouse + Vector2(20, 20)
	if pos.x + tip_size.x > area.x - 10.0:
		pos.x = mouse.x - tip_size.x - 20.0
	if pos.y + tip_size.y > area.y - 10.0:
		pos.y = mouse.y - tip_size.y - 20.0
	pos.x = clampf(pos.x, 10.0, maxf(10.0, area.x - tip_size.x - 10.0))
	pos.y = clampf(pos.y, 10.0, maxf(10.0, area.y - tip_size.y - 10.0))
	_tooltip.position = pos
