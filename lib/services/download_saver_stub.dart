/// Web fallback: the browser download in `ExportService.saveBytes` handles
/// this case, so there is no native Downloads API to call.
Future<String?> saveToAndroidDownloads(
  String name,
  List<int> bytes,
  String mime,
) async => null;
