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


## A legal 50-card deck under the deckbuilding rules: the Vanguard's own kit at
## 4 copies each (40) plus 10 filler cards drawn from colour-legal neighbour
## kits by a simple archetype heuristic (aggro bodies, or blockers/counters for
## control kits). Deterministic. `size` is kept for signature compatibility but
## a legal deck is always 50.
static func deck_for(vg: CardData, _size: int = 50) -> Array:
	var kit := load_kit()
	var deck: Array = []
	# Own kit, 4 copies each -> 40.
	for id in kit_ids(vg):
		for i in range(DeckValidator.MAX_COPIES):
			deck.append(kit[id])
	# 10 filler from colour-legal neighbour kits, 4 copies of each top pick.
	var need := DeckValidator.DECK_SIZE - deck.size()
	for id in filler_ids_for(vg):
		if need <= 0:
			break
		var take: int = min(DeckValidator.MAX_COPIES, need)
		for i in range(take):
			deck.append(kit[id])
		need -= take
	return deck


## The filler card ids for a Vanguard, ranked by archetype heuristic. Excludes
## the Vanguard's own kit and any card that is not colour-legal.
static func filler_ids_for(vg: CardData) -> Array:
	var kit := load_kit()
	var own := kit_ids(vg)
	var archetype: String = AIPolicy.ARCHETYPE_BY_VANGUARD.get(vg.id, "rush")
	var control := archetype in ["lockdown", "filter_control", "drain"]

	var pool: Array = []
	for c in kit.values():
		if c.type == CardEnums.TYPE_VANGUARD or own.has(c.id):
			continue
		if not DeckValidator.shares_colour(c, vg):
			continue
		pool.append(c)

	if control:
		# Prefer Blockers, then high counter value, then power. Stable tie-break
		# on id keeps the list deterministic.
		pool.sort_custom(func(a, b): return _control_rank(a) > _control_rank(b))
	else:
		# Aggro: efficient bodies (power minus a cost penalty), banners first.
		pool.sort_custom(func(a, b): return _aggro_rank(a) > _aggro_rank(b))

	var ids: Array = []
	for c in pool:
		ids.append(c.id)
	return ids


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
