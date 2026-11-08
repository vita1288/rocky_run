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

@JS('rrOnVisibility')
external set _visibilityCallback(JSFunction? f);

/// Calls [cb] with `true` when the browser tab is hidden / minimised,
/// `false` when it is visible again.
void onPageVisibility(void Function(bool hidden) cb) {
  _visibilityCallback = ((JSBoolean hidden) => cb(hidden.toDart)).toJS;
}
