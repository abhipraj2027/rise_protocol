import 'package:flutter/widgets.dart';

/// Fixed empty space. [Gap] is vertical (the common case inside `Column` /
/// `ListView`); use [Gap.w] for a horizontal gap inside a `Row`.
///
/// Reads more cleanly than scattering `SizedBox(height: …)` through a
/// layout, and pairs naturally with the `AppTokens.space*` scale.
class Gap extends StatelessWidget {
  const Gap(this.extent, {super.key}) : _horizontal = false;
  const Gap.w(this.extent, {super.key}) : _horizontal = true;

  final double extent;
  final bool _horizontal;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _horizontal ? extent : null,
        height: _horizontal ? null : extent,
      );
}
