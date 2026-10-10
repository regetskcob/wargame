package de.regetskcob.wargame

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.InputDevice
import android.view.MotionEvent
import android.view.ViewConfiguration
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The native half of `lib/src/watch/wear_crown.dart`: tells Dart whether
 * this is a Wear OS watch and whether its screen is round, streams the turns
 * of its crown or bezel, and taps the wrist.
 *
 * Flutter's Android embedding only takes motion events from pointing
 * devices, so the rotary encoder of a watch never reaches Dart on its own:
 * neither the menus scroll nor the tank steers. [MainActivity] hands those
 * events in here instead.
 */
class WearPlugin(private val activity: Activity, messenger: BinaryMessenger) :
  EventChannel.StreamHandler {

  private var sink: EventChannel.EventSink? = null

  init {
    MethodChannel(messenger, "wargame/wear").setMethodCallHandler { call, result ->
      when (call.method) {
        "info" -> result.success(
          mapOf(
            "watch" to activity.packageManager.hasSystemFeature(PackageManager.FEATURE_WATCH),
            // Most Wear OS watches are round, the screens then keep off the
            // corners that are not there.
            "round" to activity.resources.configuration.isScreenRound,
          ),
        )
        "vibrate" -> result.success(vibrate(call.arguments as? String))
        else -> result.notImplemented()
      }
    }
    EventChannel(messenger, "wargame/crown").setStreamHandler(this)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
  }

  override fun onCancel(arguments: Any?) {
    sink = null
  }

  /**
   * Takes a turn of the crown or bezel. Returns whether it was one, and
   * nobody else should see it; anything else goes on as before.
   */
  fun onMotion(event: MotionEvent): Boolean {
    val sink = sink ?: return false
    if (!event.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER) ||
      event.action != MotionEvent.ACTION_SCROLL
    ) {
      return false
    }
    // Turning clockwise reports a negative scroll; forward is positive in
    // Dart, the same as the Digital Crown. A bezel reports one per detent.
    val detents = -event.getAxisValue(MotionEvent.AXIS_SCROLL).toDouble()
    sink.success(mapOf("detents" to detents, "pixels" to detents * scrollFactor()))
    return true
  }

  /** How far the system scrolls a list for one detent, in logical pixels. */
  private fun scrollFactor(): Double {
    val density = activity.resources.displayMetrics.density
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      return ViewConfiguration.get(activity).scaledVerticalScrollFactor.toDouble() / density
    }
    return 64.0
  }

  /**
   * Taps the wrist for one of the moments of `lib/src/haptics.dart`, named
   * as flutter_watchos names them for the Apple Watch. Returns whether it
   * did: only the Wear OS build asks for the permission.
   */
  private fun vibrate(kind: String?): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      return false
    }
    val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      (activity.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
        .defaultVibrator
    } else {
      @Suppress("DEPRECATION")
      activity.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }
    if (!vibrator.hasVibrator()) {
      return false
    }
    val effect = when (kind) {
      // A heavy hit or a blast close by.
      "notification" -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK)
      "start" -> VibrationEffect.createOneShot(150, VibrationEffect.DEFAULT_AMPLITUDE)
      "success" -> VibrationEffect.createWaveform(longArrayOf(0, 60, 90, 60), -1)
      // The own tank destroyed or the round lost: long and unmistakable.
      "failure" -> VibrationEffect.createWaveform(longArrayOf(0, 120, 80, 300), -1)
      else -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
    }
    return try {
      vibrator.vibrate(effect)
      true
    } catch (e: SecurityException) {
      // The phone build has no VIBRATE permission.
      false
    }
  }
}
