import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// The custom question/answer mission: the user wrote their own challenge
/// (and its answer) when creating the alarm, and has to type that answer
/// back to dismiss it — a personal version of the math mission for anything
/// a math problem can't cover ("what time do the kids leave?", "what's
/// today's first meeting?").
///
/// Matching is forgiving on purpose (trimmed, case-insensitive) — the point
/// is proving you're awake enough to recall the answer, not a spelling test.
/// A wrong answer never penalizes, same philosophy as [MathMissionView].
class QnaMissionView extends StatefulWidget {
  const QnaMissionView({
    super.key,
    required this.question,
    required this.answer,
    required this.onComplete,
    this.onInteraction,
  });

  final String question;
  final String answer;
  final VoidCallback onComplete;
  final VoidCallback? onInteraction;

  @override
  State<QnaMissionView> createState() => _QnaMissionViewState();
}

class _QnaMissionViewState extends State<QnaMissionView> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isCorrect =>
      _controller.text.trim().toLowerCase() ==
      widget.answer.trim().toLowerCase();

  void _submit() {
    widget.onInteraction?.call();
    if (_isCorrect) {
      widget.onComplete();
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() => _error = 'Not quite — try again');
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.question.trim().isNotEmpty
        ? widget.question
        : 'Type the answer to dismiss';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'YOUR QUESTION',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            question,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              errorText: _error,
              hintText: 'Your answer',
            ),
            onChanged: (_) {
              widget.onInteraction?.call();
              if (_error != null) setState(() => _error = null);
            },
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
