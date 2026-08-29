import '../core/difficulty.dart';

/// The one value the music layer borrows from the difficulty curve.
///
/// Named here rather than imported ad hoc so it is obvious that the crossfade
/// follows the curve, and that changing the curve moves the music with it.
const int endlessPhaseTwoEnd = EndlessCurve.phaseTwoEnd;
