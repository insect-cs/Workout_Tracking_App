/// Conditional export: disables the browser API that leaks VideoFrames on web.
library;

export 'web_camera_compat_stub.dart'
    if (dart.library.js_interop) 'web_camera_compat_web.dart';
