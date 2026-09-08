# Rise Protocol

An Alarmy-style alarm app: exact-time alarms that survive a killed app and
Doze mode, force a full-screen ringing UI over the lock screen, and require
a mission (starting with a math problem) before they'll stop. This is the
**Phase 0 + Phase 1** slice from the plan doc — the native wake-up spike plus
the basic alarm list/create/ring/snooze/dismiss flow — for Android.

## ⚠️ Before you do anything else

This project was written in a sandbox with no network access to
`storage.googleapis.com`/`dl.google.com`, so the Flutter SDK itself couldn't
be installed here — **none of this code has been run, compiled, or
`flutter analyze`'d yet.** It's written carefully and should be very close,
but treat the first `flutter pub get` / `flutter run` as the real first
compile, and expect a handful of small fixes (a missing import, a Gradle
version mismatch, etc.) — completely normal for a from-scratch scaffold.

## Getting it running

1. **Install Flutter** (3.22+) and Android Studio / an Android SDK, if you
   haven't already: https://docs.flutter.dev/get-started/install
2. **Scaffold a fresh project so Gradle's wrapper/boilerplate is correct
   for your Flutter version** — don't hand-copy Gradle files, generate them:
   ```bash
   flutter create --org com.riseprotocol --project-name rise_protocol rise_protocol_scaffold
   ```
3. **Copy this project's custom files over the generated ones**, keeping the
   scaffold's `android/app/build.gradle`, `android/settings.gradle`,
   `android/gradle/`, and `ios/` as-is:
   - `pubspec.yaml` → replace
   - `analysis_options.yaml` → replace
   - `lib/` → replace entirely
   - `assets/` → copy in
   - `android/app/src/main/AndroidManifest.xml` → replace
   - `android/app/src/main/kotlin/com/riseprotocol/app/` → replace entirely
     (delete the generated `MainActivity.kt` in whatever package the
     scaffold used, since ours lives at this exact package path)
   - `android/app/src/main/res/values/styles.xml` → replace
   - `android/app/src/main/res/drawable/launch_background.xml` → replace
4. **Open `android/app/build.gradle`** and set:
   - `applicationId "com.riseprotocol.app"`
   - `minSdkVersion 26` (needed for `setShowWhenLocked`/`setTurnScreenOn`;
     the code has an older-API fallback path but 26+ is the well-tested one)
5. Drop a looping alarm tone at `assets/sounds/default_alarm.mp3` (see the
   placeholder file in that folder — the app still runs without it, just
   silently).
6. ```bash
   flutter pub get
   flutter run
   ```
7. On the device: create an alarm 1–2 minutes out, then **lock the screen**
   (don't just background the app — that's the whole point of the test) and
   wait. This is the actual Phase 0 spike validation.

## Cloud builds (no local Android Studio required)

`.github/workflows/build.yml` builds a release APK on GitHub's servers every
time you push to `main`, open a pull request, or trigger it manually. To use
it:

1. Push this project (after you've folded it into a `flutter create` scaffold
   per the steps above) to a GitHub repository.
2. Open the repo's **Actions** tab — a "Build Android APK" run starts
   automatically on push, or click **Run workflow** to trigger it by hand.
3. Once it finishes (green check), open that run and scroll to
   **Artifacts** → download `rise-protocol-release-apk`.
4. Unzip it to get `app-release.apk`, then copy it to your phone and install
   it (allow "install from unknown sources" if prompted).

The workflow pins Flutter `3.24.0` for reproducibility and runs
`flutter analyze` before building, so a build failure in Actions will point
at an actual lint/type error, not an environment difference. If you upgrade
Flutter locally, bump the `flutter-version` in the workflow file to match.

## What's real vs. what's a stub

| Area | Status |
|---|---|
| Cloud CI build (GitHub Actions → downloadable APK) | Implemented |
| Alarm CRUD (list, create, edit, delete, enable toggle) | Implemented |
| Repeat days, snooze length | Implemented |
| SQLite persistence (`sqflite`, no code-gen step) | Implemented |
| Exact alarm scheduling (`AlarmManager.setAlarmClock`) | Implemented |
| Full-screen ringing over lock screen | Implemented (notification full-screen-intent + best-effort direct launch — see `AlarmRingService.kt` doc comment) |
| Boot-persistence (`BootReceiver`) | Implemented, with a known simplification — see the comment at the top of `BootReceiver.kt`: it re-arms the *next* stored trigger but doesn't yet persist full repeat rules, so a long-dead-battery edge case on a repeating alarm can miss one cycle until the app is reopened |
| Foreground service / wake lock | Implemented |
| Math mission | Implemented |
| Shake / photo / barcode missions | UI shows them as "coming soon" and falls back to plain dismiss — this is Phase 2 |
| Battery-optimization / exact-alarm-permission onboarding screen | Implemented (`lib/features/onboarding/`) — shown on first launch, re-checks status when you return from system settings, and is reachable again anytime via the shield icon in the alarm list's app bar |
| Sleep tracking / anti-oversleep | Not started — Phase 4 in the plan |
| iOS | Not started — Dart/UI code is cross-platform-ready, but there's no native iOS scheduling/notification code yet (Phase 5). Apple's model is fundamentally different (no true full-screen force-wake), so this is a separate implementation, not a port |
| Automated tests | None yet — the plan's Phase 3 (reliability hardening) is where integration tests that kill/relaunch mid-alarm should get written |

## How the pieces fit together

```
Dart alarm list  →  AlarmScheduler (lib/core)  →  MethodChannel  →  Kotlin AlarmScheduler.kt
                                                                          │
                                                             AlarmManager.setAlarmClock
                                                                          │
                                                                          ▼
                                                                  AlarmReceiver.kt
                                                                          │
                                                          starts foreground service
                                                                          ▼
                                                                AlarmRingService.kt
                                                        (wake lock, full-screen-intent
                                                         notification, best-effort
                                                         direct Activity launch)
                                                                          │
                                                                          ▼
                                                          AlarmRingingActivity.kt
                                                    (own FlutterEngine, initial route
                                                     "/ringing?id=..&mission=..")
                                                                          │
                                                                          ▼
                                                        RingingScreen (lib/features/ringing)
                                                       plays audio, shows mission, calls
                                                       dismissRinging/snoozeRinging back
                                                       through the same MethodChannel
```

`BootReceiver.kt` reads the same SharedPreferences mirror `AlarmScheduler.kt`
writes to, so it can re-arm alarms after a reboot without waiting for Dart to
start.

## Immediate next steps, in order

1. Push to GitHub and get a green build out of `.github/workflows/build.yml` — this is the real first compile of this codebase, so expect (and fix) a few small errors.
2. Install the resulting APK and validate the Phase 0 spike on a real device: create an alarm 1–2 minutes out, lock the screen, and confirm it actually rings and force-wakes the display.
3. Walk through the permission-onboarding screen on that device and confirm the exact-alarm and battery-optimization checks reflect reality.
4. Test on at least one Samsung and one Xiaomi/OnePlus device if you can — their background-kill behavior is where most "the alarm just didn't go off" bug reports come from.
5. Then move to Phase 2 (shake, photo, barcode missions) per the plan doc.
