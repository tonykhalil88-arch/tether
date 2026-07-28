class_name DeckFactory
extends RefCounted

## Test/sim helper: loads the seeded card kit and builds legal decks.

const KIT_PATH := "res://data/cards/sora_akaza.json"


## id -> CardData for the whole Sora Akaza kit.
static func load_kit() -> Dictionary:
	var cards := CardImporter.import_file(KIT_PATH)
	var out: Dictionary = {}
	for c in cards:
		out[c.id] = c
	return out


static func vanguard() -> CardData:
	return load_kit()["sora_akaza_vg"]


## Return the single Vanguard plus all non-Vanguard cards in the kit.
static func non_vanguards() -> Array:
	var kit := load_kit()
	var out: Array = []
	for id in kit:
		if kit[id].type != CardEnums.TYPE_VANGUARD:
			out.append(kit[id])
	return out


## Build a 50-card deck by cycling the kit's non-Vanguard cards. Each CardData
## definition is shared (immutable); the engine wraps them in CardInstances.
static func build_deck(size: int = 50) -> Array:
	var pool := non_vanguards()
	var deck: Array = []
	var i := 0
	while deck.size() < size:
		deck.append(pool[i % pool.size()])
		i += 1
	return deck


## Build a deck stacked with a specific card id on top, padded with filler.
static func stacked_deck(top_ids: Array, filler_id: String, size: int = 50) -> Array:
	var kit := load_kit()
	var deck: Array = []
	for id in top_ids:
		deck.append(kit[id])
	while deck.size() < size:
		deck.append(kit[filler_id])
	return deck
