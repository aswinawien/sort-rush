import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the load-bearing architectural decision: the gameplay core must stay
/// engine-free.
///
/// If this fails, the unit-test layer stops being possible without a game loop
/// or a widget tree, and hidden coupling has already started. Fix the import
/// rather than relaxing this test.
void main() {
  test('lib/core imports neither Flame nor Flutter', () {
    final directory = Directory('lib/core');
    expect(
      directory.existsSync(),
      isTrue,
      reason: 'lib/core is missing; run this from the package root',
    );

    final offenders = <String>[];
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains('package:flame') ||
          source.contains('package:flutter')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'engine imports leaked into the pure core: $offenders',
    );
  });

  test('lib/core does not reach into the presentation layers', () {
    final directory = Directory('lib/core');
    final offenders = <String>[];
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains("'../game/") || source.contains("'../ui/")) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: 'core depends upwards: $offenders');
  });
}
