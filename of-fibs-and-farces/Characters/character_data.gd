extends Resource
class_name CharacterData

# Emitted when this character dies
signal died

# ---- Legacy display fields (kept for compatibility with existing .tres files) ----
@export var Name: String
@export var Element: String
@export var Icon: Texture2D
@export var Role: String #Bruiser, Applicator, Enabler, Support, Sustain, Artillery
@export var AttackCooldown: float = 0.15
@export var Skill1Icon: Texture2D
@export var Skill1CD: float = 5.0
@export var Skill2Icon: Texture2D
@export var Skill2CD: float = 5.0
@export var UltimateIcon: Texture2D
@export var UltimateCD: float = 5.0
@export var BasicAttackDamage: Array[int]
@export var BasicAttackHitFrames: Array[Array] #frames where damage is applied
@export var CritRateDefault = 0.025 #default cr, used when new run
@export var CritDamageDefault = 1.5 #default cd, used when new run
@export var CritRate = 0.025
@export var CritDamage = 1.5 #multiplier

# ---- Core stats (consumed by the base Character.gd) ----
@export var obtained: bool = true
@export var is_dead: bool = false
@export var unit_name: String = "Name"
@export var character_profile: Texture2D
@export var slot_index: int = 0
@export var speed: float = 150.0
@export var gravity: float = 900.0
@export var attack_cooldown: float = 0.1
@export var attack_damage: Array[int] = []
@export var hit_frames: Array[Array] = [] # [[start_frame, end_frame], ...] per combo step
@export var crit_rate: float = 0.025
@export var crit_damage: float = 1.5
@export var MaxHP: int = 200
@export var HP: int = 200
@export var combo_count: int = 2
@export var skill_cooldown: float = 5.0
@export var skill_texture: Texture2D

# ---- Audio: Voice ----
@export var basic_attack_audio: Array[AudioStream] = []
@export var skill_audio: Array[AudioStream] = []
@export var death_audio: Array[AudioStream] = []
@export var fua_audio: Array[AudioStream] = []
@export var hurt_audio: Array[AudioStream] = []
@export var dash_audio: Array[AudioStream] = []
@export var jump_audio: Array[AudioStream] = []
@export var skill1_audio: Array[AudioStream] = []
@export var skill2_audio: Array[AudioStream] = []
@export var skill3_audio: Array[AudioStream] = []

# ---- Audio: SFX only ----
@export var skill_effect_audio: Array[AudioStream] = []
@export var basic_effect_audio: Array[AudioStream] = []
@export var skill1_effect_audio: Array[AudioStream] = []
@export var skill2_effect_audio: Array[AudioStream] = []
@export var ultimate_effect_audio: Array[AudioStream] = []