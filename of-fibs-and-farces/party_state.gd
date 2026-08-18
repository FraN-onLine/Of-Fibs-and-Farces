extends Node
## Global Party State (Autoload singleton)
##
## Manages the player's party of up to 3 characters across all scenes.
## Each slot holds a CharacterData resource plus runtime state (HP, cooldowns).
## Timers tick globally here so cooldowns persist between scene changes.

signal slot_changed(slot_index: int, character_data: CharacterData)
signal slot_cleared(slot_index: int)
signal active_slot_changed(slot_index: int)
signal character_died(slot_index: int)
signal hp_changed(slot_index: int, current_hp: int, max_hp: int)
signal cooldown_changed(slot_index: int, skill: StringName, time_left: float)

const MAX_SLOTS := 3

# ------------------------------------------------------------------
# Slot runtime state
# ------------------------------------------------------------------
class SlotState:
	var character_data: CharacterData
	var hp: int = 0
	var max_hp: int = 0
	var is_dead: bool = false
	var skill1_cooldown_left: float = 0.0
	var skill2_cooldown_left: float = 0.0
	var ultimate_cooldown_left: float = 0.0

	func _init(data: CharacterData = null) -> void:
		if data != null:
			set_data(data)

	func set_data(data: CharacterData) -> void:
		character_data = data
		max_hp = data.MaxHP
		hp = data.HP
		is_dead = data.is_dead

	func clear() -> void:
		character_data = null
		hp = 0
		max_hp = 0
		is_dead = false
		skill1_cooldown_left = 0.0
		skill2_cooldown_left = 0.0
		ultimate_cooldown_left = 0.0


# ------------------------------------------------------------------
# State
# ------------------------------------------------------------------
var slots: Array[SlotState] = []
var active_slot: int = 0

func _ready() -> void:
	for i in MAX_SLOTS:
		slots.append(SlotState.new())


func _process(delta: float) -> void:
	tick_timers(delta)


# ==================================================================
# Slot management
# ==================================================================

## Assign a CharacterData resource to a slot (0-2).
func set_slot(slot_index: int, data: CharacterData) -> void:
	if not _valid_slot(slot_index) or data == null:
		return
	slots[slot_index].set_data(data)
	slot_changed.emit(slot_index, data)
	hp_changed.emit(slot_index, data.HP, data.MaxHP)


## Remove the character from a slot.
func clear_slot(slot_index: int) -> void:
	if not _valid_slot(slot_index):
		return
	slots[slot_index].clear()
	slot_cleared.emit(slot_index)


## Get the CharacterData in a slot (null if empty).
func get_slot_data(slot_index: int) -> CharacterData:
	if not _valid_slot(slot_index):
		return null
	return slots[slot_index].character_data


## Swap the contents of two slots.
func swap_slots(a: int, b: int) -> void:
	if not _valid_slot(a) or not _valid_slot(b) or a == b:
		return
	var tmp := slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	slot_changed.emit(a, slots[a].character_data)
	slot_changed.emit(b, slots[b].character_data)


## Set which slot is currently active (controlled by the player).
func set_active_slot(slot_index: int) -> void:
	if not _valid_slot(slot_index):
		return
	active_slot = slot_index
	active_slot_changed.emit(slot_index)


func get_active_slot() -> int:
	return active_slot


func get_active_data() -> CharacterData:
	return get_slot_data(active_slot)


## Returns true if the slot has a character assigned.
func is_slot_occupied(slot_index: int) -> bool:
	return _valid_slot(slot_index) and slots[slot_index].character_data != null


## Returns an array of all occupied slot indices.
func get_occupied_slots() -> Array[int]:
	var result: Array[int] = []
	for i in MAX_SLOTS:
		if is_slot_occupied(i):
			result.append(i)
	return result


# ==================================================================
# HP / damage
# ==================================================================

func get_hp(slot_index: int) -> int:
	if not _valid_slot(slot_index):
		return 0
	return slots[slot_index].hp


func get_max_hp(slot_index: int) -> int:
	if not _valid_slot(slot_index):
		return 0
	return slots[slot_index].max_hp


func is_slot_dead(slot_index: int) -> bool:
	if not _valid_slot(slot_index):
		return true
	return slots[slot_index].is_dead


## Directly set a slot's current HP (clamped to max). Emits hp_changed.
func set_hp(slot_index: int, value: int) -> void:
	if not _valid_slot(slot_index) or slots[slot_index].character_data == null:
		return
	var state := slots[slot_index]
	state.hp = clampi(value, 0, state.max_hp)
	if state.hp <= 0:
		state.is_dead = true
		state.character_data.is_dead = true
		character_died.emit(slot_index)
	hp_changed.emit(slot_index, state.hp, state.max_hp)


## Apply damage to a slot's character. Returns actual damage dealt.
func take_damage(slot_index: int, amount: int, type: String = "", element: String = "") -> int:
	if not _valid_slot(slot_index) or slots[slot_index].character_data == null:
		return 0
	if slots[slot_index].is_dead or amount <= 0:
		return 0

	var state := slots[slot_index]
	state.hp = maxi(state.hp - amount, 0)
	hp_changed.emit(slot_index, state.hp, state.max_hp)

	if state.hp <= 0:
		state.is_dead = true
		state.character_data.is_dead = true
		character_died.emit(slot_index)

	return amount


