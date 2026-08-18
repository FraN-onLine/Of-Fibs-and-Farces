extends CharacterBody2D
class_name Character

## Base Character controller for "Of Fibs and Farces".
## Handles movement (run / jump / dash), combat (basic attack + combo),
## skills (Skill 1, Skill 2, Ultimate), and death.
## All data-driven values come from the assigned CharacterData resource.
## Runtime HP and cooldowns sync with the global PartyState autoload.

# ==================================================================
# Movement constants
# ==================================================================
const DEFAULT_SPEED := 150.0
const DEFAULT_GRAVITY := 900.0
const JUMP_VELOCITY := -400.0
const MAX_FALL_SPEED := 1200.0 #bap

const DASH_SPEED := 650.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 0.6

# ==================================================================
# Combat constants
# ==================================================================
const COMBO_WINDOW := 0.6              # Seconds to continue a combo
const DEFAULT_COMBO_COUNT := 3
const DEFAULT_ATTACK_COOLDOWN := 0.15
const DEFAULT_ATTACK_DURATION := 0.3   # Fallback when hit_frames empty
const DEFAULT_CRIT_RATE := 0.025
const DEFAULT_CRIT_DAMAGE := 1.5
const DEFAULT_SKILL_COOLDOWN := 5.0

# ==================================================================
# Exports & node references
# ==================================================================
@export var character_data: CharacterData
@export var party_slot: int = -1        # -1 = not in a party slot

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var audio_sfx: AudioStreamPlayer2D = $SFX
@onready var audio_voice: AudioStreamPlayer2D = $Voice
@onready var collider: CollisionShape2D = $CollisionShape2D

# ==================================================================
# Runtime state (loaded from CharacterData)
# ==================================================================
var speed: float = DEFAULT_SPEED
var gravity: float = DEFAULT_GRAVITY
var max_hp: int = 200
var hp: int = 200
var attack_cooldown: float = DEFAULT_ATTACK_COOLDOWN
var attack_damage: Array[int] = []
var hit_frames: Array[Array] = []
var combo_count: int = DEFAULT_COMBO_COUNT
var skill_cooldown: float = DEFAULT_SKILL_COOLDOWN
var crit_rate: float = DEFAULT_CRIT_RATE
var crit_damage: float = DEFAULT_CRIT_DAMAGE

# --- Facing / movement ---
var facing: int = 1                       # 1 = right, -1 = left
var is_dead: bool = false

# --- Dash ---
var is_dashing: bool = false
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT

# --- Attack / combo ---
var is_attacking: bool = false
var combo_step: int = 0
var combo_window_left: float = 0.0
var attack_cooldown_left: float = 0.0
var attack_duration_left: float = 0.0

# --- Skills ---
var skill1_cooldown: float = DEFAULT_SKILL_COOLDOWN
var skill2_cooldown: float = DEFAULT_SKILL_COOLDOWN
var ultimate_cooldown: float = DEFAULT_SKILL_COOLDOWN
var skill1_cooldown_left: float = 0.0
var skill2_cooldown_left: float = 0.0
var ultimate_cooldown_left: float = 0.0

# ==================================================================
# Lifecycle
# ==================================================================

func _ready() -> void:
	load_character_data()
	register_with_party_state()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	tick_timers(delta)

	# ----------------------------------------------------------
	# Dash overrides normal movement
	# ----------------------------------------------------------
	if is_dashing:
		velocity = Vector2(dash_dir.x * DASH_SPEED, 0.0)
		sprite.flip_h = dash_dir.x < 0.0

	# ----------------------------------------------------------
	# Normal movement (left / right)
	# ----------------------------------------------------------
	else:
		var input_dir := Input.get_axis("ui_left", "ui_right")
		if input_dir != 0.0:
			facing = 1 if input_dir > 0 else -1
			velocity.x = input_dir * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)

		sprite.flip_h = facing < 0

		# Jump (W key / Jump action)
		if Input.is_action_just_pressed("Jump") and is_on_floor():
			jump()

		# Gravity
		if not is_on_floor():
			velocity.y = min(velocity.y + gravity * delta, MAX_FALL_SPEED)
		else:
			velocity.y = 0.0

	# ----------------------------------------------------------
	# Action inputs
	# ----------------------------------------------------------
	if Input.is_action_just_pressed("Dash") and dash_cooldown_left <= 0.0 and not is_dashing:
		start_dash()
	if Input.is_action_just_pressed("Basic Attack"):
		basic_attack()
	if Input.is_action_just_pressed("Skill1"):
		skill_1()
	if Input.is_action_just_pressed("Skill2"):
		skill_2()
	if Input.is_action_just_pressed("Ultimate"):
		ultimate()

	move_and_slide()


