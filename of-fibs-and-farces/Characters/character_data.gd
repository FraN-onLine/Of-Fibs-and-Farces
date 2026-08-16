extends Resource
class_name CharacterData

#Basic Data
@export var Name: String
@export var Element: String
@export var Icon: Texture
@export var Role: String #Bruiser, Applicator, Enabler, Support, Sustain, Artillery
@export var AttackCooldown: float = 0.15
@export var Skill1Icon: Texture
@export var Skill1CD: float = 5.0
@export var Skill2Icon: Texture
@export var Skill2CD: float = 5.0
@export var UltimateIcon: Texture
@export var UltimateCD: float = 5.0
@export var BasicAttackDamage: Array[int]
@export var BasicAttackHitFrames: Array[Array] #frames in the attack where damage is applied
@export var CritRateDefault = 0.025 #default cr, used when new run
@export var CritDamageDefault = 1.5 #default cd, used when new run
@export var CritRate = 0.025
@export var CritDamage = 1.5 #multiplier
@export var MaxHP = 200
@export var HP = 200
@export var combo_count = 2


# Audio Voice - up to 3 each, min 0
@export var basic_attack_audio: Array[AudioStream] = []
@export var skill1_audio: Array[AudioStream] = []
@export var skill2_audio: Array[AudioStream] = []
@export var skill3_audio: Array[AudioStream] = []
@export var death_audio: Array[AudioStream] = []
@export var hurt_audio: Array[AudioStream] = []
@export var dash_audio: Array[AudioStream] = []
@export var jump_audio: Array[AudioStream] = []

# Audio - Sfx only
@export var basic_effect_audio: Array[AudioStream] = []
@export var skill1_effect_audio: Array[AudioStream]
@export var skill2_effect_audio: Array[AudioStream] = []
@export var ultimate_effect_audio: Array[AudioStream]
