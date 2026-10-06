extends Logger
## What the engine and the scripts said, kept for a note: every error since the game started (up to ERRORS_MOST,
## then the newest) and the last LINES lines of output. Game-agnostic. The engine may log from any thread, so the
## lists sit behind a mutex. Nothing here prints (a logger that logs calls itself).
##
##   var log := NoteLog.new(); OS.add_logger(log)   ...   log.snapshot()

const LINES := 200
const ERRORS_MOST := 300

var _m := Mutex.new()
var _lines: Array[String] = []
var _errors: Array[Dictionary] = []
var _errors_seen := 0
var _start_ms := Time.get_ticks_msec()


func _log_message(message: String, error: bool) -> void:
	_m.lock()
	_keep_line(("ERR " if error else "") + message.strip_edges(false, true))
	_m.unlock()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var where := "%s:%d %s" % [file, line, function]
	var said := rationale if rationale != "" else code
	var trace := ""
	for bt in script_backtraces:
		if bt != null and not bt.is_empty():
			trace = bt.format()
			break
	_m.lock()
	_errors_seen += 1
	_errors.append({"s": (Time.get_ticks_msec() - _start_ms) / 1000.0, "type": ["error", "warning", "script", "shader"][clampi(error_type, 0, 3)],
		"said": said, "at": where, "trace": trace})
	if _errors.size() > ERRORS_MOST:
		_errors.pop_front()
	_keep_line("%s: %s (%s)" % ["WARNING" if error_type == 1 else "ERROR", said, where])
	_m.unlock()


## A copy of what is kept: {"errors": [...], "errors_seen": n, "lines": [...]}.
func snapshot() -> Dictionary:
	_m.lock()
	var out := {"errors": _errors.duplicate(true), "errors_seen": _errors_seen, "lines": _lines.duplicate()}
	_m.unlock()
	return out


func _keep_line(text: String) -> void:
	_lines.append(text)
	if _lines.size() > LINES:
		_lines.pop_front()