# ==================================================================
# Party state integration
# ==================================================================

## Register this character with the global PartyState autoload.
## If party_slot is set, HP and cooldowns sync with the global state.
func register_with_party_state() -> void:
	if party_slot < 0 or not Engine.has_singleton("PartyState"):
		return
	var ps := Engine.get_singleton("PartyState")
	if ps == null:
		return

	# Sync HP from global state if this character is already in a slot
	if ps.is_slot_occupied(party_slot):
		hp = ps.get_hp(party_slot)
		max_hp = ps.get_max_hp(party_slot)
		is_dead = ps.is_slot_dead(party_slot)
		skill1_cooldown_left = ps.get_cooldown_left(party_slot, &"skill1")
		skill2_cooldown_left = ps.get_cooldown_left(party_slot, &"skill2")
		ultimate_cooldown_left = ps.get_cooldown_left(party_slot, &"ultimate")
	else:
		# Register this character into the slot
		ps.set_slot(party_slot, character_data)


# ==================================================================
# Data loading
# ==================================================================

func load_character_data() -> void:
	if character_data == null:
		return

	# Core stats
	speed = character_data.speed
	gravity = character_data.gravity
	max_hp = character_data.MaxHP
	hp = character_data.HP
	attack_cooldown = character_data.attack_cooldown
	attack_damage = character_data.attack_damage.duplicate()
	hit_frames = character_data.hit_frames.duplicate(true)
	combo_count = maxi(character_data.combo_count, 1)
	skill_cooldown = character_data.skill_cooldown
	crit_rate = character_data.crit_rate
	crit_damage = character_data.crit_damage

	# Skill-specific cooldowns
	if character_data.Skill1CD > 0.0:
		skill1_cooldown = character_data.Skill1CD
	if character_data.Skill2CD > 0.0:
		skill2_cooldown = character_data.Skill2CD
	if character_data.UltimateCD > 0.0:
		ultimate_cooldown = character_data.UltimateCD

	# Death state
	is_dead = character_data.is_dead
	if is_dead:
		die()


# ==================================================================
# Movement
# ==================================================================

func jump() -> void:
	if is_on_floor() and not is_dashing and not is_dead:
		velocity.y = JUMP_VELOCITY
		play_random(_clips(character_data.jump_audio), audio_voice)


func start_dash() -> void:
	is_dashing = true
	dash_time_left = DASH_DURATION
	dash_cooldown_left = DASH_COOLDOWN
	dash_dir = Vector2(facing, 0.0)
	if absf(dash_dir.x) < 0.05:
		dash_dir = Vector2.RIGHT
	play_random(_clips(character_data.dash_audio), audio_voice)


# ==================================================================
# Combat
# ==================================================================

func basic_attack() -> void:
	if is_dead or is_attacking or attack_cooldown_left > 0.0 or is_dashing:
		return

	# Advance combo
	combo_step += 1
	if combo_step > combo_count:
		combo_step = 1

	is_attacking = true
	attack_duration_left = get_attack_duration(combo_step)
	attack_cooldown_left = attack_cooldown

	play_random(_clips(character_data.basic_attack_audio), audio_voice)
	play_random(_clips(character_data.basic_effect_audio), audio_sfx)


func calculate_attack_damage() -> int:
	var idx := clampi(combo_step - 1, 0, attack_damage.size() - 1)
	var base := attack_damage[idx] if not attack_damage.is_empty() else 0
	if randf() < crit_rate:
		base = int(round(base * crit_damage))
	return base


func get_attack_duration(step_num: int) -> float:
	var idx := clampi(step_num - 1, 0, hit_frames.size() - 1)
	if hit_frames.size() > idx and hit_frames[idx].size() >= 2:
		return float(hit_frames[idx][1] - hit_frames[idx][0]) + 0.2
	return DEFAULT_ATTACK_DURATION


