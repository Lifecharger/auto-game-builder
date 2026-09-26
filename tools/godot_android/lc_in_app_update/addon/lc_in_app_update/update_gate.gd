extends Node

## Forced update gate (UpdateGate autoload). Same behaviour as the Flutter apps'
## lifecharger_update_gate.dart.
##
## On launch (after the first frame) and every return to the foreground it asks Google Play,
## through the LcInAppUpdate Android plugin, whether a newer version exists. If one does,
## Play's own IMMEDIATE update screen runs; if the player backs out of it or it fails, a
## full-screen "Update required" page covers the game with a single Update button (the
## immediate flow again, or the Play Store page when Play does not allow it). While it is
## up the game is paused and Back does nothing. There is no way past it but updating.
##
## When the check cannot be made (offline, not installed from Play, debug build, desktop,
## editor, plugin missing) the game runs normally: a player is never locked out because
## Play could not be asked.
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
	_plugin = Engine.get_singleton(PLUGIN_NAME)
	_plugin.connect("update_check_completed", _on_update_check_completed)
	_plugin.connect("update_check_failed", _on_update_check_failed)
	_plugin.connect("update_flow_result", _on_update_flow_result)
	# After the first frame, like the Flutter gate's post-frame callback.
	await get_tree().process_frame
	_check(true)


## Only a release build running on Android with the plugin present asks Play.
func _is_active() -> bool:
	return OS.get_name() == "Android" and not OS.is_debug_build() and Engine.has_singleton(PLUGIN_NAME)


func is_blocked() -> bool:
	return _blocked


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _plugin != null:
		# Back from Play's update screen (cancelled) or from anywhere else: ask again.
		# Our activity is only resumed once Play's flow is gone, so nothing is starting now.
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
	if _plugin == null or _checking:
		return
	_checking = true
	_start_after_check = start_update
	_plugin.call("checkForUpdate")


func _on_update_check_completed(update_available: bool, availability: int, immediate_allowed: bool, available_version_code: int) -> void:
	_checking = false
	_availability = availability
	_immediate_allowed = immediate_allowed
	print("[UpdateGate] check: update_available=%s availability=%d immediate_allowed=%s available_version=%d" % [update_available, availability, immediate_allowed, available_version_code])
	_set_blocked(update_available)
	if update_available and _start_after_check:
		_start_update()


func _on_update_check_failed(message: String) -> void:
	_checking = false
	# Play could not be asked: nothing changes. The player keeps playing unless an update
	# was already confirmed, in which case the Update button still works from the last answer.
	push_warning("[UpdateGate] update check failed: %s" % message)
	if _blocked and _start_after_check:
		_start_update()


func _start_update() -> void:
	if _starting:
		return
	if _immediate_allowed or _availability == AVAILABILITY_IN_PROGRESS:
		_starting = true
		_plugin.call("startImmediateUpdate")
	else:
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
	if _plugin != null:
		_plugin.call("openStore")


func _on_update_pressed() -> void:
	# Re-read Play first: the answer may be stale after a cancelled flow.
	if _checking:
		_start_after_check = true
		return
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
	title.text = "UPDATE_GATE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	column.add_child(title)

	var body := Label.new()
	body.name = "Body"
	body.text = "UPDATE_GATE_BODY"
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
	button.text = "UPDATE_GATE_BUTTON"
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
