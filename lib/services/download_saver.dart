/// Platform-aware helper for saving export files where the user can find them.
///
/// On Android the file is written through `MediaStore.Downloads` so it appears
/// in the device's Downloads folder and is visible from any file manager.
/// Other platforms keep the existing app-documents fallback in `ExportService`.
library;

export 'download_saver_stub.dart' if (dart.library.io) 'download_saver_io.dart';