func skill_1() -> void:
	if is_dead or skill1_cooldown_left > 0.0:
		return
	skill1_cooldown_left = skill1_cooldown
	_sync_cooldown(&"skill1", skill1_cooldown_left)
	play_random(_clips(character_data.skill1_audio), audio_voice)
	play_random(_clips(character_data.skill1_effect_audio), audio_sfx)


func skill_2() -> void:
	if is_dead or skill2_cooldown_left > 0.0:
		return
	skill2_cooldown_left = skill2_cooldown
	_sync_cooldown(&"skill2", skill2_cooldown_left)
	play_random(_clips(character_data.skill2_audio), audio_voice)
	play_random(_clips(character_data.skill2_effect_audio), audio_sfx)


func ultimate() -> void:
	if is_dead or ultimate_cooldown_left > 0.0:
		return
	ultimate_cooldown_left = ultimate_cooldown
	_sync_cooldown(&"ultimate", ultimate_cooldown_left)
	play_random(_clips(character_data.skill3_audio), audio_voice)
	play_random(_clips(character_data.ultimate_effect_audio), audio_sfx)


# ==================================================================
# Damage & death
# ==================================================================

func take_damage(amount: int, type: String = "", element: String = "") -> void:
	if is_dead or amount <= 0:
		return
	hp = maxi(hp - amount, 0)
	_sync_hp()
	play_random(_clips(character_data.hurt_audio), audio_voice)
	if hp <= 0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	hp = 0
	velocity = Vector2.ZERO
	if collider:
		collider.set_deferred("disabled", true)
	if sprite:
		sprite.visible = false
	play_random(_clips(character_data.death_audio), audio_voice)
	if character_data:
		character_data.is_dead = true
		character_data.died.emit()
	_sync_hp()


# ==================================================================
# Timers
# ==================================================================

func tick_timers(delta: float) -> void:
	# Dash
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0.0:
			is_dashing = false
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)

	# Attack
	if attack_cooldown_left > 0.0:
		attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	if is_attacking:
		attack_duration_left -= delta
		if attack_duration_left <= 0.0:
			is_attacking = false
			combo_window_left = COMBO_WINDOW

	# Combo window (reset to step 0 when expired)
	if combo_window_left > 0.0:
		combo_window_left -= delta
		if combo_window_left <= 0.0:
			combo_step = 0

	# Skill cooldowns (local tick; global PartyState also ticks independently)
	if skill1_cooldown_left > 0.0:
		skill1_cooldown_left = maxf(skill1_cooldown_left - delta, 0.0)
	if skill2_cooldown_left > 0.0:
		skill2_cooldown_left = maxf(skill2_cooldown_left - delta, 0.0)
	if ultimate_cooldown_left > 0.0:
		ultimate_cooldown_left = maxf(ultimate_cooldown_left - delta, 0.0)


# ==================================================================
# Helpers
# ==================================================================

func play_random(clips: Array, player: AudioStreamPlayer2D) -> void:
	if clips.is_empty() or player == null or not is_inside_tree():
		return
	player.stream = clips[randi() % clips.size()]
	player.play()


func _clips(clips: Array) -> Array:
	return clips if character_data != null else []


func _sync_hp() -> void:
	if party_slot >= 0 and Engine.has_singleton("PartyState"):
		var ps := Engine.get_singleton("PartyState")
		if ps != null and ps.is_slot_occupied(party_slot):
			ps.set_hp(party_slot, hp)


func _sync_cooldown(skill: StringName, duration: float) -> void:
	if party_slot >= 0 and Engine.has_singleton("PartyState"):
		var ps := Engine.get_singleton("PartyState")
		if ps != null:
			ps.start_cooldown(party_slot, skill, duration)


# --- Convenience getters (useful for UI) ---

func get_hp() -> int:
	return hp


func get_max_hp() -> int:
	return max_hp


func is_on_cooldown() -> bool:
	return skill1_cooldown_left > 0.0 or skill2_cooldown_left > 0.0 or ultimate_cooldown_left > 0.0