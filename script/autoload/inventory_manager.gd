
extends Node

signal inventory_changed # 当背包数据变化时发出

var items: Dictionary = {} # { "item_id": quantity }

func add_item(item_id: String, quantity: int = 1) -> void:
	if quantity <= 0: return
	items[item_id] = items.get(item_id, 0) + quantity
	inventory_changed.emit() # 通知UI刷新

func remove_item(item_id: String, quantity: int = 1) -> void:
	if items.has(item_id):
		items[item_id] -= quantity
		if items[item_id] <= 0:
			items.erase(item_id)
		inventory_changed.emit()

func get_item_count(item_id: String) -> int:
	return items.get(item_id, 0)

## 清空背包：开始新的一局时调用，避免上一局的道具/加成被继承
func reset() -> void:
	items.clear()
	inventory_changed.emit()
