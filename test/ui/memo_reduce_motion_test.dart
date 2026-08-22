import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/ui/memo_board.dart';
import 'package:sort_rush/ui/theme.dart';
import 'package:sort_rush/ui/visual_style.dart';

import '../core/test_level.dart';

/// The memo board's `onClosed` in production calls `setState` on an ancestor
/// (`PlayScreen._closeShop`). The existing coverage passes a benign counter
/// callback, which cannot expose an out-of-build-phase violation — the same
/// blind spot that let the endless `LateInitializationError` ship.
void main() {
  testWidgets('closing under reduce motion does not rebuild during build',
      (tester) async {
    final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
    playToShop(engine);
    expect(engine.isShopping, isTrue);

    await tester.pumpWidget(
      VisualStyleScope(
        notifier: VisualStyleController(initial: VisualStyle.standard),
        child: MaterialApp(
          theme: buildTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: _Host(engine: engine),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('WALK ON'));
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'a zero-duration exit must not fire its callback mid-build');
  });
}

/// Mirrors `PlayScreen`: the close callback flips ancestor state.
class _Host extends StatefulWidget {
  const _Host({required this.engine});

  final RunEngine engine;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SizedBox.expand(),
          if (_open)
            MemoBoard(
              engine: widget.engine,
              onClosed: () => setState(() => _open = false),
            ),
        ],
      ),
    );
  }
}
