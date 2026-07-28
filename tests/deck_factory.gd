class_name DeckFactory
extends RefCounted

## Test/sim helper: loads the WM01 card set and builds tribe-coherent decks.

const KIT_PATH := "res://data/cards/wildmigration_set1.json"


## id -> CardData for the whole set.
static func load_kit() -> Dictionary:
	var cards := CardImporter.import_file(KIT_PATH)
	var out: Dictionary = {}
	for c in cards:
		out[c.id] = c
	return out


static func card(id: String) -> CardData:
	return load_kit().get(id)


## Every Vanguard in the set.
static func vanguards() -> Array:
	var out: Array = []
	for c in load_kit().values():
		if c.type == CardEnums.TYPE_VANGUARD:
			out.append(c)
	return out


## Default Vanguard used by generic tests (Sora Akaza, mono-red, 5 Life).
static func vanguard() -> CardData:
	return load_kit()["wm01-001"]


## The ten non-Vanguard card ids of a Vanguard's own kit (the contiguous
## wm01 block that follows it). This keeps decks PURE — Bram and Elder Neza
## are both tribe "Pact" but draw from separate kits.
static func kit_ids(vg: CardData) -> Array:
	var kit := load_kit()
	var n := int(vg.id.split("-")[1])
	var out: Array = []
	for i in range(n + 1, n + 11):
		var id := "wm01-%03d" % i
		if kit.has(id) and kit[id].type != CardEnums.TYPE_VANGUARD:
			out.append(id)
	return out


## A legal 50-card deck under STRICT PURITY (patch 1.1). Deterministic.
##   * Mono Vanguards have exactly 13 subset-legal uniques (own kit of 10 + the
##     3 mono staples). 13×4 = 52, so we trim 2 copies — one each off the two
##     lowest archetype-ranked uniques (documented per deck in the report).
##   * Dual Vanguards keep their 10-card kit at 4 copies (40) plus 10 filler
##     drawn from their now-larger subset-legal pool (both mono pools + both
##     dual kits), ranked by the existing archetype heuristic.
## `size` is kept for signature compatibility but a legal deck is always 50.
static func deck_for(vg: CardData, _size: int = 50) -> Array:
	var kit := load_kit()
	var counts := decklist(vg)
	var deck: Array = []
	for id in counts:
		for i in range(int(counts[id])):
			deck.append(kit[id])
	return deck


## The deck as an ordered {id: count} map (best archetype pick first). This is
## the canonical source the report prints and deck_for expands.
static func decklist(vg: CardData) -> Dictionary:
	if vg.colors.size() <= 1:
		return _mono_decklist(vg)
	return _dual_decklist(vg)


## Mono: all 13 subset-legal uniques at 4 copies, minus one copy each off the
## two lowest-ranked (mono_trims).
static func _mono_decklist(vg: CardData) -> Dictionary:
	var ranked := _ranked_legal_uniques(vg)     # best first
	var counts: Dictionary = {}
	for c in ranked:
		counts[c.id] = DeckValidator.MAX_COPIES
	for id in mono_trims(vg):
		counts[id] -= 1
	return counts


## Dual: own kit ×4 (40) + 10 filler from the ranked non-kit legal pool.
static func _dual_decklist(vg: CardData) -> Dictionary:
	var counts: Dictionary = {}
	for id in kit_ids(vg):
		counts[id] = DeckValidator.MAX_COPIES
	var need := DeckValidator.DECK_SIZE - kit_ids(vg).size() * DeckValidator.MAX_COPIES
	for id in filler_ids_for(vg):
		if need <= 0:
			break
		var take: int = min(DeckValidator.MAX_COPIES, need)
		counts[id] = take
		need -= take
	return counts


## The two id(s) trimmed from a mono deck (the two lowest archetype-ranked of the
## 13 uniques), so 13×4−2 = 50. Empty for dual Vanguards.
static func mono_trims(vg: CardData) -> Array:
	if vg.colors.size() > 1:
		return []
	var ranked := _ranked_legal_uniques(vg)
	var out: Array = []
	# The last two entries are the lowest-ranked.
	for c in ranked.slice(ranked.size() - 2, ranked.size()):
		out.append(c.id)
	return out


## All non-Vanguard cards subset-legal for `vg`, ranked best-first by the
## Vanguard's archetype heuristic (deterministic id tie-break).
static func _ranked_legal_uniques(vg: CardData) -> Array:
	var kit := load_kit()
	var pool: Array = []
	for c in kit.values():
		if c.type == CardEnums.TYPE_VANGUARD:
			continue
		if not DeckValidator.is_colour_legal(c, vg):
			continue
		pool.append(c)
	_rank_pool(pool, vg)
	return pool


## The filler card ids for a Vanguard, ranked by archetype heuristic. Excludes
## the Vanguard's own kit and any card that is not subset-legal. (Dual decks.)
static func filler_ids_for(vg: CardData) -> Array:
	var kit := load_kit()
	var own := kit_ids(vg)
	var pool: Array = []
	for c in kit.values():
		if c.type == CardEnums.TYPE_VANGUARD or own.has(c.id):
			continue
		if not DeckValidator.is_colour_legal(c, vg):
			continue
		pool.append(c)
	_rank_pool(pool, vg)
	var ids: Array = []
	for c in pool:
		ids.append(c.id)
	return ids


## Sort `pool` in place, best archetype pick first. Control kits value Blockers /
## counters; aggro kits value efficient bodies.
static func _rank_pool(pool: Array, vg: CardData) -> void:
	var archetype: String = AIPolicy.ARCHETYPE_BY_VANGUARD.get(vg.id, "rush")
	var control := archetype in ["lockdown", "filter_control", "drain"]
	if control:
		pool.sort_custom(func(a, b): return _control_rank(a) > _control_rank(b))
	else:
		pool.sort_custom(func(a, b): return _aggro_rank(a) > _aggro_rank(b))


static func _aggro_rank(c: CardData) -> int:
	var banner_bonus := 1000000 if c.type == CardEnums.TYPE_BANNER else 0
	return banner_bonus + c.power - c.cost * 500 - int(c.id.substr(5)) # id tie-break


static func _control_rank(c: CardData) -> int:
	var blocker := 2000000 if c.has_keyword(CardEnums.KW_BLOCKER) else 0
	return blocker + c.counter * 100 + c.power - int(c.id.substr(5))


## Validate a Vanguard's generated deck (used by tests and callers).
static func validate_deck_for(vg: CardData) -> Dictionary:
	return DeckValidator.validate(deck_for(vg), vg)


## Generic deck for the default Vanguard.
static func build_deck(_size: int = 50) -> Array:
	return deck_for(vanguard())


## A deck stacked with specific card ids on top, padded with a filler id.
static func stacked_deck(top_ids: Array, filler_id: String, size: int = 50) -> Array:
	var kit := load_kit()
	var deck: Array = []
	for id in top_ids:
		deck.append(kit[id])
	while deck.size() < size:
		deck.append(kit[filler_id])
	return deck


static func _cycle(pool: Array, size: int) -> Array:
	var deck: Array = []
	var i := 0
	while deck.size() < size and not pool.is_empty():
		deck.append(pool[i % pool.size()])
		i += 1
	return deck
