import 'dart:math';

import 'package:flutter/material.dart';

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
class MathMissionView extends StatefulWidget {
  const MathMissionView({
    super.key,
    required this.difficulty,
    required this.onComplete,
    this.problemCount = 3,
  });

  final int difficulty;
  final int problemCount;
  final VoidCallback onComplete;

  @override
  State<MathMissionView> createState() => _MathMissionViewState();
}

class _MathMissionViewState extends State<MathMissionView> {
  late List<MathProblem> _problems;
  int _index = 0;
  final _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _problems = List.generate(
      widget.problemCount,
      (_) => MathProblem.random(widget.difficulty),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final entered = int.tryParse(_controller.text.trim());
    final current = _problems[_index];
    if (entered == current.answer) {
      _controller.clear();
      if (_index == _problems.length - 1) {
        widget.onComplete();
      } else {
        setState(() {
          _index++;
          _error = null;
        });
      }
    } else {
      setState(() => _error = 'Not quite — try again');
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _problems[_index];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Problem ${_index + 1} of ${_problems.length}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          current.prompt,
          style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              errorText: _error,
              hintText: 'Answer',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(220, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