## Heal a slot's character. Returns actual HP restored.
func heal(slot_index: int, amount: int) -> int:
	if not _valid_slot(slot_index) or slots[slot_index].character_data == null:
		return 0
	if slots[slot_index].is_dead or amount <= 0:
		return 0

	var state := slots[slot_index]
	var before := state.hp
	state.hp = mini(state.hp + amount, state.max_hp)
	var healed := state.hp - before
	hp_changed.emit(slot_index, state.hp, state.max_hp)
	return healed


## Revive a dead character in a slot with a percentage of max HP (0.0 - 1.0).
func revive(slot_index: int, hp_percent: float = 1.0) -> void:
	if not _valid_slot(slot_index) or slots[slot_index].character_data == null:
		return
	var state := slots[slot_index]
	state.is_dead = false
	state.character_data.is_dead = false
	state.hp = int(round(state.max_hp * clampf(hp_percent, 0.0, 1.0)))
	hp_changed.emit(slot_index, state.hp, state.max_hp)


# ==================================================================
# Cooldowns / timers
# ==================================================================

## Start a cooldown for a skill on a slot. skill: "skill1", "skill2", "ultimate".
func start_cooldown(slot_index: int, skill: StringName, duration: float) -> void:
	if not _valid_slot(slot_index) or duration <= 0.0:
		return
	var state := slots[slot_index]
	match skill:
		&"skill1":
			state.skill1_cooldown_left = duration
		&"skill2":
			state.skill2_cooldown_left = duration
		&"ultimate":
			state.ultimate_cooldown_left = duration
	cooldown_changed.emit(slot_index, skill, duration)


func get_cooldown_left(slot_index: int, skill: StringName) -> float:
	if not _valid_slot(slot_index):
		return 0.0
	var state := slots[slot_index]
	match skill:
		&"skill1":
			return state.skill1_cooldown_left
		&"skill2":
			return state.skill2_cooldown_left
		&"ultimate":
			return state.ultimate_cooldown_left
	return 0.0


func is_on_cooldown(slot_index: int, skill: StringName) -> bool:
	return get_cooldown_left(slot_index, skill) > 0.0


func tick_timers(delta: float) -> void:
	for i in MAX_SLOTS:
		var state := slots[i]
		if state.character_data == null:
			continue

		# Skill 1
		if state.skill1_cooldown_left > 0.0:
			state.skill1_cooldown_left = maxf(state.skill1_cooldown_left - delta, 0.0)
			cooldown_changed.emit(i, &"skill1", state.skill1_cooldown_left)

		# Skill 2
		if state.skill2_cooldown_left > 0.0:
			state.skill2_cooldown_left = maxf(state.skill2_cooldown_left - delta, 0.0)
			cooldown_changed.emit(i, &"skill2", state.skill2_cooldown_left)

		# Ultimate
		if state.ultimate_cooldown_left > 0.0:
			state.ultimate_cooldown_left = maxf(state.ultimate_cooldown_left - delta, 0.0)
			cooldown_changed.emit(i, &"ultimate", state.ultimate_cooldown_left)


# ==================================================================
# Persistence helpers (generic)
# ==================================================================

## Serialize the party state to a Dictionary (for save files).
func to_dict() -> Dictionary:
	var data := {
		"active_slot": active_slot,
		"slots": [],
	}
	for i in MAX_SLOTS:
		var state := slots[i]
		data["slots"].append({
			"character_path": state.character_data.resource_path if state.character_data != null else "",
			"hp": state.hp,
			"max_hp": state.max_hp,
			"is_dead": state.is_dead,
			"skill1_cd": state.skill1_cooldown_left,
			"skill2_cd": state.skill2_cooldown_left,
			"ultimate_cd": state.ultimate_cooldown_left,
		})
	return data


## Restore party state from a Dictionary (from save files).
func from_dict(data: Dictionary) -> void:
	if data.has("active_slot"):
		active_slot = int(data["active_slot"])
	if not data.has("slots"):
		return

	var saved_slots: Array = data["slots"]
	for i in mini(saved_slots.size(), MAX_SLOTS):
		var entry: Dictionary = saved_slots[i]
		var path: String = entry.get("character_path", "")
		if path.is_empty():
			clear_slot(i)
			continue

		var res := load(path) as CharacterData
		if res == null:
			clear_slot(i)
			continue

		set_slot(i, res)
		var state := slots[i]
		state.hp = int(entry.get("hp", state.max_hp))
		state.max_hp = int(entry.get("max_hp", state.max_hp))
		state.is_dead = bool(entry.get("is_dead", false))
		state.skill1_cooldown_left = float(entry.get("skill1_cd", 0.0))
		state.skill2_cooldown_left = float(entry.get("skill2_cd", 0.0))
		state.ultimate_cooldown_left = float(entry.get("ultimate_cd", 0.0))
		hp_changed.emit(i, state.hp, state.max_hp)


# ==================================================================
# Internal
# ==================================================================

func _valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < MAX_SLOTS