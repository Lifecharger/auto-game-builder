package com.lifecharger.appmanager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_manager/installed_apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledVersion" -> {
                        val packageName = call.arguments as? String
                        if (packageName.isNullOrEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            result.success(info.versionName)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    "getInstalledVersions" -> {
                        @Suppress("UNCHECKED_CAST")
                        val packageNames = call.arguments as? List<String> ?: emptyList()
                        val versions = mutableMapOf<String, String?>()
                        for (pkg in packageNames) {
                            try {
                                val info = packageManager.getPackageInfo(pkg, 0)
                                versions[pkg] = info.versionName
                            } catch (e: Exception) {
                                versions[pkg] = null
                            }
                        }
                        result.success(versions)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
