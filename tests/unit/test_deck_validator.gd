extends GutTest

## Deckbuilding rules (patch 1.1): exactly 50 cards, max 4 copies, and STRICT
## PURITY — every deck card's colour set must be a SUBSET of the Vanguard's.

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

# --- Strict Purity: subset legality --------------------------------------

func test_strict_purity_rejects_offcolour_card():
	# Start from a legal mono-red Sora deck and swap in one purple card so ONLY
	# the colour rule is violated.
	var deck: Array = _legal_deck()
	deck[0] = DeckFactory.card("wm01-085")    # Powder Imp, purple — illegal with red Sora
	var r: Dictionary = DeckValidator.validate(deck, DeckFactory.card("wm01-001"))
	assert_false(r["ok"])
	assert_string_contains(r["reason"], "subset")

func test_dual_card_is_illegal_in_a_mono_deck():
	# {red,green} is NOT a subset of {red} — the key tightening vs the old rule,
	# under which a red/green card was legal in a mono-red deck.
	var sora := DeckFactory.card("wm01-001")           # mono red
	var red_green := DeckFactory.card("wm01-013")       # Verdigris, red/green
	assert_false(DeckValidator.is_colour_legal(red_green, sora),
		"a red/green card is illegal under a mono-red Vanguard")

func test_mono_card_is_legal_in_a_dual_deck():
	# Both mono halves of a dual Vanguard are legal; the third colour is not.
	var kaya := DeckFactory.card("wm01-012")            # red/green
	assert_true(DeckValidator.is_colour_legal(DeckFactory.card("wm01-002"), kaya),
		"a mono-red card is legal under red/green")
	assert_true(DeckValidator.is_colour_legal(DeckFactory.card("wm01-035"), kaya),
		"a mono-green card is legal under red/green")
	assert_true(DeckValidator.is_colour_legal(DeckFactory.card("wm01-013"), kaya),
		"a red/green card is legal under red/green")
	assert_false(DeckValidator.is_colour_legal(DeckFactory.card("wm01-046"), kaya),
		"a mono-blue card is illegal under red/green")

func test_is_colour_legal_helper_matches_subset_semantics():
	var sora := DeckFactory.card("wm01-001")   # red
	assert_true(DeckValidator.is_colour_legal(DeckFactory.card("wm01-002"), sora), "mono-red under red")
	assert_false(DeckValidator.is_colour_legal(DeckFactory.card("wm01-013"), sora), "red/green NOT subset of red")
	assert_false(DeckValidator.is_colour_legal(DeckFactory.card("wm01-085"), sora), "purple NOT subset of red")

func test_vanguard_must_be_a_vanguard():
	var r: Dictionary = DeckValidator.validate(_legal_deck(), DeckFactory.card("wm01-005"))
	assert_false(r["ok"], "a Banner is not a legal Vanguard")

func test_every_deck_card_is_subset_legal_for_every_vanguard():
	for vg in DeckFactory.vanguards():
		for c in DeckFactory.deck_for(vg):
			assert_true(DeckValidator.is_colour_legal(c, vg),
				"%s (%s) subset-legal under %s (%s)" % [c.id, str(c.colors), vg.id, str(vg.colors)])
