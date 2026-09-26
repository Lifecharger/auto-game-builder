package com.lifecharger.inappupdate

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Godot Android plugin (v2) around Play Core In-App Updates, used for the forced update gate.
 *
 * GDScript singleton: LcInAppUpdate
 *
 * Methods
 *   checkForUpdate()            -> update_check_completed / update_check_failed
 *   startImmediateUpdate()      -> update_flow_result (re-reads Play first; an AppUpdateInfo is single use)
 *   openStore()                 -> opens market://details?id=<package>, falls back to the https page
 *   setBackBlocked(blocked)     -> while true the Android back button / gesture does nothing
 *   getPackageName()
 *
 * Signals
 *   update_check_completed(update_available: bool, availability: int, immediate_allowed: bool, available_version_code: int)
 *       update_available is true for UPDATE_AVAILABLE and DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS.
 *   update_check_failed(message: String)
 *       Play could not be asked (offline, not installed from Play, ...). The game keeps running.
 *   update_flow_result(result_code: int, message: String)
 *       -1 RESULT_OK, 0 RESULT_CANCELED, 1 RESULT_IN_APP_UPDATE_FAILED, 2 RESULT_NOT_STARTED (this plugin).
 */
class LcInAppUpdatePlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "LcInAppUpdate"
        private const val REQUEST_CODE_IMMEDIATE = 0x4C55 // "LU"
        const val RESULT_NOT_STARTED = 2

        private const val SIGNAL_CHECK_COMPLETED = "update_check_completed"
        private const val SIGNAL_CHECK_FAILED = "update_check_failed"
        private const val SIGNAL_FLOW_RESULT = "update_flow_result"
    }

    private var appUpdateManager: AppUpdateManager? = null

    @Volatile
    private var backBlocked = false
    private var backCallback: OnBackPressedCallback? = null

    override fun getPluginName(): String = "LcInAppUpdate"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo(
            SIGNAL_CHECK_COMPLETED,
            java.lang.Boolean::class.java,
            java.lang.Integer::class.java,
            java.lang.Boolean::class.java,
            java.lang.Integer::class.java,
        ),
        SignalInfo(SIGNAL_CHECK_FAILED, String::class.java),
        SignalInfo(SIGNAL_FLOW_RESULT, java.lang.Integer::class.java, String::class.java),
    )

    private fun manager(): AppUpdateManager? {
        appUpdateManager?.let { return it }
        val act: Activity = activity ?: return null
        return AppUpdateManagerFactory.create(act.applicationContext).also { appUpdateManager = it }
    }

    private fun isUpdateAvailable(info: AppUpdateInfo): Boolean {
        val availability = info.updateAvailability()
        return availability == UpdateAvailability.UPDATE_AVAILABLE ||
            availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
    }

    private fun describe(e: Throwable): String = e.message ?: e.javaClass.simpleName

    @UsedByGodot
    fun checkForUpdate() {
        val mgr = manager()
        if (mgr == null) {
            emitSignal(SIGNAL_CHECK_FAILED, "no activity")
            return
        }
        try {
            mgr.appUpdateInfo
                .addOnSuccessListener { info ->
                    val availability = info.updateAvailability()
                    val immediateAllowed = info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
                    Log.i(TAG, "check: availability=$availability immediateAllowed=$immediateAllowed available=${info.availableVersionCode()}")
                    emitSignal(
                        SIGNAL_CHECK_COMPLETED,
                        isUpdateAvailable(info),
                        availability,
                        immediateAllowed,
                        info.availableVersionCode(),
                    )
                }
                .addOnFailureListener { e ->
                    Log.w(TAG, "check failed: ${describe(e)}")
                    emitSignal(SIGNAL_CHECK_FAILED, describe(e))
                }
        } catch (e: Exception) {
            Log.w(TAG, "check threw: ${describe(e)}")
            emitSignal(SIGNAL_CHECK_FAILED, describe(e))
        }
    }

    @UsedByGodot
    fun startImmediateUpdate() {
        val act = activity
        val mgr = manager()
        if (act == null || mgr == null) {
            emitSignal(SIGNAL_FLOW_RESULT, RESULT_NOT_STARTED, "no activity")
            return
        }
        try {
            mgr.appUpdateInfo
                .addOnSuccessListener { info ->
                    val availability = info.updateAvailability()
                    val canStart = availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS ||
                        (availability == UpdateAvailability.UPDATE_AVAILABLE && info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE))
                    if (!canStart) {
                        emitSignal(SIGNAL_FLOW_RESULT, RESULT_NOT_STARTED, "immediate update not allowed (availability=$availability)")
                        return@addOnSuccessListener
                    }
                    act.runOnUiThread {
                        try {
                            val started = mgr.startUpdateFlowForResult(
                                info,
                                act,
                                AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
                                REQUEST_CODE_IMMEDIATE,
                            )
                            if (!started) {
                                emitSignal(SIGNAL_FLOW_RESULT, RESULT_NOT_STARTED, "update flow not started")
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "startUpdateFlowForResult threw: ${describe(e)}")
                            emitSignal(SIGNAL_FLOW_RESULT, RESULT_NOT_STARTED, describe(e))
                        }
                    }
                }
                .addOnFailureListener { e ->
                    Log.w(TAG, "immediate: check failed: ${describe(e)}")
                    emitSignal(SIGNAL_FLOW_RESULT, RESULT_NOT_STARTED, describe(e))
                }
        } catch (e: Exception) {
            Log.w(TAG, "immediate threw: ${describe(e)}")
            emitSignal(SIGNAL_FLOW_RESULT, RESULT_NOT_STARTED, describe(e))
        }
    }

    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onMainActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CODE_IMMEDIATE) return
        // RESULT_OK normally never arrives: Play restarts the app into the new version.
        Log.i(TAG, "immediate update flow result: $resultCode")
        emitSignal(SIGNAL_FLOW_RESULT, resultCode, "")
    }

    @UsedByGodot
    fun openStore() {
        val act = activity ?: return
        val pkg = act.packageName
        act.runOnUiThread {
            try {
                act.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (e: ActivityNotFoundException) {
                Log.i(TAG, "no market app, opening the web store page")
                try {
                    act.startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$pkg"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                } catch (e2: ActivityNotFoundException) {
                    Log.e(TAG, "no activity can open the store page: ${describe(e2)}")
                }
            }
        }
    }

    @UsedByGodot
    fun getPackageName(): String = activity?.packageName ?: ""

    /**
     * While blocked, the back button and the back gesture do nothing. Two paths are covered:
     * the key event path (Godot.onBackPressed -> onMainBackPressed) and the AndroidX
     * OnBackPressedDispatcher (predictive back, targetSdk 36), where a callback added later
     * takes priority over the callback the host activity registered.
     */
    @UsedByGodot
    fun setBackBlocked(blocked: Boolean) {
        backBlocked = blocked
        val act = activity as? ComponentActivity ?: return
        act.runOnUiThread {
            var callback = backCallback
            if (callback == null) {
                if (!blocked) return@runOnUiThread
                callback = object : OnBackPressedCallback(true) {
                    override fun handleOnBackPressed() {
                        Log.i(TAG, "back ignored: update required")
                    }
                }
                act.onBackPressedDispatcher.addCallback(act, callback)
                backCallback = callback
            }
            callback.isEnabled = blocked
        }
    }

    override fun onMainBackPressed(): Boolean = backBlocked
}
