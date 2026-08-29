import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/machine_intensity.dart';
import '../../ui/theme.dart';
import '../belt_ground.dart';
import '../clutch_band.dart';
import '../package_painter.dart';
import '../sort_rush_game.dart';

/// Renders every package currently on the belt.
///
/// Packages are drawn straight from engine state rather than being mirrored
/// into one component each. Keeping a component per package would mean
/// reconciling two lifecycles every frame for no visual gain, and a desync
/// between them would be a bug the player sees.
class BeltComponent extends PositionComponent
    with HasGameReference<SortRushGame> {
  static const double packageSize = 56;

  static final Paint _scanPaint = Paint()..strokeWidth = 1;

  /// Quiet wall fill. Stays put when the line flips to `warn` so the band
  /// does not strobe (design system forbids rapid flashing).
  static final Paint _bandFill = Paint()
    ..color = Tokens.mute.withValues(alpha: 0.18);

  static final Paint _bandEdge = Paint()
    ..color = Tokens.acid.withValues(alpha: 0.28)
    ..strokeWidth = 1;

  static final Paint _lanePaint = Paint()
    ..color = Tokens.mute.withValues(alpha: BeltGround.laneAlpha);

  static final Paint _slatPaint = Paint()
    ..color = Tokens.mute.withValues(alpha: BeltGround.slatAlpha)
    ..strokeWidth = 1;

  /// MAXXXX rules, misregistered by [_maxxxxSplit]. Static: printed while the
  /// state holds, never animated. A pulsing wall here is the CRT-screensaver
  /// failure rejected on 2026-08-17, and rapid flashing is forbidden outright.
  static final Paint _maxxxxCyan = Paint()
    ..color = Tokens.hues[0].withValues(alpha: 0.55)
    ..strokeWidth = 2;

  static final Paint _maxxxxMagenta = Paint()
    ..color = Tokens.hues[1].withValues(alpha: 0.55)
    ..strokeWidth = 2;

  static const double _maxxxxSplit = 3;

  static final Paint _railPaint = Paint()
    ..color = Tokens.mute.withValues(alpha: BeltGround.railAlpha)
    ..strokeWidth = 1;

  /// The belt ground, recorded once per size.
  ///
  /// Rails and slats are identical every frame, and *Performance is measured
  /// before it is optimised* (2026-08-16) found the chutes burning 41% of the
  /// frame doing exactly this before they were cached. Same fix, same reason:
  /// see `BinComponent._buildIdentity`.
  Picture? _ground;
  double _groundWidth = 0;
  double _groundHeight = 0;

  @override
  void render(Canvas canvas) {
    // Before the reduce-motion gate, deliberately. The ground never moves, so
    // there is nothing here for reduce-motion to spare anyone — and dropping
    // it would leave that player the blank field this slice exists to fix.
    _paintGround(canvas);

    final engine = game.engine;
    if (!game.reduceMotion) {
      final opacity = MachineIntensity.scanlineOpacity(
        engine.pressureProgress,
        engine.score.comboTier,
      );
      if (opacity > 0) {
        _scanPaint.color = Tokens.paper.withValues(alpha: opacity);
        for (var y = 0.0; y < size.y; y += 4) {
          canvas.drawLine(Offset(0, y), Offset(size.x, y), _scanPaint);
        }
      }
      _paintClutchBand(canvas);
      _paintMaxxxx(canvas);
    }

    final front = engine.frontMost;

    for (final package in engine.active) {
      // `lane` is zero for a solo package, so anything outside a cluster
      // still travels dead centre exactly as it always did.
      final centre = Offset(
        size.x / 2 + package.lane * BeltGround.laneStep(packageSize),
        package.progress * size.y,
      );
      PackagePainter.paintPackage(
        canvas,
        Rect.fromCenter(
          center: centre,
          width: packageSize,
          height: packageSize,
        ),
        package.spec,
        isActive: identical(package, front),
        isUnstable: package.isUnstable,
        labelVisible: engine.labelVisible(package),
        hazardous: engine.hazardousCargo,
      );
    }
  }

  /// Lane, rails and slats. Static, cached, and drawn behind everything.
  void _paintGround(Canvas canvas) {
    if (_ground == null ||
        _groundWidth != size.x ||
        _groundHeight != size.y) {
      _ground?.dispose();
      _ground = _buildGround(size.x, size.y);
      _groundWidth = size.x;
      _groundHeight = size.y;
    }
    canvas.drawPicture(_ground!);
  }

  Picture _buildGround(double width, double height) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final lane = BeltGround.laneWidth(width, packageSize: packageSize);
    final left = BeltGround.laneLeft(width, packageSize: packageSize);
    final right = left + lane;

    canvas.drawRect(Rect.fromLTWH(left, 0, lane, height), _lanePaint);

    // Slats first, so a rail is never overdrawn at its own ends.
    for (var y = BeltGround.slatSpacing;
        y < height;
        y += BeltGround.slatSpacing) {
      canvas.drawLine(Offset(left, y), Offset(right, y), _slatPaint);
    }

    canvas.drawLine(Offset(left, 0), Offset(left, height), _railPaint);
    canvas.drawLine(Offset(right, 0), Offset(right, height), _railPaint);

    return recorder.endRecording();
  }

  @override
  void onRemove() {
    _ground?.dispose();
    _ground = null;
    super.onRemove();
  }

  /// The MAXXXX wall: two misregistered rules top and bottom.
  ///
  /// Wall only. Nothing here touches a package, a chute, or the lane a package
  /// is read in — §5.2 withholds decoration from those, and MAXXXX arrives
  /// exactly when the player is most invested, so obscuring the read at that
  /// moment would turn the reward into a punishment.
  void _paintMaxxxx(Canvas canvas) {
    if (!game.engine.score.isMaxxxx) {
      return;
    }
    for (final y in [1.0, size.y - 1]) {
      canvas.drawLine(
        Offset(0, y - _maxxxxSplit),
        Offset(size.x, y - _maxxxxSplit),
        _maxxxxCyan,
      );
      canvas.drawLine(
        Offset(0, y + _maxxxxSplit),
        Offset(size.x, y + _maxxxxSplit),
        _maxxxxMagenta,
      );
    }
  }

  /// Wall, not package: a mute/acid strip sitting on the sort line. Paint
  /// only — this is not a tap target. Reduce-motion skips the call.
  void _paintClutchBand(Canvas canvas) {
    final engine = game.engine;
    final readWindow = clutchBandReadWindow(
      liveReadWindow: engine.frontMost?.readWindow,
      tuningReadWindow: engine.tuning.readWindow,
    );
    final height = clutchBandHeight(size.y, readWindow);
    if (height <= 0) {
      return;
    }
    final top = size.y - height;
    canvas.drawRect(Rect.fromLTWH(0, top, size.x, height), _bandFill);
    canvas.drawLine(Offset(0, top), Offset(size.x, top), _bandEdge);
  }
}
