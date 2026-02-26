/// Conditional export: uses dart:html on web, no-op stub on native.
export 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart';
