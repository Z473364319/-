extends Resource
class_name WeaponData

enum WeaponType { MELEE, RANGED }

@export var weapon_name: String = "未知武器"
@export var weapon_type: WeaponType = WeaponType.MELEE
@export var damage: int = 10               # 伤害
@export var attack_cooldown: float = 0.1   # 攻击间隔（由武器决定）
@export var icon: Texture2D                # 武器贴图
@export var bullet_scene: PackedScene      # 仅远程：子弹场景   # 仅近战：固定攻击范围
@export var icon_scale: float = 0.1   # 武器图标缩放（默认缩小10倍）
