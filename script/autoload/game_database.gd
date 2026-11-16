extends Node2D
## 全局总资源库（Autoload单例）
## 用于集中管理玩家属性、武器、敌人类型等数据

# ==================== 数据数组 ====================
@export_group("角色属性数据")
@export var all_character_stats: Array[CharacterStats] = []

@export_group("武器数据")
@export var all_weapons: Array[WeaponData] = []

@export_group(" 物品数据")
@export var all_upgrades: Array[UpgradeData] = []

@export_group("敌人数据")
@export var all_enemy_types: Array[EnemyData] = []

# ==================== 获取方法 ====================
func get_character_stats(stats_name: String) -> CharacterStats:
	for stats in all_character_stats:
		if stats.resource_name == stats_name:
			return stats
	return null

func get_weapon_data(weapon_name: String) -> WeaponData:
	for weapon in all_weapons:
		if weapon.weapon_name == weapon_name:
			return weapon
	return null

func get_enemy_data(enemy_name: String) -> EnemyData:
	for enemy in all_enemy_types:
		if enemy.enemy_name == enemy_name:
			return enemy
	return null
	
func get_upgrade_data_by_id(id: String) -> UpgradeData:
	for upg in GameDatabase.all_upgrades:
		if upg.id == id:
			return upg
	return null


## 随机获取一种敌人数据（波次管理器使用）
func get_random_enemy_data() -> EnemyData:
	return all_enemy_types.pick_random()
