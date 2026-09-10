import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The time, rendered as an instrument: hours and minutes as separate
/// fixed-width tabular blocks so nothing shifts as digits change, with a
/// colon that breathes once every ~1.4s.
///
/// Defaults to `displayLarge` (Space Grotesk) in [AppTokens.ringingForeground];
/// pass [style] to override.
class ClockDisplay extends StatefulWidget {
  const ClockDisplay({
    super.key,
    required this.time,
    this.style,
    this.pulseColon = true,
  });

  final DateTime time;
  final TextStyle? style;
  final bool pulseColon;

  @override
  State<ClockDisplay> createState() => _ClockDisplayState();
}

class _ClockDisplayState extends State<ClockDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulseColon) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ClockDisplay old) {
    super.didUpdateWidget(old);
    if (widget.pulseColon && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulseColon && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = (widget.style ??
            Theme.of(context).textTheme.displayLarge ??
            const TextStyle())
        .copyWith(color: widget.style?.color ?? t.ringingForeground);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(_two(widget.time.hour), style: base),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final v = widget.pulseColon
                ? 0.35 + 0.65 * Curves.easeInOut.transform(_controller.value)
                : 1.0;
            return Opacity(opacity: v, child: child);
          },
          child: Text(':', style: base),
        ),
        Text(_two(widget.time.minute), style: base),
      ],
    );
  }
}
