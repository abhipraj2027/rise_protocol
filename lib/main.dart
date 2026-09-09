import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/alarm_bridge.dart';
import 'core/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'data/alarm.dart';
import 'features/alarms/alarm_list_screen.dart';
import 'features/alarms/edit_alarm_screen.dart';
import 'features/dev/gallery_screen.dart';
import 'features/onboarding/permission_onboarding_screen.dart';
import 'features/ringing/ringing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: RiseProtocolApp()));
}

class RiseProtocolApp extends ConsumerWidget {
  const RiseProtocolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Rise Protocol',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // The native full-screen-intent Activity launches a *second* Flutter
      // engine directly into the ringing route (see
      // android/.../AlarmRingingActivity.kt), passing the alarm id + mission
      // type as the initial route. WidgetsApp exposes that via
      // `defaultRouteName`, which we parse once at startup.
      initialRoute: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      onGenerateRoute: (settings) => _onGenerateRoute(settings, ref),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings, WidgetRef ref) {
    final uri = Uri.parse(settings.name ?? '/');

    if (uri.path == '/ringing') {
      final id = int.tryParse(uri.queryParameters['id'] ?? '') ?? -1;
      final mission = MissionType.fromName(uri.queryParameters['mission'] ?? 'none');
      final label = uri.queryParameters['label'] ?? '';
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => Theme(
          data: AppTheme.ringing(),
          child: RingingScreen(alarmId: id, label: label, missionType: mission),
        ),
      );
    }

    if (uri.path == '/edit') {
      final id = int.tryParse(uri.queryParameters['id'] ?? '');
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => EditAlarmScreen(alarmId: id),
      );
    }

    if (uri.path == '/gallery') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const GalleryScreen(),
      );
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (context) => const _HomeBootstrap(),
    );
  }
}

/// Runs the on-open native cleanup + resync described in [AlarmBridge]
/// before showing the alarm list.
class _HomeBootstrap extends ConsumerStatefulWidget {
  const _HomeBootstrap();

  @override
  ConsumerState<_HomeBootstrap> createState() => _HomeBootstrapState();
}

class _HomeBootstrapState extends ConsumerState<_HomeBootstrap> {
  late final Future<bool> _onboardingComplete;

  @override
  void initState() {
    super.initState();
    ref.read(alarmBridgeProvider).stopAnyRingingService();
    _onboardingComplete = ref.read(appPrefsProvider).isOnboardingComplete();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _onboardingComplete,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data!
            ? const AlarmListScreen()
            : const PermissionOnboardingScreen();
      },
    );
  }
}
