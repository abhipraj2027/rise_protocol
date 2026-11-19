import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rise_protocol/core/theme/app_theme.dart';
import 'package:rise_protocol/features/ringing/missions/math_mission.dart';

Future<void> pumpMission(
  WidgetTester tester, {
  required VoidCallback onComplete,
  int problemCount = 3,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.ringing(),
      home: Scaffold(
        body: Center(
          child: MathMissionView(
            difficulty: 3,
            problemCount: problemCount,
            onComplete: onComplete,
          ),
        ),
      ),
    ),
  );
}

/// Reads the on-screen problem ("12 + 7 =" / "40 − 3 =") and solves it.
int currentAnswer(WidgetTester tester) {
  final prompt = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((s) => s.endsWith(' ='));
  final parts = prompt.split(' ');
  final a = int.parse(parts[0]);
  final b = int.parse(parts[2]);
  return parts[1] == '+' ? a + b : a - b;
}

/// Taps keypad keys only — the answer display shows the same digits.
Future<void> typeNumber(WidgetTester tester, int n) async {
  for (final digit in '$n'.split('')) {
    await tester.tap(
      find.descendant(of: find.byType(InkWell), matching: find.text(digit)),
    );
    await tester.pump();
  }
}

String shownAnswer(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('math-answer'))).data!;

double feedbackOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find.ancestor(
      of: find.text('Not quite — try again'),
      matching: find.byType(AnimatedOpacity),
    ))
    .opacity;

/// A wrong number none of whose leading digits is the right answer, so
/// typing it never triggers the auto-advance.
int wrongAnswer(WidgetTester tester) => currentAnswer(tester) + 1;

void main() {
  testWidgets('correct answers advance on their own and complete the mission',
      (tester) async {
    var completed = false;
    await pumpMission(tester, onComplete: () => completed = true);

    for (var i = 0; i < 3; i++) {
      expect(completed, isFalse);
      await typeNumber(tester, currentAnswer(tester));
      await tester.pumpAndSettle();
    }
    expect(completed, isTrue);
  });

  testWidgets('a wrong answer clears the entry and shows feedback',
      (tester) async {
    var completed = false;
    await pumpMission(
      tester,
      problemCount: 1,
      onComplete: () => completed = true,
    );

    final wrong = wrongAnswer(tester);
    await typeNumber(tester, wrong);
    expect(shownAnswer(tester), '$wrong');
    expect(feedbackOpacity(tester), 0);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(shownAnswer(tester), '?');
    expect(feedbackOpacity(tester), 1);
    expect(completed, isFalse);
  });

  testWidgets('backspace removes the last digit', (tester) async {
    await pumpMission(tester, problemCount: 1, onComplete: () {});

    final wrong = '${wrongAnswer(tester)}';
    await typeNumber(tester, int.parse(wrong));
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    final rest = wrong.substring(0, wrong.length - 1);
    expect(shownAnswer(tester), rest.isEmpty ? '?' : rest);
  });
}
