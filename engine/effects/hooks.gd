class_name EffectHooks
extends RefCounted

## Escape hatch for bespoke card effects that the data-driven action set in
## EffectEngine cannot express. JSON effects use:
##     { "trigger": "...", "action": "hook", "params": { "hook": "my_id" } }
## and the id is looked up here.
##
## Each hook is `func(game, source, ctx) -> void`. Register real ones next
## session as card text arrives; the mechanism is exercised by tests today.

static var _registry: Dictionary = {}


static func register(hook_id: String, cb: Callable) -> void:
	_registry[hook_id] = cb


static func has(hook_id: String) -> bool:
	return _registry.has(hook_id)


static func run(hook_id: String, game, source: CardInstance, ctx: Dictionary) -> void:
	if not _registry.has(hook_id):
		push_warning("EffectHooks: no hook registered for '%s'" % hook_id)
		return
	var cb: Callable = _registry[hook_id]
	if cb.is_valid():
		cb.call(game, source, ctx)


static func clear() -> void:
	_registry.clear()
