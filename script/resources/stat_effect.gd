extends Resource
class_name StatEffect

@export_enum(
	"max_health",
	"speed", 
	"damage_multiplier",
 	"dash_cooldown",
	"lifesteal", 
	"armor", 
	"combo",
	"dash_speed",
	"health_regen") 
var stat_type: String = "max_health"

@export var value: float = 10.0
