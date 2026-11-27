extends CanvasLayer
class_name shop_ui

# 信号：商店关闭时通知波次管理器
signal shop_closed

# 节点引用
@onready var gold_label: Label = $Panel/MarginContainer/VBoxContainer/GoldLabel
@onready var item_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ItemContainer
@onready var refresh_btn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/RefreshBtn
@onready var continue_btn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ContinueBtn

var shop_card_scene = preload("res://Scenes/UI/shop_card.tscn")
var current_player: Node2D = null

func _ready() -> void:
	hide()
	refresh_btn.pressed.connect(_on_refresh_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	# 【关键】保证游戏暂停时，商店UI依然能响应鼠标点击
	process_mode = Node.PROCESS_MODE_ALWAYS

func open_shop(player: Node2D) -> void:
	current_player = player
	show()
	get_tree().paused = true
	_generate_items()

func _generate_items() -> void:
	# 【关键修复】彻底清空旧商品，立刻从容器移除并销毁，防止UI挤压错位
	for child in item_container.get_children():
		item_container.remove_child(child)
		child.queue_free()
		
	_update_gold_ui()
	
	# 1. 获取物品池：0007 是唯一性能力，背包里已经有时就不再刷出来
	var available_upgrades = []
	for upgrade in GameDatabase.all_upgrades:
		# 用 InventoryManager 的背包数据判断（player.inventory_upgrades 已经不更新了，判断会失效）
		if upgrade.id == "0007" and InventoryManager.get_item_count("0007") > 0:
			continue
		if upgrade.id == "0010" and InventoryManager.get_item_count("0010") > 0:
			continue
		available_upgrades.append(upgrade)
		
	if available_upgrades.is_empty():
		push_warning("商店：没有可用的物品了！")
		return
	
	# 2. 复制并打乱过滤后的物品池
	var shuffled = available_upgrades.duplicate()
	shuffled.shuffle()
	
	# 3. 每张卡片展示不同的物品；池子不足 4 个时就有几个显示几个
	var total_items_to_show = mini(4, shuffled.size())
	for i in range(total_items_to_show):
		var card = shop_card_scene.instantiate()
		item_container.add_child(card)
		
		var upgrade = shuffled[i]
		
		card.setup(upgrade)
		card.bought.connect(_on_item_bought)

func _update_gold_ui() -> void:
	if current_player:
		gold_label.text = "金币: " + str(current_player.loot_count)

func _on_item_bought(upgrade_data: UpgradeData, price: int) -> void:
	# 1. 判断金币是否足够
	if current_player.loot_count >= price:
		# 扣除金币
		current_player.loot_count -= price
		# 应用升级效果
		current_player.apply_upgrade(upgrade_data)
		_update_gold_ui()
		print("购买成功！")
		
		# 找到是被点击的那个卡片，把它的按钮禁用并改文字
		for card in item_container.get_children():
			if card.upgrade_data == upgrade_data:
				card.buy_button.disabled = true
				card.buy_button.text = "已购买"
				break
	else:
		# 【新增】金币不足时，弹出提醒
		_show_warning("金币不足！")
		print("金币不足！")

# ================= 动态生成提示文字 =================
func _show_warning(text: String) -> void:
	# 创建一个 Label
	var warning_label = Label.new()
	warning_label.text = text
	# 设置字体大小和红色颜色
	warning_label.add_theme_font_size_override("font_size", 36)
	warning_label.add_theme_color_override("font_color", Color.RED)
	warning_label.add_theme_color_override("font_outline_color", Color.BLACK)
	warning_label.add_theme_constant_override("outline_size", 6)
	
	# 居中显示在屏幕偏下方的位置
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.set_anchors_preset(Control.PRESET_CENTER)
	warning_label.position = Vector2(-100, 150) # 根据你的分辨率微调位置
	warning_label.size = Vector2(200, 50)
	
	add_child(warning_label)
	
	# 使用 Tween 动画让它向上飘并消失
	var tween = create_tween()
	tween.set_parallel(true)
	# 0.8 秒内向上飘 50 像素
	tween.tween_property(warning_label, "position:y", warning_label.position.y - 50, 0.8)
	# 0.8 秒内渐渐透明
	tween.tween_property(warning_label, "modulate:a", 0.0, 0.8)
	
	# 动画播完后自动销毁
	tween.chain().tween_callback(warning_label.queue_free)

func _on_refresh_pressed() -> void:
	var refresh_cost = 5
	if current_player.loot_count >= refresh_cost:
		current_player.loot_count -= refresh_cost
		_generate_items()
	else:
		print("金币不足，无法刷新！")

func _on_continue_pressed() -> void:
	hide()
	get_tree().paused = false
	shop_closed.emit()
