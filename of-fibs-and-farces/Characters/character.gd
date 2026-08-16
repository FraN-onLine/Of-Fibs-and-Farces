extends CharacterBody2D
class_name Character

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@export var character_data: CharacterData
@onready var sprite = $Sprite
@onready var audio_sfx = $SFX
@onready var audio_voice = $Voice

func _ready():
	load_character_data()
	pass
	
func load_character_data():
	pass

func _physics_process(delta: float) -> void:
	pass
	#general character movement logic
	
func take_damage(amount: int, type: String, element: String):
	pass

func die():
	pass
	
func basic_attack():
	pass

func jump():
	pass
	
func skill_1():
	pass
	
func skill_2():
	pass
	
func ultimate():
	pass
