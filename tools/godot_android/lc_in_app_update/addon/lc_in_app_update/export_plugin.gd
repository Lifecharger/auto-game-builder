@tool
extends EditorPlugin

## Ships the LcInAppUpdate Android plugin (v2 AAR) with every Android export and adds
## the Play Core In-App Updates dependency to the gradle build.
##
## Source of the AAR: Auto Game Builder tools/godot_android/lc_in_app_update
## (rebuild + copy into the games with its build_and_install.py). The gameplay side is
## update_gate.gd, registered as the UpdateGate autoload.

var _export_plugin: LcInAppUpdateExportPlugin


func _enter_tree() -> void:
	_export_plugin = LcInAppUpdateExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null


class LcInAppUpdateExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "LcInAppUpdate"
	const ADDON_DIR := "lc_in_app_update"
	const APP_UPDATE_DEPENDENCY := "com.google.android.play:app-update:2.1.0"

	func _get_name() -> String:
		return PLUGIN_NAME

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray([ADDON_DIR + "/bin/debug/" + PLUGIN_NAME + "-debug.aar"])
		return PackedStringArray([ADDON_DIR + "/bin/release/" + PLUGIN_NAME + "-release.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([APP_UPDATE_DEPENDENCY])
