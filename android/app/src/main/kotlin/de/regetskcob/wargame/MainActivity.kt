package de.regetskcob.wargame

import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  private var gamepads: GamepadPlugin? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    gamepads = GamepadPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
  }

  // Gamepad input reaches the activity as events, not as state to poll: the
  // plugin keeps the state, and the events go on to Flutter's focus too.
  override fun dispatchKeyEvent(event: KeyEvent): Boolean {
    if (GamepadPlugin.isGamepad(event.device)) {
      gamepads?.onKey(event)
    }
    return super.dispatchKeyEvent(event)
  }

  override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
    if (GamepadPlugin.isGamepad(event.device)) {
      gamepads?.onMotion(event)
    }
    return super.dispatchGenericMotionEvent(event)
  }
}
