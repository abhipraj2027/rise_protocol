import 'package:flutter/material.dart';

import '../../data/alarm.dart';

/// The icon and short name shown for each [MissionType] — shared by the mission picker in
/// the editor and the small badge on each alarm card.
extension MissionTypeIcon on MissionType {
  IconData get icon => switch (this) {
        MissionType.none => Icons.touch_app_outlined,
        MissionType.math => Icons.calculate_outlined,
        MissionType.shake => Icons.vibration,
        MissionType.photo => Icons.photo_camera_outlined,
        MissionType.barcode => Icons.qr_code_scanner,
        MissionType.qna => Icons.quiz_outlined,
      };

  /// One-word name for tight spots like the chip on an alarm card.
  String get shortLabel => switch (this) {
        MissionType.none => 'No mission',
        MissionType.math => 'Math',
        MissionType.shake => 'Shake',
        MissionType.photo => 'Photo',
        MissionType.barcode => 'Barcode',
        MissionType.qna => 'Question',
      };
}
