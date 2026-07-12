class_name MapHistory
extends RefCounted

## Undo stack for MapDocument. Snapshots the full document (cells + every
## element array) — see analysis.md §4a: the pre-refactor version only
## snapshotted `cells`, so Undo silently never restored habitas/AZN/zones.

const MAX_HISTORY := 50

var _history: Array = []
var _index: int = -1

func reset() -> void:
	_history.clear()
	_index = -1

func save_state(doc: MapDocument) -> void:
	if _index < _history.size() - 1:
		_history.resize(_index + 1)

	_history.append(doc.snapshot())
	_index = _history.size() - 1

	if _history.size() > MAX_HISTORY:
		_history.pop_front()
		_index -= 1

func can_undo() -> bool:
	return _index > 0

func undo(doc: MapDocument) -> void:
	if not can_undo():
		return
	_index -= 1
	doc.restore(_history[_index])
