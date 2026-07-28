extends GutTest

## Patch 0.2 spot-checks that still hold, plus the refresh-rider ENGINE support
## (the rider mechanic is retained even though no card uses it after Patch 0.4).

# --- Changelog spot-checks (values load correctly) ------------------------

func test_changelog_values_loaded():
	var kit: Dictionary = DeckFactory.load_kit()
	# Kaya rest ability Aura cost 2 -> 1 (0.2, still in effect)
	assert_eq(int(kit["wm01-012"].effects[0]["cost"]["aura"]), 1, "Kaya rest costs 1")
	# Bo & Lantern rested bonus 2000 -> 3000
	assert_eq(int(kit["wm01-015"].effects[0]["action"]["amount"]), 3000, "Bo & Lantern +3000")
	# Bram refresh ability Aura cost 2 -> 1
	assert_eq(int(kit["wm01-023"].effects[0]["cost"]["aura"]), 1, "Bram refresh costs 1")
	# Rue freeze cost removed (no cost key, still once per turn)
	assert_false(kit["wm01-067"].effects[0].has("cost"), "Rue freeze has no Aura cost")
	assert_true(bool(kit["wm01-067"].effects[0].get("once_per_turn", false)), "still once per turn")
	# Field Vivisector power 3000 -> 4000
	assert_eq(int(kit["wm01-069"].power), 4000, "Vivisector power 4000")

# --- Refresh rider mechanic: ENGINE support retained (no card uses it now) --

func test_refresh_rider_engine_support_retained():
	# Craft a refresh action with an applies_to:"refreshed" rider and confirm the
	# engine still buffs exactly the refreshed Banners (Patch 0.4 keeps support).
	var g := Scenario.fresh()
	var a: CardInstance = Scenario.spawn_banner(g, 0, "wm01-027", true)  # rested Pact 5000
	var untouched: CardInstance = Scenario.spawn_banner(g, 0, "wm01-036", false)  # not rested
	var cd := CardData.from_dict({
		"id": "test_refresher", "name": "Test Refresher", "type": "technique",
		"colors": ["red"], "cost": 0, "keywords": [],
		"effects": [{ "trigger": "main", "action": {
			"type": "refresh", "target": "own_banner", "filter_tribe": "Pact", "up_to": 2,
			"rider": { "type": "power_buff", "amount": 1500, "duration": "turn", "applies_to": "refreshed" },
		} }],
	})
	var inst: CardInstance = g._make_instance(cd, 0)
	g._fire(inst, CardEnums.EV_MAIN)
	assert_eq(a.current_power(), 6500, "refreshed Banner got the +1500 rider")
	assert_false(a.exhausted)
	assert_eq(untouched.current_power(), 3000, "ready Banner untouched")

# --- Rue fires with zero Aura ---------------------------------------------

func test_rue_freezes_aura_with_zero_aura_available():
	var g := Scenario.fresh()
	var rue: CardInstance = g._make_instance(DeckFactory.card("wm01-067"), 0)
	rue.zone = CardEnums.ZONE_VANGUARD
	g.state.players[0].vanguard = rue
	Scenario.set_aura(g, 0, 0, 0)      # no Aura at all
	g.state.players[1].aura_total = 4
	g.declare_attack(rue, g.state.players[1].vanguard)
	assert_eq(g.state.players[1].aura_frozen_pending, 1, "froze Aura despite 0 Aura available")
	assert_eq(int(g.state.watch.get("rue_aura_frozen", 0)), 1)
