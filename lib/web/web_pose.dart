/// Conditional export: real MoveNet implementation on web, stub elsewhere.
library;

export 'web_pose_stub.dart' if (dart.library.js_interop) 'web_pose_web.dart';
