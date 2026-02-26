// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Opens [url] in a new browser tab using a direct synchronous JS call.
///
/// This is the only method that reliably works on iOS Safari:
/// - url_launcher uses window.open() **after** async operations (canLaunchUrl),
///   which causes Safari to lose the user-gesture context and silently block
///   the popup.
/// - Calling window.open() here directly, with no awaits before it, ensures
///   it runs synchronously within the user's tap gesture → Safari allows it.
void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}
