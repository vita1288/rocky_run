import 'dart:js_interop';

// `window.rrSfx` is defined in web/index.html.
@JS('rrSfx')
external JSObject? get _engine;

@JS('rrSfx.load')
external void _load(JSString names);

@JS('rrSfx.play')
external JSBoolean _play(JSString name, JSNumber volume);

bool webSfxAvailable() => _engine != null;

void webSfxLoad(List<String> names) {
  if (_engine == null) return;
  _load(names.join(',').toJS);
}

/// Returns false if the sound is not decoded yet (caller falls back).
bool webSfxPlay(String name, double volume) {
  if (_engine == null) return false;
  return _play(name.toJS, volume.toJS).toDart;
}
