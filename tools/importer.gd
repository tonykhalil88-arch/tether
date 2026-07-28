class_name CardImporter
extends RefCounted

## Converts card-definition JSON into CardData Resources and back.
##
## The importer is deliberately lossless: for any well-formed card dict `d`,
##     CardImporter.card_to_dict(CardData.from_dict(d)) == _normalize(d)
## where _normalize only fills defaulted-but-absent fields. Re-importing the
## emitted dict is a fixed point (see tests/unit/test_importer.gd).

const REQUIRED_KEYS := ["id", "name", "type"]

## Per-entry problems (invalid type, missing keys, malformed entry) from the
## most recent import. Skipped cards are recorded here rather than raised as
## engine errors, so a bad row never aborts the batch and callers can surface
## the issues however they like.
static var last_issues: Array = []


## Parse a JSON string into an Array[CardData]. `source` names the file for
## error messages. Returns [] and pushes an error on malformed JSON.
static func import_string(json_text: String, source: String = "<string>") -> Array:
	var parsed = JSON.parse_string(json_text)
	if parsed == null:
		push_error("CardImporter: failed to parse JSON from %s" % source)
		return []
	return _cards_from_parsed(parsed, source)


## Load and parse a JSON file (res:// or user:// path) into Array[CardData].
static func import_file(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("CardImporter: file not found: %s" % path)
		return []
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("CardImporter: empty or unreadable file: %s" % path)
		return []
	return import_string(text, path)


## Import every *.json card file in a directory. Returns a Dictionary keyed
## by card id -> CardData.
static func import_dir(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("CardImporter: cannot open dir: %s" % dir_path)
		return out
	for fname in dir.get_files():
		if not fname.to_lower().ends_with(".json"):
			continue
		var cards := import_file(dir_path.path_join(fname))
		for c in cards:
			out[c.id] = c
	return out


## Serialise a CardData back to a plain dict (JSON schema shape).
static func card_to_dict(card: CardData) -> Dictionary:
	return card.to_dict()


## Serialise a list of CardData to an Array of dicts.
static func cards_to_dicts(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append(c.to_dict())
	return out


## Emit an Array[CardData] as pretty JSON (round-trips back through import).
static func export_string(cards: Array) -> String:
	return JSON.stringify(cards_to_dicts(cards), "    ")


# --- internals ------------------------------------------------------------

static func _cards_from_parsed(parsed, source: String) -> Array:
	last_issues = []
	var raw_list: Array = []
	# Accept either a bare array of cards or an object with a "cards" array.
	if typeof(parsed) == TYPE_ARRAY:
		raw_list = parsed
	elif typeof(parsed) == TYPE_DICTIONARY and parsed.has("cards"):
		raw_list = parsed["cards"]
	else:
		push_error("CardImporter: %s is neither a card array nor {cards:[...]}" % source)
		return []

	var out: Array = []
	for entry in raw_list:
		# Per-entry problems are recorded and skipped; the rest still imports.
		if typeof(entry) != TYPE_DICTIONARY:
			last_issues.append("%s has a non-object card entry" % source)
			continue
		var missing := _missing_required(entry)
		if not missing.is_empty():
			last_issues.append("card in %s missing keys %s" % [source, str(missing)])
			continue
		if not CardEnums.is_valid_type(str(entry.get("type", ""))):
			last_issues.append("card '%s' in %s has invalid type '%s'" % [
				str(entry.get("id", "?")), source, str(entry.get("type", ""))])
			continue
		out.append(CardData.from_dict(entry))
	return out


static func _missing_required(entry: Dictionary) -> Array:
	var missing: Array = []
	for k in REQUIRED_KEYS:
		if not entry.has(k) or str(entry[k]).is_empty():
			missing.append(k)
	return missing
