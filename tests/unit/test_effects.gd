extends GutTest

## Effect system: event bus, data-driven actions, and the hook escape hatch.

func test_event_bus_subscribe_and_emit():
	var bus := EventBus.new()
	var hits := { "count": 0, "last": null }
	bus.subscribe("ping", func(payload): hits["count"] += 1; hits["last"] = payload)
	bus.emit("ping", { "x": 7 })
	bus.emit("ping", { "x": 8 })
	assert_eq(hits["count"], 2, "handler fired twice")
	assert_eq(hits["last"]["x"], 8, "payload delivered")

func test_event_bus_unsubscribe():
	var bus := EventBus.new()
	var hits := { "count": 0 }
	var token: int = bus.subscribe("ping", func(_p): hits["count"] += 1)
	bus.emit("ping")
	bus.unsubscribe(token)
	bus.emit("ping")
	assert_eq(hits["count"], 1, "no delivery after unsubscribe")

func test_on_play_draw_effect_fires():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var deck_before: int = g.state.players[0].deck.size()
	var scout: CardInstance = Scenario.hand_card(g, 0, "redgale_scout")  # On Play: draw 1
	assert_true(g.play_card(0, scout))
	assert_eq(g.state.players[0].deck.size(), deck_before - 1, "On Play drew a card")

func test_power_buff_action_targets_self():
	var g := Scenario.fresh()
	var b: CardInstance = Scenario.spawn_banner(g, 0, "cinder_darter")  # 3000
	EffectEngine.resolve(g, b, { "action": "power_buff", "params": { "target": "self", "amount": 2000 } })
	assert_eq(b.current_power(), 5000, "self buff applied")

func test_ko_action_removes_low_power_enemy_banner():
	var g := Scenario.fresh()
	var matriarch: CardInstance = Scenario.spawn_banner(g, 0, "wildfire_matriarch")
	var weak: CardInstance = Scenario.spawn_banner(g, 1, "redgale_scout")  # 2000 <= 3000
	# Fire the On Play effect (ko_enemy_banner_max_power: 3000).
	EffectEngine.fire(g, matriarch, CardEnums.EV_ON_PLAY)
	assert_eq(weak.zone, CardEnums.ZONE_TRASH, "low-power enemy Banner KO'd")

func test_hook_escape_hatch_runs():
	var flag := { "ran": false }
	EffectHooks.register("test_flag", func(_g, _s, _c): flag["ran"] = true)
	var cd := CardData.from_dict({
		"id": "hooky", "name": "Hooky", "type": "Banner", "colors": ["Red"],
		"cost": 1, "power": 1000, "counter": 0, "life": 0, "keywords": [],
		"effects": [{ "trigger": "on_play", "action": "hook", "params": { "hook": "test_flag" } }],
		"flavor": "", "faction": "", "tribe": "",
	})
	var g := Scenario.fresh()
	var inst: CardInstance = g._make_instance(cd, 0)
	EffectEngine.fire(g, inst, CardEnums.EV_ON_PLAY)
	assert_true(flag["ran"], "hook executed")
	EffectHooks.clear()

func test_activate_main_respects_once_per_turn():
	var g := Scenario.fresh()
	var adept: CardInstance = Scenario.spawn_banner(g, 0, "kindling_adept")
	assert_true(g.activate_main(adept), "first activation ok")
	assert_false(g.activate_main(adept), "Once Per Turn blocks a second activation")
