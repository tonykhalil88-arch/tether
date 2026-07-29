extends GutTest

## Brief 10 smoke tests: card-text synthesis, inspector data binding, and
## placeholder-art determinism. Presentation only; the engine is untouched.


# --- CardText -------------------------------------------------------------

func test_card_text_describes_known_effects():
	var ragnir := DeckFactory.card("wm01-002")   # On Play (2 Aura): KO ... 5000
	var text := CardText.rules_text(ragnir)
	assert_string_contains(text, "On Play")
	assert_string_contains(text, "KO")
	assert_string_contains(text, "5000")


func test_card_text_includes_keyword_lines():
	var rush_card := DeckFactory.card("wm01-006")  # Redgale Twins, Rush
	assert_true(rush_card.has_keyword("rush"), "test card prints Rush")
	assert_string_contains(CardText.rules_text(rush_card).to_lower(), "rush")


func test_card_text_handles_a_card_with_no_effects():
	# A vanilla body should not crash and yields an empty/short description.
	var vanilla: CardData = null
	for id in ["wm01-005", "wm01-046", "wm01-036"]:
		var c := DeckFactory.card(id)
		if c != null and c.effects.is_empty() and c.keywords.is_empty():
			vanilla = c
			break
	if vanilla != null:
		assert_eq(CardText.rules_text(vanilla).strip_edges(), "")


# --- Inspector data binding -----------------------------------------------

func test_inspector_binds_card_data_on_pin():
	var insp := CardInspector.new()
	add_child_autofree(insp)
	var card := DeckFactory.card("wm01-002")   # Ragnir
	insp.pin(card)
	assert_true(insp.is_open(), "pinning opens the inspector")
	assert_eq(insp.current_card(), card, "inspector holds the pinned card")
	assert_string_contains(insp.inspected_text(), "KO")
	assert_string_contains(insp.meta_text(), "Cost")
	# Esc / close.
	insp.close()
	assert_false(insp.is_open(), "close hides the inspector")


func test_inspector_switches_card_on_new_hover_while_open():
	var insp := CardInspector.new()
	add_child_autofree(insp)
	insp.pin(DeckFactory.card("wm01-002"))
	# A transient hover repopulates immediately when already open.
	insp.hover_show(DeckFactory.card("wm01-004"))   # Mika, search_top
	assert_string_contains(insp.inspected_text(), "look at the top")


# --- Placeholder-art determinism ------------------------------------------

func test_placeholder_art_is_deterministic_per_id():
	var c := DeckFactory.card("wm01-036")
	var a := PlaceholderArt.card_art(c, 168, 240)
	var b := PlaceholderArt.card_art(c, 168, 240)
	assert_eq(a.get_data(), b.get_data(), "same id -> identical art bytes")


func test_placeholder_art_differs_between_ids():
	var a := PlaceholderArt.card_art(DeckFactory.card("wm01-002"), 168, 240)
	var b := PlaceholderArt.card_art(DeckFactory.card("wm01-003"), 168, 240)
	assert_ne(a.get_data(), b.get_data(), "different ids -> different art")


func test_dual_vanguard_renders_a_5050_vertical_split_not_a_blend():
	# Under patch 1.2 ONLY Vanguards are multi-coloured. Kaya is red/green — the
	# art field left half must be RED, right half GREEN, and NEITHER the blend.
	var kaya := DeckFactory.card("wm01-012")   # dual Vanguard, colors = [red, green]
	var img := PlaceholderArt.card_art(kaya, 168, 240)
	var left := img.get_pixel(20, 90)
	var right := img.get_pixel(148, 90)
	var ids: Array = PlaceholderArt.identity_colors(kaya.colors)
	assert_ne(left, right, "dual Vanguard has a left/right split, not one colour")
	assert_true(_col_close(left, ids[0]), "left half is colour A (red)")
	assert_true(_col_close(right, ids[1]), "right half is colour B (green)")
	var blended: Color = ids[0].lerp(ids[1], 0.5)
	assert_false(_col_close(left, blended), "left half is never the blended colour")
	assert_false(_col_close(right, blended), "right half is never the blended colour")
	# Determinism: same id -> same split.
	var img2 := PlaceholderArt.card_art(kaya, 168, 240)
	assert_eq(img.get_data(), img2.get_data(), "same id -> identical split art")


## Colours compared with an 8-bit tolerance (RGBA8 quantises float channels).
func _col_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


func test_recoloured_ex_dual_banner_renders_solid_not_split():
	# Verdigris was red/green in 1.1; recoloured mono green in 1.2. Because the
	# split is data-driven, it now renders SOLID — the split only ever appears on
	# multi-coloured Vanguards.
	var verdigris := DeckFactory.card("wm01-013")   # now mono green
	assert_eq(verdigris.colors.size(), 1, "ex-dual Banner is now mono")
	var img := PlaceholderArt.card_art(verdigris, 168, 240)
	assert_eq(img.get_pixel(20, 90), img.get_pixel(148, 90),
		"recoloured mono Banner art field is one colour on both halves")


func test_mono_colour_card_is_solid_not_split():
	var ragnir := DeckFactory.card("wm01-002")   # mono red
	var img := PlaceholderArt.card_art(ragnir, 168, 240)
	assert_eq(img.get_pixel(20, 90), img.get_pixel(148, 90),
		"mono card art field is one colour on both halves")


func test_dual_vanguard_sprite_splits_too():
	PlaceholderArt.clear_cache()
	var rue := DeckFactory.card("wm01-067")   # blue/purple Vanguard
	var img := PlaceholderArt.sprite_for(rue, 96).get_image()
	# Opaque body pixels either side of the vertical centre differ by colour.
	assert_ne(img.get_pixel(30, 54), img.get_pixel(66, 54),
		"dual Vanguard creature sprite is split, not one colour")


func test_creature_sprite_fallback_is_per_id_not_the_shared_diamond():
	AssetManifest.clear_cache()
	PlaceholderArt.clear_cache()
	# A card with no art file falls back to its DETERMINISTIC placeholder sprite.
	var id := "wm01-036"   # no assets/cards/ entry
	var bundle := AssetManifest.resolve(id)
	var expected := PlaceholderArt.sprite_for(DeckFactory.card(id))
	assert_eq(bundle["sprite_idle"], expected, "fallback uses the per-id sprite")
	assert_ne(bundle["sprite_idle"], AssetManifest.placeholder_sprite(),
		"not the shared magenta diamond")


func test_wired_example_card_keeps_its_real_sprite():
	AssetManifest.clear_cache()
	var bundle := AssetManifest.resolve("wm01-008")   # has real art
	assert_true(bundle["has_manifest"], "example card still has its manifest")
	assert_ne(bundle["sprite_idle"], PlaceholderArt.sprite_for(DeckFactory.card("wm01-008")),
		"real art wins over the placeholder")
