/// Tiny helpers for on-screen wording.
library;

import 'package:flutter/foundation.dart';

/// English / Bahasa Indonesia. Usage: tr('Jump', 'Lompat')
bool useIndonesian = false;

String tr(String en, String id) => useIndonesian ? id : en;

/// Phones and tablets (Android / iOS, also the web version opened on a phone).
/// They have no keyboard, so hints talk about taps and the Back button instead.
bool get isTouchDevice =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Pick the keyboard wording on PC, the touch wording on phones.
String ctl(String keyboard, String touch) => isTouchDevice ? touch : keyboard;
