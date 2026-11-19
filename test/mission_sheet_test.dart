import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rise_protocol/core/theme/app_theme.dart';
import 'package:rise_protocol/data/alarm.dart';
import 'package:rise_protocol/features/alarms/widgets/mission_sheet.dart';

/// A typical phone: 360 x 800 logical pixels.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  test('missionCount survives a database round trip', () {
    const alarm = Alarm(hour: 7, minute: 0, missionDifficulty: 3, missionCount: 5);
    final back = Alarm.fromMap(alarm.toMap());
    expect(back.missionDifficulty, 3);
    expect(back.missionCount, 5);
  });

  test('rows written before missionCount existed default to 3', () {
    final map = const Alarm(hour: 7, minute: 0).toMap()..remove('mission_count');
    expect(Alarm.fromMap(map).missionCount, 3);
  });

  test('missionSummary', () {
    const math = Alarm(hour: 7, minute: 0, missionDifficulty: 2, missionCount: 4);
    expect(missionSummary(math), 'Math · Medium · 4');
    expect(
      missionSummary(math.copyWith(missionType: MissionType.none)),
      'None',
    );
    expect(
      missionSummary(math.copyWith(missionType: MissionType.qna)),
      'Question',
    );
  });

  testWidgets('the sheet returns the chosen difficulty and problem count',
      (tester) async {
    usePhoneScreen(tester);
    Alarm? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showMissionSheet(
                    context,
                    const Alarm(hour: 7, minute: 0),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result?.missionType, MissionType.math);
    expect(result?.missionDifficulty, 3);
    expect(result?.missionCount, 5);
  });

  testWidgets('a custom question needs both fields before Done is enabled',
      (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showMissionSheet(
                  context,
                  const Alarm(hour: 7, minute: 0),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();

    FilledButton done() => tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Done'),
            matching: find.byType(FilledButton),
          ),
        );
    expect(done().onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Question'), 'Kids leave at?');
    await tester.enterText(find.widgetWithText(TextField, 'Answer'), '7:45');
    await tester.pumpAndSettle();
    expect(done().onPressed, isNotNull);
  });
}
