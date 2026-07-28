class_name PlayerState
extends RefCounted

## All per-player game state: the zones, the Aura economy, and the freeze /
## cost-reduction bookkeeping introduced by set WM01.

const MAX_BATTLE_AREA := 5
const MAX_ACTIVE_AURA := 10

var index: int = 0

var deck: Array = []
var hand: Array = []
var life: Array = []
var battle_area: Array = []
var stage: CardInstance = null
var trash: Array = []
var vanguard: CardInstance = null

# Aura economy -------------------------------------------------------------
var aura_total: int = 0
var aura_exhausted: int = 0
# Aura tokens that stay exhausted through the NEXT Refresh Phase (frozen).
var aura_frozen_pending: int = 0

# Freeze / cost-reduction bookkeeping --------------------------------------
var banner_freezes_used: int = 0            # this turn; capped per turn
var cost_charges: Array = []                # pending {amount, filter_tribe, minimum}


func _init(player_index: int = 0) -> void:
	index = player_index


# --- Aura -----------------------------------------------------------------

func aura_available() -> int:
	return aura_total - aura_exhausted


func gain_aura(amount: int) -> void:
	aura_total = min(MAX_ACTIVE_AURA, aura_total + amount)


func spend_aura(amount: int) -> bool:
	if amount < 0 or aura_available() < amount:
		return false
	aura_exhausted += amount
	return true


## Refresh step for Aura: all exhausted Aura becomes available again, except a
## quantity equal to the pending frozen amount, which stays exhausted for this
## turn (then thaws).
func refresh_aura() -> void:
	aura_exhausted = min(aura_total, aura_frozen_pending)
	aura_frozen_pending = 0


# --- Battle area ----------------------------------------------------------

func battle_area_full() -> bool:
	return battle_area.size() >= MAX_BATTLE_AREA


# --- Zone bookkeeping -----------------------------------------------------

func remove_from_current_zone(inst: CardInstance) -> void:
	match inst.zone:
		CardEnums.ZONE_DECK: deck.erase(inst)
		CardEnums.ZONE_HAND: hand.erase(inst)
		CardEnums.ZONE_LIFE: life.erase(inst)
		CardEnums.ZONE_BATTLE: battle_area.erase(inst)
		CardEnums.ZONE_TRASH: trash.erase(inst)
		CardEnums.ZONE_STAGE:
			if stage == inst:
				stage = null
		CardEnums.ZONE_VANGUARD:
			if vanguard == inst:
				vanguard = null


func send_to_trash(inst: CardInstance) -> void:
	remove_from_current_zone(inst)
	inst.zone = CardEnums.ZONE_TRASH
	inst.exhausted = false
	inst.frozen = false
	inst.clear_battle_bonus()
	inst.clear_turn_bonus()
	trash.append(inst)


func snapshot_counts() -> Dictionary:
	return {
		"deck": deck.size(),
		"hand": hand.size(),
		"life": life.size(),
		"battle": battle_area.size(),
		"stage": 1 if stage else 0,
		"trash": trash.size(),
		"aura_total": aura_total,
		"aura_available": aura_available(),
	}
