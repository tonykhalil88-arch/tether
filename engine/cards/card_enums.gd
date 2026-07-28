class_name CardEnums
extends RefCounted

## Canonical string vocabularies for WILDMIGRATION card data.
##
## These match the authoritative set JSON exactly (lower-case), so card data
## round-trips losslessly. The engine references them through these constants
## to avoid stringly-typed typos leaking into rules logic.

# --- Card types (lower-case, as authored) ---------------------------------
const TYPE_VANGUARD := "vanguard"
const TYPE_BANNER := "banner"
const TYPE_TECHNIQUE := "technique"
const TYPE_STAGE := "stage"

const CARD_TYPES := [TYPE_VANGUARD, TYPE_BANNER, TYPE_TECHNIQUE, TYPE_STAGE]

# --- Printed keywords -----------------------------------------------------
const KW_RUSH := "rush"
const KW_BLOCKER := "blocker"
# Freeze is a runtime status applied by effects, not a printed keyword, but it
# is referenced widely so it lives here too.
const KW_FREEZE := "freeze"

const KEYWORDS := [KW_RUSH, KW_BLOCKER]

# --- Effect triggers / event-bus event ids --------------------------------
const EV_ON_PLAY := "on_play"
const EV_MAIN := "main"                       # main-phase Technique resolution
const EV_COUNTER := "counter"                 # defensive [Counter] Technique
const EV_LIFE_TRIGGER := "life_trigger"       # revealed from Life on a hit
const EV_WHEN_ATTACKING := "when_attacking"
const EV_ACTIVATE_MAIN := "activate_main"
const EV_PASSIVE := "passive"                 # continuous while in play
const EV_ON_ATTACK_DECLARED := "on_attack_declared"
const EV_ON_BATTLE_END := "on_battle_end"
const EV_ON_TURN_START := "on_turn_start"
const EV_ON_TURN_END := "on_turn_end"
const EV_ON_KO := "on_ko"

# --- Effect action types (action.type in the JSON) ------------------------
const ACT_POWER_BUFF := "power_buff"
const ACT_KO := "ko"
const ACT_REST := "rest"
const ACT_REFRESH := "refresh"
const ACT_REST_AND_FREEZE := "rest_and_freeze"
const ACT_FREEZE := "freeze"
const ACT_BOUNCE := "bounce"
const ACT_DRAW := "draw"
const ACT_DRAW_THEN_BOTTOM := "draw_then_bottom"
const ACT_GAIN_AURA := "gain_aura"
const ACT_COST_REDUCTION := "cost_reduction"
const ACT_SEARCH_TOP := "search_top"
const ACT_PLAY_SELF := "play_self"

# --- Effect target selectors ----------------------------------------------
const TGT_SELF := "self"
const TGT_ENEMY_BANNER := "enemy_banner"
const TGT_ENEMY_AURA := "enemy_aura"
const TGT_OWN_BANNER := "own_banner"
const TGT_OWN_BANNERS := "own_banners"
const TGT_OWN_OTHER_BANNER := "own_other_banner"
const TGT_OWN_UNIT := "own_unit"
const TGT_OWN_VANGUARD := "own_vanguard"

# --- Zones ----------------------------------------------------------------
const ZONE_DECK := "deck"
const ZONE_HAND := "hand"
const ZONE_LIFE := "life"
const ZONE_BATTLE := "battle"
const ZONE_STAGE := "stage"
const ZONE_AURA := "aura"
const ZONE_TRASH := "trash"
const ZONE_VANGUARD := "vanguard"

# --- Balance rules --------------------------------------------------------
const POWER_CEILING := 9000
const BANNER_FREEZE_CAP_PER_TURN := 1


static func is_valid_type(t: String) -> bool:
	return CARD_TYPES.has(t)


static func is_dual_color(colors: Array) -> bool:
	var seen := {}
	for c in colors:
		seen[c] = true
	return seen.size() >= 2
