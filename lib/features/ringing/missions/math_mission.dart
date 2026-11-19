import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/gap.dart';

/// A single math problem the user must answer correctly to pass the
/// mission. `difficulty` widens the operand range and adds operations —
/// wired up to the alarm's `missionDifficulty` field (1-3).
class MathProblem {
  final String prompt;
  final int answer;

  const MathProblem._(this.prompt, this.answer);

  factory MathProblem.random(int difficulty) {
    final rnd = Random();
    final maxOperand = switch (difficulty) {
      1 => 12,
      2 => 50,
      _ => 200,
    };
    final a = rnd.nextInt(maxOperand) + 1;
    final b = rnd.nextInt(maxOperand) + 1;
    final useSubtraction = difficulty >= 2 && rnd.nextBool();
    if (useSubtraction) {
      final hi = max(a, b);
      final lo = min(a, b);
      return MathProblem._('$hi − $lo', hi - lo);
    }
    return MathProblem._('$a + $b', a + b);
  }
}

/// A sequence of [problemCount] problems, all of which must be answered
/// correctly before [onComplete] fires. Answering wrong doesn't penalize —
/// Alarmy-style missions aim to force alertness, not create failure states
/// that lock the user out of stopping the alarm.
///
/// Input is an on-screen keypad rather than the system keyboard: big targets
/// that are easy to hit half asleep, no layout jump when a keyboard opens,
/// and no autocorrect. A correct answer advances on its own; the check key
/// is there to get "wrong" feedback.
class MathMissionView extends StatefulWidget {
  const MathMissionView({
    super.key,
    required this.difficulty,
    required this.onComplete,
    this.onInteraction,
    this.problemCount = 3,
  });

  final int difficulty;
  final int problemCount;
  final VoidCallback onComplete;

  /// Called whenever the user presses a key, so the host can quiet the
  /// alarm while they work on the answer.
  final VoidCallback? onInteraction;

  @override
  State<MathMissionView> createState() => _MathMissionViewState();
}

class _MathMissionViewState extends State<MathMissionView>
    with SingleTickerProviderStateMixin {
  /// Answers top out at 400 (200 + 200), so four digits is plenty.
  static const _maxDigits = 4;

  late final List<MathProblem> _problems;
  late final AnimationController _shake;
  int _index = 0;
  String _entry = '';
  bool _wrong = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _problems = List.generate(
      widget.problemCount,
      (_) => MathProblem.random(widget.difficulty),
    );
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  MathProblem get _current => _problems[_index];

  void _digit(int d) {
    if (_done || _entry.length >= _maxDigits) return;
    if (_entry == '0') _entry = '';
    widget.onInteraction?.call();
    HapticFeedback.selectionClick();
    setState(() {
      _entry += '$d';
      _wrong = false;
    });
    if (int.parse(_entry) == _current.answer) _advance();
  }

  void _backspace() {
    if (_done || _entry.isEmpty) return;
    widget.onInteraction?.call();
    HapticFeedback.selectionClick();
    setState(() {
      _entry = _entry.substring(0, _entry.length - 1);
      _wrong = false;
    });
  }

  void _clear() {
    if (_done || _entry.isEmpty) return;
    widget.onInteraction?.call();
    HapticFeedback.mediumImpact();
    setState(() {
      _entry = '';
      _wrong = false;
    });
  }

  void _submit() {
    if (_done || _entry.isEmpty) return;
    widget.onInteraction?.call();
    if (int.parse(_entry) == _current.answer) {
      _advance();
      return;
    }
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    setState(() {
      _entry = '';
      _wrong = true;
    });
  }

  void _advance() {
    if (_index == _problems.length - 1) {
      setState(() => _done = true);
      widget.onComplete();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _index++;
      _entry = '';
      _wrong = false;
    });
  }

  /// Hardware keys too — handy on the web preview and with a paired keyboard.
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final char = event.character;
    if (char != null && char.length == 1 && '0123456789'.contains(char)) {
      _digit(int.parse(char));
    } else if (key == LogicalKeyboardKey.backspace) {
      _backspace();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProgressBars(
              total: _problems.length,
              completed: _done ? _problems.length : _index,
            ),
            const Gap(AppTokens.space24),
            AnimatedSwitcher(
              duration: AppTokens.motionBase,
              switchInCurve: AppTokens.easeStandard,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.15, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                '${_current.prompt} =',
                key: ValueKey(_index),
                style: text.displayMedium?.copyWith(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Gap(AppTokens.space16),
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                // Damped sine: three quick swings that settle back to centre.
                final v = _shake.value;
                final dx = sin(v * pi * 6) * 12 * (1 - v);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: _AnswerField(entry: _entry, wrong: _wrong),
            ),
            SizedBox(
              height: 28,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _wrong ? 1 : 0,
                  duration: AppTokens.motionFast,
                  child: Text(
                    'Not quite — try again',
                    style: text.bodySmall?.copyWith(color: t.danger),
                  ),
                ),
              ),
            ),
            const Gap(AppTokens.space8),
            _Keypad(
              canSubmit: _entry.isNotEmpty && !_done,
              onDigit: _digit,
              onBackspace: _backspace,
              onClear: _clear,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// One pill per problem: filled once solved, outlined for the one in play.
class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.total, required this.completed});

  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const Gap.w(AppTokens.space8),
          AnimatedContainer(
            duration: AppTokens.motionBase,
            curve: AppTokens.easeStandard,
            width: i == completed ? 40 : 28,
            height: 6,
            decoration: BoxDecoration(
              color: i < completed
                  ? t.missionAccent
                  : i == completed
                      ? t.missionAccent.withValues(alpha: 0.35)
                      : t.surface2,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            ),
          ),
        ],
      ],
    );
  }
}

