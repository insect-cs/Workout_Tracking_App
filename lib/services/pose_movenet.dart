/// Conditional export: bundled TFLite MoveNet on native, no-op elsewhere.
library;

export 'pose_movenet_native.dart'
    if (dart.library.js_interop) 'pose_movenet_stub.dart';
