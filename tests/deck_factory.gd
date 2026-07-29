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


## A legal 50-card deck under STRICT PURITY (patch 1.2). Deterministic.
##
## With the mono recolour every colour pool is now large (Red 18 / Green 28 /
## Blue 21 / Purple 25 uniques; dual Vanguards see both their mono pools, 40+),
## so ALL eight Vanguards build the same way: the Vanguard's own 10-card kit at
## 4 copies each (40) plus 10 filler drawn from the ranked subset-legal pool
## (best archetype pick first, taken as 4 + 4 + 2). This surfaces real cross-kit
## tech — e.g. rush picks up Ashvane / Ola / Outriders; lockdown picks up Korgan.
## `size` is kept for signature compatibility but a legal deck is always 50.
static func deck_for(vg: CardData, _size: int = 50) -> Array:
	var kit := load_kit()
	var counts := decklist(vg)
	var deck: Array = []
	for id in counts:
		for i in range(int(counts[id])):
			deck.append(kit[id])
	return deck


## The deck as an ordered {id: count} map: own kit ×4 (40) + 10 ranked filler.
static func decklist(vg: CardData) -> Dictionary:
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


## Back-compat stub: patch 1.1 mono decks trimmed 2 copies off a 13-unique pool;
## patch 1.2's larger pools use kit ×4 + filler for every Vanguard, so no deck is
## trimmed. Kept so the 1.1 revalidation script still resolves.
static func mono_trims(_vg: CardData) -> Array:
	return []


## The filler card ids for a Vanguard, ranked by archetype heuristic. Excludes
## the Vanguard's own kit and any card that is not subset-legal.
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
