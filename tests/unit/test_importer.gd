extends GutTest

## JSON <-> CardData importer: lossless round-trip, validation, dir import,
## power ceiling — over the real 100-card WM01 set (patch 1.1).

func test_set_composition():
	var cards: Array = CardImporter.import_file(DeckFactory.KIT_PATH)
	assert_eq(cards.size(), 100, "100 cards in the set (patch 1.1)")
	var counts := { "vanguard": 0, "banner": 0, "technique": 0, "stage": 0 }
	for c in cards:
		counts[c.type] += 1
	assert_eq(counts["vanguard"], 8, "8 Vanguards")
	assert_eq(counts["banner"], 68, "68 Banners (56 + the Purity Twelve)")
	assert_eq(counts["technique"], 16, "16 Techniques")
	assert_eq(counts["stage"], 8, "8 Stages")

func test_round_trip_is_a_fixed_point_for_all_cards():
	var cards: Array = CardImporter.import_file(DeckFactory.KIT_PATH)
	for c in cards:
		var d1: Dictionary = c.to_dict()
		var c2: CardData = CardData.from_dict(d1)
		var d2: Dictionary = c2.to_dict()
		assert_eq(d2, d1, "dict -> CardData -> dict stable for %s" % c.id)

func test_round_trip_preserves_nested_effects():
	var sora: CardData = DeckFactory.card("wm01-001")
	var d: Dictionary = sora.to_dict()
	assert_eq(d["type"], "vanguard")
	assert_eq(d["life"], 5)
	assert_eq(d["colors"], ["red"])
	var eff: Dictionary = d["effects"][0]
	assert_eq(eff["trigger"], "activate_main")
	assert_eq(int(eff["action"]["amount"]), 2000, "nested effect params survive")
	assert_true(eff["action"].has("rider"), "rider preserved")

func test_effects_are_deep_copied_not_shared():
	var sora: CardData = DeckFactory.card("wm01-001")
	var d: Dictionary = sora.to_dict()
	d["effects"][0]["action"]["amount"] = 99999
	var d2: Dictionary = sora.to_dict()
	assert_eq(int(d2["effects"][0]["action"]["amount"]), 2000, "resource unchanged")

func test_invalid_type_is_rejected():
	var bad := '[{"id":"x","name":"X","type":"sorcery"}]'
	var cards: Array = CardImporter.import_string(bad, "<test>")
	assert_eq(cards.size(), 0, "invalid type dropped")
	assert_eq(CardImporter.last_issues.size(), 1)

func test_clean_set_reports_no_issues_and_respects_ceiling():
	var cards: Array = CardImporter.import_file(DeckFactory.KIT_PATH)
	assert_eq(cards.size(), 100)
	assert_eq(CardImporter.last_issues.size(), 0, "no issues on the real set")
	for c in cards:
		assert_true(c.power <= CardEnums.POWER_CEILING, "%s within power ceiling" % c.id)

func test_power_ceiling_violation_is_flagged():
	var over := '[{"id":"big","name":"Too Big","type":"banner","power":10000}]'
	var cards: Array = CardImporter.import_string(over, "<test>")
	assert_eq(cards.size(), 1, "still imported")
	assert_eq(CardImporter.last_issues.size(), 1, "but flagged as over ceiling")

func test_import_dir_keys_by_id():
	var by_id: Dictionary = CardImporter.import_dir("res://data/cards")
	assert_true(by_id.has("wm01-024"), "dir import keyed by id")
	assert_eq(by_id["wm01-024"].name, "Korgan, Iron-Hided")
