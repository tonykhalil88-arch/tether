extends GutTest

## Effect system: event bus, the WM01 data-driven actions, and the hook hatch.

func test_event_bus_subscribe_and_emit():
	var bus := EventBus.new()
	var hits := { "count": 0, "last": null }
	bus.subscribe("ping", func(payload): hits["count"] += 1; hits["last"] = payload)
	bus.emit("ping", { "x": 7 })
	bus.emit("ping", { "x": 8 })
	assert_eq(hits["count"], 2)
	assert_eq(hits["last"]["x"], 8)

func test_event_bus_unsubscribe():
	var bus := EventBus.new()
	var hits := { "count": 0 }
	var token: int = bus.subscribe("ping", func(_p): hits["count"] += 1)
	bus.emit("ping")
	bus.unsubscribe(token)
	bus.emit("ping")
	assert_eq(hits["count"], 1)

func test_on_play_gain_aura_action():
	var g := Scenario.fresh()
	var before: int = g.state.players[0].aura_total
	var brandt: CardInstance = Scenario.spawn_banner(g, 0, "wm01-061")  # on_play gain_aura 1
	g._fire(brandt, CardEnums.EV_ON_PLAY)
	assert_eq(g.state.players[0].aura_total, before + 1)

func test_on_play_ko_removes_low_power_enemy_banner():
	var g := Scenario.fresh()
	var garrow: CardInstance = Scenario.spawn_banner(g, 0, "wm01-007")  # ko max_power 2000
	var weak: CardInstance = Scenario.spawn_banner(g, 1, "wm01-004")    # Mika, power 2000
	g._fire(garrow, CardEnums.EV_ON_PLAY)
	assert_eq(weak.zone, CardEnums.ZONE_TRASH, "power <= 2000 KO'd")

func test_on_play_costed_effect_pays_aura():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var ragnir: CardInstance = Scenario.spawn_banner(g, 0, "wm01-002")  # on_play cost 2: ko max 5000
	var target: CardInstance = Scenario.spawn_banner(g, 1, "wm01-005")  # 5000
	g._fire(ragnir, CardEnums.EV_ON_PLAY)
	assert_eq(target.zone, CardEnums.ZONE_TRASH, "KO'd")
	assert_eq(g.state.players[0].aura_available(), 3, "paid 2 Aura")

func test_search_top_adds_matching_card():
	var g := Scenario.fresh()  # P0 deck is Redgale
	var before: int = g.state.players[0].hand.size()
	var mika: CardInstance = Scenario.spawn_banner(g, 0, "wm01-004")  # search Redgale, add 1
	g._fire(mika, CardEnums.EV_ON_PLAY)
	assert_eq(g.state.players[0].hand.size(), before + 1, "one Redgale card added")

func test_hook_escape_hatch_runs():
	var flag := { "ran": false }
	EffectHooks.register("test_flag", func(_g, _s, _c): flag["ran"] = true)
	var cd := CardData.from_dict({
		"id": "hooky", "name": "Hooky", "type": "banner", "colors": ["red"],
		"cost": 1, "power": 1000, "keywords": [],
		"effects": [{ "trigger": "on_play", "action": { "type": "hook", "hook": "test_flag" } }],
	})
	var g := Scenario.fresh()
	var inst: CardInstance = g._make_instance(cd, 0)
	g._fire(inst, CardEnums.EV_ON_PLAY)
	assert_true(flag["ran"], "hook executed")
	EffectHooks.clear()

func test_activate_main_respects_once_per_turn():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	# Give P0 an Averil Vanguard (activate_main draw_then_bottom, once per turn).
	var averil: CardInstance = g._make_instance(DeckFactory.card("wm01-045"), 0)
	averil.zone = CardEnums.ZONE_VANGUARD
	g.state.players[0].vanguard = averil
	assert_true(g.activate_main(averil), "first activation ok")
	assert_false(g.activate_main(averil), "Once Per Turn blocks the second")
