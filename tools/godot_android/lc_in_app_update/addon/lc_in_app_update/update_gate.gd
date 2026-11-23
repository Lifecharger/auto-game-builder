extends Node

## Forced update gate (UpdateGate autoload). Same behaviour as the Flutter apps'
## lifecharger_update_gate.dart.
##
## On launch (after the first frame) and every return to the foreground it asks Google Play
## (on Android) through the LcInAppUpdate plugin, or Apple App Store (on iOS) via the iTunes
## Lookup API, whether a newer version exists.
##
## On Android: Play's own IMMEDIATE update screen runs; if the player backs out of it or it fails,
## a full-screen "Update required" page covers the game with a single Update button (the
## immediate flow again, or the Play Store page when Play does not allow it).
##
## On iOS: If the store version is strictly newer than current semver, the full-screen "Update
## required" page covers the game, and pressing Update opens the game's App Store product page.
##
## While the blocking page is up the game is paused and Back does nothing. There is no way past
## it but updating.
##
## When the check cannot be made (offline, not installed from store, debug build, desktop,
## editor, plugin missing) the game runs normally: a player is never locked out because
## the store could not be asked.
##
## Strings come from the game's own translations: UPDATE_GATE_TITLE, UPDATE_GATE_BODY,
## UPDATE_GATE_BUTTON.

const PLUGIN_NAME := "LcInAppUpdate"

## Play Core UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
const AVAILABILITY_IN_PROGRESS := 3
## update_flow_result codes (Activity.RESULT_OK / RESULT_CANCELED,
## ActivityResult.RESULT_IN_APP_UPDATE_FAILED, plugin RESULT_NOT_STARTED).
const RESULT_OK := -1
const RESULT_CANCELED := 0
const RESULT_FAILED := 1
const RESULT_NOT_STARTED := 2

## Above every game overlay (the games top out at layer 100).
const OVERLAY_LAYER := 1000

const COLOR_BACKGROUND := Color(0.055, 0.043, 0.086, 0.97)
const COLOR_TITLE := Color(1, 1, 1)
const COLOR_BODY := Color(0.81, 0.78, 0.87)
const COLOR_BUTTON := Color(0.95, 0.66, 0.16)
const COLOR_BUTTON_PRESSED := Color(0.78, 0.52, 0.1)
const COLOR_BUTTON_TEXT := Color(0.1, 0.07, 0.02)

var _plugin: Object = null
var _http_request: HTTPRequest = null
var _app_store_url: String = ""
var _blocked := false
var _checking := false
var _starting := false
var _start_after_check := false
var _availability := 0
var _immediate_allowed := false
var _paused_before := false
var _layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _is_active():
		return
	if OS.get_name() == "Android":
		_plugin = Engine.get_singleton(PLUGIN_NAME)
		_plugin.connect("update_check_completed", _on_update_check_completed)
		_plugin.connect("update_check_failed", _on_update_check_failed)
		_plugin.connect("update_flow_result", _on_update_flow_result)
	elif OS.get_name() == "iOS":
		_http_request = HTTPRequest.new()
		_http_request.name = "UpdateGateHttp"
		_http_request.timeout = 10.0
		add_child(_http_request)
		_http_request.request_completed.connect(_on_ios_http_completed)

	# After the first frame, like the Flutter gate's post-frame callback.
	await get_tree().process_frame
	_check(true)


## Release build on Android with plugin present, or release build on iOS.
func _is_active() -> bool:
	if OS.is_debug_build():
		return false
	var os_name := OS.get_name()
	if os_name == "Android":
		return Engine.has_singleton(PLUGIN_NAME)
	if os_name == "iOS":
		return true
	return false


func is_blocked() -> bool:
	return _blocked


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _is_active():
		# Back from Play's/App Store's update screen (cancelled) or from anywhere else: ask again.
		_starting = false
		_check(not _blocked)


func _process(_delta: float) -> void:
	# A game script may unpause on its own (resume handlers, closing a popup); keep the
	# game frozen for as long as the gate is up.
	if _blocked and not get_tree().paused:
		get_tree().paused = true


func _input(event: InputEvent) -> void:
	if _blocked and event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()


func _check(start_update: bool) -> void:
	if _checking:
		return
	_start_after_check = start_update
	if OS.get_name() == "Android":
		if _plugin == null:
			return
		_checking = true
		_plugin.call("checkForUpdate")
	elif OS.get_name() == "iOS":
		if _http_request == null:
			return
		var bundle_id := _get_bundle_id()
		if bundle_id.is_empty():
			push_warning("[UpdateGate] bundle_id not found for iOS update check")
			return
		_checking = true
		var url := "https://itunes.apple.com/lookup?bundleId=" + bundle_id
		var err := _http_request.request(url)
		if err != OK:
			push_warning("[UpdateGate] iOS update check request failed: %d" % err)
			_checking = false


func _get_bundle_id() -> String:
	var id: String = ""
	if ProjectSettings.has_setting("android/modules/package/unique_name"):
		id = str(ProjectSettings.get_setting("android/modules/package/unique_name"))
	if id.is_empty() and ProjectSettings.has_setting("modules/package/unique_name"):
		id = str(ProjectSettings.get_setting("modules/package/unique_name"))
	if id.is_empty() and ProjectSettings.has_setting("application/config/ios/bundle_identifier"):
		id = str(ProjectSettings.get_setting("application/config/ios/bundle_identifier"))
	if id.is_empty() and ProjectSettings.has_setting("package/unique_name"):
		id = str(ProjectSettings.get_setting("package/unique_name"))
	return id.strip_edges()


