/// Conditional export: browser downloads on web, a throwing stub elsewhere.
library;

export 'file_downloader_stub.dart'
    if (dart.library.js_interop) 'file_downloader_web.dart';