/// The read-only display above the keypad: typed digits, or a faint "?"
/// placeholder. Borders red after a wrong answer until the next key press.
class _AnswerField extends StatelessWidget {
  const _AnswerField({required this.entry, required this.wrong});

  final String entry;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: AppTokens.motionFast,
      width: 200,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.surface1,
        borderRadius: AppTokens.cornerLg,
        border: Border.all(
          color: wrong ? t.danger : t.hairline,
          width: wrong ? 2 : 1,
        ),
      ),
      child: Text(
        entry.isEmpty ? '?' : entry,
        key: const ValueKey('math-answer'),
        style: text.displaySmall?.copyWith(
          color: entry.isEmpty ? t.textFaint : t.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.canSubmit,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onSubmit,
  });

  final bool canSubmit;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final digitStyle = text.headlineMedium?.copyWith(color: t.textPrimary);

    Widget digit(int d) => _Key(
          onTap: () => onDigit(d),
          semanticLabel: '$d',
          child: Text('$d', style: digitStyle),
        );

    Widget row(List<Widget> keys) => Row(
          children: [
            for (var i = 0; i < keys.length; i++) ...[
              if (i > 0) const Gap.w(AppTokens.space12),
              Expanded(child: keys[i]),
            ],
          ],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ]) ...[
          row([for (final d in r) digit(d)]),
          const Gap(AppTokens.space12),
        ],
        row([
          _Key(
            onTap: onBackspace,
            onLongPress: onClear,
            semanticLabel: 'Delete',
            child: Icon(Icons.backspace_outlined, color: t.textSecondary),
          ),
          digit(0),
          _Key(
            onTap: canSubmit ? onSubmit : null,
            semanticLabel: 'Check answer',
            filled: true,
            child: Icon(
              Icons.check_rounded,
              size: 30,
              color: canSubmit ? t.onBrand : t.textFaint,
            ),
          ),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.onLongPress,
    this.filled = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String semanticLabel;

  /// The brand-filled check key; the rest sit on [AppTokens.surface2].
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    final color = filled && enabled ? t.brand : t.surface2;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppTokens.motionFast,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: AppTokens.cornerMd,
          boxShadow: filled && enabled ? t.glow : null,
        ),
        child: Material(
          color: color,
          borderRadius: AppTokens.cornerMd,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
