extends GutTest

## Passive, conditional power buffs computed on demand so thresholds apply and
## unapply dynamically (Dreyse @ 8 Aura, Siegeworks, Old Hollow).

const DREYSE := "wm01-078"       # +1000 own Bulwark Banners while aura_total >= 8
const SIEGEWORKS := "wm01-088"   # Stage: +1000 own Vanguard while aura_total >= 8
const BRAM_VG := "wm01-023"      # Pact Vanguard
const OLD_HOLLOW := "wm01-044"   # Stage: +1000 own Pact Blockers on opponent turn
const BULWARK_BANNER := "wm01-060"   # Bulwark, 5000
const PACT_BLOCKER := "wm01-029"     # Greatox Matron, Pact Blocker, 6000
const OFF_TRIBE := "wm01-005"        # Redgale, 5000

func test_dreyse_threshold_applies_and_unapplies_dynamically():
	var g := Scenario.fresh_with_vanguards(DREYSE, DREYSE)
	var b: CardInstance = Scenario.spawn_banner(g, 0, BULWARK_BANNER)  # 5000
	g.state.players[0].aura_total = 7
	assert_eq(g.effective_power(b), 5000, "below 8: no buff")
	g.state.players[0].aura_total = 8
	assert_eq(g.effective_power(b), 6000, "at 8: +1000")
	g.state.players[0].aura_total = 7
	assert_eq(g.effective_power(b), 5000, "drops back below 8: buff removed")

func test_dreyse_only_buffs_bulwark_banners():
	var g := Scenario.fresh_with_vanguards(DREYSE, DREYSE)
	g.state.players[0].aura_total = 8
	var off: CardInstance = Scenario.spawn_banner(g, 0, OFF_TRIBE)
	assert_eq(g.effective_power(off), 5000, "non-Bulwark unaffected")

func test_dreyse_passive_is_gated_to_your_turn():
	var g := Scenario.fresh_with_vanguards(DREYSE, DREYSE)
	var b: CardInstance = Scenario.spawn_banner(g, 0, BULWARK_BANNER)
	g.state.players[0].aura_total = 8
	g.state.active_player = 1
	assert_eq(g.effective_power(b), 5000, "your_turn passive off on opponent's turn")
	g.state.active_player = 0
	assert_eq(g.effective_power(b), 6000, "on again on your turn")

func test_siegeworks_buffs_vanguard_at_threshold():
	var g := Scenario.fresh_with_vanguards(DREYSE, DREYSE)
	Scenario.set_stage(g, 0, SIEGEWORKS)
	var vg: CardInstance = g.state.players[0].vanguard
	g.state.players[0].aura_total = 8
	assert_eq(g.effective_power(vg), 6000, "Vanguard 5000 + 1000 Siegeworks")
	g.state.players[0].aura_total = 7
	assert_eq(g.effective_power(vg), 5000)

func test_old_hollow_buffs_pact_blockers_only_on_opponent_turn():
	var g := Scenario.fresh_with_vanguards(BRAM_VG, BRAM_VG)
	Scenario.set_stage(g, 0, OLD_HOLLOW)
	var blk: CardInstance = Scenario.spawn_banner(g, 0, PACT_BLOCKER)  # 6000 Pact Blocker
	g.state.active_player = 0
	assert_eq(g.effective_power(blk), 6000, "no buff on your own turn")
	g.state.active_player = 1
	assert_eq(g.effective_power(blk), 7000, "+1000 defending on the opponent's turn")
