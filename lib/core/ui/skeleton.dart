import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A placeholder block with a slow shimmer, used while real content loads.
/// Wrap several in a column to mock a list.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = AppTokens.radiusSm,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final x = _controller.value * 2 - 1; // -1 → 1
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(x - 0.6, 0),
                end: Alignment(x + 0.6, 0),
                colors: [t.surface2, t.surface1, t.surface2],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The alarm list's loading state: a hero-shaped block plus a few tile rows.
class AlarmListSkeleton extends StatelessWidget {
  const AlarmListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space12,
        AppTokens.space16,
        AppTokens.space16,
      ),
      children: const [
        SkeletonBox(height: 132, radius: AppTokens.radiusXl),
        SizedBox(height: AppTokens.space24),
        SkeletonBox(height: 96, radius: AppTokens.radiusLg),
        SizedBox(height: AppTokens.space12),
        SkeletonBox(height: 96, radius: AppTokens.radiusLg),
        SizedBox(height: AppTokens.space12),
        SkeletonBox(height: 96, radius: AppTokens.radiusLg),
      ],
    );
  }
}