static func is_store_version_newer(current: String, store: String) -> bool:
	var clean_current := current.strip_edges().split("+")[0]
	var clean_store := store.strip_edges().split("+")[0]
	var regex := RegEx.new()
	if regex.compile("^\d+(\.\d+)*$") != OK:
		return false
	if regex.search(clean_current) == null or regex.search(clean_store) == null:
		return false
	var c_parts := clean_current.split(".")
	var s_parts := clean_store.split(".")
	var max_len := maxi(c_parts.size(), s_parts.size())
	for i in range(max_len):
		var c := c_parts[i].to_int() if i < c_parts.size() else 0
		var s := s_parts[i].to_int() if i < s_parts.size() else 0
		if s > c:
			return true
		if s < c:
			return false
	return false


func _on_ios_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_checking = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[UpdateGate] iOS lookup failed: result=%d code=%d" % [result, response_code])
		return
	var text := body.get_string_from_utf8()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[UpdateGate] iOS lookup JSON parse error: %d" % err)
		return
	var data: Variant = json.data
	if not (data is Dictionary):
		return
	var results: Variant = (data as Dictionary).get("results", [])
	if not (results is Array) or (results as Array).is_empty():
		return
	var first: Variant = (results as Array)[0]
	if not (first is Dictionary):
		return
	var first_dict := first as Dictionary
	var store_version := str(first_dict.get("version", ""))
	var track_view_url := str(first_dict.get("trackViewUrl", ""))
	if track_view_url.is_empty() and first_dict.has("trackId"):
		track_view_url = "https://apps.apple.com/app/id" + str(first_dict.get("trackId"))
	_app_store_url = track_view_url
	var current_version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var needed := is_store_version_newer(current_version, store_version)
	print("[UpdateGate] iOS check: current=%s store=%s needed=%s" % [current_version, store_version, needed])
	_set_blocked(needed)
	if needed and _start_after_check:
		_start_update()


func _on_update_check_completed(update_available: bool, availability: int, immediate_allowed: bool, available_version_code: int) -> void:
	_checking = false
	_availability = availability
	_immediate_allowed = immediate_allowed
	print("[UpdateGate] Android check: update_available=%s availability=%d immediate_allowed=%s available_version=%d" % [update_available, availability, immediate_allowed, available_version_code])
	_set_blocked(update_available)
	if update_available and _start_after_check:
		_start_update()


func _on_update_check_failed(message: String) -> void:
	_checking = false
	# Play could not be asked: nothing changes. The player keeps playing unless an update
	# was already confirmed, in which case the Update button still works from the last answer.
	push_warning("[UpdateGate] Android check failed: %s" % message)
	if _blocked and _start_after_check:
		_start_update()


func _start_update() -> void:
	if _starting:
		return
	if OS.get_name() == "Android":
		if _immediate_allowed or _availability == AVAILABILITY_IN_PROGRESS:
			_starting = true
			_plugin.call("startImmediateUpdate")
		else:
			_open_store()
	elif OS.get_name() == "iOS":
		_open_store()


func _on_update_flow_result(result_code: int, message: String) -> void:
	_starting = false
	print("[UpdateGate] immediate update flow result: %d %s" % [result_code, message])
	if result_code == RESULT_OK:
		return # Play restarts the game into the new version.
	if result_code == RESULT_NOT_STARTED and _blocked:
		# Play would not run the immediate flow: send the player to the store page instead.
		_open_store()
	# Cancelled or failed: the blocking page stays up.


func _open_store() -> void:
	if OS.get_name() == "Android":
		if _plugin != null:
			_plugin.call("openStore")
	elif OS.get_name() == "iOS":
		if not _app_store_url.is_empty():
			OS.shell_open(_app_store_url)


func _on_update_pressed() -> void:
	# Re-read store first: the answer may be stale after a cancelled flow.
	if _checking:
		_start_after_check = true
		return
	if OS.get_name() == "iOS" and not _app_store_url.is_empty():
		OS.shell_open(_app_store_url)
	_check(true)


func _set_blocked(blocked: bool) -> void:
	if blocked == _blocked:
		return
	_blocked = blocked
	if _plugin != null:
		_plugin.call("setBackBlocked", blocked)
	var tree := get_tree()
	if blocked:
		_paused_before = tree.paused
		tree.paused = true
		_show_overlay()
	else:
		_hide_overlay()
		tree.paused = _paused_before


func _show_overlay() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "UpdateGateLayer"
	_layer.layer = OVERLAY_LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var root := Control.new()
	root.name = "UpdateGate"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = COLOR_BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 96)
	margin.add_theme_constant_override("margin_bottom", 96)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var title := Label.new()
	title.name = "Title"
	var title_text := tr("UPDATE_GATE_TITLE")
	if title_text == "UPDATE_GATE_TITLE":
		title_text = "Update required"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	column.add_child(title)

	var body := Label.new()
	body.name = "Body"
	var body_text := tr("UPDATE_GATE_BODY")
	if body_text == "UPDATE_GATE_BODY":
		body_text = "A new version is available. Please update to keep playing."
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 28)
	body.add_theme_color_override("font_color", COLOR_BODY)
	column.add_child(body)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	var button := Button.new()
	button.name = "UpdateButton"
	var button_text := tr("UPDATE_GATE_BUTTON")
	if button_text == "UPDATE_GATE_BUTTON":
		button_text = "Update"
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 34)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, COLOR_BUTTON_TEXT)
	button.add_theme_stylebox_override("normal", _button_style(COLOR_BUTTON))
	button.add_theme_stylebox_override("hover", _button_style(COLOR_BUTTON))
	button.add_theme_stylebox_override("focus", _button_style(COLOR_BUTTON))
	button.add_theme_stylebox_override("pressed", _button_style(COLOR_BUTTON_PRESSED))
	button.pressed.connect(_on_update_pressed)
	column.add_child(button)


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	style.set_content_margin_all(16)
	return style


func _hide_overlay() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
