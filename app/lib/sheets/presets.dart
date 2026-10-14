import 'package:flutter/material.dart';

class Preset {
  const Preset(this.title, this.icon, {this.unit = '', this.hint = '', this.numeric = false});

  final String title;
  final IconData icon;

  /// The unit filled in when this is chosen under Other.
  final String unit;

  /// Placeholder for the value field under Other.
  final String hint;

  /// Whether the value is a number (charted under Measurements).
  final bool numeric;
}

const somethingElse = 'Something else';

const routinePresets = [
  Preset('Bath', Icons.bathtub_outlined),
  Preset('Nail trim', Icons.content_cut),
  Preset('Play time', Icons.toys_outlined),
  Preset('Story time', Icons.menu_book_outlined),
  Preset('Tummy time', Icons.child_care),
  Preset('Vitamin or probiotic', Icons.medication_outlined),
  Preset('Walk or outdoor time', Icons.park_outlined),
];

const otherPresets = [
  Preset('Weight', Icons.monitor_weight_outlined, unit: 'kg', hint: 'e.g. 4.2', numeric: true),
  Preset('Height', Icons.height, unit: 'cm', hint: 'e.g. 55', numeric: true),
  Preset('Head size', Icons.face_outlined, unit: 'cm', hint: 'Around the head', numeric: true),
  Preset('Temperature', Icons.thermostat, unit: '°C', hint: 'e.g. 37.2', numeric: true),
  Preset('Medicine', Icons.medication_liquid_outlined, hint: 'Which medicine and dose'),
  Preset('Vaccine', Icons.vaccines_outlined, hint: 'Which vaccine'),
  Preset('Baby first', Icons.star_outline, hint: 'What happened'),
];

/// The icon for a routine or measurement title, falling back to [fallback].
IconData presetIcon(String title, IconData fallback) {
  for (final p in [...routinePresets, ...otherPresets]) {
    if (p.title == title) return p.icon;
  }
  return fallback;
}
