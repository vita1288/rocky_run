/// Low-latency sound effects for the web (Web Audio API, see web/index.html).
/// On Android / Windows this is a no-op stub and audioplayers is used instead.
export 'web_sfx_stub.dart' if (dart.library.js_interop) 'web_sfx_web.dart';
