import 'package:flutter/material.dart';

/// Rocky Run colour palette and shared text/button styles.
const kAccent = Color(0xFFE8714A); // Rocky orange
const kPeach = Color(0xFFFFB38F);
const kGold = Color(0xFFFFE066);
const kPanelDark = Color(0xF22B1712);
const kInk = Color(0xFF3A1E14); // dark brown text on light cards

/// Bold game-style label with a soft drop shadow.
Text gameLabel(String text, double size, {Color color = Colors.white}) {
  return Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.2,
      shadows: const [Shadow(color: Colors.black54, offset: Offset(2, 2))],
    ),
  );
}

final ButtonStyle outlinedOnDark = OutlinedButton.styleFrom(
  foregroundColor: Colors.white,
  side: const BorderSide(color: kPeach, width: 2),
);

final ButtonStyle accentFilled = FilledButton.styleFrom(
  backgroundColor: kAccent,
  foregroundColor: Colors.white,
);
