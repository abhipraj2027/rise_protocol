import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Fades + lifts a list item into place on first appearance, offset by
/// [index] so a list settles in a quick cascade rather than all at once.
/// Give it a stable [Key] tied to the item's id so it doesn't replay when
/// the list rebuilds for an unrelated change.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 45),
  });

  final int index;
  final Widget child;
  final Duration step;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTokens.motionBase,
    );
    Future.delayed(widget.step * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final v = AppTokens.easeStandard.transform(_controller.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 14),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
