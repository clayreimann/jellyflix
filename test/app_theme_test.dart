import 'package:flutter_test/flutter_test.dart';
import 'package:jellyflix/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('light and dark themes', () {
    final light = buildAppTheme(Brightness.light);
    final dark = buildAppTheme(Brightness.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    // dark keeps the original pale green accent
    expect(dark.colorScheme.primary, const Color(0xFFDBEBC0));
    // light's accent is dark enough to read on its surface
    expect(light.colorScheme.primary.computeLuminance(),
        lessThan(light.colorScheme.surface.computeLuminance() / 3));
  });
}
