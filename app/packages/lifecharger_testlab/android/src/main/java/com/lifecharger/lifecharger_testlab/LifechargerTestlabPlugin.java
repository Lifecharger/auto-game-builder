package com.lifecharger.lifecharger_testlab;

import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.os.Build;
import android.provider.Settings;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Answers "isTestLab" on the "lifecharger/testlab" channel: true on Firebase Test Lab and Google Play
 * pre-launch-report devices, which set Settings.System "firebase.test.lab" to "true".
 *
 * Answers "lastExits" {since: epoch ms}: Android's own record of why this app's process ended
 * (ApplicationExitInfo, Android 11+; an empty list before that), newer than `since`, oldest first.
 */
public class LifechargerTestlabPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
  private MethodChannel channel;
  private Context context;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    context = binding.getApplicationContext();
    channel = new MethodChannel(binding.getBinaryMessenger(), "lifecharger/testlab");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if (call.method.equals("lastExits")) {
      Number since = call.argument("since");
      result.success(lastExits(since == null ? 0L : since.longValue()));
      return;
    }
    if (!call.method.equals("isTestLab")) {
      result.notImplemented();
      return;
    }
    String value = Settings.System.getString(context.getContentResolver(), "firebase.test.lab");
    result.success("true".equals(value));
  }

  private List<Map<String, Object>> lastExits(long since) {
    List<Map<String, Object>> out = new ArrayList<>();
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return out;
    ActivityManager manager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
    if (manager == null) return out;
    List<ApplicationExitInfo> exits = manager.getHistoricalProcessExitReasons(context.getPackageName(), 0, 16);
    // newest first from Android; the client wants them in the order they happened
    for (int i = exits.size() - 1; i >= 0; i--) {
      ApplicationExitInfo info = exits.get(i);
      if (info.getTimestamp() <= since) continue;
      // only the app's own main process (ad and WebView helper processes die all the time)
      if (!context.getPackageName().equals(info.getProcessName())) continue;
      Map<String, Object> row = new HashMap<>();
      row.put("reason", info.getReason());
      row.put("importance", info.getImportance());
      row.put("at", info.getTimestamp());
      row.put("rss", info.getRss());
      row.put("status", info.getStatus());
      String description = info.getDescription();
      if (description != null) row.put("desc", description);
      out.add(row);
    }
    return out;
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    channel = null;
    context = null;
  }
}
