#StatusEffect.gd
extends Resource
class_name StatusEffect

enum StatusType { POSITIVE, NEGATIVE }

var id: String
var name: String
var description: String
var type: StatusType
var duration: float  # в секундах
var icon: Texture2D

# Модификаторы характеристик
var speed_modifier: float = 1.0
var strength_modifier: int = 0
var fortitude_modifier: int = 0
var agility_modifier: int = 0
var endurance_modifier: int = 0
var luck_modifier: int = 0
var health_regen_modifier: float = 0.0

func _init(status_id: String, status_name: String, status_desc: String, 
		  status_type: StatusType, status_duration: float, status_icon: Texture2D = null):
	id = status_id
	name = status_name
	description = status_desc
	type = status_type
	duration = status_duration
	icon = status_icon
