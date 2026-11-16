extends Node

const SAVE_PATH = "user://high_scores.cfg"
var last_game_wave: int = 0
var last_game_gold: int = 0


# 读取最高记录
func get_high_scores() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		return {
			"wave": config.get_value("record", "highest_wave", 0),
			"gold": config.get_value("record", "highest_gold", 0)
		}
	return {"wave": 0, "gold": 0}

# 保存最高记录（只有当打破记录时才更新）
func save_high_scores(current_wave: int, current_gold: int) -> void:
	var records = get_high_scores()
	var config = ConfigFile.new()
	config.load(SAVE_PATH)
	
	var updated = false
	if current_wave > records["wave"]:
		config.set_value("record", "highest_wave", current_wave)
		updated = true
		
	if current_gold > records["gold"]:
		config.set_value("record", "highest_gold", current_gold)
		updated = true
		
	if updated:
		config.save(SAVE_PATH)
		print("保存新记录！最高波次: ", max(current_wave, records["wave"]), " 最高金币: ", max(current_gold, records["gold"]))
		
		
# ================= 【新增】记录本局结束数据 =================
func set_game_over_data(wave: int, gold: int) -> void:
	last_game_wave = wave
	last_game_gold = gold
# ============================================================
