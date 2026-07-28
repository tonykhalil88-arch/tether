class_name CardEnums
extends RefCounted

## Canonical string vocabularies for WILDMIGRATION card data.
##
## Card definitions store these as plain strings (so JSON round-trips
## losslessly), but the engine references them through these constants to
## avoid stringly-typed typos leaking into rules logic.

# --- Card types -----------------------------------------------------------
const TYPE_VANGUARD := "Vanguard"
const TYPE_BANNER := "Banner"
const TYPE_TECHNIQUE := "Technique"
const TYPE_STAGE := "Stage"

const CARD_TYPES := [TYPE_VANGUARD, TYPE_BANNER, TYPE_TECHNIQUE, TYPE_STAGE]

# --- Keywords -------------------------------------------------------------
const KW_RUSH := "Rush"
const KW_BLOCKER := "Blocker"
const KW_ON_PLAY := "On Play"
const KW_WHEN_ATTACKING := "When Attacking"
const KW_ACTIVATE_MAIN := "Activate: Main"
const KW_ONCE_PER_TURN := "Once Per Turn"
const KW_COUNTER := "Counter"
const KW_TRIGGER := "Trigger"
const KW_YOUR_TURN := "Your Turn"

const KEYWORDS := [
	KW_RUSH, KW_BLOCKER, KW_ON_PLAY, KW_WHEN_ATTACKING,
	KW_ACTIVATE_MAIN, KW_ONCE_PER_TURN, KW_COUNTER, KW_TRIGGER, KW_YOUR_TURN,
]

# --- Effect trigger names (event-bus event ids) ---------------------------
const EV_ON_PLAY := "on_play"
const EV_WHEN_ATTACKING := "when_attacking"
const EV_ON_ATTACK_DECLARED := "on_attack_declared"
const EV_ON_BATTLE_END := "on_battle_end"
const EV_ON_TURN_START := "on_turn_start"
const EV_ON_TURN_END := "on_turn_end"
const EV_ON_TRIGGER_REVEAL := "on_trigger_reveal"
const EV_ON_KO := "on_ko"

# --- Zones ----------------------------------------------------------------
const ZONE_DECK := "deck"
const ZONE_HAND := "hand"
const ZONE_LIFE := "life"
const ZONE_BATTLE := "battle"
const ZONE_STAGE := "stage"
const ZONE_AURA := "aura"
const ZONE_TRASH := "trash"
const ZONE_VANGUARD := "vanguard"


static func is_valid_type(t: String) -> bool:
	return CARD_TYPES.has(t)


static func is_dual_color(colors: Array) -> bool:
	# Distinct colour count of 2+ marks a card as multi-colour.
	var seen := {}
	for c in colors:
		seen[c] = true
	return seen.size() >= 2
