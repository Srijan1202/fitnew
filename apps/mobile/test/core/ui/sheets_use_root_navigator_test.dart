import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Beta 6.0: the emulator check found the water sheet and Community's sheets
/// opening inside their tab, under the floating tab bar, which covered the
/// sheet's bottom and stayed undimmed. Every bottom sheet opens on the root
/// navigator, above the tab bar.
void main() {
  test('every showModalBottomSheet sets useRootNavigator: true', () {
    final missing = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final m in RegExp(r'showModalBottomSheet\s*(<[^>]*>)?\s*\(')
          .allMatches(src)) {
        // The call's own arguments: up to the builder, which comes after them.
        final end = src.indexOf('builder:', m.end);
        final args = src.substring(m.end, end < 0 ? src.length : end);
        if (!args.contains('useRootNavigator: true')) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          missing.add('${f.path.replaceAll(r'\', '/')}:$line');
        }
      }
    }
    expect(missing, isEmpty);
  });
}
