package de.regetskcob.wargame

import android.app.Activity
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.hardware.input.InputManager
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

/**
 * The native half of `lib/src/tv/tv_input.dart` on Android, the same as
 * `ios/Runner/GamepadPlugin.swift`: reads the game controllers and streams
 * what they hold to Dart whenever something changes.
 *
 * Android has no polling API like GameController, so [MainActivity] hands
 * every key and motion event of a gamepad in here and the state of each
 * controller is kept from them. Controllers are reported in the order they
 * came in: whoever picks one up steers with it right away, and two of them
 * play two on one screen.
 *
 * The events still go on to Flutter as well: the pad and A move the focus
 * in the menus as arrow keys and enter, only the round reads the state.
 *
 * On a television the remote counts as a controller too, last in the list
 * like the Siri Remote on the Apple TV: its d-pad drives, OK fires and
 * play/pause or menu set off items and special weapons.
 */
class GamepadPlugin(private val activity: Activity, messenger: BinaryMessenger) :
  EventChannel.StreamHandler, InputManager.InputDeviceListener {

  private class Pad {
    var lx = 0.0
    var ly = 0.0
    var rx = 0.0
    var ry = 0.0
    var hatX = 0.0
    var hatY = 0.0
    var l2 = false
    var r2 = false
    val keys = mutableSetOf<Int>()
  }

  private val inputs = activity.getSystemService(Context.INPUT_SERVICE) as InputManager
  private val pads = linkedMapOf<Int, Pad>()

  /** Android TV, Google TV or a Fire TV: the remote is always at hand. */
  val isTv: Boolean = isTelevision(activity)

  /** Keys held on the remote, whichever device of it sent them. */
  private val remote = mutableSetOf<Int>()
  private var sink: EventChannel.EventSink? = null
  private var last: Map<String, Any>? = null

  init {
    EventChannel(messenger, "wargame/gamepad").setStreamHandler(this)
    MethodChannel(messenger, "wargame/tv").setMethodCallHandler { call, result ->
      when (call.method) {
        "info" -> result.success(mapOf("tv" to isTv))
        "keepAwake" -> {
          // Controller input does not count as a touch, so the screen
          // would dim in the middle of a fight.
          if (call.arguments as? Boolean == true) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
          } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
          }
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
    inputs.registerInputDeviceListener(this, Handler(Looper.getMainLooper()))
    for (id in inputs.inputDeviceIds) {
      onInputDeviceAdded(id)
    }
    send()
  }

  override fun onCancel(arguments: Any?) {
    inputs.unregisterInputDeviceListener(this)
    sink = null
    last = null
  }

  override fun onInputDeviceAdded(deviceId: Int) {
    if (isGamepad(InputDevice.getDevice(deviceId)) && deviceId !in pads) {
      pads[deviceId] = Pad()
      send()
    }
  }

  override fun onInputDeviceRemoved(deviceId: Int) {
    if (pads.remove(deviceId) != null) {
      send()
    }
  }

  override fun onInputDeviceChanged(deviceId: Int) {}

  /** Takes a key of a gamepad. Always lets it on to Flutter. */
  fun onKey(event: KeyEvent) {
    val pad = padOf(event.device) ?: return
    when (event.action) {
      KeyEvent.ACTION_DOWN -> pad.keys.add(event.keyCode)
      KeyEvent.ACTION_UP -> pad.keys.remove(event.keyCode)
    }
    send()
  }

  /**
   * Takes a key of the remote of a television. Remotes come as several
   * devices (the d-pad, the media keys, HDMI-CEC), so they are kept as one.
   * Always lets it on to Flutter: the d-pad walks the menus, OK presses and
   * Back steps back.
   */
  fun onRemoteKey(event: KeyEvent) {
    if (!isTv || event.keyCode !in remoteKeys) {
      return
    }
    when (event.action) {
      KeyEvent.ACTION_DOWN -> remote.add(event.keyCode)
      KeyEvent.ACTION_UP -> remote.remove(event.keyCode)
    }
    send()
  }

  /** Takes the sticks, the triggers and the hat of a gamepad. */
  fun onMotion(event: MotionEvent) {
    if (event.source and InputDevice.SOURCE_JOYSTICK != InputDevice.SOURCE_JOYSTICK ||
      event.action != MotionEvent.ACTION_MOVE
    ) {
      return
    }
    val pad = padOf(event.device) ?: return
    val device = event.device
    pad.lx = axis(event, device, MotionEvent.AXIS_X)
    pad.ly = -axis(event, device, MotionEvent.AXIS_Y)
    pad.rx = axis(event, device, MotionEvent.AXIS_Z)
    pad.ry = -axis(event, device, MotionEvent.AXIS_RZ)
    pad.hatX = event.getAxisValue(MotionEvent.AXIS_HAT_X).toDouble()
    pad.hatY = event.getAxisValue(MotionEvent.AXIS_HAT_Y).toDouble()
    // Controllers name their triggers either way.
    pad.l2 = maxOf(
      event.getAxisValue(MotionEvent.AXIS_LTRIGGER),
      event.getAxisValue(MotionEvent.AXIS_BRAKE),
    ) > 0.5f
    pad.r2 = maxOf(
      event.getAxisValue(MotionEvent.AXIS_RTRIGGER),
      event.getAxisValue(MotionEvent.AXIS_GAS),
    ) > 0.5f
    send()
  }

  private fun padOf(device: InputDevice?): Pad? {
    if (device == null || !isGamepad(device)) {
      return null
    }
    return pads.getOrPut(device.id) { Pad() }
  }

  private fun send() {
    val state = mapOf(
      "pads" to pads.values.map(::read) + if (isTv) listOf(readRemote()) else emptyList(),
    )
    if (state == last) {
      return
    }
    last = state
    sink?.success(state)
  }

  /** What one controller holds right now, with y up as on iOS. */
  private fun read(pad: Pad): Map<String, Any> {
    fun key(code: Int) = code in pad.keys
    return mapOf(
      "kind" to "gamepad",
      "lx" to pad.lx,
      "ly" to pad.ly,
      "rx" to pad.rx,
      "ry" to pad.ry,
      "a" to key(KeyEvent.KEYCODE_BUTTON_A),
      "b" to key(KeyEvent.KEYCODE_BUTTON_B),
      "x" to key(KeyEvent.KEYCODE_BUTTON_X),
      "y" to key(KeyEvent.KEYCODE_BUTTON_Y),
      "l1" to key(KeyEvent.KEYCODE_BUTTON_L1),
      "r1" to key(KeyEvent.KEYCODE_BUTTON_R1),
      "l2" to (pad.l2 || key(KeyEvent.KEYCODE_BUTTON_L2)),
      "r2" to (pad.r2 || key(KeyEvent.KEYCODE_BUTTON_R2)),
      "up" to (pad.hatY < -0.5 || key(KeyEvent.KEYCODE_DPAD_UP)),
      "down" to (pad.hatY > 0.5 || key(KeyEvent.KEYCODE_DPAD_DOWN)),
      "left" to (pad.hatX < -0.5 || key(KeyEvent.KEYCODE_DPAD_LEFT)),
      "right" to (pad.hatX > 0.5 || key(KeyEvent.KEYCODE_DPAD_RIGHT)),
    )
  }

  /**
   * What the remote holds, in the shape of the Siri Remote: the d-pad as
   * the stick (diagonals with two keys), OK as a, play/pause or menu as x.
   */
  private fun readRemote(): Map<String, Any> {
    fun key(vararg codes: Int) = codes.any { it in remote }
    fun axis(minus: Int, plus: Int) =
      (if (plus in remote) 1.0 else 0.0) - (if (minus in remote) 1.0 else 0.0)
    return mapOf(
      "kind" to "remote",
      "lx" to axis(KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT),
      "ly" to axis(KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_DPAD_UP),
      "a" to key(KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER),
      // The Google TV Streamer's remote has no play/pause, so menu as well.
      "x" to key(
        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
        KeyEvent.KEYCODE_MEDIA_PLAY,
        KeyEvent.KEYCODE_MEDIA_PAUSE,
        KeyEvent.KEYCODE_MENU,
      ),
    )
  }

  companion object {
    private val remoteKeys = setOf(
      KeyEvent.KEYCODE_DPAD_UP,
      KeyEvent.KEYCODE_DPAD_DOWN,
      KeyEvent.KEYCODE_DPAD_LEFT,
      KeyEvent.KEYCODE_DPAD_RIGHT,
      KeyEvent.KEYCODE_DPAD_CENTER,
      KeyEvent.KEYCODE_ENTER,
      KeyEvent.KEYCODE_NUMPAD_ENTER,
      KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
      KeyEvent.KEYCODE_MEDIA_PLAY,
      KeyEvent.KEYCODE_MEDIA_PAUSE,
      KeyEvent.KEYCODE_MENU,
    )

    /**
     * Android TV and Google TV run in television mode and have leanback,
     * Fire OS names its own feature.
     */
    fun isTelevision(context: Context): Boolean {
      val modes = context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
      val packages = context.packageManager
      return modes.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
        packages.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
        packages.hasSystemFeature("amazon.hardware.fire_tv")
    }

    /** Gamepads with sticks, not the keyboards and remotes that also send keys. */
    fun isGamepad(device: InputDevice?): Boolean {
      if (device == null || device.isVirtual) {
        return false
      }
      val sources = device.sources
      return sources and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD &&
        sources and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK
    }

    /** An axis without the jitter of a stick at rest. */
    private fun axis(event: MotionEvent, device: InputDevice, axis: Int): Double {
      val range = device.getMotionRange(axis, event.source) ?: return 0.0
      val value = event.getAxisValue(axis)
      return if (abs(value) > range.flat) value.toDouble() else 0.0
    }
  }
}
