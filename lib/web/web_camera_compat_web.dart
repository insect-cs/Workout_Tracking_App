import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Works around a Chromium/camera_web issue where an in-flight
/// MediaStreamTrackProcessor `VideoFrame` is never closed when the camera
/// stops, logging “A VideoFrame was garbage collected without being closed”.
///
/// Removing the API from `window` before `CameraController.initialize()` makes
/// camera_web fall back to drawing `<video>` frames to a canvas, which does not
/// allocate VideoFrames. Pose detection output is unchanged.
abstract final class WebCameraCompat {
  static bool _disabled = false;

  static void disableMediaStreamTrackProcessor() {
    if (_disabled) return;
    _disabled = true;
    try {
      web.window.delete('MediaStreamTrackProcessor'.toJS);
    } catch (_) {
      // Older browsers do not expose the API; nothing to disable.
    }
  }
}
