extends Panel

# 信号：当玩家点击购买时，通知商店主界面
signal bought(upgrade_data: UpgradeData, price: int)

# 数据
var upgrade_data: UpgradeData = null
var price: int = 0

# 节点引用（严格对应你截图里的路径）
@onready var icon_rect: TextureRect = $VBoxContainer/IconRect
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var price_label: Label = $VBoxContainer/PriceLabel
@onready var buy_button: Button = $VBoxContainer/BuyButton

func _ready() -> void:
	# 连接按钮点击事件
	buy_button.pressed.connect(_on_buy_pressed)

# 初始化卡片数据（由 shop_ui.gd 调用）
func setup(data: UpgradeData) -> void:
	upgrade_data = data
	if data:
		price = data.price
		icon_rect.texture = data.icon
		name_label.text = data.upgrade_name
		desc_label.text = data.description
		price_label.text = str(price) + " 金币"
	else:
		name_label.text = "未知"

# 点击购买按钮
func _on_buy_pressed() -> void:
	# 1. 只要点击了，就发出购买信号，把判断留给主界面
	bought.emit(upgrade_data, price) # 等主界面确认购买成功后，会通过代码把按钮关掉的
