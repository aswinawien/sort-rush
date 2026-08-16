import 'package:flutter/material.dart';

/// Lays a column out to fill the viewport when it fits, and scrolls when it
/// does not.
///
/// `docs/design-system.md` requires system text scaling to be respected
/// outside the game canvas. A plain `Column` with `Spacer`s honours the
/// designed composition at normal text sizes but overflows once the type
/// grows — and an overflowing column does not clip politely, it pushes the
/// primary action off the bottom of the screen where no amount of scrolling
/// reaches it.
///
/// The `IntrinsicHeight` plus `minHeight` pairing is what keeps both
/// behaviours: when the natural content height is under the viewport the
/// column is stretched to the viewport and the spacers distribute the slack
/// exactly as before; when it is over, the column takes its natural height,
/// the spacers collapse to nothing, and the scroll view takes over.
///
/// `ResultsScreen` solved the same problem with a plain scroll view because
/// its actions are pinned outside the scrolling area. This widget is for the
/// screens whose actions live inside the composition.
class FitOrScroll extends StatelessWidget {
  const FitOrScroll({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
