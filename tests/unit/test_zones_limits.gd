extends GutTest

## Zone limits: Battle Area cap of 5, and Stage uniqueness (max 1 per player).

const B := "wm01-005"        # Denji, no effects
const STAGE := "wm01-011"    # Dunmar Canyon Run

func test_battle_area_accepts_five():
	var g := Scenario.fresh()
	for i in range(5):
		Scenario.spawn_banner(g, 0, B)
	assert_eq(g.state.players[0].battle_area.size(), 5)
	assert_true(g.state.players[0].battle_area_full())

func test_sixth_banner_cannot_be_played():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 10, 0)
	for i in range(5):
		Scenario.spawn_banner(g, 0, B)
	var sixth: CardInstance = Scenario.hand_card(g, 0, B)
	assert_false(g.play_card(0, sixth), "cannot exceed Battle Area cap of 5")
	assert_eq(g.state.players[0].battle_area.size(), 5)
	assert_eq(sixth.zone, CardEnums.ZONE_HAND)

func test_stage_is_placed():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 5, 0)
	var stage: CardInstance = Scenario.hand_card(g, 0, STAGE)
	assert_true(g.play_card(0, stage))
	assert_eq(g.state.players[0].stage, stage)

func test_second_stage_replaces_first():
	var g := Scenario.fresh()
	Scenario.set_aura(g, 0, 10, 0)
	var first: CardInstance = Scenario.hand_card(g, 0, STAGE)
	var second: CardInstance = Scenario.hand_card(g, 0, STAGE)
	g.play_card(0, first)
	g.play_card(0, second)
	assert_eq(g.state.players[0].stage, second, "new Stage takes the slot")
	assert_eq(first.zone, CardEnums.ZONE_TRASH, "old Stage to Trash — max 1")
