/// Conditional export: platform-specific playback for saved live videos.
library;

export 'pose_video_source_stub.dart'
    if (dart.library.js_interop) 'pose_video_source_web.dart';
