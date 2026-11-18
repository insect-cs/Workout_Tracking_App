/// Unsupported fallback used by non-web test/platform builds.
void downloadBytes(String name, List<int> bytes, String mime) {
  throw UnsupportedError('Browser downloads are only available on the web.');
}
