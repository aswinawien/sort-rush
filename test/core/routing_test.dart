import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/routing.dart';

void main() {
  group('ShapeRouting', () {
    final routing = ShapeRouting(const [
      PackageShape.circle,
      PackageShape.triangle,
      PackageShape.square,
    ]);

    test('maps each shape to its position in the bin order', () {
      expect(
        routing.binFor(
          const PackageSpec(shape: PackageShape.circle, colorIndex: 0),
        ),
        0,
      );
      expect(
        routing.binFor(
          const PackageSpec(shape: PackageShape.triangle, colorIndex: 2),
        ),
        1,
      );
      expect(
        routing.binFor(
          const PackageSpec(shape: PackageShape.square, colorIndex: 1),
        ),
        2,
      );
    });

    test('ignores hue entirely', () {
      for (var hue = 0; hue < 3; hue++) {
        expect(
          routing.binFor(
            PackageSpec(shape: PackageShape.circle, colorIndex: hue),
          ),
          0,
        );
      }
    });

    test('bins carry a silhouette and a letter, never a colour', () {
      expect(routing.bins, hasLength(3));
      expect(routing.bins[0].label, 'A');
      expect(routing.bins[1].label, 'B');
      expect(routing.bins[2].label, 'C');
      for (final bin in routing.bins) {
        expect(bin.shape, isNotNull);
        expect(bin.pattern, isNull);
      }
    });
  });

  group('ColorRouting', () {
    final routing = ColorRouting(const [0, 1]);

    test('maps each hue to its position in the bin order', () {
      expect(
        routing.binFor(
          const PackageSpec(shape: PackageShape.square, colorIndex: 0),
        ),
        0,
      );
      expect(
        routing.binFor(
          const PackageSpec(shape: PackageShape.circle, colorIndex: 1),
        ),
        1,
      );
    });

    test('ignores shape entirely — this is the attribute switch', () {
      for (final shape in PackageShape.values) {
        expect(routing.binFor(PackageSpec(shape: shape, colorIndex: 1)), 1);
      }
    });

    test('bins carry a pattern swatch, never a colour', () {
      for (final bin in routing.bins) {
        expect(bin.pattern, isNotNull);
        expect(bin.shape, isNull);
      }
    });
  });

  group('accessibility contract', () {
    test('every hue is permanently paired with a distinct pattern', () {
      final patterns = <FillPattern>{};
      for (var hue = 0; hue < 3; hue++) {
        final spec = PackageSpec(shape: PackageShape.circle, colorIndex: hue);
        patterns.add(spec.pattern);
      }
      // Three hues, three distinct patterns: the game stays playable when
      // every hue renders as the same grey.
      expect(patterns, hasLength(3));
    });
  });
}
