/// Stub: open URL on platforms that don't have dart:html (e.g. mobile).
/// Use url_launcher package on iOS/Android, or this no-op on unknown.
Future<void> openUrl(String url) async {
  // No-op; on mobile you would use url_launcher here
}
