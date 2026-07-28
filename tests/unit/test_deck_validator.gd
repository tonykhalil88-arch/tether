extends GutTest

## Deckbuilding rules: exactly 50 cards, max 4 copies, colour legality.

func _legal_deck() -> Array:
	return DeckFactory.deck_for(DeckFactory.card("wm01-001"))  # Sora, red

func test_generated_decks_are_legal_for_every_vanguard():
	for vg in DeckFactory.vanguards():
		var r: Dictionary = DeckFactory.validate_deck_for(vg)
		assert_true(r["ok"], "%s deck legal: %s" % [vg.id, r["reason"]])

func test_deck_must_be_exactly_fifty():
	var deck: Array = _legal_deck()
	deck.pop_back()  # 49
	var r: Dictionary = DeckValidator.validate(deck, DeckFactory.card("wm01-001"))
	assert_false(r["ok"])
	assert_string_contains(r["reason"], "50")

func test_max_four_copies():
	var kit := DeckFactory.load_kit()
	var deck: Array = []
	for i in range(5):
		deck.append(kit["wm01-005"])   # 5 copies -> illegal
	while deck.size() < 50:
		deck.append(kit["wm01-002"])
	var r: Dictionary = DeckValidator.validate(deck, DeckFactory.card("wm01-001"))
	assert_false(r["ok"])
	assert_string_contains(r["reason"], "max 4")

func test_colour_legality_enforced():
	# Start from a legal Sora deck (50, <=4 copies) and swap in one purple card
	# so ONLY the colour rule is violated.
	var deck: Array = _legal_deck()
	deck[0] = DeckFactory.card("wm01-085")    # Powder Imp, purple — illegal with red Sora
	var r: Dictionary = DeckValidator.validate(deck, DeckFactory.card("wm01-001"))
	assert_false(r["ok"])
	assert_string_contains(r["reason"], "colour")

func test_shares_colour_helper():
	var sora := DeckFactory.card("wm01-001")   # red
	assert_true(DeckValidator.shares_colour(DeckFactory.card("wm01-013"), sora), "red/green shares red")
	assert_false(DeckValidator.shares_colour(DeckFactory.card("wm01-085"), sora), "purple shares nothing")

func test_vanguard_must_be_a_vanguard():
	var r: Dictionary = DeckValidator.validate(_legal_deck(), DeckFactory.card("wm01-005"))
	assert_false(r["ok"], "a Banner is not a legal Vanguard")

func test_filler_is_colour_legal_neighbour_kit():
	var neza := DeckFactory.card("wm01-034")   # green, lockdown -> Pact blockers filler
	var filler := DeckFactory.filler_ids_for(neza)
	assert_false(filler.is_empty())
	var kit := DeckFactory.load_kit()
	for id in filler:
		assert_true(DeckValidator.shares_colour(kit[id], neza), "%s colour-legal for Neza" % id)
		assert_false(DeckFactory.kit_ids(neza).has(id), "%s is from a neighbour kit" % id)
