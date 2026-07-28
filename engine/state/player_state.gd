class_name PlayerState
extends RefCounted

## All per-player game state: the zones and the Aura economy.
##
## Zone contents are Arrays of CardInstance except `stage` (single slot) and
## `vanguard` (single card). Aura is modelled as a token pool with a total
## size and an exhausted count; "active" (spendable) Aura is the difference.

const MAX_BATTLE_AREA := 5
const MAX_ACTIVE_AURA := 10

var index: int = 0                       # 0 or 1

var deck: Array = []                     # Array[CardInstance] (top = index 0)
var hand: Array = []
var life: Array = []                     # face-down; index 0 = top
var battle_area: Array = []              # Array[CardInstance] Banners, max 5
var stage: CardInstance = null           # single Stage slot
var trash: Array = []
var vanguard: CardInstance = null

# Aura economy -------------------------------------------------------------
var aura_total: int = 0                  # size of the Aura pool
var aura_exhausted: int = 0              # tokens currently spent/exhausted


func _init(player_index: int = 0) -> void:
	index = player_index


# --- Aura -----------------------------------------------------------------

## Spendable (unexhausted) Aura.
func aura_available() -> int:
	return aura_total - aura_exhausted


## Gain Aura tokens this turn; the pool total is capped at MAX_ACTIVE_AURA.
func gain_aura(amount: int) -> void:
	aura_total = min(MAX_ACTIVE_AURA, aura_total + amount)


## Exhaust `amount` Aura to pay a cost. Returns false (no change) if the
## player cannot afford it.
func spend_aura(amount: int) -> bool:
	if amount < 0 or aura_available() < amount:
		return false
	aura_exhausted += amount
	return true


## Refresh step: all exhausted Aura becomes available again.
func refresh_aura() -> void:
	aura_exhausted = 0


# --- Battle area ----------------------------------------------------------

func battle_area_full() -> bool:
	return battle_area.size() >= MAX_BATTLE_AREA


# --- Refresh (unexhaust everything the player controls) -------------------

func refresh_all() -> void:
	refresh_aura()
	if vanguard:
		vanguard.refresh()
	for b in battle_area:
		b.refresh()
	if stage:
		stage.refresh()


# --- Zone bookkeeping -----------------------------------------------------

## Remove a CardInstance from whatever zone array it currently sits in.
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
	inst.clear_battle_bonus()
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
