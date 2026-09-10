import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/big_switch.dart';
import '../../core/ui/clock_display.dart';
import '../../core/ui/gap.dart';
import '../../core/ui/glass_surface.dart';
import '../../core/ui/primary_button.dart';
import '../../core/ui/section_header.dart';
import '../../core/ui/weekday_selector.dart';

/// A living catalogue of the shared UI primitives, in their common states.
/// Not part of the shipped flows — reachable via the `/gallery` route for
/// visual QA while the redesign is in progress.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _switchOn = true;
  Set<int> _days = {1, 3, 5};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: const Text('Component gallery')),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.space20),
        children: [
          const SectionHeader('Type scale', subtitle: 'display / headline / title / body / label'),
          const Gap(AppTokens.space12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('06:40', style: text.displayLarge),
                Text('Display medium', style: text.displayMedium),
                Text('Headline medium', style: text.headlineMedium),
                Text('Title medium', style: text.titleMedium),
                Text('Body medium — the quiet supporting line.', style: text.bodyMedium),
                Text('LABEL SMALL', style: text.labelSmall),
              ],
            ),
          ),
          const Gap(AppTokens.space32),

          const SectionHeader('ClockDisplay', subtitle: 'tabular blocks, breathing colon'),
          const Gap(AppTokens.space12),
          AppCard(
            child: Center(
              child: ClockDisplay(
                time: DateTime.now(),
                style: text.displayLarge?.copyWith(color: t.textPrimary),
              ),
            ),
          ),
          const Gap(AppTokens.space32),

          const SectionHeader('Semantic colors'),
          const Gap(AppTokens.space12),
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space8,
            children: [
              _Swatch('brand', t.brand),
              _Swatch('missionAccent', t.missionAccent),
              _Swatch('success', t.success),
              _Swatch('warning', t.warning),
              _Swatch('danger', t.danger),
              _Swatch('surface1', t.surface1),
              _Swatch('surface2', t.surface2),
            ],
          ),
          const Gap(AppTokens.space32),

          const SectionHeader('AppCard'),
          const Gap(AppTokens.space12),
          const AppCard(child: Text('Plain card')),
          const Gap(AppTokens.space8),
          AppCard(onTap: () {}, child: const Text('Tappable card (ripple)')),
          const Gap(AppTokens.space8),
          const AppCard(selected: true, child: Text('Selected card (brand hairline)')),
          const Gap(AppTokens.space8),
          const AppCard(elevated: true, child: Text('Elevated card (shadowCard)')),
          const Gap(AppTokens.space32),

          const SectionHeader('BigSwitch'),
          const Gap(AppTokens.space12),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_switchOn ? 'On' : 'Off', style: text.titleMedium),
                BigSwitch(
                  value: _switchOn,
                  onChanged: (v) => setState(() => _switchOn = v),
                ),
              ],
            ),
          ),
          const Gap(AppTokens.space8),
          const AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Disabled'), BigSwitch(value: false, onChanged: null)],
            ),
          ),
          const Gap(AppTokens.space32),

          const SectionHeader('WeekdaySelector'),
          const Gap(AppTokens.space12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WeekdaySelector(
                  selected: _days,
                  onChanged: (d) => setState(() => _days = d),
                ),
                const Gap(AppTokens.space16),
                Text('Read-only, small:', style: text.bodySmall),
                const Gap(AppTokens.space8),
                WeekdaySelector(selected: _days, readOnly: true, size: 22),
              ],
            ),
          ),
          const Gap(AppTokens.space32),

          const SectionHeader('Buttons'),
          const Gap(AppTokens.space12),
          PrimaryButton(label: 'Primary (amber glow)', onPressed: () {}),
          const Gap(AppTokens.space8),
          const PrimaryButton(label: 'Primary (disabled)', onPressed: null),
          const Gap(AppTokens.space8),
          FilledButton(onPressed: () {}, child: const Text('Filled button')),
          const Gap(AppTokens.space8),
          OutlinedButton(onPressed: () {}, child: const Text('Outlined button')),
          const Gap(AppTokens.space8),
          TextButton(onPressed: () {}, child: const Text('Text button')),
          const Gap(AppTokens.space32),

          const SectionHeader('GlassSurface', subtitle: 'blurs whatever is behind it'),
          const Gap(AppTokens.space12),
          Stack(
            children: [
              Row(
                children: [
                  Expanded(child: Container(height: 96, color: t.brand)),
                  Expanded(child: Container(height: 96, color: t.missionAccent)),
                ],
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.space12),
                  child: GlassSurface(
                    child: Center(
                      child: Text('Frosted panel', style: text.titleSmall),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppTokens.space32),

          const SectionHeader('Inputs'),
          const Gap(AppTokens.space12),
          const TextField(decoration: InputDecoration(hintText: 'Label, e.g. Gym')),
          const Gap(AppTokens.space40),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppTokens.cornerSm,
            border: Border.all(color: context.tokens.hairline),
          ),
        ),
        const Gap(AppTokens.space4),
        Text(name, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
