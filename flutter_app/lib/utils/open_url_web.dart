// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Opens [url] in a new browser tab (web only).
Future<void> openUrl(String url) async {
  html.window.open(url, '_blank');
}
