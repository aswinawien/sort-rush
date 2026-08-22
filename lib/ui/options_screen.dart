import 'package:flutter/material.dart';

import 'audio_scope.dart';
import 'theme.dart';
import 'visual_style.dart';
import 'widgets/fit_or_scroll.dart';
import 'widgets/scan_lines.dart';

/// Settings, as a depot terminal page rather than a system dialog.
///
/// Selection is never carried by colour alone: every chosen option is marked
/// with a filled bullet and an inverted label, so the screen is readable with
/// all hues rendered as the same grey — the same guarantee the belt gives.
class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = VisualProfile.of(context);
    final audio = AudioScope.maybeOf(context);
    final visual = VisualStyleScope.maybeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ScanLines(opacity: profile.neon ? 0.10 : 0.05),
          ),
          SafeArea(
            child: FitOrScroll(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  Text('DEPOT 7 · TERMINAL', style: Tokens.label),
                  const SizedBox(height: 6),
                  Text(
                    'OPTIONS',
                    style: Tokens.display.copyWith(
                      color: Tokens.paper,
                      fontSize: 38,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Group(
                    title: 'SOUND',
                    children: [
                      _Choice(
                        key: const Key('sound-on'),
                        label: 'ON',
                        selected: !(audio?.muted ?? false),
                        onTap: () => audio?.setMuted(false),
                      ),
                      _Choice(
                        key: const Key('sound-off'),
                        label: 'OFF',
                        selected: audio?.muted ?? false,
                        onTap: () => audio?.setMuted(true),
                      ),
                    ],
                  ),
                  _Group(
                    title: 'VISUAL STYLE',
                    children: [
                      _Choice(
                        key: const Key('style-standard'),
                        label: 'STANDARD',
                        note: 'Clear factory terminal',
                        selected: !(visual?.isNeon ?? false),
                        onTap: () => visual?.set(VisualStyle.standard),
                      ),
                      _Choice(
                        key: const Key('style-neon'),
                        label: 'IMMERSIVE NEON',
                        note: 'Full CRT glow and neon shift atmosphere',
                        selected: visual?.isNeon ?? false,
                        onTap: () => visual?.set(VisualStyle.immersiveNeon),
                      ),
                    ],
                  ),
                  _Group(
                    title: 'REDUCE MOTION',
                    children: [
                      _Choice(
                        key: const Key('motion-off'),
                        label: 'OFF',
                        selected: !(visual?.reduceMotion ?? false),
                        onTap: () => visual?.setReduceMotion(false),
                      ),
                      _Choice(
                        key: const Key('motion-on'),
                        label: 'ON',
                        note: 'Also forced on when the device asks for it',
                        selected: visual?.reduceMotion ?? false,
                        onTap: () => visual?.setReduceMotion(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ActionRow(
                    key: const Key('reset-settings'),
                    label: 'RESET SETTINGS',
                    onTap: () => visual?.reset(),
                  ),
                  const SizedBox(height: 28),
                  _BackRow(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Tokens.label),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 22),
      ],
    );
  }
}

/// One option row. Focusable, so keyboard and controller traversal reach it.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final String label;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neon = VisualProfile.of(context).neon;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A glyph, not a colour. This is the whole selected-state cue for
              // anyone who cannot separate acid from paper.
              Text(
                selected ? '■' : '□',
                style: Tokens.body.copyWith(
                  color: selected ? Tokens.acid : Tokens.mute,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Tokens.body.copyWith(
                        color: selected ? Tokens.acid : Tokens.paper,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                        letterSpacing: selected && neon ? 2.5 : 1,
                      ),
                    ),
                    if (note != null) Text(note!, style: Tokens.label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An action, not a choice. Deliberately carries no selection glyph — nothing
/// about it is ever "currently on".
class _ActionRow extends StatelessWidget {
  const _ActionRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.centerLeft,
        child: Text(label, style: Tokens.body.copyWith(color: Tokens.warn)),
      ),
    );
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Tokens.paper,
          foregroundColor: Tokens.ink,
          shape: const RoundedRectangleBorder(),
        ),
        child: Text(
          'BACK TO DEPOT',
          style: Tokens.body.copyWith(color: Tokens.ink, letterSpacing: 3),
        ),
      ),
    );
  }
}
