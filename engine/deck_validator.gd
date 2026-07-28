class_name DeckValidator
extends RefCounted

## Enforces the WILDMIGRATION deckbuilding rules:
##   1. A deck is exactly 50 cards, plus 1 Vanguard.
##   2. At most 4 copies of any card id.
##   3. STRICT PURITY (patch 1.1): every deck card's colour set must be a
##      SUBSET of the Vanguard's colours. A mono-red Vanguard admits only
##      mono-red cards; a red/green Vanguard admits mono-red, mono-green, and
##      red/green cards — but never a card carrying a colour the Vanguard lacks.
##
## Used by DeckFactory (build valid decks), the tests, and the engine
## (GameEngine.setup can enforce it). An illegal deck is a hard failure with a
## human-readable reason.

const DECK_SIZE := 50
const MAX_COPIES := 4


## Returns { "ok": bool, "reason": String }. `deck` is an Array[CardData]
## (the 50-card deck, Vanguard excluded).
static func validate(deck: Array, vanguard: CardData) -> Dictionary:
	if vanguard == null or vanguard.type != CardEnums.TYPE_VANGUARD:
		return _fail("Vanguard card is missing or not of type 'vanguard'")

	if deck.size() != DECK_SIZE:
		return _fail("deck must be exactly %d cards, got %d" % [DECK_SIZE, deck.size()])

	var counts := {}
	for c in deck:
		if c == null:
			return _fail("deck contains a null card")
		counts[c.id] = int(counts.get(c.id, 0)) + 1
	for id in counts:
		if counts[id] > MAX_COPIES:
			return _fail("card '%s' appears %d times (max %d copies per deck)" % [
				id, counts[id], MAX_COPIES])

	for c in deck:
		if not is_colour_legal(c, vanguard):
			return _fail("card '%s' colours %s are not a subset of Vanguard '%s' colours %s (Strict Purity)" % [
				c.id, str(c.colors), vanguard.id, str(vanguard.colors)])

	return { "ok": true, "reason": "" }


## STRICT PURITY: true iff `card`'s colour set is a SUBSET of `vanguard`'s. A
## colourless card (empty set) is legal under any Vanguard.
static func is_colour_legal(card: CardData, vanguard: CardData) -> bool:
	for col in card.colors:
		if not vanguard.colors.has(col):
			return false
	return true


## Back-compat alias. Under Strict Purity, legality is subset — NOT sharing a
## colour. Kept so existing callers read clearly; delegates to is_colour_legal.
static func shares_colour(card: CardData, vanguard: CardData) -> bool:
	return is_colour_legal(card, vanguard)


## Validate and push a hard engine error on failure. Returns ok.
static func validate_or_push(deck: Array, vanguard: CardData) -> bool:
	var r := validate(deck, vanguard)
	if not r["ok"]:
		push_error("DeckValidator: illegal deck — %s" % r["reason"])
	return r["ok"]


static func _fail(reason: String) -> Dictionary:
	return { "ok": false, "reason": reason }
