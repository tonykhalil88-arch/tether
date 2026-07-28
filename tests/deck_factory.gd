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


## A pure-kit 50-card deck: the kit's ten non-Vanguard cards, cycled to `size`
## (10 -> 50 = 5 copies of each). See the balance report for the decklist
## rationale (4x core + 1x same-kit filler; hybrids are out of scope).
static func deck_for(vg: CardData, size: int = 50) -> Array:
	var kit := load_kit()
	var pool: Array = []
	for id in kit_ids(vg):
		pool.append(kit[id])
	return _cycle(pool, size)


## Generic deck for the default Vanguard.
static func build_deck(size: int = 50) -> Array:
	return deck_for(vanguard(), size)


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
