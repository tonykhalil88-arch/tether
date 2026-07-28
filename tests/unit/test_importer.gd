extends GutTest

## JSON <-> CardData importer: lossless round-trip, validation, dir import.

func test_kit_has_expected_composition():
	var cards: Array = CardImporter.import_file(DeckFactory.KIT_PATH)
	assert_eq(cards.size(), 11, "11 cards in the kit")
	var counts := { "Vanguard": 0, "Banner": 0, "Technique": 0, "Stage": 0 }
	for c in cards:
		counts[c.type] += 1
	assert_eq(counts["Vanguard"], 1, "1 Vanguard")
	assert_eq(counts["Banner"], 7, "7 Banners")
	assert_eq(counts["Technique"], 2, "2 Techniques")
	assert_eq(counts["Stage"], 1, "1 Stage")

func test_round_trip_is_a_fixed_point():
	var cards: Array = CardImporter.import_file(DeckFactory.KIT_PATH)
	for c in cards:
		var d1: Dictionary = c.to_dict()
		var c2: CardData = CardData.from_dict(d1)
		var d2: Dictionary = c2.to_dict()
		assert_eq(d2, d1, "dict -> CardData -> dict is stable for %s" % c.id)

func test_round_trip_preserves_source_fields():
	var vg: CardData = DeckFactory.vanguard()
	var d: Dictionary = vg.to_dict()
	assert_eq(d["id"], "sora_akaza_vg")
	assert_eq(d["type"], "Vanguard")
	assert_eq(d["life"], 5)
	assert_eq(d["colors"], ["Red"])
	assert_eq(d["keywords"], ["When Attacking"])
	assert_true(d["effects"].size() >= 1, "effects preserved")

func test_effects_are_deep_copied_not_shared():
	var vg: CardData = DeckFactory.vanguard()
	var d: Dictionary = vg.to_dict()
	# Mutating the emitted dict must not corrupt the resource.
	d["effects"][0]["params"]["amount"] = 99999
	var d2: Dictionary = vg.to_dict()
	# Nested effect params keep JSON's numeric typing (float); cast to compare.
	assert_eq(int(d2["effects"][0]["params"]["amount"]), 1000, "resource unchanged")

func test_invalid_type_is_rejected():
	var bad := '[{"id":"x","name":"X","type":"Sorcery"}]'
	var cards: Array = CardImporter.import_string(bad, "<test>")
	assert_eq(cards.size(), 0, "invalid type dropped")
	assert_eq(CardImporter.last_issues.size(), 1, "issue recorded for the bad card")

func test_missing_required_key_is_rejected():
	var bad := '[{"name":"No Id","type":"Banner"}]'
	var cards: Array = CardImporter.import_string(bad, "<test>")
	assert_eq(cards.size(), 0, "missing id dropped")
	assert_eq(CardImporter.last_issues.size(), 1, "issue recorded for the missing key")

func test_valid_cards_import_with_no_issues():
	var cards: Array = CardImporter.import_file(DeckFactory.KIT_PATH)
	assert_eq(cards.size(), 11)
	assert_eq(CardImporter.last_issues.size(), 0, "clean kit reports no issues")

func test_import_dir_keys_by_id():
	var by_id: Dictionary = CardImporter.import_dir("res://data/cards")
	assert_true(by_id.has("cinder_darter"), "dir import keyed by id")
	assert_eq(by_id["cinder_darter"].type, "Banner")

func test_export_string_reimports_equal():
	var cards: Array = CardImporter.import_file(DeckFactory.KIT_PATH)
	var json_text: String = CardImporter.export_string(cards)
	var reimported: Array = CardImporter.import_string(json_text, "<export>")
	assert_eq(reimported.size(), cards.size(), "same count after export+reimport")
	assert_eq(reimported[0].to_dict(), cards[0].to_dict(), "first card identical")
