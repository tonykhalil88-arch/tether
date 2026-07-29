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
	assert_false(DeckValidator.is_colour_legal(DeckFactory.card("wm01-046"), kaya),
		"a mono-blue card is illegal under red/green")

func test_is_colour_legal_helper_matches_subset_semantics():
	var sora := DeckFactory.card("wm01-001")   # red
	assert_true(DeckValidator.is_colour_legal(DeckFactory.card("wm01-002"), sora), "mono-red under red")
	assert_false(DeckValidator.is_colour_legal(DeckFactory.card("wm01-024"), sora), "mono-green NOT subset of red")
	assert_false(DeckValidator.is_colour_legal(DeckFactory.card("wm01-085"), sora), "purple NOT subset of red")

# --- patch 1.2 cross-kit legality (mono recolour) ------------------------

func test_mono_recolour_opens_cross_kit_tech():
	# Sora (mono red) may now run Wagon Drake — a Morrow Runner recoloured to red.
	var sora := DeckFactory.card("wm01-001")
	var wagon := DeckFactory.card("wm01-019")
	assert_eq(wagon.colors, ["red"] as Array, "Wagon Drake is mono red in 1.2")
	assert_true(DeckValidator.is_colour_legal(wagon, sora), "Sora may run Wagon Drake")
	# ...and it actually lands in the built deck (filler from the wider red pool).
	var in_deck := false
	for c in DeckFactory.deck_for(sora):
		if c.id == "wm01-019":
			in_deck = true
	assert_true(in_deck, "Wagon Drake appears in Sora's rebuilt deck")

	# Neza (mono green) may now run Korgan — an Old Pact body recoloured to green.
	var neza := DeckFactory.card("wm01-034")
	var korgan := DeckFactory.card("wm01-024")
	assert_eq(korgan.colors, ["green"] as Array, "Korgan is mono green in 1.2")
	assert_true(DeckValidator.is_colour_legal(korgan, neza), "Neza may run Korgan")

func test_dual_vanguard_may_run_either_mono_pool():
	# Kaya (red/green) shops both her mono pools; her colour pair excludes blue/purple.
	var kaya := DeckFactory.card("wm01-012")
	assert_true(DeckValidator.is_colour_legal(DeckFactory.card("wm01-019"), kaya), "mono-red Wagon Drake legal under Kaya")
	assert_true(DeckValidator.is_colour_legal(DeckFactory.card("wm01-024"), kaya), "mono-green Korgan legal under Kaya")
	assert_false(DeckValidator.is_colour_legal(DeckFactory.card("wm01-046"), kaya), "mono-blue illegal under Kaya")
	assert_false(DeckValidator.is_colour_legal(DeckFactory.card("wm01-085"), kaya), "mono-purple illegal under Kaya")

func test_vanguard_must_be_a_vanguard():
	var r: Dictionary = DeckValidator.validate(_legal_deck(), DeckFactory.card("wm01-005"))
	assert_false(r["ok"], "a Banner is not a legal Vanguard")

func test_every_deck_card_is_subset_legal_for_every_vanguard():
	for vg in DeckFactory.vanguards():
		for c in DeckFactory.deck_for(vg):
			assert_true(DeckValidator.is_colour_legal(c, vg),
				"%s (%s) subset-legal under %s (%s)" % [c.id, str(c.colors), vg.id, str(vg.colors)])
