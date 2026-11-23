/// No-op on native platforms; ML Kit does not use MediaStreamTrackProcessor.
abstract final class WebCameraCompat {
  static void disableMediaStreamTrackProcessor() {}
}
