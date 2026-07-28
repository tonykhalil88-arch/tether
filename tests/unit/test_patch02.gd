extends GutTest

## Patch 0.2 — the six approved buffs and the new Stampede rider mechanic.

# --- Changelog spot-checks (values load correctly) ------------------------

func test_changelog_values_loaded():
	var kit: Dictionary = DeckFactory.load_kit()
	# 1. Kaya rest ability Aura cost 2 -> 1
	assert_eq(int(kit["wm01-012"].effects[0]["cost"]["aura"]), 1, "Kaya rest costs 1")
	# 2. Bo & Lantern rested bonus 2000 -> 3000
	assert_eq(int(kit["wm01-015"].effects[0]["action"]["amount"]), 3000, "Bo & Lantern +3000")
	# 3. Bram refresh ability Aura cost 2 -> 1
	assert_eq(int(kit["wm01-023"].effects[0]["cost"]["aura"]), 1, "Bram refresh costs 1")
	# 4. Stampede rider present (amount became 2000 in Patch 0.3)
	var rider: Dictionary = kit["wm01-032"].effects[0]["action"].get("rider", {})
	assert_eq(str(rider.get("applies_to", "")), "refreshed", "Stampede rider applies_to refreshed")
	assert_eq(int(rider.get("amount", 0)), 2000)
	# 5. Rue freeze cost removed (no cost key, still once per turn)
	assert_false(kit["wm01-067"].effects[0].has("cost"), "Rue freeze has no Aura cost")
	assert_true(bool(kit["wm01-067"].effects[0].get("once_per_turn", false)), "still once per turn")
	# 6. Field Vivisector power 3000 -> 4000
	assert_eq(int(kit["wm01-069"].power), 4000, "Vivisector power 4000")

# --- Stampede rider: buffs exactly the refreshed Banners -------------------

func test_stampede_rider_buffs_only_the_refreshed_banners():
	var g := Scenario.fresh()
	# Two rested cost-3 Pact Banners (eligible) + one that Stampede won't touch.
	var a: CardInstance = Scenario.spawn_banner(g, 0, "wm01-027", true)  # Warband Outriders 5000
	var b: CardInstance = Scenario.spawn_banner(g, 0, "wm01-025", true)  # Bram Shieldbrother 3000
	var untouched_ready: CardInstance = Scenario.spawn_banner(g, 0, "wm01-036", false)  # not rested
	var untouched_big: CardInstance = Scenario.spawn_banner(g, 0, "wm01-035", true)     # cost 7 > max 3
	var stampede: CardInstance = g._make_instance(DeckFactory.card("wm01-032"), 0)
	g._fire(stampede, CardEnums.EV_MAIN)

	assert_eq(a.current_power(), 7000, "refreshed Banner +2000 (5000 -> 7000)")
	assert_eq(b.current_power(), 5000, "refreshed Banner +2000 (3000 -> 5000)")
	assert_false(a.exhausted, "and it was refreshed")
	assert_eq(untouched_ready.current_power(), 3000, "already-ready Banner not buffed")
	assert_eq(untouched_big.current_power(), 9000, "over-cost Banner not buffed")

func test_stampede_rider_buff_expires_at_end_of_turn():
	var g := Scenario.fresh()
	var a: CardInstance = Scenario.spawn_banner(g, 0, "wm01-027", true)
	var stampede: CardInstance = g._make_instance(DeckFactory.card("wm01-032"), 0)
	g._fire(stampede, CardEnums.EV_MAIN)
	assert_eq(a.current_power(), 7000, "buffed for the turn")
	g.end_turn()
	assert_eq(a.current_power(), 5000, "turn-duration buff expired")

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
